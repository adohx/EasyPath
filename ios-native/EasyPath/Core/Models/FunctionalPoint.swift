import Foundation

/// A point along a route that the user must notice to complete the trip
/// successfully — a turn, a bus stop, a building entrance.
///
/// Mirrors `docs/1.无障碍出行辅助系统_产品与技术设计文档.md` section 4.3.3
/// and the `FunctionalPoint` type table in `docs/4.接口文档.md` section 4.4.
struct FunctionalPoint: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let type: FunctionalPointType
    let location: Coordinates
    let description: String
    let importance: FunctionalPointImportance
    let triggerDistanceMeters: Double
    let requiresConfirmation: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, location, description, importance
        case triggerDistanceMeters = "trigger_distance_meters"
        case requiresConfirmation = "requires_confirmation"
    }
}

/// - Note: The backend currently only emits the "required" transit-transfer
/// cases (`buildingEntrance`, `busBoard`, `busAlight`, `busTransfer`).
/// "Navigation" cases (turns, landmarks) are part of the design (section
/// 4.3.2) but not yet produced by `/api/routes/plan` as of `docs/4.接口文档.md`.
enum FunctionalPointType: String, Codable, Sendable {
    case buildingEntrance = "building_entrance"
    case busBoard = "bus_board"
    case busAlight = "bus_alight"
    case busTransfer = "bus_transfer"
    case turn
    case landmark
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FunctionalPointType(rawValue: raw) ?? .unknown
    }
}

enum FunctionalPointImportance: String, Codable, Sendable {
    case navigation
    case required
}
