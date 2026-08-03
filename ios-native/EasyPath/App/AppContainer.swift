import Foundation
import SwiftData

/// The single composition root for the app: builds every concrete
/// infrastructure implementation once and hands out the protocol-typed
/// dependencies each feature's ViewModel needs, via manual constructor
/// injection. No third-party DI container is used (see
/// `.claude/guidelines.md`).
///
/// Add a new dependency here, not inside individual features — a
/// feature's `Data` layer should only ever receive protocols through its
/// initializer.
@MainActor
final class AppContainer {
    let apiClient: APIClientProtocol
    let locationProvider: LocationProviding
    let speechOutput: SpeechOutputting
    let speechRecognizer: SpeechRecognizing
    let haptics: HapticsPlaying
    let disclaimerStore: DisclaimerAcknowledging
    let settingsStore: AppSettingsStoring
    let personalPlacesRepository: PersonalPlacesRepositoring
    let routePlanningRepository: RoutePlanningRepositoring
    let explorationRepository: ExplorationRepositoring
    let appHandoffService: AppHandoffServicing

    private static let ownURLScheme = "easypath"

    init(modelContainer: ModelContainer) {
        apiClient = APIClient(baseURL: AppConfig.backendBaseURL)
        locationProvider = CoreLocationProvider()
        settingsStore = UserDefaultsAppSettingsStore()
        speechOutput = SpeechOutput(settingsStore: settingsStore)
        speechRecognizer = SpeechRecognizer()
        haptics = HapticsPlayer()
        disclaimerStore = UserDefaultsDisclaimerStore()
        routePlanningRepository = APIRoutePlanningRepository(apiClient: apiClient)
        explorationRepository = APIExplorationRepository(apiClient: apiClient)
        personalPlacesRepository = SwiftDataPersonalPlacesRepository(
            store: TrackedPlaceStore(modelContainer: modelContainer)
        )
        appHandoffService = AppHandoffService(ownCallbackScheme: Self.ownURLScheme)
    }

    /// Routes an incoming `easypath://...` URL (from `.onOpenURL` in
    /// `App/RootView.swift`) — currently only the Google Maps
    /// x-callback-url return address built in `HandoffURLBuilder`. Logs
    /// the parsed result; no feature reacts to it yet (see
    /// `Core/Handoff/HandoffCallback.swift`).
    func handleIncomingURL(_ url: URL) {
        guard let callback = HandoffCallback(url: url, ownScheme: Self.ownURLScheme) else {
            Log.navigation.info("Received unrecognized incoming URL: \(url)")
            return
        }
        switch callback {
        case .googleMapsFinished:
            Log.navigation.info("Returned from Google Maps hand-off")
        }
    }

    func makeDisclaimerViewModel() -> DisclaimerViewModel {
        DisclaimerViewModel(store: disclaimerStore)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(store: settingsStore)
    }

    func makeRoutePlanningViewModel() -> RoutePlanningViewModel {
        RoutePlanningViewModel(
            repository: routePlanningRepository,
            speechOutput: speechOutput,
            speechRecognizer: speechRecognizer,
            handoffService: appHandoffService,
            settingsStore: settingsStore
        )
    }

    func makeExplorationViewModel() -> ExplorationViewModel {
        ExplorationViewModel(
            repository: explorationRepository,
            personalPlacesRepository: personalPlacesRepository,
            settingsStore: settingsStore
        )
    }

    func makePersonalPlacesViewModel() -> PersonalPlacesViewModel {
        PersonalPlacesViewModel(repository: personalPlacesRepository)
    }

    func makeOutdoorNavigationViewModel() -> OutdoorNavigationViewModel {
        OutdoorNavigationViewModel(
            locationProvider: locationProvider,
            speechOutput: speechOutput,
            haptics: haptics
        )
    }
}
