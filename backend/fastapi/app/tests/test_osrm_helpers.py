import pytest

from main import _abs_direction, _osrm_step_instruction, _osrm_to_route


@pytest.mark.parametrize(
    ("bearing", "expected"),
    [
        (0, "north"),
        (45, "northeast"),
        (90, "east"),
        (135, "southeast"),
        (180, "south"),
        (225, "southwest"),
        (270, "west"),
        (315, "northwest"),
        (360, "north"),
    ],
)
def test_abs_direction(bearing, expected):
    assert _abs_direction(bearing) == expected


def test_step_instruction_depart_with_distance():
    step = {
        "maneuver": {"type": "depart", "bearing_after": 0},
        "name": "Ouellette Avenue",
        "distance": 120,
    }
    assert _osrm_step_instruction(step) == (
        "Head north on Ouellette Avenue for 120 metres"
    )


def test_step_instruction_depart_without_distance():
    step = {
        "maneuver": {"type": "depart", "bearing_after": 90},
        "name": "Ouellette Avenue",
        "distance": 0,
    }
    assert _osrm_step_instruction(step) == "Head east on Ouellette Avenue"


def test_step_instruction_arrive():
    step = {"maneuver": {"type": "arrive"}, "name": "Library", "distance": 0}
    assert _osrm_step_instruction(step) == "Arrive at your destination"


def test_step_instruction_turn_left():
    step = {
        "maneuver": {"type": "turn", "modifier": "left"},
        "name": "Wyandotte Street",
        "distance": 50,
    }
    assert _osrm_step_instruction(step) == "Turn left onto Wyandotte Street"


def test_step_instruction_continue_straight_with_distance():
    step = {
        "maneuver": {"type": "continue", "modifier": "straight"},
        "name": "Ouellette Avenue",
        "distance": 300,
    }
    assert _osrm_step_instruction(step) == (
        "Continue straight on Ouellette Avenue for 300 metres"
    )


def test_step_instruction_roundabout_with_exit():
    step = {
        "maneuver": {"type": "roundabout", "exit": 2},
        "name": "Tecumseh Road",
        "distance": 0,
    }
    assert _osrm_step_instruction(step) == (
        "At the roundabout, take exit 2 onto Tecumseh Road"
    )


def test_step_instruction_unknown_type_falls_back_to_continue():
    step = {"maneuver": {"type": "fork"}, "name": "Howard Avenue", "distance": 0}
    assert _osrm_step_instruction(step) == "Continue on Howard Avenue"


def test_step_instruction_defaults_name_to_the_road():
    step = {"maneuver": {"type": "arrive"}, "distance": 0}
    assert _osrm_step_instruction(step) == "Arrive at your destination"

    step = {"maneuver": {"type": "continue", "modifier": "straight"}, "distance": 0}
    assert _osrm_step_instruction(step) == "Continue straight on the road"


def _sample_osrm_route():
    return {
        "distance": 950.4,
        "duration": 723.8,
        "geometry": {
            "coordinates": [[-83.0364, 42.3149], [-83.0391, 42.3192]],
        },
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
                        "distance": 300,
                    },
                    {
                        "maneuver": {
                            "type": "turn",
                            "modifier": "left",
                            "location": [-83.038, 42.317],
                        },
                        "name": "Wyandotte Street",
                        "distance": 200,
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


def test_osrm_to_route_basic_shape():
    route = _osrm_to_route(
        _sample_osrm_route(),
        "osrm_route_1",
        42.3149, -83.0364,
        42.3192, -83.0391,
        "Current Location", "Windsor Public Library",
        traffic_signal_positions=[],
    )

    assert route["id"] == "osrm_route_1"
    assert route["mode"] == "walk"
    assert route["total_duration_seconds"] == 724
    assert route["total_walking_distance_meters"] == 950
    assert route["transfer_count"] == 0
    # OSRM returns [lon, lat]; route geometry should be converted to [lat, lon]
    assert route["geometry"] == [[42.3149, -83.0364], [42.3192, -83.0391]]


def test_osrm_to_route_builds_single_walking_leg_with_steps():
    route = _osrm_to_route(
        _sample_osrm_route(),
        "osrm_route_1",
        42.3149, -83.0364,
        42.3192, -83.0391,
        "Current Location", "Windsor Public Library",
        traffic_signal_positions=[],
    )

    assert len(route["legs"]) == 1
    leg = route["legs"][0]
    assert leg["mode"] == "walk"
    assert leg["from"]["name"] == "Current Location"
    assert leg["to"]["name"] == "Windsor Public Library"
    assert leg["duration_seconds"] == 724
    assert leg["distance_meters"] == 950
    assert [s["instruction"] for s in leg["steps"]] == [
        "Head north on Ouellette Avenue for 300 metres",
        "Turn left onto Wyandotte Street",
        "Arrive at your destination",
    ]


def test_osrm_to_route_functional_points_for_turn_and_arrival():
    route = _osrm_to_route(
        _sample_osrm_route(),
        "osrm_route_1",
        42.3149, -83.0364,
        42.3192, -83.0391,
        "Current Location", "Windsor Public Library",
        traffic_signal_positions=[],
    )

    fps = route["functional_points"]
    assert [fp["type"] for fp in fps] == ["turn", "building_entrance"]
    assert fps[0]["description"] == "Turn left onto Wyandotte Street"
    assert fps[0]["coordinates"] == {"lat": 42.317, "lon": -83.038}
    assert fps[1]["description"] == "Windsor Public Library — destination"
    assert fps[1]["coordinates"] == {"lat": 42.3192, "lon": -83.0391}


def test_osrm_to_route_risk_point_severity_without_signals():
    route = _osrm_to_route(
        _sample_osrm_route(),
        "osrm_route_1",
        42.3149, -83.0364,
        42.3192, -83.0391,
        "Current Location", "Windsor Public Library",
        traffic_signal_positions=[],
    )

    risk_points = route["risk_points"]
    assert len(risk_points) == 1
    rp = risk_points[0]
    assert rp["severity"] == "low"
    assert rp["trigger_distance_meters"] == 80
    assert rp["description"] == "Intersection at Wyandotte Street"

    summary = route["accessibility_summary"]
    assert summary["score"] == 83  # 85 - 0 medium - 1 low * 2
    assert summary["street_crossings"] == 1
    assert summary["audible_signals"] == 0


def test_osrm_to_route_risk_point_severity_with_nearby_signal():
    route = _osrm_to_route(
        _sample_osrm_route(),
        "osrm_route_1",
        42.3149, -83.0364,
        42.3192, -83.0391,
        "Current Location", "Windsor Public Library",
        traffic_signal_positions=[(42.317, -83.038)],
    )

    risk_points = route["risk_points"]
    assert len(risk_points) == 1
    rp = risk_points[0]
    assert rp["severity"] == "medium"
    assert rp["trigger_distance_meters"] == 100
    assert rp["description"] == "Signalised intersection at Wyandotte Street"

    summary = route["accessibility_summary"]
    assert summary["score"] == 80  # 85 - 1 medium * 5
    assert summary["audible_signals"] == 1
