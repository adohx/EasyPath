import Foundation

/// A location that requires extra caution — a signalled intersection,
/// construction, a sidewalk closure.
///
/// Mirrors section 7.3 of
/// `docs/1.无障碍出行辅助系统_产品与技术设计文档.md` and the `RiskPoint`
/// type table in `docs/4.接口文档.md` section 4.5.
struct RiskPoint: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let type: RiskPointType
    let location: Coordinates
    let description: String
    let severity: RiskSeverity
    /// The backend (`_motis_itinerary_to_route` in
    /// `backend/fastapi/app/main.py`) never actually sends this field —
    /// optional so a missing key decodes to `nil` instead of failing the
    /// whole `RoutePlan` decode (this broke route planning entirely on
    /// 2026-08-03 before being caught, alongside `location` below).
    let source: String?
    let updatedAt: Date?
    let triggerDistanceMeters: Double

    /// - Note: the wire key is `coordinates`, not `location` — the
    /// design doc's Dart-era naming didn't match what the backend
    /// actually emits. Same 2026-08-03 bug as `source`.
    enum CodingKeys: String, CodingKey {
        case id, type, description, severity, source
        case location = "coordinates"
        case updatedAt = "updated_at"
        case triggerDistanceMeters = "trigger_distance_meters"
    }
}

/// - Note: only `intersection` is currently populated by the backend
/// (from Overpass `highway=traffic_signals`). `busRisk` is modelled per the
/// design doc (section 4.4.2) but not yet produced — see
/// `docs/4.接口文档.md` section 4.5.
enum RiskPointType: String, Codable, Sendable {
    case intersection
    case busRisk = "bus_risk"
    case construction
    case sidewalkClosure = "sidewalk_closure"
    case steps
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RiskPointType(rawValue: raw) ?? .unknown
    }
}

enum RiskSeverity: String, Codable, Sendable {
    case low
    case medium
    case high
}
