import CoreLocation
import Foundation
import Testing
@testable import EasyPath

@MainActor
struct ExplorationViewModelTests {
    @Test func loadNearbyDefaultsRadiusFromSettings() async {
        let repository = FakeExplorationRepository()
        let settingsStore = FakeAppSettingsStore()
        settingsStore.settings.alertRadiusMeters = 350
        let viewModel = ExplorationViewModel(
            repository: repository,
            personalPlacesRepository: FakePersonalPlacesRepository(),
            settingsStore: settingsStore,
            locationProvider: FakeLocationProvider()
        )

        await viewModel.loadNearby(center: Coordinates(latitude: 0, longitude: 0))

        #expect(repository.lastRadiusMeters == 350)
    }

    @Test func loadNearbyHonorsExplicitRadiusOverSettingsDefault() async {
        let repository = FakeExplorationRepository()
        let settingsStore = FakeAppSettingsStore()
        settingsStore.settings.alertRadiusMeters = 350
        let viewModel = ExplorationViewModel(
            repository: repository,
            personalPlacesRepository: FakePersonalPlacesRepository(),
            settingsStore: settingsStore,
            locationProvider: FakeLocationProvider()
        )

        await viewModel.loadNearby(center: Coordinates(latitude: 0, longitude: 0), radiusMeters: 100)

        #expect(repository.lastRadiusMeters == 100)
    }

    @Test func mergesOfficialAndPersonalPlacesIntoSections() async {
        let repository = FakeExplorationRepository()
        repository.resultToReturn = [.pharmacy: [
            ExplorationItem(
                id: "item-1", category: .pharmacy, name: "Pharmacy",
                location: Coordinates(latitude: 0, longitude: 0),
                distanceMeters: 10, bearingDegrees: 0, priority: 1
            ),
        ]]
        let personalPlaces = FakePersonalPlacesRepository()
        personalPlaces.placesToReturn = [
            TrackedPlace(
                id: "place-1", name: "My Place", location: Coordinates(latitude: 0, longitude: 0),
                category: TrackedPlaceCategory(id: "c", label: "Work", isUserDefined: false),
                tag: .remindIfConvenient, isPaused: false, addedVia: .search, createdAt: Date()
            ),
        ]
        let viewModel = ExplorationViewModel(
            repository: repository,
            personalPlacesRepository: personalPlaces,
            settingsStore: FakeAppSettingsStore(),
            locationProvider: FakeLocationProvider()
        )

        await viewModel.loadNearby(center: Coordinates(latitude: 0, longitude: 0))

        #expect(viewModel.sections.map(\.label).sorted() == ["Work", "pharmacy"])
    }

    @Test func loadNearbyAroundCurrentLocationUsesLocationProvider() async {
        let repository = FakeExplorationRepository()
        let locationProvider = FakeLocationProvider()
        locationProvider.locationToYield = CLLocation(latitude: 42.3149, longitude: -83.0364)
        let viewModel = ExplorationViewModel(
            repository: repository,
            personalPlacesRepository: FakePersonalPlacesRepository(),
            settingsStore: FakeAppSettingsStore(),
            locationProvider: locationProvider
        )

        await viewModel.loadNearbyAroundCurrentLocation()

        #expect(locationProvider.didRequestAuthorization)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func loadNearbyAroundCurrentLocationFailsWhenLocationUnavailable() async {
        let locationProvider = FakeLocationProvider()
        locationProvider.locationToYield = nil
        let viewModel = ExplorationViewModel(
            repository: FakeExplorationRepository(),
            personalPlacesRepository: FakePersonalPlacesRepository(),
            settingsStore: FakeAppSettingsStore(),
            locationProvider: locationProvider
        )

        await viewModel.loadNearbyAroundCurrentLocation()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.sections.isEmpty)
    }
}

final class FakeExplorationRepository: ExplorationRepositoring, @unchecked Sendable {
    var resultToReturn: [ExplorationCategory: [ExplorationItem]] = [:]
    private(set) var lastRadiusMeters: Int?

    func nearby(center: Coordinates, radiusMeters: Int) async throws -> [ExplorationCategory: [ExplorationItem]] {
        lastRadiusMeters = radiusMeters
        return resultToReturn
    }
}

final class FakePersonalPlacesRepository: PersonalPlacesRepositoring, @unchecked Sendable {
    var placesToReturn: [TrackedPlace] = []

    func fetchAll() async throws -> [TrackedPlace] { placesToReturn }
    func add(_ place: TrackedPlace) async throws {}
    func update(_ place: TrackedPlace) async throws {}
    func delete(id: String) async throws {}
}
