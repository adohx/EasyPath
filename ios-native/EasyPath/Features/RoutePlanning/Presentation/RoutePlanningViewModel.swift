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
    private let handoffService: AppHandoffServicing

    init(
        repository: RoutePlanningRepositoring,
        speechOutput: SpeechOutputting,
        handoffService: AppHandoffServicing
    ) {
        self.repository = repository
        self.speechOutput = speechOutput
        self.handoffService = handoffService
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

    /// Hands `leg` off to a specialized third-party app instead of
    /// tracking it ourselves — demo of the orchestration direction
    /// discussed with the product manager (see
    /// `.claude/memory/third_party_deeplink_feasibility.md` and
    /// `docs/9.第三方生态调研与集成可行性.md`). Not the default path;
    /// see this module's README.
    func openLegInThirdPartyApp(_ leg: JourneyLeg, target: HandoffTarget) async {
        let mode: HandoffTravelMode = switch leg.mode {
        case .walk: .walking
        case .transit, .bus: .transit
        case .taxi: .driving
        }
        let opened = await handoffService.openDirections(
            to: leg.to.coordinates,
            destinationName: leg.to.name,
            from: leg.from.coordinates,
            mode: mode,
            in: target
        )
        if !opened {
            errorMessage = "\(target.displayName) isn't installed."
        }
    }

    private static func summary(for route: RoutePlan) -> String {
        let minutes = route.totalDurationSeconds / 60
        return "Estimated total time: \(minutes) minutes, "
            + "with \(route.transferCount) transfers."
    }
}
