import httpx
import pytest
import respx

from main import MOTIS_URL, NOMINATIM_URL, OVERPASS_URL

ROUTE_REQUEST_BODY = {
    "origin": {"lat": 42.3149, "lon": -83.0364},
    "destination": {"lat": 42.3192, "lon": -83.0391},
    "origin_name": "Current Location",
    "destination_name": "Windsor Public Library",
}


def _motis_direct_walk_payload():
    """A MOTIS "direct" (transit-free) walking connection — what MOTIS
    returns when no transit itinerary exists for the trip."""
    return {
        "duration": 723.8,
        "legs": [
            {
                "mode": "WALK",
                "from": {"name": "Current Location", "lat": 42.3149, "lon": -83.0364},
                "to": {"name": "Windsor Public Library", "lat": 42.3192, "lon": -83.0391},
                "duration": 723.8,
                "distance": 950.4,
                "steps": [
                    {"relativeDirection": "DEPART", "streetName": "Ouellette Avenue", "distance": 950},
                ],
            }
        ],
    }


# ── /health ──────────────────────────────────────────────────────────────────

def test_health_check(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok", "phase": 2}


# ── /api/places/search ──────────────────────────────────────────────────────

@respx.mock
def test_search_places_success(client):
    respx.get(f"{NOMINATIM_URL}/search").mock(
        return_value=httpx.Response(
            200,
            json=[
                {
                    "place_id": 12345,
                    "display_name": (
                        "Windsor Public Library, 850 Ouellette Avenue, "
                        "Windsor, ON"
                    ),
                    "lat": "42.3192",
                    "lon": "-83.0391",
                    "type": "library",
                    "address": {"building": "Windsor Public Library"},
                }
            ],
        )
    )

    resp = client.get("/api/places/search?q=library")
    assert resp.status_code == 200
    data = resp.json()
    assert data["query"] == "library"
    result = data["results"][0]
    assert result["id"] == "nominatim_12345"
    assert result["name"] == "Windsor Public Library"
    assert result["coordinates"] == {"lat": 42.3192, "lon": -83.0391}


@respx.mock
def test_search_places_empty_results_returns_empty_list(client):
    respx.get(f"{NOMINATIM_URL}/search").mock(
        return_value=httpx.Response(200, json=[])
    )

    resp = client.get("/api/places/search?q=nonexistentplace")
    assert resp.status_code == 200
    data = resp.json()
    assert data["results"] == []


@respx.mock
def test_search_places_request_error_returns_empty_list(client):
    respx.get(f"{NOMINATIM_URL}/search").mock(side_effect=httpx.ConnectError("boom"))

    resp = client.get("/api/places/search?q=library")
    assert resp.status_code == 200
    data = resp.json()
    assert data["results"] == []


# ── /api/places/reverse ─────────────────────────────────────────────────────

@respx.mock
def test_reverse_geocode_success(client):
    respx.get(f"{NOMINATIM_URL}/reverse").mock(
        return_value=httpx.Response(
            200, json={"display_name": "850 Ouellette Avenue, Windsor, ON"}
        )
    )

    resp = client.get("/api/places/reverse?lat=42.3192&lon=-83.0391")
    assert resp.status_code == 200
    data = resp.json()
    assert data["address"] == "850 Ouellette Avenue, Windsor, ON"
    assert data["confidence"] == "high"
    assert data["coordinates"] == {"lat": 42.3192, "lon": -83.0391}


@respx.mock
def test_reverse_geocode_failure_falls_back(client):
    respx.get(f"{NOMINATIM_URL}/reverse").mock(side_effect=httpx.ConnectError("boom"))

    resp = client.get("/api/places/reverse?lat=42.3192&lon=-83.0391")
    assert resp.status_code == 200
    data = resp.json()
    assert data["confidence"] == "low"
    assert data["address"] == "42.3192, -83.0391"


# ── /api/routes/plan ─────────────────────────────────────────────────────────

@respx.mock
def test_plan_route_uses_motis_when_available(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(
        return_value=httpx.Response(
            200,
            json={
                "itineraries": [
                    {
                        "duration": 600,
                        "legs": [
                            {
                                "mode": "WALK",
                                "from": {
                                    "name": "Current Location",
                                    "lat": 42.3149,
                                    "lon": -83.0364,
                                },
                                "to": {
                                    "name": "Windsor Public Library",
                                    "lat": 42.3192,
                                    "lon": -83.0391,
                                },
                                "duration": 600,
                                "distance": 450,
                                "legGeometry": {
                                    "points": "wq|afXrmoxnp@lggIqmrg@",
                                    "precision": 7,
                                    "length": 2,
                                },
                                "steps": [
                                    {
                                        "relativeDirection": "DEPART",
                                        "streetName": "Ouellette Avenue",
                                        "distance": 450,
                                    }
                                ],
                            }
                        ],
                    }
                ]
            },
        )
    )

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    route = resp.json()["routes"][0]
    assert route["id"] == "motis_route_1"
    assert route["total_duration_seconds"] == 600
    assert route["total_walking_distance_meters"] == 450
    assert route["legs"][0]["steps"][0]["instruction"] == (
        "Head out on Ouellette Avenue for 450 metres"
    )
    flat_geometry = [value for point in route["geometry"] for value in point]
    assert flat_geometry == pytest.approx(
        [42.3148332, -83.036593, 42.2980261, -82.9700609]
    )
    motis_request = respx.calls.last.request
    assert motis_request.url.params["maxMatchingDistance"] == "60"


@respx.mock
def test_plan_route_motis_transit_itinerary(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(
        return_value=httpx.Response(
            200,
            json={
                "itineraries": [
                    {
                        "duration": 1680,
                        "legs": [
                            {
                                "mode": "WALK",
                                "from": {
                                    "name": "Current Location",
                                    "lat": 42.3149,
                                    "lon": -83.0364,
                                },
                                "to": {
                                    "name": "Ouellette Ave at Wyandotte St",
                                    "lat": 42.3170,
                                    "lon": -83.0370,
                                },
                                "duration": 180,
                                "distance": 250,
                                "steps": [
                                    {
                                        "relativeDirection": "DEPART",
                                        "streetName": "Ouellette Avenue",
                                        "distance": 250,
                                    }
                                ],
                            },
                            {
                                "mode": "BUS",
                                "from": {
                                    "name": "Ouellette Ave at Wyandotte St",
                                    "lat": 42.3170,
                                    "lon": -83.0370,
                                },
                                "to": {
                                    "name": "Ouellette Ave at Elliott St",
                                    "lat": 42.3190,
                                    "lon": -83.0385,
                                },
                                "duration": 1200,
                                "routeShortName": "1A",
                                "headsign": "Downtown",
                                "agencyName": "Transit Windsor",
                                "realTime": False,
                                "steps": [],
                            },
                            {
                                "mode": "WALK",
                                "from": {
                                    "name": "Ouellette Ave at Elliott St",
                                    "lat": 42.3190,
                                    "lon": -83.0385,
                                },
                                "to": {
                                    "name": "Windsor Public Library",
                                    "lat": 42.3192,
                                    "lon": -83.0391,
                                },
                                "duration": 300,
                                "distance": 200,
                                "steps": [],
                            },
                        ],
                    }
                ]
            },
        )
    )

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    route = resp.json()["routes"][0]
    assert route["mode"] == "transit"
    assert route["transfer_count"] == 0
    assert route["accessibility_summary"]["transfer_count"] == 0

    bus_leg = route["legs"][1]
    assert bus_leg["mode"] == "bus"
    assert bus_leg["transit_info"] == {
        "route": "1A",
        "headsign": "Downtown",
        "agency": "Transit Windsor",
        "scheduled": True,
    }

    fp_types = [fp["type"] for fp in route["functional_points"]]
    assert "bus_board" in fp_types
    assert "bus_alight" in fp_types
    assert "building_entrance" in fp_types


@respx.mock
def test_plan_route_motis_transit_transfer(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(
        return_value=httpx.Response(
            200,
            json={
                "itineraries": [
                    {
                        "duration": 2000,
                        "legs": [
                            {
                                "mode": "WALK",
                                "from": {
                                    "name": "Current Location",
                                    "lat": 42.3149,
                                    "lon": -83.0364,
                                },
                                "to": {
                                    "name": "Stop A",
                                    "lat": 42.3170,
                                    "lon": -83.0370,
                                },
                                "duration": 180,
                                "distance": 200,
                                "steps": [],
                            },
                            {
                                "mode": "BUS",
                                "from": {
                                    "name": "Stop A",
                                    "lat": 42.3170,
                                    "lon": -83.0370,
                                },
                                "to": {
                                    "name": "Transfer Stop",
                                    "lat": 42.3180,
                                    "lon": -83.0378,
                                },
                                "duration": 600,
                                "routeShortName": "1A",
                                "headsign": "Downtown",
                                "agencyName": "Transit Windsor",
                                "realTime": False,
                                "steps": [],
                            },
                            {
                                "mode": "BUS",
                                "from": {
                                    "name": "Transfer Stop",
                                    "lat": 42.3180,
                                    "lon": -83.0378,
                                },
                                "to": {
                                    "name": "Stop B",
                                    "lat": 42.3190,
                                    "lon": -83.0385,
                                },
                                "duration": 600,
                                "routeShortName": "2B",
                                "headsign": "College",
                                "agencyName": "Transit Windsor",
                                "realTime": False,
                                "steps": [],
                            },
                            {
                                "mode": "WALK",
                                "from": {
                                    "name": "Stop B",
                                    "lat": 42.3190,
                                    "lon": -83.0385,
                                },
                                "to": {
                                    "name": "Windsor Public Library",
                                    "lat": 42.3192,
                                    "lon": -83.0391,
                                },
                                "duration": 200,
                                "distance": 200,
                                "steps": [],
                            },
                        ],
                    }
                ]
            },
        )
    )

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    route = resp.json()["routes"][0]
    assert route["transfer_count"] == 1

    transfer_points = [
        fp for fp in route["functional_points"] if fp["type"] == "bus_transfer"
    ]
    assert len(transfer_points) == 1
    assert "Transfer to Route 2B (College) at Transfer Stop" in (
        transfer_points[0]["description"]
    )


@respx.mock
def test_plan_route_falls_back_to_motis_direct_walk_when_no_transit_itinerary(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(
        return_value=httpx.Response(
            200,
            json={"itineraries": [], "direct": [_motis_direct_walk_payload()]},
        )
    )

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    route = resp.json()["routes"][0]
    assert route["id"] == "motis_route_1"
    assert route["mode"] == "walk"
    assert route["total_walking_distance_meters"] == 950


@respx.mock
def test_plan_route_returns_empty_when_motis_fails(client):
    respx.post(OVERPASS_URL).mock(return_value=httpx.Response(500))
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(return_value=httpx.Response(500))

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    assert resp.json()["routes"] == []


@respx.mock
def test_plan_route_returns_empty_when_motis_has_neither_itinerary_nor_direct(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(
        return_value=httpx.Response(200, json={"itineraries": [], "direct": []})
    )

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    assert resp.json()["routes"] == []


# ── /api/exploration/nearby ──────────────────────────────────────────────────

@respx.mock
def test_nearby_exploration_success(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(
            200,
            json={
                "elements": [
                    {
                        "type": "node",
                        "id": 1,
                        "lat": 42.3155,
                        "lon": -83.0360,
                        "tags": {"amenity": "cafe", "name": "Joe's Cafe"},
                    }
                ]
            },
        )
    )

    resp = client.get("/api/exploration/nearby?lat=42.3150&lon=-83.0360")
    assert resp.status_code == 200
    data = resp.json()
    assert data["categories"]["restaurant"][0]["name"] == "Joe's Cafe"


@respx.mock
def test_nearby_exploration_returns_empty_categories_when_no_results(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )

    resp = client.get("/api/exploration/nearby?lat=42.3150&lon=-83.0360")
    assert resp.status_code == 200
    data = resp.json()
    assert data["categories"] == {}


@respx.mock
def test_nearby_exploration_returns_empty_categories_on_failure(client):
    respx.post(OVERPASS_URL).mock(side_effect=httpx.ConnectError("boom"))

    resp = client.get("/api/exploration/nearby?lat=42.3150&lon=-83.0360")
    assert resp.status_code == 200
    data = resp.json()
    assert data["categories"] == {}
