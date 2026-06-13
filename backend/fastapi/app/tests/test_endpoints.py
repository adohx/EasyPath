import httpx
import respx

from main import MOTIS_URL, NOMINATIM_URL, OSRM_URL, OVERPASS_URL

ROUTE_REQUEST_BODY = {
    "origin": {"lat": 42.3149, "lon": -83.0364},
    "destination": {"lat": 42.3192, "lon": -83.0391},
    "origin_name": "Current Location",
    "destination_name": "Windsor Public Library",
}

# Matches OSRM_URL/route/v1/foot/<origin_lon>,<origin_lat>;<dest_lon>,<dest_lat>
OSRM_ROUTE_URL = (
    f"{OSRM_URL}/route/v1/foot/-83.0364,42.3149;-83.0391,42.3192"
)


def _osrm_route_payload():
    return {
        "distance": 950.4,
        "duration": 723.8,
        "geometry": {"coordinates": [[-83.0364, 42.3149], [-83.0391, 42.3192]]},
        "legs": [
            {
                "steps": [
                    {
                        "maneuver": {
                            "type": "depart",
                            "bearing_after": 0,
                            "location": [-83.0364, 42.3149],
                        },
                        "name": "Ouellette Avenue",
                        "distance": 950,
                    },
                    {
                        "maneuver": {
                            "type": "arrive",
                            "location": [-83.0391, 42.3192],
                        },
                        "name": "",
                        "distance": 0,
                    },
                ]
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
def test_search_places_empty_results_falls_back_to_mock(client):
    respx.get(f"{NOMINATIM_URL}/search").mock(
        return_value=httpx.Response(200, json=[])
    )

    resp = client.get("/api/places/search?q=nonexistentplace")
    assert resp.status_code == 200
    data = resp.json()
    assert data["results"][0]["id"] == "mock_001"


@respx.mock
def test_search_places_request_error_falls_back_to_mock(client):
    respx.get(f"{NOMINATIM_URL}/search").mock(side_effect=httpx.ConnectError("boom"))

    resp = client.get("/api/places/search?q=library")
    assert resp.status_code == 200
    data = resp.json()
    assert data["results"][0]["id"] == "mock_001"


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
                "plan": {
                    "itineraries": [
                        {
                            "duration": 600,
                            "walkDistance": 450,
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
                                    "steps": [
                                        {
                                            "relativeDirection": "depart",
                                            "streetName": "Ouellette Avenue",
                                            "distance": 450,
                                        }
                                    ],
                                }
                            ],
                        }
                    ]
                }
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
        "Depart on Ouellette Avenue for 450 metres"
    )


@respx.mock
def test_plan_route_falls_back_to_osrm_when_motis_unavailable(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(return_value=httpx.Response(500))
    respx.get(OSRM_ROUTE_URL).mock(
        return_value=httpx.Response(200, json={"routes": [_osrm_route_payload()]})
    )

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    route = resp.json()["routes"][0]
    assert route["id"] == "osrm_route_1"
    assert route["total_walking_distance_meters"] == 950


@respx.mock
def test_plan_route_falls_back_to_mock_when_all_sources_fail(client):
    respx.post(OVERPASS_URL).mock(return_value=httpx.Response(500))
    respx.get(f"{MOTIS_URL}/api/v1/plan").mock(return_value=httpx.Response(500))
    respx.get(OSRM_ROUTE_URL).mock(return_value=httpx.Response(500))

    resp = client.post("/api/routes/plan", json=ROUTE_REQUEST_BODY)
    assert resp.status_code == 200
    route = resp.json()["routes"][0]
    assert route["id"] == "mock_route_001"


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
def test_nearby_exploration_empty_falls_back_to_mock(client):
    respx.post(OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )

    resp = client.get("/api/exploration/nearby?lat=42.3150&lon=-83.0360")
    assert resp.status_code == 200
    data = resp.json()
    assert data["categories"]["restaurant"][0]["id"] == "mock_exp_001"


@respx.mock
def test_nearby_exploration_failure_falls_back_to_mock(client):
    respx.post(OVERPASS_URL).mock(side_effect=httpx.ConnectError("boom"))

    resp = client.get("/api/exploration/nearby?lat=42.3150&lon=-83.0360")
    assert resp.status_code == 200
    data = resp.json()
    assert data["categories"]["bus_stop"][0]["id"] == "mock_exp_003"
