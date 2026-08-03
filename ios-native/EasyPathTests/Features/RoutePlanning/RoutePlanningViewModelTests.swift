import Foundation
import Testing
@testable import EasyPath

@MainActor
struct RoutePlanningViewModelTests {
    private func makeViewModel(
        recognizer: FakeSpeechRecognizer = FakeSpeechRecognizer(),
        repository: FakeRoutePlanningRepository = FakeRoutePlanningRepository(),
        settingsStore: FakeAppSettingsStore = FakeAppSettingsStore()
    ) -> RoutePlanningViewModel {
        RoutePlanningViewModel(
            repository: repository,
            speechOutput: FakeSpeechOutput(),
            speechRecognizer: recognizer,
            handoffService: FakeAppHandoffService(),
            settingsStore: settingsStore
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
        routesToReturn
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
