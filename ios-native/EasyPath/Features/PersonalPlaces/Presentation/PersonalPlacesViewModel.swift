import Foundation

@Observable
@MainActor
final class PersonalPlacesViewModel {
    private(set) var places: [TrackedPlace] = []
    private(set) var errorMessage: String?

    private let repository: PersonalPlacesRepositoring

    init(repository: PersonalPlacesRepositoring) {
        self.repository = repository
    }

    func load() async {
        do {
            places = try await repository.fetchAll()
        } catch {
            Log.personalPlaces.error("Failed to load tracked places: \(error)")
            errorMessage = "Could not load your saved places."
        }
    }

    /// Toggles pause state without deleting — paused places keep their
    /// data but stop competing for proximity announcements (design doc
    /// section 2.3).
    func togglePaused(_ place: TrackedPlace) async {
        var updated = place
        updated.isPaused.toggle()
        do {
            try await repository.update(updated)
            await load()
        } catch {
            Log.personalPlaces.error("Failed to toggle paused state: \(error)")
            errorMessage = "Could not update that place."
        }
    }

    /// Design doc section 2.3 requires a second voice confirmation before
    /// permanent deletion; that confirmation flow belongs in the View
    /// (see `PersonalPlacesView`), this only performs the deletion once
    /// confirmed.
    func delete(_ place: TrackedPlace) async {
        do {
            try await repository.delete(id: place.id)
            await load()
        } catch {
            Log.personalPlaces.error("Failed to delete tracked place: \(error)")
            errorMessage = "Could not delete that place."
        }
    }
}
