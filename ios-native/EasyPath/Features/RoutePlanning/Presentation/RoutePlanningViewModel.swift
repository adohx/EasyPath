import CoreLocation
import Foundation

@Observable
@MainActor
final class RoutePlanningViewModel {
    var query = ""
    private(set) var searchResults: [Place] = []
    private(set) var routeOptions: [RoutePlan] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isListening = false

    private let repository: RoutePlanningRepositoring
    private let speechOutput: SpeechOutputting
    private let speechRecognizer: SpeechRecognizing
    private let handoffService: AppHandoffServicing
    private let settingsStore: AppSettingsStoring
    private let locationProvider: LocationProviding

    init(
        repository: RoutePlanningRepositoring,
        speechOutput: SpeechOutputting,
        speechRecognizer: SpeechRecognizing,
        handoffService: AppHandoffServicing,
        settingsStore: AppSettingsStoring,
        locationProvider: LocationProviding
    ) {
        self.repository = repository
        self.speechOutput = speechOutput
        self.speechRecognizer = speechRecognizer
        self.handoffService = handoffService
        self.settingsStore = settingsStore
        self.locationProvider = locationProvider
    }

    /// Formats a distance per the user's `MeasurementUnit` preference
    /// (design doc section 1.1.1) — used for `RouteSummaryRow`'s walking
    /// distance display.
    func formattedDistance(_ meters: Double) -> String {
        DistanceFormatter.string(meters: meters, unit: settingsStore.load().measurementUnit)
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

    func searchCurrentQuery() async {
        await search(query: query)
    }

    /// Design doc section 3.1.1.1's "hold to talk" flow, tap-to-toggle
    /// instead of press-and-hold: a hold gesture isn't reliably
    /// discoverable with VoiceOver, so `RoutePlanningView`'s microphone
    /// button starts listening on one tap and stops on the next.
    func startVoiceInput() async {
        let authorized = await speechRecognizer.requestAuthorization()
        guard authorized else {
            errorMessage = "Speech recognition isn't authorized in Settings."
            return
        }
        do {
            try speechRecognizer.startListening()
            isListening = true
        } catch {
            Log.navigation.error("Failed to start speech recognition: \(error)")
            errorMessage = "Couldn't start listening."
        }
    }

    /// Stops listening, and if a transcript came back, fills it into
    /// `query` and searches with it immediately — mirroring the design
    /// doc's "识别文字 → 意图识别（这里简化为直接搜索）→ TTS 确认" flow.
    func stopVoiceInputAndSearch() async {
        isListening = false
        guard let transcript = await speechRecognizer.stopListening(), !transcript.isEmpty else {
            return
        }
        query = transcript
        await search(query: transcript)
    }

    /// Tapping a search result (design doc section 2.1.1): gets the
    /// user's current GPS fix as the origin — per section 2.1.5 the
    /// default origin is "current location", confirmed to the user via
    /// the spoken route summary `planRoutes` already announces — then
    /// plans routes to it. This is the only current entry point into
    /// `planRoutes`; there's no manual-origin flow yet.
    func selectDestination(_ place: Place) async {
        isLoading = true
        errorMessage = nil

        locationProvider.requestWhenInUseAuthorization()
        var location: CLLocation?
        for await update in locationProvider.locationUpdates() {
            location = update
            break
        }
        guard let location else {
            isLoading = false
            errorMessage = "Could not determine your current location."
            return
        }

        isLoading = false
        await planRoutes(origin: Coordinates(location.coordinate), to: place)
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
