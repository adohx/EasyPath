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
            settingsStore: settingsStore
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
            settingsStore: settingsStore
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
            settingsStore: FakeAppSettingsStore()
        )

        await viewModel.loadNearby(center: Coordinates(latitude: 0, longitude: 0))

        #expect(viewModel.sections.map(\.label).sorted() == ["Work", "pharmacy"])
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
