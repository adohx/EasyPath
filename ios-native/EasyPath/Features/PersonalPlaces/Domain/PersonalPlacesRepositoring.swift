import Foundation

/// CRUD boundary for user-saved `TrackedPlace`s (design doc section 2.3,
/// "个人地点管理"). Distinct from `Exploration`, which only reads
/// official, non-editable points of interest — see both modules'
/// READMEs for how the two are meant to combine in the UI.
protocol PersonalPlacesRepositoring: Sendable {
    func fetchAll() async throws -> [TrackedPlace]
    func add(_ place: TrackedPlace) async throws
    func update(_ place: TrackedPlace) async throws
    func delete(id: String) async throws
}
