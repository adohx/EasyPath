import Foundation

/// Maps between the plain `TrackedPlace` domain struct and the
/// `Sendable` `TrackedPlaceRecord` DTO that crosses into/out of the
/// `TrackedPlaceStore` actor (`Core/Persistence`). Categories are stored
/// flattened onto the record rather than as a separate SwiftData
/// relationship — there is no independent lifecycle for a category
/// beyond the places that reference it, so this keeps the storage model
/// simple until that assumption changes.
final class SwiftDataPersonalPlacesRepository: PersonalPlacesRepositoring {
    private let store: TrackedPlaceStoring

    init(store: TrackedPlaceStoring) {
        self.store = store
    }

    func fetchAll() async throws -> [TrackedPlace] {
        try await store.fetchAll().map(Self.domainModel(from:))
    }

    func add(_ place: TrackedPlace) async throws {
        try await store.insert(Self.record(from: place))
    }

    func update(_ place: TrackedPlace) async throws {
        try await store.update(Self.record(from: place))
    }

    func delete(id: String) async throws {
        try await store.delete(id: id)
    }

    private static func record(from place: TrackedPlace) -> TrackedPlaceRecord {
        TrackedPlaceRecord(
            id: place.id,
            name: place.name,
            latitude: place.location.latitude,
            longitude: place.location.longitude,
            categoryId: place.category.id,
            categoryLabel: place.category.label,
            categoryIsUserDefined: place.category.isUserDefined,
            tagRawValue: place.tag.rawValue,
            isPaused: place.isPaused,
            addedViaRawValue: place.addedVia.rawValue,
            createdAt: place.createdAt
        )
    }

    private static func domainModel(from record: TrackedPlaceRecord) -> TrackedPlace {
        TrackedPlace(
            id: record.id,
            name: record.name,
            location: Coordinates(latitude: record.latitude, longitude: record.longitude),
            category: TrackedPlaceCategory(
                id: record.categoryId,
                label: record.categoryLabel,
                isUserDefined: record.categoryIsUserDefined
            ),
            tag: PlaceTag(rawValue: record.tagRawValue) ?? .remindIfConvenient,
            isPaused: record.isPaused,
            addedVia: AddedVia(rawValue: record.addedViaRawValue) ?? .search,
            createdAt: record.createdAt
        )
    }
}
