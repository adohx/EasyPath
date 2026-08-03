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
    let source: String
    let updatedAt: Date?
    let triggerDistanceMeters: Double

    enum CodingKeys: String, CodingKey {
        case id, type, location, description, severity, source
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
