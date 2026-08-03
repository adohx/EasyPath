import CoreLocation
import Foundation

@Observable
@MainActor
final class OutdoorNavigationViewModel {
    private(set) var state: NavigationState?
    private(set) var isNavigating = false

    private let locationProvider: LocationProviding
    private let speechOutput: SpeechOutputting
    private let haptics: HapticsPlaying
    private var route: RoutePlan?
    private var consecutiveOffRouteReadings = 0

    /// Design doc section 2.2.5: a single noisy GPS fix should not
    /// trigger an off-route warning — require several consecutive
    /// off-route readings first.
    private static let offRouteConfirmationCount = 3

    private var locationTask: Task<Void, Never>?

    init(locationProvider: LocationProviding, speechOutput: SpeechOutputting, haptics: HapticsPlaying) {
        self.locationProvider = locationProvider
        self.speechOutput = speechOutput
        self.haptics = haptics
    }

    func startNavigating(route: RoutePlan) {
        self.route = route
        isNavigating = true
        consecutiveOffRouteReadings = 0

        locationProvider.requestWhenInUseAuthorization()
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self else { return }
            for await location in locationProvider.locationUpdates() {
                await self.handle(location: location)
            }
        }
    }

    func stopNavigating() {
        isNavigating = false
        locationTask?.cancel()
        locationTask = nil
        route = nil
        state = nil
    }

    private func handle(location: CLLocation) async {
        guard let route else { return }

        let newState = NavigationStateBuilder.build(
            location: Coordinates(location.coordinate),
            headingDegrees: location.course >= 0 ? location.course : nil,
            speedMetersPerSecond: location.speed >= 0 ? location.speed : nil,
            route: route,
            functionalPoints: route.functionalPoints,
            riskPoints: route.riskPoints
        )
        state = newState

        if newState.isOffRoute {
            consecutiveOffRouteReadings += 1
        } else {
            consecutiveOffRouteReadings = 0
        }

        if consecutiveOffRouteReadings == Self.offRouteConfirmationCount {
            await haptics.play(.urgentBurst)
            await speechOutput.speak(
                "You may be walking away from the route. Please stop and confirm your direction.",
                priority: .riskPoint
            )
        }
    }
}
