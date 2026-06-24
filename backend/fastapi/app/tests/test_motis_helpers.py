from main import _merge_motis_steps, _motis_itinerary_to_route, _motis_step_instruction


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
