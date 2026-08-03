import Foundation

/// The accessibility score for a route, plus the raw inputs that produced
/// it — the design doc (section 2.1.9) is explicit that the score must
/// never be announced without also announcing what it was computed from.
///
/// - Note: `docs/4.接口文档.md` section 4.2 shows `accessibility_summary`
/// only as an opaque `{...}` object; the exact backend field set has not
/// been pinned down yet. Every field here is optional, so the synthesized
/// `Decodable` conformance treats missing keys as `nil` instead of failing
/// the whole `RoutePlan` decode. Update this once the backend response
/// shape is confirmed against a live call.
struct AccessibilitySummary: Codable, Hashable, Sendable {
    let score: Int?
    let riskPointCount: Int?
    let importantIntersectionCount: Int?
    let crossingCount: Int?
    let hasConstruction: Bool?
    let hasSidewalkClosure: Bool?
    let hasSteps: Bool?
    let hasAccessibleEntrance: Bool?
    let hasAudiblePedestrianSignal: Bool?
    let requiresParkingLotCrossing: Bool?
    let dataComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case score
        case riskPointCount = "risk_point_count"
        case importantIntersectionCount = "important_intersection_count"
        case crossingCount = "crossing_count"
        case hasConstruction = "has_construction"
        case hasSidewalkClosure = "has_sidewalk_closure"
        case hasSteps = "has_steps"
        case hasAccessibleEntrance = "has_accessible_entrance"
        case hasAudiblePedestrianSignal = "has_audible_pedestrian_signal"
        case requiresParkingLotCrossing = "requires_parking_lot_crossing"
        case dataComplete = "data_complete"
    }
}
