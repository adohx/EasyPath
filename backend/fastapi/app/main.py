from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Accessibility Navigation Assistant API",
    description="Backend API for the ANA app - Phase 1 (mock data)",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check():
    return {"status": "ok", "phase": 1}


@app.get("/api/places/search")
def search_places(q: str):
    """Mock place search - returns hardcoded Windsor results for Phase 1."""
    return {
        "query": q,
        "results": [
            {
                "id": "place_001",
                "name": "Windsor Public Library",
                "address": "850 Ouellette Avenue, Windsor, ON",
                "coordinates": {"lat": 42.3192, "lon": -83.0391},
                "type": "library",
            },
            {
                "id": "place_002",
                "name": "Windsor Regional Hospital",
                "address": "1995 Lens Avenue, Windsor, ON",
                "coordinates": {"lat": 42.2800, "lon": -83.0050},
                "type": "hospital",
            },
        ],
    }


@app.get("/api/places/reverse")
def reverse_geocode(lat: float, lon: float):
    """Mock reverse geocode."""
    return {
        "coordinates": {"lat": lat, "lon": lon},
        "address": "Ouellette Avenue and Wyandotte Street, Windsor, ON",
        "confidence": "medium",
    }


@app.post("/api/routes/plan")
def plan_route(body: dict):
    """Mock route planning - returns two sample routes for Phase 1."""
    return {
        "routes": [
            {
                "id": "route_001",
                "mode": "transit",
                "total_duration_seconds": 1680,
                "total_walking_distance_meters": 450,
                "transfer_count": 0,
                "legs": [
                    {
                        "id": "leg_001",
                        "mode": "walk",
                        "from": {"name": "Current Location", "coordinates": {"lat": 42.3150, "lon": -83.0360}},
                        "to": {"name": "Ouellette Ave at Wyandotte St", "coordinates": {"lat": 42.3170, "lon": -83.0370}},
                        "duration_seconds": 180,
                        "distance_meters": 250,
                        "steps": [
                            {"instruction": "Head north on Ouellette Avenue", "distance_meters": 250},
                        ],
                    },
                    {
                        "id": "leg_002",
                        "mode": "bus",
                        "from": {"name": "Ouellette Ave at Wyandotte St", "coordinates": {"lat": 42.3170, "lon": -83.0370}},
                        "to": {"name": "Ouellette Ave at Elliott St", "coordinates": {"lat": 42.3190, "lon": -83.0385}},
                        "duration_seconds": 1200,
                        "distance_meters": 2100,
                        "transit_info": {"route": "1A", "headsign": "Downtown", "scheduled": True},
                        "steps": [],
                    },
                    {
                        "id": "leg_003",
                        "mode": "walk",
                        "from": {"name": "Ouellette Ave at Elliott St", "coordinates": {"lat": 42.3190, "lon": -83.0385}},
                        "to": {"name": "Windsor Public Library - Main Entrance", "coordinates": {"lat": 42.3192, "lon": -83.0391}},
                        "duration_seconds": 300,
                        "distance_meters": 200,
                        "steps": [
                            {"instruction": "Walk north on Ouellette Avenue", "distance_meters": 120},
                            {"instruction": "Turn left — library entrance is on your left", "distance_meters": 80},
                        ],
                    },
                ],
                "functional_points": [
                    {"id": "fp_001", "type": "bus_board", "description": "Board bus 1A at Ouellette Ave / Wyandotte St", "importance": "required", "trigger_distance_meters": 80, "coordinates": {"lat": 42.3170, "lon": -83.0370}},
                    {"id": "fp_002", "type": "bus_alight", "description": "Alight at Ouellette Ave / Elliott St", "importance": "required", "trigger_distance_meters": 80, "coordinates": {"lat": 42.3190, "lon": -83.0385}},
                    {"id": "fp_003", "type": "building_entrance", "description": "Windsor Public Library — main entrance", "importance": "navigation", "trigger_distance_meters": 40, "coordinates": {"lat": 42.3192, "lon": -83.0391}},
                ],
                "risk_points": [
                    {"id": "rp_001", "type": "intersection", "description": "Large intersection at Ouellette Ave and Wyandotte St — pedestrian signal present", "severity": "medium", "trigger_distance_meters": 100, "coordinates": {"lat": 42.3170, "lon": -83.0370}},
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
            {
                "id": "route_002",
                "mode": "walk",
                "total_duration_seconds": 2400,
                "total_walking_distance_meters": 1800,
                "transfer_count": 0,
                "legs": [
                    {
                        "id": "leg_101",
                        "mode": "walk",
                        "from": {"name": "Current Location", "coordinates": {"lat": 42.3150, "lon": -83.0360}},
                        "to": {"name": "Windsor Public Library - Main Entrance", "coordinates": {"lat": 42.3192, "lon": -83.0391}},
                        "duration_seconds": 2400,
                        "distance_meters": 1800,
                        "steps": [
                            {"instruction": "Head north on Ouellette Avenue for approximately 300 metres", "distance_meters": 300},
                            {"instruction": "Continue north past Wyandotte Street intersection", "distance_meters": 500},
                            {"instruction": "Continue north on Ouellette Avenue for approximately 1 kilometre", "distance_meters": 1000},
                            {"instruction": "Library entrance is on your left", "distance_meters": 0},
                        ],
                    },
                ],
                "functional_points": [
                    {"id": "fp_101", "type": "building_entrance", "description": "Windsor Public Library — main entrance", "importance": "navigation", "trigger_distance_meters": 40, "coordinates": {"lat": 42.3192, "lon": -83.0391}},
                ],
                "risk_points": [
                    {"id": "rp_101", "type": "intersection", "description": "Large intersection at Ouellette Ave and Wyandotte St", "severity": "medium", "trigger_distance_meters": 100, "coordinates": {"lat": 42.3170, "lon": -83.0370}},
                    {"id": "rp_102", "type": "intersection", "description": "Intersection at Ouellette Ave and University Ave", "severity": "low", "trigger_distance_meters": 80, "coordinates": {"lat": 42.3180, "lon": -83.0380}},
                ],
                "accessibility_summary": {
                    "score": 65,
                    "street_crossings": 4,
                    "transfer_count": 0,
                    "known_entrances": 1,
                    "audible_signals": 1,
                    "construction_alerts": 0,
                    "walking_distance_meters": 1800,
                    "data_complete": True,
                },
            },
        ]
    }


@app.get("/api/exploration/nearby")
def nearby_exploration(lat: float, lon: float, radius_meters: int = 300):
    """Mock nearby exploration points around a location."""
    return {
        "center": {"lat": lat, "lon": lon},
        "radius_meters": radius_meters,
        "categories": {
            "restaurant": [
                {"id": "exp_001", "name": "Cafe Ambrosia", "distance_meters": 50, "bearing_degrees": 45, "coordinates": {"lat": lat + 0.0003, "lon": lon + 0.0003}},
                {"id": "exp_002", "name": "The Artichoke", "distance_meters": 80, "bearing_degrees": 180, "coordinates": {"lat": lat - 0.0005, "lon": lon}},
            ],
            "pharmacy": [
                {"id": "exp_003", "name": "Shoppers Drug Mart", "distance_meters": 120, "bearing_degrees": 270, "coordinates": {"lat": lat, "lon": lon - 0.001}},
            ],
            "bus_stop": [
                {"id": "exp_004", "name": "Ouellette Ave at Elliott St", "distance_meters": 60, "bearing_degrees": 0, "coordinates": {"lat": lat + 0.0004, "lon": lon}},
            ],
            "hotel": [
                {"id": "exp_005", "name": "Holiday Inn Windsor", "distance_meters": 200, "bearing_degrees": 90, "coordinates": {"lat": lat, "lon": lon + 0.002}},
                {"id": "exp_006", "name": "Radisson Riverfront Hotel", "distance_meters": 280, "bearing_degrees": 135, "coordinates": {"lat": lat - 0.001, "lon": lon + 0.002}},
            ],
            "parking": [
                {"id": "exp_007", "name": "Library Parking Lot", "distance_meters": 90, "bearing_degrees": 315, "coordinates": {"lat": lat + 0.0003, "lon": lon - 0.0006}},
            ],
        },
    }
