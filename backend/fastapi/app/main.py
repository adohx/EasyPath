import math
import os
from typing import Optional

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

MOTIS_URL = os.getenv("MOTIS_URL", "http://motis:8080")
OVERPASS_URL = os.getenv("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
OSRM_URL = os.getenv("OSRM_URL", "https://router.project-osrm.org")
NOMINATIM_URL = "https://nominatim.openstreetmap.org"
USER_AGENT = "AccessibilityNavigationAssistant/2.0"

# Windsor bounding box: west, south, east, north
WINDSOR_BBOX = (-83.2, 42.2, -82.8, 42.5)

app = FastAPI(
    title="Accessibility Navigation Assistant API",
    description="Backend API for the ANA app - Phase 2 (live data)",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request models ──────────────────────────────────────────────────────────────

class RoutePlanRequest(BaseModel):
    origin: dict
    destination: dict
    origin_name: Optional[str] = "Current Location"
    destination_name: Optional[str] = "Destination"


# ── Geo helpers ─────────────────────────────────────────────────────────────────

def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance in meters between two lat/lon points."""
    R = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Bearing in degrees (0 = north) from point 1 to point 2."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    x = math.sin(dl) * math.cos(p2)
    y = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def _decode_polyline(encoded: str, precision: int) -> list[list[float]]:
    """Decode a Google-style encoded polyline into [lat, lon] pairs.

    MOTIS encodes each leg's geometry at the precision given in its
    ``legGeometry.precision`` field (7 rather than the more common 5),
    so the scaling factor must be passed in explicitly.
    """
    factor = 10**precision
    coordinates: list[list[float]] = []
    index = 0
    lat = 0
    lon = 0
    while index < len(encoded):
        for is_latitude in (True, False):
            shift = 0
            result = 0
            while True:
                byte = ord(encoded[index]) - 63
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20:
                    break
            delta = ~(result >> 1) if result & 1 else (result >> 1)
            if is_latitude:
                lat += delta
            else:
                lon += delta
        coordinates.append([lat / factor, lon / factor])
    return coordinates


# ── OSM / Overpass helpers ──────────────────────────────────────────────────────

# Map OSM amenity/shop/tourism tags → unified category key
_OSM_CATEGORY: dict[str, str] = {
    "restaurant": "restaurant", "cafe": "restaurant", "fast_food": "restaurant",
    "bar": "restaurant", "pub": "restaurant", "food_court": "restaurant",
    "pharmacy": "pharmacy", "chemist": "pharmacy",
    "hospital": "hospital", "clinic": "hospital", "doctors": "hospital",
    "bank": "bank", "atm": "bank",
    "school": "school", "college": "school", "university": "school",
    "library": "library",
    "supermarket": "shop", "convenience": "shop", "clothes": "shop",
    "electronics": "shop", "hardware": "shop", "bakery": "shop",
    "hotel": "hotel", "motel": "hotel", "guest_house": "hotel", "hostel": "hotel",
    "parking": "parking",
    "bus_stop": "bus_stop",
    "park": "park", "playground": "park",
}


def _osm_category(tags: dict) -> Optional[str]:
    for key in ("amenity", "shop", "tourism", "leisure", "highway"):
        val = tags.get(key)
        if val and val in _OSM_CATEGORY:
            return _OSM_CATEGORY[val]
    return None


def _overpass_to_categories(
    elements: list[dict], center_lat: float, center_lon: float
) -> dict[str, list]:
    groups: dict[str, list] = {}
    for el in elements:
        if el.get("type") != "node":
            continue
        tags = el.get("tags", {})
        cat = _osm_category(tags)
        if not cat:
            continue
        lat, lon = el.get("lat", center_lat), el.get("lon", center_lon)
        name = (
            tags.get("name")
            or tags.get("brand")
            or tags.get("operator")
            or cat.replace("_", " ").title()
        )
        dist = round(_haversine(center_lat, center_lon, lat, lon))
        bear = round(_bearing(center_lat, center_lon, lat, lon))
        item = {
            "id": f"osm_{el['id']}",
            "name": name,
            "distance_meters": dist,
            "bearing_degrees": bear,
            "coordinates": {"lat": lat, "lon": lon},
        }
        groups.setdefault(cat, []).append(item)
    # Sort each category by distance
    for items in groups.values():
        items.sort(key=lambda i: i["distance_meters"])
    return groups


# ── OSRM route parsing ──────────────────────────────────────────────────────────

_MODIFIER_TO_WORD = {
    "left": "left", "right": "right",
    "sharp left": "sharp left", "sharp right": "sharp right",
    "slight left": "slightly left", "slight right": "slightly right",
    "straight": "straight ahead", "uturn": "U-turn",
}


def _osrm_step_instruction(step: dict) -> str:
    maneuver = step.get("maneuver", {})
    mtype = maneuver.get("type", "")
    modifier = maneuver.get("modifier", "")
    name = step.get("name") or "the road"
    dist = round(step.get("distance", 0))

    if mtype == "depart":
        direction = _abs_direction(maneuver.get("bearing_after", 0))
        return f"Head {direction} on {name}" + (f" for {dist} metres" if dist else "")
    if mtype == "arrive":
        return "Arrive at your destination"
    if mtype in ("turn", "new name", "continue"):
        word = _MODIFIER_TO_WORD.get(modifier, modifier)
        if word == "straight ahead":
            return f"Continue straight on {name}" + (f" for {dist} metres" if dist else "")
        return f"Turn {word} onto {name}"
    if mtype == "roundabout":
        exit_n = maneuver.get("exit", 1)
        return f"At the roundabout, take exit {exit_n} onto {name}"
    return f"Continue on {name}"


def _abs_direction(bearing: float) -> str:
    dirs = ["north", "northeast", "east", "southeast",
            "south", "southwest", "west", "northwest"]
    return dirs[round(bearing / 45) % 8]


# ── MOTIS step parsing ──────────────────────────────────────────────────────────

_MOTIS_DIRECTION_PHRASES = {
    "DEPART": "Head out",
    "CONTINUE": "Continue",
    "SLIGHTLY_LEFT": "Turn slightly left",
    "LEFT": "Turn left",
    "HARD_LEFT": "Turn sharply left",
    "SLIGHTLY_RIGHT": "Turn slightly right",
    "RIGHT": "Turn right",
    "HARD_RIGHT": "Turn sharply right",
    "UTURN_LEFT": "Make a U-turn",
    "UTURN_RIGHT": "Make a U-turn",
    "CIRCLE_CLOCKWISE": "Enter the roundabout",
    "CIRCLE_COUNTERCLOCKWISE": "Enter the roundabout",
    "ELEVATOR": "Take the elevator",
}

# Directions that describe travelling along a street rather than turning
# onto one, so they take "on {street}" instead of "onto {street}".
_MOTIS_STRAIGHT_DIRECTIONS = {"DEPART", "CONTINUE"}


def _motis_step_instruction(step: dict) -> str:
    direction = str(step.get("relativeDirection") or "CONTINUE").upper()
    street = str(step.get("streetName") or "")
    dist = round(step.get("distance") or 0)
    phrase = _MOTIS_DIRECTION_PHRASES.get(
        direction, direction.replace("_", " ").capitalize()
    )

    if direction in _MOTIS_STRAIGHT_DIRECTIONS:
        inst = f"{phrase} on {street}" if street else f"{phrase} straight"
    elif street:
        inst = f"{phrase} onto {street}"
    else:
        inst = phrase

    return f"{inst} for {dist} metres" if dist else inst


def _osrm_to_route(
    osrm_route: dict,
    route_id: str,
    origin_lat: float, origin_lon: float,
    dest_lat: float, dest_lon: float,
    origin_name: str, dest_name: str,
    traffic_signal_positions: list[tuple[float, float]],
) -> dict:
    legs = osrm_route.get("legs", [])
    steps = legs[0].get("steps", []) if legs else []

    total_distance = round(osrm_route.get("distance", 0))
    total_duration = round(osrm_route.get("duration", 0))

    # Extract polyline geometry: OSRM returns [lon, lat], convert to [lat, lon]
    geojson_coords = osrm_route.get("geometry", {}).get("coordinates", [])
    geometry = [[c[1], c[0]] for c in geojson_coords]

    # Build navigation steps
    nav_steps = []
    for s in steps:
        inst = _osrm_step_instruction(s)
        nav_steps.append({
            "instruction": inst,
            "distance_meters": round(s.get("distance", 0)),
        })

    # Build a single walking leg
    built_legs = [
        {
            "id": f"{route_id}_leg_1",
            "mode": "walk",
            "from": {"name": origin_name, "coordinates": {"lat": origin_lat, "lon": origin_lon}},
            "to": {"name": dest_name, "coordinates": {"lat": dest_lat, "lon": dest_lon}},
            "duration_seconds": total_duration,
            "distance_meters": total_distance,
            "steps": nav_steps,
        }
    ]

    # Functional points: significant turns + destination entrance
    functional_points = []
    fp_idx = 1
    for s in steps:
        maneuver = s.get("maneuver", {})
        mtype = maneuver.get("type", "")
        modifier = maneuver.get("modifier", "")
        loc = maneuver.get("location", [origin_lon, origin_lat])
        lat, lon = loc[1], loc[0]

        if mtype == "arrive":
            functional_points.append({
                "id": f"{route_id}_fp_{fp_idx}",
                "type": "building_entrance",
                "description": f"{dest_name} — destination",
                "importance": "navigation",
                "trigger_distance_meters": 40,
                "coordinates": {"lat": dest_lat, "lon": dest_lon},
            })
            fp_idx += 1
        elif mtype == "turn" and modifier in ("left", "right", "sharp left", "sharp right"):
            name = s.get("name") or "intersection"
            functional_points.append({
                "id": f"{route_id}_fp_{fp_idx}",
                "type": "turn",
                "description": f"Turn {_MODIFIER_TO_WORD.get(modifier, modifier)} onto {name}",
                "importance": "navigation",
                "trigger_distance_meters": 30,
                "coordinates": {"lat": lat, "lon": lon},
            })
            fp_idx += 1

    # Risk points: turns near known traffic signals → medium; other significant turns → low
    risk_points = []
    rp_idx = 1
    for s in steps:
        maneuver = s.get("maneuver", {})
        mtype = maneuver.get("type", "")
        modifier = maneuver.get("modifier", "")
        if mtype not in ("turn", "new name") or modifier == "straight":
            continue
        loc = maneuver.get("location", [origin_lon, origin_lat])
        lat, lon = loc[1], loc[0]
        name = s.get("name") or "intersection"

        has_signal = any(
            _haversine(lat, lon, slat, slon) < 60
            for slat, slon in traffic_signal_positions
        )
        risk_points.append({
            "id": f"{route_id}_rp_{rp_idx}",
            "type": "intersection",
            "description": f"{'Signalised intersection' if has_signal else 'Intersection'} at {name}",
            "severity": "medium" if has_signal else "low",
            "trigger_distance_meters": 100 if has_signal else 80,
            "coordinates": {"lat": lat, "lon": lon},
        })
        rp_idx += 1

    # Accessibility score: starts at 85, minus 5 per medium risk, minus 2 per low risk
    medium_count = sum(1 for r in risk_points if r["severity"] == "medium")
    low_count = sum(1 for r in risk_points if r["severity"] == "low")
    score = max(30, 85 - medium_count * 5 - low_count * 2)

    return {
        "id": route_id,
        "mode": "walk",
        "total_duration_seconds": total_duration,
        "total_walking_distance_meters": total_distance,
        "transfer_count": 0,
        "legs": built_legs,
        "geometry": geometry,
        "functional_points": functional_points,
        "risk_points": risk_points,
        "accessibility_summary": {
            "score": score,
            "street_crossings": medium_count + low_count,
            "transfer_count": 0,
            "known_entrances": 1,
            "audible_signals": medium_count,
            "construction_alerts": 0,
            "walking_distance_meters": total_distance,
            "data_complete": True,
        },
    }


# ── Overpass: fetch traffic signals in bounding box ─────────────────────────────

async def _fetch_traffic_signals(
    min_lat: float, min_lon: float, max_lat: float, max_lon: float
) -> list[tuple[float, float]]:
    query = (
        f'[out:json][timeout:15];'
        f'node["highway"="traffic_signals"]'
        f'({min_lat},{min_lon},{max_lat},{max_lon});'
        f'out body;'
    )
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(OVERPASS_URL, data={"data": query}, timeout=15.0)
            if resp.status_code == 200:
                elements = resp.json().get("elements", [])
                return [(el["lat"], el["lon"]) for el in elements if el.get("type") == "node"]
    except Exception:
        pass
    return []


# ── Health ──────────────────────────────────────────────────────────────────────

@app.get("/health")
def health_check():
    return {"status": "ok", "phase": 2}


# ── Place search ────────────────────────────────────────────────────────────────

@app.get("/api/places/search")
async def search_places(q: str):
    """Real place search via Nominatim, bounded to Windsor area."""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{NOMINATIM_URL}/search",
                params={
                    "q": q,
                    "format": "jsonv2",
                    "countrycodes": "ca",
                    "limit": 6,
                    "viewbox": f"{WINDSOR_BBOX[0]},{WINDSOR_BBOX[3]},{WINDSOR_BBOX[2]},{WINDSOR_BBOX[1]}",
                    "bounded": 1,
                    "addressdetails": 1,
                },
                headers={"User-Agent": USER_AGENT},
                timeout=8.0,
            )
        if resp.status_code == 200:
            data = resp.json()
            if data:
                results = []
                for item in data:
                    addr = item.get("address", {})
                    display = item.get("display_name", "")
                    name = (
                        item.get("name")
                        or addr.get("building")
                        or display.split(",")[0].strip()
                    )
                    results.append({
                        "id": f"nominatim_{item['place_id']}",
                        "name": name,
                        "address": display,
                        "coordinates": {
                            "lat": float(item["lat"]),
                            "lon": float(item["lon"]),
                        },
                        "type": item.get("type", "place"),
                    })
                return {"query": q, "results": results}
    except Exception:
        pass

    # Fallback mock
    return {"query": q, "results": _mock_places()}


@app.get("/api/places/reverse")
async def reverse_geocode(lat: float, lon: float):
    """Reverse geocode via Nominatim."""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{NOMINATIM_URL}/reverse",
                params={"lat": lat, "lon": lon, "format": "jsonv2"},
                headers={"User-Agent": USER_AGENT},
                timeout=8.0,
            )
        if resp.status_code == 200:
            data = resp.json()
            return {
                "coordinates": {"lat": lat, "lon": lon},
                "address": data.get("display_name", ""),
                "confidence": "high",
            }
    except Exception:
        pass
    return {
        "coordinates": {"lat": lat, "lon": lon},
        "address": f"{lat:.4f}, {lon:.4f}",
        "confidence": "low",
    }


# ── Route planning ──────────────────────────────────────────────────────────────

@app.post("/api/routes/plan")
async def plan_route(body: RoutePlanRequest):
    """
    Route planning: tries MOTIS first, then OSRM public demo, then mock.
    Automatically extracts functional points and risk points.
    """
    origin = body.origin
    dest = body.destination
    olat, olon = float(origin["lat"]), float(origin["lon"])
    dlat, dlon = float(dest["lat"]), float(dest["lon"])
    oname = body.origin_name or "Current Location"
    dname = body.destination_name or "Destination"

    # Bounding box for traffic signal query
    min_lat = min(olat, dlat) - 0.005
    max_lat = max(olat, dlat) + 0.005
    min_lon = min(olon, dlon) - 0.005
    max_lon = max(olon, dlon) + 0.005
    signals = await _fetch_traffic_signals(min_lat, min_lon, max_lat, max_lon)

    # 1. Try MOTIS
    motis_routes = await _plan_via_motis(olat, olon, dlat, dlon, oname, dname, signals)
    if motis_routes:
        return {"routes": motis_routes}

    # 2. Try OSRM public demo server (foot profile)
    osrm_routes = await _plan_via_osrm(olat, olon, dlat, dlon, oname, dname, signals)
    if osrm_routes:
        return {"routes": osrm_routes}

    # 3. Fallback mock
    return {"routes": _mock_routes()}


def _transit_functional_points(route_id, legs_out, dname, dlat, dlon) -> list:
    points = []
    for current, nxt in zip(legs_out, legs_out[1:]):
        if current["mode"] == "walk" and nxt["mode"] == "bus":
            info = nxt["transit_info"]
            points.append({
                "id": f"{route_id}_fp_{len(points) + 1}",
                "type": "bus_board",
                "description": (
                    f"Board Route {info['route']} ({info['headsign']}) "
                    f"at {nxt['from']['name']}"
                ),
                "importance": "required",
                "trigger_distance_meters": 80,
                "coordinates": nxt["from"]["coordinates"],
            })
        elif current["mode"] == "bus" and nxt["mode"] == "walk":
            points.append({
                "id": f"{route_id}_fp_{len(points) + 1}",
                "type": "bus_alight",
                "description": f"Alight at {current['to']['name']}",
                "importance": "required",
                "trigger_distance_meters": 80,
                "coordinates": current["to"]["coordinates"],
            })
        elif current["mode"] == "bus" and nxt["mode"] == "bus":
            info = nxt["transit_info"]
            points.append({
                "id": f"{route_id}_fp_{len(points) + 1}",
                "type": "bus_transfer",
                "description": (
                    f"Transfer to Route {info['route']} "
                    f"({info['headsign']}) at {current['to']['name']}"
                ),
                "importance": "required",
                "trigger_distance_meters": 80,
                "coordinates": current["to"]["coordinates"],
            })

    points.append({
        "id": f"{route_id}_fp_{len(points) + 1}",
        "type": "building_entrance",
        "description": f"{dname} — destination",
        "importance": "navigation",
        "trigger_distance_meters": 40,
        "coordinates": {"lat": dlat, "lon": dlon},
    })
    return points


async def _plan_via_motis(
    olat, olon, dlat, dlon, oname, dname, signals
) -> list:
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{MOTIS_URL}/api/v1/plan",
                params={
                    "fromPlace": f"{olat},{olon}",
                    "toPlace": f"{dlat},{dlon}",
                    "mode": "TRANSIT,WALK",
                    "numItineraries": 2,
                },
                timeout=10.0,
            )
        if resp.status_code != 200:
            return []
        data = resp.json()
        itineraries = data.get("itineraries", [])
        if not itineraries:
            return []

        results = []
        for idx, itin in enumerate(itineraries[:2]):
            route_id = f"motis_route_{idx + 1}"
            legs_out = []
            all_steps = []
            geometry: list[list[float]] = []
            transit_leg_count = 0
            total_walk_distance = 0
            for leg in itin.get("legs", []):
                leg_geometry = leg.get("legGeometry") or {}
                if leg_geometry.get("points"):
                    geometry.extend(
                        _decode_polyline(
                            leg_geometry["points"],
                            leg_geometry.get("precision", 5),
                        )
                    )

                leg_steps = []
                for step in leg.get("steps", []):
                    dist = round(step.get("distance") or 0)
                    leg_steps.append({
                        "instruction": _motis_step_instruction(step),
                        "distance_meters": dist,
                    })
                    all_steps.append(step)

                leg_mode = "walk" if leg.get("mode", "WALK") == "WALK" else "bus"
                if leg_mode == "bus":
                    transit_leg_count += 1
                else:
                    total_walk_distance += round(leg.get("distance", 0))

                leg_out = {
                    "id": f"{route_id}_leg_{len(legs_out) + 1}",
                    "mode": leg_mode,
                    "from": {
                        "name": leg.get("from", {}).get("name", oname),
                        "coordinates": {
                            "lat": leg.get("from", {}).get("lat", olat),
                            "lon": leg.get("from", {}).get("lon", olon),
                        },
                    },
                    "to": {
                        "name": leg.get("to", {}).get("name", dname),
                        "coordinates": {
                            "lat": leg.get("to", {}).get("lat", dlat),
                            "lon": leg.get("to", {}).get("lon", dlon),
                        },
                    },
                    "duration_seconds": round(leg.get("duration", 0)),
                    "distance_meters": round(leg.get("distance", 0)),
                    "steps": leg_steps,
                }
                if leg_mode == "bus":
                    leg_out["transit_info"] = {
                        "route": leg.get("routeShortName", ""),
                        "headsign": leg.get("headsign", ""),
                        "agency": leg.get("agencyName", ""),
                        "scheduled": not leg.get("realTime", False),
                    }
                legs_out.append(leg_out)

            total_dur = round(itin.get("duration", 0))
            total_dist = total_walk_distance
            transfer_count = max(0, transit_leg_count - 1)
            route_mode = "transit" if transit_leg_count > 0 else "walk"
            risk_points = [
                {
                    "id": f"{route_id}_rp_{i + 1}",
                    "type": "intersection",
                    "description": "Signalised intersection",
                    "severity": "medium",
                    "trigger_distance_meters": 100,
                    "coordinates": {"lat": slat, "lon": slon},
                }
                for i, (slat, slon) in enumerate(signals[:5])
            ]
            # Accessibility score: starts at 85, then subtracts per-route
            # penalties so different itineraries for the same request are
            # distinguishable — 3 points per street crossing, 8 per
            # transfer, and 1 per 200 metres of walking.
            crossing_count = len(risk_points)
            score = max(30, 85
                         - crossing_count * 3
                         - transfer_count * 8
                         - round(total_dist / 200))
            results.append({
                "id": route_id,
                "mode": route_mode,
                "total_duration_seconds": total_dur,
                "total_walking_distance_meters": total_dist,
                "transfer_count": transfer_count,
                "geometry": geometry,
                "legs": legs_out,
                "functional_points": _transit_functional_points(
                    route_id, legs_out, dname, dlat, dlon
                ),
                "risk_points": risk_points,
                "accessibility_summary": {
                    "score": score,
                    "street_crossings": crossing_count,
                    "transfer_count": transfer_count,
                    "known_entrances": 1,
                    "audible_signals": crossing_count,
                    "construction_alerts": 0,
                    "walking_distance_meters": total_dist,
                    "data_complete": True,
                },
            })
        return results
    except Exception:
        return []


async def _plan_via_osrm(
    olat, olon, dlat, dlon, oname, dname, signals
) -> list:
    """Walking route from OSRM public demo server."""
    try:
        url = f"{OSRM_URL}/route/v1/foot/{olon},{olat};{dlon},{dlat}"
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                url,
                params={
                    "steps": "true",
                    "overview": "full",
                    "geometries": "geojson",
                    "annotations": "false",
                    "alternatives": "false",
                },
                timeout=10.0,
            )
        if resp.status_code != 200:
            return []
        data = resp.json()
        osrm_routes = data.get("routes", [])
        if not osrm_routes:
            return []

        results = []
        for idx, r in enumerate(osrm_routes[:2]):
            route_id = f"osrm_route_{idx + 1}"
            results.append(
                _osrm_to_route(
                    r, route_id,
                    olat, olon, dlat, dlon,
                    oname, dname, signals,
                )
            )
        return results
    except Exception:
        return []


# ── Nearby exploration ──────────────────────────────────────────────────────────

@app.get("/api/exploration/nearby")
async def nearby_exploration(lat: float, lon: float, radius_meters: int = 300):
    """Real nearby POI exploration via Overpass API."""
    query = (
        f"[out:json][timeout:20];"
        f"("
        f'node["amenity"](around:{radius_meters},{lat},{lon});'
        f'node["shop"](around:{radius_meters},{lat},{lon});'
        f'node["tourism"](around:{radius_meters},{lat},{lon});'
        f'node["highway"="bus_stop"](around:{radius_meters},{lat},{lon});'
        f'node["leisure"="park"](around:{radius_meters},{lat},{lon});'
        f");"
        f"out body;"
    )
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                OVERPASS_URL, data={"data": query}, timeout=20.0
            )
        if resp.status_code == 200:
            elements = resp.json().get("elements", [])
            if elements:
                categories = _overpass_to_categories(elements, lat, lon)
                return {
                    "center": {"lat": lat, "lon": lon},
                    "radius_meters": radius_meters,
                    "categories": categories,
                }
    except Exception:
        pass

    # Fallback mock
    return {
        "center": {"lat": lat, "lon": lon},
        "radius_meters": radius_meters,
        "categories": _mock_exploration_categories(lat, lon),
    }


# ── Fallback mock data ──────────────────────────────────────────────────────────

def _mock_places() -> list:
    return [
        {
            "id": "mock_001",
            "name": "Windsor Public Library",
            "address": "850 Ouellette Avenue, Windsor, ON",
            "coordinates": {"lat": 42.3192, "lon": -83.0391},
            "type": "library",
        },
        {
            "id": "mock_002",
            "name": "Windsor Regional Hospital",
            "address": "1995 Lens Avenue, Windsor, ON",
            "coordinates": {"lat": 42.2800, "lon": -83.0050},
            "type": "hospital",
        },
    ]


def _mock_routes() -> list:
    return [
        {
            "id": "mock_route_001",
            "mode": "walk",
            "total_duration_seconds": 1200,
            "total_walking_distance_meters": 900,
            "transfer_count": 0,
            "legs": [
                {
                    "id": "mock_leg_001",
                    "mode": "walk",
                    "from": {"name": "Current Location", "coordinates": {"lat": 42.3150, "lon": -83.0360}},
                    "to": {"name": "Windsor Public Library", "coordinates": {"lat": 42.3192, "lon": -83.0391}},
                    "duration_seconds": 1200,
                    "distance_meters": 900,
                    "steps": [
                        {"instruction": "Head north on Ouellette Avenue for 300 metres", "distance_meters": 300},
                        {"instruction": "Continue north past Wyandotte Street intersection", "distance_meters": 400},
                        {"instruction": "Turn left — the library entrance is on your left", "distance_meters": 200},
                    ],
                }
            ],
            "functional_points": [
                {
                    "id": "mock_fp_001",
                    "type": "building_entrance",
                    "description": "Windsor Public Library — main entrance",
                    "importance": "navigation",
                    "trigger_distance_meters": 40,
                    "coordinates": {"lat": 42.3192, "lon": -83.0391},
                }
            ],
            "risk_points": [
                {
                    "id": "mock_rp_001",
                    "type": "intersection",
                    "description": "Ouellette Ave at Wyandotte St — busy intersection",
                    "severity": "medium",
                    "trigger_distance_meters": 100,
                    "coordinates": {"lat": 42.3170, "lon": -83.0370},
                }
            ],
            "accessibility_summary": {
                "score": 78,
                "street_crossings": 2,
                "transfer_count": 0,
                "known_entrances": 1,
                "audible_signals": 1,
                "construction_alerts": 0,
                "walking_distance_meters": 900,
                "data_complete": False,
            },
        },
        {
            "id": "mock_route_002",
            "mode": "transit",
            "total_duration_seconds": 1680,
            "total_walking_distance_meters": 450,
            "transfer_count": 0,
            "legs": [
                {
                    "id": "mock_leg_101",
                    "mode": "walk",
                    "from": {"name": "Current Location", "coordinates": {"lat": 42.3150, "lon": -83.0360}},
                    "to": {"name": "Ouellette Ave at Wyandotte St", "coordinates": {"lat": 42.3170, "lon": -83.0370}},
                    "duration_seconds": 180,
                    "distance_meters": 250,
                    "steps": [
                        {"instruction": "Head north on Ouellette Avenue for 250 metres", "distance_meters": 250},
                    ],
                },
                {
                    "id": "mock_leg_102",
                    "mode": "bus",
                    "from": {"name": "Ouellette Ave at Wyandotte St", "coordinates": {"lat": 42.3170, "lon": -83.0370}},
                    "to": {"name": "Ouellette Ave at Elliott St", "coordinates": {"lat": 42.3190, "lon": -83.0385}},
                    "duration_seconds": 1200,
                    "distance_meters": 2100,
                    "steps": [
                        {"instruction": "Board Route 1A bus towards Downtown at Ouellette Ave / Wyandotte St", "distance_meters": 0},
                        {"instruction": "Ride approximately 2.1 kilometres to Ouellette Ave / Elliott St", "distance_meters": 2100},
                        {"instruction": "Alight here — this is your stop at Ouellette Ave / Elliott St", "distance_meters": 0},
                    ],
                    "transit_info": {
                        "route": "1A",
                        "headsign": "Downtown",
                        "agency": "Transit Windsor",
                        "scheduled": True,
                    },
                },
                {
                    "id": "mock_leg_103",
                    "mode": "walk",
                    "from": {"name": "Ouellette Ave at Elliott St", "coordinates": {"lat": 42.3190, "lon": -83.0385}},
                    "to": {"name": "Windsor Public Library", "coordinates": {"lat": 42.3192, "lon": -83.0391}},
                    "duration_seconds": 300,
                    "distance_meters": 200,
                    "steps": [
                        {"instruction": "Walk north on Ouellette Avenue for 120 metres", "distance_meters": 120},
                        {"instruction": "Turn left — the library entrance appears to be on your left", "distance_meters": 80},
                    ],
                },
            ],
            "functional_points": [
                {
                    "id": "mock_fp_101",
                    "type": "bus_board",
                    "description": "Board Route 1A bus at Ouellette Ave / Wyandotte St",
                    "importance": "required",
                    "trigger_distance_meters": 80,
                    "coordinates": {"lat": 42.3170, "lon": -83.0370},
                },
                {
                    "id": "mock_fp_102",
                    "type": "bus_alight",
                    "description": "Alight at Ouellette Ave / Elliott St",
                    "importance": "required",
                    "trigger_distance_meters": 80,
                    "coordinates": {"lat": 42.3190, "lon": -83.0385},
                },
                {
                    "id": "mock_fp_103",
                    "type": "building_entrance",
                    "description": "Windsor Public Library — main entrance",
                    "importance": "navigation",
                    "trigger_distance_meters": 40,
                    "coordinates": {"lat": 42.3192, "lon": -83.0391},
                },
            ],
            "risk_points": [
                {
                    "id": "mock_rp_101",
                    "type": "intersection",
                    "description": "Ouellette Ave at Wyandotte St — busy intersection, audible pedestrian signal may be present",
                    "severity": "medium",
                    "trigger_distance_meters": 100,
                    "coordinates": {"lat": 42.3170, "lon": -83.0370},
                },
                {
                    "id": "mock_rp_102",
                    "type": "bus_risk",
                    "description": "Temporary stop relocation — Ouellette Ave at Elliott St",
                    "severity": "medium",
                    "trigger_distance_meters": 150,
                    "coordinates": {"lat": 42.3190, "lon": -83.0385},
                },
            ],
            "accessibility_summary": {
                "score": 78,
                "street_crossings": 2,
                "transfer_count": 0,
                "known_entrances": 1,
                "audible_signals": 1,
                "construction_alerts": 0,
                "walking_distance_meters": 450,
                "data_complete": True,
            },
        },
    ]


def _mock_exploration_categories(lat: float, lon: float) -> dict:
    return {
        "restaurant": [
            {"id": "mock_exp_001", "name": "Cafe Ambrosia", "distance_meters": 50,
             "bearing_degrees": 45, "coordinates": {"lat": lat + 0.0003, "lon": lon + 0.0003}},
        ],
        "pharmacy": [
            {"id": "mock_exp_002", "name": "Shoppers Drug Mart", "distance_meters": 120,
             "bearing_degrees": 270, "coordinates": {"lat": lat, "lon": lon - 0.001}},
        ],
        "bus_stop": [
            {"id": "mock_exp_003", "name": "Ouellette Ave at Elliott St", "distance_meters": 60,
             "bearing_degrees": 0, "coordinates": {"lat": lat + 0.0004, "lon": lon}},
        ],
    }
