import Foundation
import SwiftData

/// SwiftData-backed storage for `TrackedPlace`.
///
/// Replaces the Flutter version's `SharedPreferences` + JSON-array
/// approach (`app/lib/services/tracked_place_repository.dart`). SwiftData
/// gives `PersonalPlaces` real queries (by category, by tag, by paused
/// state) instead of decoding the whole list on every read.
@Model
final class TrackedPlaceEntity {
    @Attribute(.unique) var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var categoryId: String
    var categoryLabel: String
    var categoryIsUserDefined: Bool
    var tagRawValue: String
    var isPaused: Bool
    var addedViaRawValue: String
    var createdAt: Date

    init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        categoryId: String,
        categoryLabel: String,
        categoryIsUserDefined: Bool,
        tagRawValue: String,
        isPaused: Bool,
        addedViaRawValue: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.categoryId = categoryId
        self.categoryLabel = categoryLabel
        self.categoryIsUserDefined = categoryIsUserDefined
        self.tagRawValue = tagRawValue
        self.isPaused = isPaused
        self.addedViaRawValue = addedViaRawValue
        self.createdAt = createdAt
    }
}

/// A plain, `Sendable` mirror of `TrackedPlaceEntity`'s stored properties.
///
/// SwiftData's `@Model` classes are not `Sendable` — they're tied to the
/// `ModelContext` that created them and cannot cross an actor boundary
/// (the compiler rejects it under Swift 6 strict concurrency). This type
/// is what actually crosses into/out of the `TrackedPlaceStore` actor;
/// `Features/PersonalPlaces/Data` maps between this and the plain
/// `TrackedPlace` domain struct in `Core/Models`.
struct TrackedPlaceRecord: Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let categoryId: String
    let categoryLabel: String
    let categoryIsUserDefined: Bool
    let tagRawValue: String
    let isPaused: Bool
    let addedViaRawValue: String
    let createdAt: Date
}

/// Thin CRUD wrapper around a `ModelContext`. Feature repositories depend
/// on `TrackedPlaceStoring`, not this concrete type, so tests can inject a
/// fake in-memory store instead of standing up SwiftData.
protocol TrackedPlaceStoring: Sendable {
    func fetchAll() async throws -> [TrackedPlaceRecord]
    func insert(_ record: TrackedPlaceRecord) async throws
    func update(_ record: TrackedPlaceRecord) async throws
    func delete(id: String) async throws
}

@ModelActor
actor TrackedPlaceStore: TrackedPlaceStoring {
    func fetchAll() throws -> [TrackedPlaceRecord] {
        let descriptor = FetchDescriptor<TrackedPlaceEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(Self.record(from:))
    }

    func insert(_ record: TrackedPlaceRecord) throws {
        modelContext.insert(Self.entity(from: record))
        try modelContext.save()
    }

    /// SwiftData tracks changes by object identity, not by `id` value, so
    /// this fetches the existing managed object and applies `record`'s
    /// fields onto it rather than inserting a disconnected replacement.
    func update(_ record: TrackedPlaceRecord) throws {
        let targetId = record.id
        let descriptor = FetchDescriptor<TrackedPlaceEntity>(
            predicate: #Predicate { $0.id == targetId }
        )
        guard let managed = try modelContext.fetch(descriptor).first else {
            modelContext.insert(Self.entity(from: record))
            try modelContext.save()
            return
        }

        managed.name = record.name
        managed.latitude = record.latitude
        managed.longitude = record.longitude
        managed.categoryId = record.categoryId
        managed.categoryLabel = record.categoryLabel
        managed.categoryIsUserDefined = record.categoryIsUserDefined
        managed.tagRawValue = record.tagRawValue
        managed.isPaused = record.isPaused
        managed.addedViaRawValue = record.addedViaRawValue
        managed.createdAt = record.createdAt
        try modelContext.save()
    }

    func delete(id: String) throws {
        let target = id
        try modelContext.delete(
            model: TrackedPlaceEntity.self,
            where: #Predicate { $0.id == target }
        )
        try modelContext.save()
    }

    private static func entity(from record: TrackedPlaceRecord) -> TrackedPlaceEntity {
        TrackedPlaceEntity(
            id: record.id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            categoryId: record.categoryId,
            categoryLabel: record.categoryLabel,
            categoryIsUserDefined: record.categoryIsUserDefined,
            tagRawValue: record.tagRawValue,
            isPaused: record.isPaused,
            addedViaRawValue: record.addedViaRawValue,
            createdAt: record.createdAt
        )
    }

    private static func record(from entity: TrackedPlaceEntity) -> TrackedPlaceRecord {
        TrackedPlaceRecord(
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            categoryId: entity.categoryId,
            categoryLabel: entity.categoryLabel,
            categoryIsUserDefined: entity.categoryIsUserDefined,
            tagRawValue: entity.tagRawValue,
            isPaused: entity.isPaused,
            addedViaRawValue: entity.addedViaRawValue,
            createdAt: entity.createdAt
        )
    }
}
