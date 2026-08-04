import CoreLocation
import Foundation

@Observable
@MainActor
final class ExplorationViewModel {
    private(set) var sections: [ExplorationSection] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: ExplorationRepositoring
    private let personalPlacesRepository: PersonalPlacesRepositoring
    private let settingsStore: AppSettingsStoring
    private let locationProvider: LocationProviding

    init(
        repository: ExplorationRepositoring,
        personalPlacesRepository: PersonalPlacesRepositoring,
        settingsStore: AppSettingsStoring,
        locationProvider: LocationProviding
    ) {
        self.repository = repository
        self.personalPlacesRepository = personalPlacesRepository
        self.settingsStore = settingsStore
        self.locationProvider = locationProvider
    }

    /// Called from `ExplorationView`'s `.task` on first appearance —
    /// without this, nothing ever calls `loadNearby`, so the screen
    /// would show "No Nearby Places" forever regardless of backend or
    /// location health. Gets a current GPS fix (with the same timeout
    /// guard as `RoutePlanning`'s destination selection — see
    /// `LocationProviding.currentLocation(timeout:)`) and loads around
    /// it.
    func loadNearbyAroundCurrentLocation() async {
        isLoading = true
        errorMessage = nil

        guard let location = await locationProvider.currentLocation() else {
            isLoading = false
            errorMessage = "Could not determine your current location."
            return
        }

        await loadNearby(center: Coordinates(location.coordinate))
    }

    /// Loads nearby points of interest around `center` — either the
    /// user's current location or a searched-for place, per design doc
    /// section 2.1.2 (探索 and 查找地点 share one entry point) — and
    /// merges in any of the user's own `TrackedPlace`s that fall within
    /// the same radius, per that section's "官方探索点与用户已保存的
    /// 个人地点按分类混合展示" requirement (see `ExplorationMerger`).
    ///
    /// - Parameter radiusMeters: defaults to `Settings`' alert-radius
    ///   preference (design doc section 1.1.1) when not given explicitly.
    func loadNearby(center: Coordinates, radiusMeters: Int? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let radius = radiusMeters ?? Int(settingsStore.load().alertRadiusMeters)

        do {
            async let officialTask = repository.nearby(center: center, radiusMeters: radius)
            async let personalTask = personalPlacesRepository.fetchAll()
            let (official, personal) = try await (officialTask, personalTask)
            sections = ExplorationMerger.merge(
                official: official,
                personalPlaces: personal,
                center: center,
                radiusMeters: radius
            )
        } catch {
            Log.exploration.error("Nearby exploration query failed: \(error)")
            errorMessage = "Could not load nearby places."
            sections = []
        }
    }
}
