from main import (
    _infer_motis_step_directions,
    _merge_motis_steps,
    _motis_itinerary_to_route,
    _motis_step_instruction,
)


def test_step_instruction_depart_with_street_and_distance():
    step = {"relativeDirection": "DEPART", "streetName": "Ouellette Avenue", "distance": 120}
    assert _motis_step_instruction(step) == "Head out on Ouellette Avenue for 120 metres"


def test_step_instruction_left_onto_street():
    step = {"relativeDirection": "LEFT", "streetName": "Wyandotte Street", "distance": 50}
    assert _motis_step_instruction(step) == "Turn left onto Wyandotte Street for 50 metres"


def test_step_instruction_continue_without_street_falls_back_to_straight():
    step = {"relativeDirection": "CONTINUE", "streetName": "", "distance": 30}
    assert _motis_step_instruction(step) == "Continue straight for 30 metres"


def test_merge_motis_steps_combines_consecutive_continues():
    steps = [
        {"relativeDirection": "DEPART", "streetName": "Ouellette Avenue", "distance": 50},
        {"relativeDirection": "CONTINUE", "streetName": "Ouellette Avenue", "distance": 30},
        {"relativeDirection": "CONTINUE", "streetName": "Ouellette Avenue", "distance": 40},
        {"relativeDirection": "LEFT", "streetName": "Wyandotte Street", "distance": 80},
    ]

    merged = _merge_motis_steps(steps)

    assert len(merged) == 3
    assert merged[0]["relativeDirection"] == "DEPART"
    assert merged[1]["relativeDirection"] == "CONTINUE"
    assert merged[1]["distance"] == 70
    assert merged[1]["streetName"] == "Ouellette Avenue"
    assert merged[2]["relativeDirection"] == "LEFT"


def test_merge_motis_steps_clears_street_name_when_segments_disagree():
    steps = [
        {"relativeDirection": "CONTINUE", "streetName": "Maiden Lane", "distance": 20},
        {"relativeDirection": "CONTINUE", "streetName": "Pelissier Street", "distance": 15},
    ]

    merged = _merge_motis_steps(steps)

    assert len(merged) == 1
    assert merged[0]["distance"] == 35
    assert merged[0]["streetName"] == ""


def _direct_walk_connection():
    return {
        "duration": 579,
        "legs": [
            {
                "mode": "WALK",
                "from": {"name": "Current Location", "lat": 42.3149, "lon": -83.0364},
                "to": {"name": "Windsor Public Library", "lat": 42.3192, "lon": -83.0391},
                "duration": 579,
                "distance": 664,
                "steps": [
                    {"relativeDirection": "DEPART", "streetName": "Ouellette Avenue", "distance": 300},
                    {"relativeDirection": "LEFT", "streetName": "Wyandotte Street", "distance": 364},
                ],
            }
        ],
    }


def test_motis_itinerary_to_route_builds_walk_only_route_from_direct_connection():
    route = _motis_itinerary_to_route(
        _direct_walk_connection(),
        "motis_route_1",
        "Current Location", "Windsor Public Library",
        42.3149, -83.0364, 42.3192, -83.0391,
        signals=[],
    )

    assert route["id"] == "motis_route_1"
    assert route["mode"] == "walk"
    assert route["transfer_count"] == 0
    assert route["total_walking_distance_meters"] == 664
    assert len(route["legs"]) == 1
    assert route["legs"][0]["mode"] == "walk"
    assert [s["instruction"] for s in route["legs"][0]["steps"]] == [
        "Head out on Ouellette Avenue for 300 metres",
        "Turn left onto Wyandotte Street for 364 metres",
    ]


def _encode_polyline(coords: list[tuple[float, float]], precision: int = 7) -> str:
    """Minimal Google-style polyline encoder, the inverse of main's
    `_decode_polyline`, used to build realistic MOTIS step fixtures.
    """
    factor = 10**precision

    def _encode_value(value: int) -> str:
        value = ~(value << 1) if value < 0 else (value << 1)
        chunks = []
        while value >= 0x20:
            chunks.append((value & 0x1F) | 0x20)
            value >>= 5
        chunks.append(value)
        return "".join(chr(c + 63) for c in chunks)

    output = []
    prev_lat, prev_lon = 0, 0
    for lat, lon in coords:
        lat_i, lon_i = round(lat * factor), round(lon * factor)
        output.append(_encode_value(lat_i - prev_lat))
        output.append(_encode_value(lon_i - prev_lon))
        prev_lat, prev_lon = lat_i, lon_i
    return "".join(output)


def _step(coords, distance, direction="CONTINUE", street=""):
    return {
        "relativeDirection": direction,
        "streetName": street,
        "distance": distance,
        "polyline": {"points": _encode_polyline(coords), "precision": 7},
    }


def test_infer_motis_step_directions_keeps_straight_segments_as_continue():
    steps = [
        _step([(42.0000, -83.0000), (42.0009, -83.0000)], distance=100),
        _step([(42.0009, -83.0000), (42.0018, -83.0000)], distance=100),
    ]

    inferred = _infer_motis_step_directions(steps)

    assert [s["relativeDirection"] for s in inferred] == ["CONTINUE", "CONTINUE"]


def test_infer_motis_step_directions_detects_real_turn_from_bearing_change():
    steps = [
        _step([(42.0000, -83.0000), (42.0009, -83.0000)], distance=100),
        # Second step turns ~90 degrees east.
        _step([(42.0009, -83.0000), (42.0009, -82.9990)], distance=82),
    ]

    inferred = _infer_motis_step_directions(steps)

    assert inferred[0]["relativeDirection"] == "CONTINUE"
    assert inferred[1]["relativeDirection"] == "RIGHT"


def test_infer_motis_step_directions_ignores_short_noisy_segments():
    steps = [
        _step([(42.0000, -83.0000), (42.0009, -83.0000)], distance=100),
        # Sharp bearing change, but far too short to be a real turn.
        _step([(42.0009, -83.0000), (42.0009, -82.9999)], distance=3),
    ]

    inferred = _infer_motis_step_directions(steps)

    assert inferred[1]["relativeDirection"] == "CONTINUE"


def test_infer_motis_step_directions_never_overrides_elevator_or_stairs():
    steps = [
        _step([(42.0000, -83.0000), (42.0009, -83.0000)], distance=100),
        _step(
            [(42.0009, -83.0000), (42.0009, -82.9990)],
            distance=82,
            direction="ELEVATOR",
        ),
    ]

    inferred = _infer_motis_step_directions(steps)

    assert inferred[1]["relativeDirection"] == "ELEVATOR"


def test_motis_itinerary_to_route_reports_real_turns_not_just_continue():
    """Regression test: MOTIS always reports "CONTINUE" per raw step, so
    without direction inference the whole leg collapses into a single
    "Continue straight" instruction and no turns are ever announced.
    """
    connection = {
        "duration": 200,
        "legs": [
            {
                "mode": "WALK",
                "from": {"name": "Origin", "lat": 42.0000, "lon": -83.0000},
                "to": {"name": "Destination", "lat": 42.0009, "lon": -82.9990},
                "duration": 200,
                "distance": 182,
                "steps": [
                    _step(
                        [(42.0000, -83.0000), (42.0009, -83.0000)],
                        distance=100,
                        street="Ouellette Avenue",
                    ),
                    _step(
                        [(42.0009, -83.0000), (42.0009, -82.9990)],
                        distance=82,
                        street="Wyandotte Street",
                    ),
                ],
            }
        ],
    }

    route = _motis_itinerary_to_route(
        connection, "motis_route_1", "Origin", "Destination",
        42.0000, -83.0000, 42.0009, -82.9990,
        signals=[],
    )

    instructions = [s["instruction"] for s in route["legs"][0]["steps"]]
    assert len(instructions) == 2
    assert instructions[0] == "Continue on Ouellette Avenue for 100 metres"
    assert instructions[1] == "Turn right onto Wyandotte Street for 82 metres"
