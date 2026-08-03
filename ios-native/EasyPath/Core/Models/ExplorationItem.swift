import Foundation

/// A point of interest returned by `GET /api/exploration/nearby`, grouped
/// by category on the response's `categories` map.
///
/// Mirrors section 4.5 of
/// `docs/1.无障碍出行辅助系统_产品与技术设计文档.md`. This is always an
/// "official" exploration point sourced from map data — it carries no
/// user-editable category or tag, unlike `TrackedPlace`.
struct ExplorationItem: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let category: ExplorationCategory
    let name: String
    let location: Coordinates
    let distanceMeters: Double
    let bearingDegrees: Double
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case id, category, name, location, priority
        case distanceMeters = "distance_meters"
        case bearingDegrees = "bearing_degrees"
    }
}

/// Conforms to `CodingKeyRepresentable` (via the default implementation
/// for `String`-backed `RawRepresentable` types) so
/// `[ExplorationCategory: [ExplorationItem]]` can decode directly from the
/// `categories` JSON object in the `/api/exploration/nearby` response.
extension ExplorationCategory: CodingKeyRepresentable {}

enum ExplorationCategory: String, Codable, Sendable, CaseIterable {
    case restaurant
    case hotel
    case pharmacy
    case hospital
    case busStop = "bus_stop"
    case parking
    case restroom
    case shop
    case bank
    case publicFacility = "public_facility"
    case buildingEntrance = "building_entrance"
    case crosswalk
    case trafficSignal = "traffic_signal"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ExplorationCategory(rawValue: raw) ?? .unknown
    }
}
