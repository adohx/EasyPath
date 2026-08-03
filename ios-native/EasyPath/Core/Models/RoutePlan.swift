import Foundation

/// A single candidate itinerary returned by `POST /api/routes/plan`.
///
/// Named after the backend's `RoutePlan` response object (see
/// `docs/4.接口文档.md` section 4.2), which plays the same role as
/// `JourneyPlan` in the original product design doc (section 7.1).
struct RoutePlan: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let mode: TravelMode
    let totalDurationSeconds: Int
    let totalWalkingDistanceMeters: Double
    let transferCount: Int
    let legs: [JourneyLeg]
    let functionalPoints: [FunctionalPoint]
    let riskPoints: [RiskPoint]
    let accessibilitySummary: AccessibilitySummary
    let geometry: [Coordinates]

    enum CodingKeys: String, CodingKey {
        case id, mode, legs, geometry
        case totalDurationSeconds = "total_duration_seconds"
        case totalWalkingDistanceMeters = "total_walking_distance_meters"
        case transferCount = "transfer_count"
        case functionalPoints = "functional_points"
        case riskPoints = "risk_points"
        case accessibilitySummary = "accessibility_summary"
    }
}

enum TravelMode: String, Codable, Sendable {
    case walk
    case transit
    case bus
    case taxi
}

/// One leg of a route, e.g. a walking segment or a single bus ride.
///
/// See `docs/4.接口文档.md` section 4.3.
struct JourneyLeg: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let mode: TravelMode
    let from: LegEndpoint
    let to: LegEndpoint
    let durationSeconds: Int
    let distanceMeters: Double
    let steps: [NavigationStep]
    let transitInfo: TransitInfo?

    enum CodingKeys: String, CodingKey {
        case id, mode, from, to, steps
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case transitInfo = "transit_info"
    }
}

struct LegEndpoint: Codable, Hashable, Sendable {
    let name: String
    let coordinates: Coordinates
}

struct NavigationStep: Codable, Hashable, Sendable {
    let instruction: String
    let distanceMeters: Double

    enum CodingKeys: String, CodingKey {
        case instruction
        case distanceMeters = "distance_meters"
    }
}

/// Present only when `JourneyLeg.mode == .bus`.
///
/// `scheduled == false` means the timing came from MOTIS real-time data
/// rather than the static GTFS schedule (design doc section 4.1.2 requires
/// this distinction to always be surfaced to the user).
struct TransitInfo: Codable, Hashable, Sendable {
    let route: String
    let headsign: String
    let agency: String
    let scheduled: Bool
}
