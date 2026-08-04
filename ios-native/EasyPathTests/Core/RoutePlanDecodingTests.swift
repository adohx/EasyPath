import Foundation
import Testing
@testable import EasyPath

/// Regression tests for the 2026-08-03 bug where `FunctionalPoint`,
/// `RiskPoint`, and `AccessibilitySummary` were modelled from
/// `docs/4.接口文档.md`'s example JSON rather than what the backend
/// (`backend/fastapi/app/main.py`) actually sends, breaking route
/// planning outright with `DecodingError`s on a real device. Each test
/// uses a JSON literal copied from a real `/api/routes/plan` response.
struct RoutePlanDecodingTests {
    @Test func decodesFunctionalPointFromRealBackendShape() throws {
        let json = """
        {
          "id": "motis_route_1_fp_1",
          "type": "bus_board",
          "description": "Board Route 1C (Transway1C) at Mill at Sandwich",
          "importance": "required",
          "trigger_distance_meters": 80,
          "coordinates": {"lat": 42.302008730000004, "lon": -83.07538136999997}
        }
        """
        let point = try JSONDecoder().decode(FunctionalPoint.self, from: Data(json.utf8))

        #expect(point.location.latitude == 42.302008730000004)
        #expect(point.requiresConfirmation == nil)
    }

    @Test func decodesRiskPointFromRealBackendShape() throws {
        let json = """
        {
          "id": "motis_route_1_rp_1",
          "type": "intersection",
          "description": "Signalised intersection",
          "severity": "medium",
          "trigger_distance_meters": 100,
          "coordinates": {"lat": 42.3134318, "lon": -83.0387507}
        }
        """
        let point = try JSONDecoder().decode(RiskPoint.self, from: Data(json.utf8))

        #expect(point.location.longitude == -83.0387507)
        #expect(point.source == nil)
    }

    @Test func decodesAccessibilitySummaryFromRealBackendShape() throws {
        let json = """
        {
          "score": 66,
          "street_crossings": 5,
          "transfer_count": 0,
          "known_entrances": 1,
          "audible_signals": 5,
          "construction_alerts": 0,
          "walking_distance_meters": 821,
          "data_complete": true
        }
        """
        let summary = try JSONDecoder().decode(AccessibilitySummary.self, from: Data(json.utf8))

        #expect(summary.score == 66)
        #expect(summary.streetCrossings == 5)
        #expect(summary.knownEntrances == 1)
        #expect(summary.dataComplete == true)
    }

    @Test func decodesFullRoutePlanFromRealBackendShape() throws {
        let json = """
        {
          "id": "motis_route_1",
          "mode": "walk",
          "total_duration_seconds": 493,
          "total_walking_distance_meters": 569,
          "transfer_count": 0,
          "legs": [],
          "functional_points": [
            {
              "id": "fp-1", "type": "building_entrance",
              "description": "City Hall — destination", "importance": "navigation",
              "trigger_distance_meters": 40,
              "coordinates": {"lat": 42.317, "lon": -83.035}
            }
          ],
          "risk_points": [
            {
              "id": "rp-1", "type": "intersection", "description": "Signalised intersection",
              "severity": "medium", "trigger_distance_meters": 100,
              "coordinates": {"lat": 42.313, "lon": -83.038}
            }
          ],
          "accessibility_summary": {
            "score": 66, "street_crossings": 1, "transfer_count": 0,
            "known_entrances": 1, "audible_signals": 1, "construction_alerts": 0,
            "walking_distance_meters": 569, "data_complete": true
          },
          "geometry": [[42.3148, -83.0365], [42.3149, -83.0359]]
        }
        """
        let route = try JSONDecoder().decode(RoutePlan.self, from: Data(json.utf8))

        #expect(route.functionalPoints.count == 1)
        #expect(route.riskPoints.count == 1)
        #expect(route.geometry.count == 2)
        #expect(route.accessibilitySummary.score == 66)
    }
}
