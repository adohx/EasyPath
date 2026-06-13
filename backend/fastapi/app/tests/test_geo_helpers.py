import pytest

from main import _bearing, _decode_polyline, _haversine


def test_haversine_same_point_is_zero():
    assert _haversine(42.3149, -83.0364, 42.3149, -83.0364) == 0


def test_haversine_one_degree_latitude_is_about_111km():
    distance = _haversine(0, 0, 1, 0)
    assert distance == pytest.approx(111_195, abs=50)


def test_haversine_one_degree_longitude_at_equator_is_about_111km():
    distance = _haversine(0, 0, 0, 1)
    assert distance == pytest.approx(111_195, abs=50)


def test_haversine_is_symmetric():
    a = (42.3149, -83.0364)
    b = (42.3192, -83.0391)
    assert _haversine(*a, *b) == pytest.approx(_haversine(*b, *a))


@pytest.mark.parametrize(
    ("lat2", "lon2", "expected_bearing"),
    [
        (1, 0, 0),  # due north
        (0, 1, 90),  # due east
        (-1, 0, 180),  # due south
        (0, -1, 270),  # due west
    ],
)
def test_bearing_cardinal_directions(lat2, lon2, expected_bearing):
    assert _bearing(0, 0, lat2, lon2) == pytest.approx(
        expected_bearing, abs=0.5
    )


def _flatten(coords: list[list[float]]) -> list[float]:
    return [value for point in coords for value in point]


def test_decode_polyline_matches_google_example():
    encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    coords = _decode_polyline(encoded, 5)
    assert _flatten(coords) == pytest.approx(
        _flatten([[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]])
    )


def test_decode_polyline_at_motis_precision_7():
    encoded = "wq|afXrmoxnp@lggIqmrg@"
    coords = _decode_polyline(encoded, 7)
    assert _flatten(coords) == pytest.approx(
        _flatten([[42.3148332, -83.036593], [42.2980261, -82.9700609]])
    )
