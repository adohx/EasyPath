import CoreLocation
import Foundation
import Testing
@testable import EasyPath

@MainActor
struct RoutePlanningViewModelTests {
    private func makeViewModel(
        recognizer: FakeSpeechRecognizer = FakeSpeechRecognizer(),
        repository: FakeRoutePlanningRepository = FakeRoutePlanningRepository(),
        settingsStore: FakeAppSettingsStore = FakeAppSettingsStore(),
        locationProvider: FakeLocationProvider = FakeLocationProvider()
    ) -> RoutePlanningViewModel {
        RoutePlanningViewModel(
            repository: repository,
            speechOutput: FakeSpeechOutput(),
            speechRecognizer: recognizer,
            handoffService: FakeAppHandoffService(),
            settingsStore: settingsStore,
            locationProvider: locationProvider
        )
    }

    @Test func stopVoiceInputAndSearchFillsQueryAndSearches() async {
        let recognizer = FakeSpeechRecognizer()
        recognizer.transcriptToReturn = "Windsor Public Library"
        let repository = FakeRoutePlanningRepository()
        repository.searchResultsToReturn = [
            Place(id: "1", name: "Windsor Public Library", address: nil, coordinates: Coordinates(latitude: 0, longitude: 0), type: nil),
        ]
        let viewModel = makeViewModel(recognizer: recognizer, repository: repository)

        await viewModel.startVoiceInput()
        #expect(viewModel.isListening == true)

        await viewModel.stopVoiceInputAndSearch()

        #expect(viewModel.isListening == false)
        #expect(viewModel.query == "Windsor Public Library")
        #expect(viewModel.searchResults.count == 1)
    }

    @Test func startVoiceInputFailsWhenNotAuthorized() async {
        let recognizer = FakeSpeechRecognizer()
        recognizer.authorizationResult = false
        let viewModel = makeViewModel(recognizer: recognizer)

        await viewModel.startVoiceInput()

        #expect(viewModel.isListening == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func emptyTranscriptDoesNotTriggerSearch() async {
        let recognizer = FakeSpeechRecognizer()
        recognizer.transcriptToReturn = nil
        let repository = FakeRoutePlanningRepository()
        let viewModel = makeViewModel(recognizer: recognizer, repository: repository)

        await viewModel.stopVoiceInputAndSearch()

        #expect(repository.searchCallCount == 0)
    }

    @Test func formattedDistanceUsesMetricByDefault() {
        let viewModel = makeViewModel()
        #expect(viewModel.formattedDistance(450) == "450m")
    }

    @Test func formattedDistanceHonorsImperialSetting() {
        let settingsStore = FakeAppSettingsStore()
        settingsStore.settings.measurementUnit = .imperial
        let viewModel = makeViewModel(settingsStore: settingsStore)

        #expect(viewModel.formattedDistance(100) == "328ft")
    }

    @Test func selectDestinationPlansRoutesFromCurrentLocation() async {
        let locationProvider = FakeLocationProvider()
        locationProvider.locationToYield = CLLocation(latitude: 42.3149, longitude: -83.0364)
        let repository = FakeRoutePlanningRepository()
        repository.routesToReturn = [
            RoutePlan(
                id: "route-1", mode: .walk, totalDurationSeconds: 300,
                totalWalkingDistanceMeters: 400, transferCount: 0, legs: [],
                functionalPoints: [], riskPoints: [],
                accessibilitySummary: AccessibilitySummary(
                    score: nil, streetCrossings: nil, transferCount: nil,
                    knownEntrances: nil, audibleSignals: nil, constructionAlerts: nil,
                    walkingDistanceMeters: nil, dataComplete: nil
                ),
                geometry: []
            ),
        ]
        let viewModel = makeViewModel(repository: repository, locationProvider: locationProvider)
        let destination = Place(
            id: "1", name: "Windsor City Hall", address: nil,
            coordinates: Coordinates(latitude: 42.3170535, longitude: -83.0349931), type: nil
        )

        await viewModel.selectDestination(destination)

        #expect(locationProvider.didRequestAuthorization)
        #expect(repository.lastPlanRoutesOrigin == Coordinates(latitude: 42.3149, longitude: -83.0364))
        #expect(repository.lastPlanRoutesDestination == destination.coordinates)
        #expect(viewModel.routeOptions.count == 1)
    }

    @Test func selectDestinationFailsWhenLocationUnavailable() async {
        let locationProvider = FakeLocationProvider()
        locationProvider.locationToYield = nil
        let repository = FakeRoutePlanningRepository()
        let viewModel = makeViewModel(repository: repository, locationProvider: locationProvider)
        let destination = Place(
            id: "1", name: "Windsor City Hall", address: nil,
            coordinates: Coordinates(latitude: 42.3170535, longitude: -83.0349931), type: nil
        )

        await viewModel.selectDestination(destination)

        #expect(viewModel.errorMessage != nil)
        #expect(repository.lastPlanRoutesDestination == nil)
    }
}

final class FakeSpeechRecognizer: SpeechRecognizing, @unchecked Sendable {
    var authorizationResult = true
    var transcriptToReturn: String?
    private(set) var didStartListening = false

    func requestAuthorization() async -> Bool { authorizationResult }

    func startListening() throws {
        didStartListening = true
    }

    func stopListening() async -> String? {
        transcriptToReturn
    }
}

final class FakeRoutePlanningRepository: RoutePlanningRepositoring, @unchecked Sendable {
    var searchResultsToReturn: [Place] = []
    var routesToReturn: [RoutePlan] = []
    private(set) var searchCallCount = 0
    private(set) var lastPlanRoutesOrigin: Coordinates?
    private(set) var lastPlanRoutesDestination: Coordinates?

    func searchDestinations(query: String) async throws -> [Place] {
        searchCallCount += 1
        return searchResultsToReturn
    }

    func planRoutes(
        origin: Coordinates,
        destination: Coordinates,
        originName: String?,
        destinationName: String?
    ) async throws -> [RoutePlan] {
        lastPlanRoutesOrigin = origin
        lastPlanRoutesDestination = destination
        return routesToReturn
    }
}

final class FakeLocationProvider: LocationProviding, @unchecked Sendable {
    var locationToYield: CLLocation? = CLLocation(latitude: 42.3149, longitude: -83.0364)
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    private(set) var didRequestAuthorization = false

    func requestWhenInUseAuthorization() {
        didRequestAuthorization = true
    }

    func locationUpdates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            if let locationToYield {
                continuation.yield(locationToYield)
            }
            continuation.finish()
        }
    }

    func headingUpdates() -> AsyncStream<HeadingReading> {
        AsyncStream { continuation in continuation.finish() }
    }
}

final class FakeSpeechOutput: SpeechOutputting, @unchecked Sendable {
    func speak(_ text: String, priority: AnnouncementPriorityTier) async {}
    func stop() {}
}

@MainActor
final class FakeAppHandoffService: AppHandoffServicing {
    var isInstalledResult = true
    var openDirectionsResult = true

    func isInstalled(_ target: HandoffTarget) -> Bool { isInstalledResult }

    func openDirections(
        to destination: Coordinates,
        destinationName: String?,
        from origin: Coordinates?,
        mode: HandoffTravelMode,
        in target: HandoffTarget
    ) async -> Bool {
        openDirectionsResult
    }
}

final class FakeAppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    var settings = AppSettings.default

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
}
