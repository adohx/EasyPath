import Foundation

/// Official (map-data-sourced) points of interest around a location —
/// design doc sections 1.1.3 and 2.1.2. Read-only; user-saved places are
/// `PersonalPlaces`' responsibility, merged into the same UI by category
/// (see this module's README).
protocol ExplorationRepositoring: Sendable {
    func nearby(
        center: Coordinates,
        radiusMeters: Int
    ) async throws -> [ExplorationCategory: [ExplorationItem]]
}
