import Foundation
import Testing
@testable import EasyPath

struct ExplorationMergerTests {
    private let center = Coordinates(latitude: 42.3149, longitude: -83.0364)

    private func explorationItem(category: ExplorationCategory, id: String = "item-1") -> ExplorationItem {
        ExplorationItem(
            id: id,
            category: category,
            name: "Test Place",
            location: center,
            distanceMeters: 50,
            bearingDegrees: 0,
            priority: 1
        )
    }

    private func trackedPlace(
        id: String = "place-1",
        categoryLabel: String = "Uncategorized",
        metersAway: Double
    ) -> TrackedPlace {
        TrackedPlace(
            id: id,
            name: "My Place",
            location: Coordinates(latitude: center.latitude, longitude: center.longitude + metersAway / 111_000),
            category: TrackedPlaceCategory(id: "cat", label: categoryLabel, isUserDefined: false),
            tag: .remindIfConvenient,
            isPaused: false,
            addedVia: .search,
            createdAt: Date()
        )
    }

    @Test func officialItemsAreGroupedByCategoryRawValue() {
        let sections = ExplorationMerger.merge(
            official: [.restaurant: [explorationItem(category: .restaurant)]],
            personalPlaces: [],
            center: center,
            radiusMeters: 200
        )

        #expect(sections.count == 1)
        #expect(sections.first?.label == "restaurant")
        #expect(sections.first?.items.count == 1)
    }

    @Test func personalPlaceWithinRadiusIsIncluded() {
        let sections = ExplorationMerger.merge(
            official: [:],
            personalPlaces: [trackedPlace(categoryLabel: "Pharmacy", metersAway: 50)],
            center: center,
            radiusMeters: 200
        )

        #expect(sections.count == 1)
        #expect(sections.first?.label == "Pharmacy")
        #expect(sections.first?.items.first?.id == "personal-place-1")
    }

    @Test func personalPlaceOutsideRadiusIsExcluded() {
        let sections = ExplorationMerger.merge(
            official: [:],
            personalPlaces: [trackedPlace(metersAway: 5_000)],
            center: center,
            radiusMeters: 200
        )

        #expect(sections.isEmpty)
    }

    @Test func officialAndPersonalPlacesCoexistAsSeparateSections() {
        let sections = ExplorationMerger.merge(
            official: [.pharmacy: [explorationItem(category: .pharmacy)]],
            personalPlaces: [trackedPlace(categoryLabel: "Work", metersAway: 10)],
            center: center,
            radiusMeters: 200
        )

        #expect(sections.count == 2)
        #expect(sections.map(\.label).sorted() == ["Work", "pharmacy"])
    }

    @Test func sectionsAreSortedAlphabeticallyByLabel() {
        let sections = ExplorationMerger.merge(
            official: [.restaurant: [explorationItem(category: .restaurant)], .bank: [explorationItem(category: .bank, id: "bank-1")]],
            personalPlaces: [],
            center: center,
            radiusMeters: 200
        )

        #expect(sections.map(\.label) == ["bank", "restaurant"])
    }
}
