import Foundation

/// Thin adapter over `APIClientProtocol` — this feature currently has no
/// transformation to do beyond what `Core/Networking` already returns.
/// Waypoint support (design doc section 2.1.4, multi-stop `/api/routes/plan`
/// requests) is not yet implemented client- or server-side; see this
/// module's README.
final class APIRoutePlanningRepository: RoutePlanningRepositoring {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func searchDestinations(query: String) async throws -> [Place] {
        try await apiClient.searchPlaces(query: query)
    }

    func planRoutes(
        origin: Coordinates,
        destination: Coordinates,
        originName: String?,
        destinationName: String?
    ) async throws -> [RoutePlan] {
        try await apiClient.planRoutes(
            origin: origin,
            destination: destination,
            originName: originName,
            destinationName: destinationName
        )
    }
}
