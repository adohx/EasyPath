import Foundation

/// Search-mode (探路模式) domain boundary: destination search plus
/// generating and comparing candidate `RoutePlan`s. Corresponds to
/// design doc sections 2.1.1 through 2.1.10.
protocol RoutePlanningRepositoring: Sendable {
    func searchDestinations(query: String) async throws -> [Place]
    func planRoutes(
        origin: Coordinates,
        destination: Coordinates,
        originName: String?,
        destinationName: String?
    ) async throws -> [RoutePlan]
}
