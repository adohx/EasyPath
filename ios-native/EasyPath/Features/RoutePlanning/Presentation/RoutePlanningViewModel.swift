import Foundation

@Observable
@MainActor
final class RoutePlanningViewModel {
    private(set) var searchResults: [Place] = []
    private(set) var routeOptions: [RoutePlan] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: RoutePlanningRepositoring
    private let speechOutput: SpeechOutputting

    init(repository: RoutePlanningRepositoring, speechOutput: SpeechOutputting) {
        self.repository = repository
        self.speechOutput = speechOutput
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            searchResults = try await repository.searchDestinations(query: query)
        } catch {
            Log.navigation.error("Destination search failed: \(error)")
            errorMessage = "Could not search for that destination."
            searchResults = []
        }
    }

    /// Plans routes from `origin` to `destination` and announces the
    /// first option's summary per design doc section 2.1.8.
    func planRoutes(origin: Coordinates, to destination: Place) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            routeOptions = try await repository.planRoutes(
                origin: origin,
                destination: destination.coordinates,
                originName: "Current Location",
                destinationName: destination.name
            )
            if let first = routeOptions.first {
                await speechOutput.speak(
                    Self.summary(for: first),
                    priority: .navigationOrExploration
                )
            }
        } catch {
            Log.navigation.error("Route planning failed: \(error)")
            errorMessage = "Could not plan a route to that destination."
            routeOptions = []
        }
    }

    private static func summary(for route: RoutePlan) -> String {
        let minutes = route.totalDurationSeconds / 60
        return "Estimated total time: \(minutes) minutes, "
            + "with \(route.transferCount) transfers."
    }
}
