import logging
import math
import os
from typing import Optional

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logger = logging.getLogger(__name__)

MOTIS_URL = os.getenv("MOTIS_URL", "http://motis:8080")
OVERPASS_URL = os.getenv("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
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


def _step_bearing(step: dict) -> Optional[float]:
    """Net compass bearing of a single MOTIS step, from the first to
    the last point of its own polyline. Returns None when the step
    carries no usable geometry (e.g. an elevator step).
    """
    poly = step.get("polyline") or {}
    points = poly.get("points")
    if not points:
        return None
    coords = _decode_polyline(points, poly.get("precision", 7))
    if len(coords) < 2:
        return None
    (lat1, lon1), (lat2, lon2) = coords[0], coords[-1]
    if lat1 == lat2 and lon1 == lon2:
        return None
    return _bearing(lat1, lon1, lat2, lon2)


def _infer_relative_direction(prev_bearing: float, bearing: float) -> str:
    """Classifies a manoeuvre from the change between two bearings."""
    diff = (bearing - prev_bearing + 180) % 360 - 180
    magnitude = abs(diff)
    if magnitude < 20:
        return "CONTINUE"
    if magnitude < 45:
        return "SLIGHTLY_RIGHT" if diff > 0 else "SLIGHTLY_LEFT"
    if magnitude < 150:
        return "RIGHT" if diff > 0 else "LEFT"
    if magnitude < 170:
        return "HARD_RIGHT" if diff > 0 else "HARD_LEFT"
    return "UTURN_RIGHT" if diff > 0 else "UTURN_LEFT"


# Segments shorter than this are usually just OSM way-splitting or a
# curb/driveway nudge rather than a manoeuvre a pedestrian would
# actually notice, so their bearing is too noisy to classify as a real
# turn — treat them as a continuation of whatever came before instead
# of announcing a spurious "turn right for 4 metres".
_MIN_TURN_DISTANCE_METERS = 8


def _infer_motis_step_directions(steps: list[dict]) -> list[dict]:
    """MOTIS's own street router never computes a real relativeDirection
    for ordinary street segments — it hard-codes CONTINUE for every
    non-elevator, non-stairs step (see motis-project/motis's
    street_routing.cc, `get_step_instructions`, which is marked
    "TODO entry/exit/u-turn"). Without this, every walking leg comes
    back as one flat "Continue straight for N metres" and turns are
    never announced. Estimate the real manoeuvre instead from the
    bearing change between each step's own polyline and the previous
    one's, and only touch steps MOTIS left as the generic CONTINUE.
    """
    inferred: list[dict] = []
    prev_bearing: Optional[float] = None
    for step in steps:
        copy = dict(step)
        bearing = _step_bearing(step)
        direction = str(step.get("relativeDirection") or "CONTINUE").upper()
        distance = step.get("distance") or 0
        if (
            direction == "CONTINUE"
            and bearing is not None
            and prev_bearing is not None
            and distance >= _MIN_TURN_DISTANCE_METERS
        ):
            copy["relativeDirection"] = _infer_relative_direction(prev_bearing, bearing)
        if bearing is not None:
            prev_bearing = bearing
        inferred.append(copy)
    return inferred


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


def _merge_motis_steps(steps: list[dict]) -> list[dict]:
    """Collapses consecutive plain "CONTINUE" MOTIS walking-leg steps
    (no real turn — just an underlying way-segment or street-name
    boundary) into one step with the combined distance, so a single
    straight stretch doesn't turn into a string of repeated
    announcements. Real manoeuvres are never merged.
    """
    merged: list[dict] = []
    for step in steps:
        direction = str(step.get("relativeDirection") or "CONTINUE").upper()
        is_plain = direction == "CONTINUE"
        if is_plain and merged and merged[-1]["_plain"]:
            prev = merged[-1]
            prev["distance"] = (prev.get("distance") or 0) + (step.get("distance") or 0)
            if prev.get("streetName") != step.get("streetName"):
                prev["streetName"] = ""
        else:
            copy = dict(step)
            copy["_plain"] = is_plain
            merged.append(copy)
    for step in merged:
        step.pop("_plain", None)
    return merged


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
            resp = await client.post(
                OVERPASS_URL,
                data={"data": query},
                headers={"User-Agent": USER_AGENT},
                timeout=15.0,
            )
            if resp.status_code == 200:
                elements = resp.json().get("elements", [])
                return [(el["lat"], el["lon"]) for el in elements if el.get("type") == "node"]
            logger.warning(
                "Overpass traffic-signal query returned status %s", resp.status_code
            )
    except Exception:
        logger.exception("Overpass traffic-signal query failed")
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
                    "limit": 20,
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
        else:
            logger.warning("Nominatim search returned status %s", resp.status_code)
    except Exception:
        logger.exception("Nominatim search failed")

    return {"query": q, "results": []}


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
    Route planning via MOTIS (self-hosted): transit+walk itineraries when
    a transit option exists, otherwise its own transit-free walking
    connection. Automatically extracts functional points and risk points.
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

    motis_routes = await _plan_via_motis(olat, olon, dlat, dlon, oname, dname, signals)
    if motis_routes:
        return {"routes": motis_routes}

    # MOTIS unreachable or found neither a transit itinerary nor a
    # transit-free walking connection — be honest about it rather than
    # fabricating a route.
    return {"routes": []}


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


def _motis_itinerary_to_route(
    itin, route_id, oname, dname, olat, olon, dlat, dlon, signals
) -> dict:
    """Builds one route dict from a single MOTIS itinerary — used for
    both real transit itineraries (`data["itineraries"]`) and the
    transit-free walking connection MOTIS returns under `data["direct"]`
    when requesting mode=TRANSIT,WALK and no transit option exists.
    """
    legs_out = []
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
        raw_steps = _infer_motis_step_directions(leg.get("steps", []))
        for step in _merge_motis_steps(raw_steps):
            dist = round(step.get("distance") or 0)
            leg_steps.append({
                "instruction": _motis_step_instruction(step),
                "distance_meters": dist,
            })

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
    return {
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
    }


# MOTIS snaps fromPlace/toPlace onto the street network within this
# many metres and otherwise returns zero routes; its default is only
# 25m, which is too tight for destinations set back from the road
# behind a driveway or parking lot (e.g. suburban libraries, schools,
# big-box stores) — those points geocode fine but silently fail to
# route. 60m comfortably covers a large parking lot without matching
# onto the wrong street entirely.
_MOTIS_MAX_MATCHING_DISTANCE_METERS = 60


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
                    "maxMatchingDistance": _MOTIS_MAX_MATCHING_DISTANCE_METERS,
                },
                timeout=10.0,
            )
        if resp.status_code != 200:
            return []
        data = resp.json()

        itineraries = data.get("itineraries", [])
        if itineraries:
            return [
                _motis_itinerary_to_route(
                    itin, f"motis_route_{idx + 1}",
                    oname, dname, olat, olon, dlat, dlon, signals,
                )
                for idx, itin in enumerate(itineraries[:2])
            ]

        # No transit itinerary exists for this trip — MOTIS still
        # returns a transit-free walking connection under "direct"
        # (computed from the same self-hosted street network used for
        # transit routing), so there is no need for a separate walking
        # router/service as a fallback.
        direct = data.get("direct", [])
        return [
            _motis_itinerary_to_route(
                conn, f"motis_route_{idx + 1}",
                oname, dname, olat, olon, dlat, dlon, signals,
            )
            for idx, conn in enumerate(direct[:2])
        ]
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
                OVERPASS_URL,
                data={"data": query},
                headers={"User-Agent": USER_AGENT},
                timeout=20.0,
            )
        if resp.status_code == 200:
            elements = resp.json().get("elements", [])
            return {
                "center": {"lat": lat, "lon": lon},
                "radius_meters": radius_meters,
                # Empty is a legitimate result (no POIs in range) — still
                # real data, not a failure.
                "categories": _overpass_to_categories(elements, lat, lon),
            }
        logger.warning(
            "Overpass exploration query returned status %s", resp.status_code
        )
    except Exception:
        logger.exception("Overpass exploration query failed")

    # The query itself failed (not just "no results") — be honest about
    # it rather than fabricating places.
    return {
        "center": {"lat": lat, "lon": lon},
        "radius_meters": radius_meters,
        "categories": {},
    }

