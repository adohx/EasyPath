import Foundation

final class APIExplorationRepository: ExplorationRepositoring {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func nearby(
        center: Coordinates,
        radiusMeters: Int
    ) async throws -> [ExplorationCategory: [ExplorationItem]] {
        try await apiClient.nearbyExploration(center: center, radiusMeters: radiusMeters)
    }
}
