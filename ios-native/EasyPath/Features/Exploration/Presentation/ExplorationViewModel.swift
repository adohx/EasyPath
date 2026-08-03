import Foundation

@Observable
@MainActor
final class ExplorationViewModel {
    private(set) var categories: [ExplorationCategory: [ExplorationItem]] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: ExplorationRepositoring

    init(repository: ExplorationRepositoring) {
        self.repository = repository
    }

    /// Loads nearby points of interest around `center` — either the
    /// user's current location or a searched-for place, per design doc
    /// section 2.1.2 ("探索"和"查找地点" share one entry point).
    func loadNearby(center: Coordinates, radiusMeters: Int = 200) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            categories = try await repository.nearby(center: center, radiusMeters: radiusMeters)
        } catch {
            Log.exploration.error("Nearby exploration query failed: \(error)")
            errorMessage = "Could not load nearby places."
            categories = [:]
        }
    }
}
