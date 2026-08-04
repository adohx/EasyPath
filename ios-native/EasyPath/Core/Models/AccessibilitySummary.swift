import Foundation

/// The accessibility score for a route, plus the raw inputs that produced
/// it — the design doc (section 2.1.9) is explicit that the score must
/// never be announced without also announcing what it was computed from.
///
/// - Note: field names/set confirmed 2026-08-03 directly against
/// `_motis_itinerary_to_route` in `backend/fastapi/app/main.py` — the
/// previous version of this type was written from `docs/4.接口文档.md`'s
/// example (which used a different, richer field set that the backend
/// never actually implemented) and silently decoded every field to `nil`
/// as a result, since all fields were optional. Kept optional here too
/// even though the backend currently always sends them, since that
/// contract still isn't formally pinned down.
struct AccessibilitySummary: Codable, Hashable, Sendable {
    let score: Int?
    let streetCrossings: Int?
    let transferCount: Int?
    let knownEntrances: Int?
    let audibleSignals: Int?
    let constructionAlerts: Int?
    let walkingDistanceMeters: Double?
    let dataComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case score
        case streetCrossings = "street_crossings"
        case transferCount = "transfer_count"
        case knownEntrances = "known_entrances"
        case audibleSignals = "audible_signals"
        case constructionAlerts = "construction_alerts"
        case walkingDistanceMeters = "walking_distance_meters"
        case dataComplete = "data_complete"
    }
}
