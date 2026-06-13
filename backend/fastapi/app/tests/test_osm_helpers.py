import pytest

from main import _osm_category, _overpass_to_categories


@pytest.mark.parametrize(
    ("tags", "expected"),
    [
        ({"amenity": "cafe"}, "restaurant"),
        ({"amenity": "pharmacy"}, "pharmacy"),
        ({"shop": "supermarket"}, "shop"),
        ({"highway": "bus_stop"}, "bus_stop"),
        ({"leisure": "park"}, "park"),
        ({"amenity": "spaceport"}, None),
        ({}, None),
    ],
)
def test_osm_category_maps_known_tags(tags, expected):
    assert _osm_category(tags) == expected


def test_osm_category_prefers_amenity_over_shop():
    tags = {"amenity": "cafe", "shop": "convenience"}
    assert _osm_category(tags) == "restaurant"


def test_overpass_to_categories_groups_and_sorts_by_distance():
    center_lat, center_lon = 42.3150, -83.0360
    elements = [
        {
            "type": "node",
            "id": 1,
            "lat": center_lat + 0.002,
            "lon": center_lon,
            "tags": {"amenity": "cafe", "name": "Far Cafe"},
        },
        {
            "type": "node",
            "id": 2,
            "lat": center_lat + 0.0005,
            "lon": center_lon,
            "tags": {"amenity": "cafe", "name": "Near Cafe"},
        },
        {
            "type": "node",
            "id": 3,
            "lat": center_lat,
            "lon": center_lon + 0.001,
            "tags": {"highway": "bus_stop", "name": "Main St Stop"},
        },
    ]

    categories = _overpass_to_categories(elements, center_lat, center_lon)

    assert set(categories.keys()) == {"restaurant", "bus_stop"}
    restaurant_ids = [item["id"] for item in categories["restaurant"]]
    assert restaurant_ids == ["osm_2", "osm_1"]


def test_overpass_to_categories_skips_non_node_and_unmapped_tags():
    elements = [
        {"type": "way", "id": 10, "tags": {"amenity": "cafe"}},
        {"type": "node", "id": 11, "lat": 42.31, "lon": -83.03, "tags": {}},
        {
            "type": "node",
            "id": 12,
            "lat": 42.31,
            "lon": -83.03,
            "tags": {"amenity": "spaceport"},
        },
    ]

    assert _overpass_to_categories(elements, 42.3150, -83.0360) == {}


@pytest.mark.parametrize(
    ("tags", "expected_name"),
    [
        ({"amenity": "cafe", "name": "Joe's Cafe"}, "Joe's Cafe"),
        ({"amenity": "cafe", "brand": "Tim Hortons"}, "Tim Hortons"),
        ({"amenity": "cafe", "operator": "Acme Co"}, "Acme Co"),
        ({"highway": "bus_stop"}, "Bus Stop"),
    ],
)
def test_overpass_to_categories_name_fallback_order(tags, expected_name):
    elements = [{"type": "node", "id": 1, "lat": 42.31, "lon": -83.03, "tags": tags}]
    categories = _overpass_to_categories(elements, 42.3150, -83.0360)
    item = next(iter(categories.values()))[0]
    assert item["name"] == expected_name
