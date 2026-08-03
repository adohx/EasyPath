import Foundation

/// One row in the merged Exploration list — either an official
/// `ExplorationItem` (from map data, read-only) or the user's own
/// `TrackedPlace` — shown side by side under a shared category label per
/// design doc section 2.1.2: "官方探索点与用户已保存的个人地点按分类
/// 混合展示".
enum ExplorationDisplayItem: Identifiable, Hashable {
    case official(ExplorationItem)
    case personal(TrackedPlace)

    var id: String {
        switch self {
        case .official(let item): "official-\(item.id)"
        case .personal(let place): "personal-\(place.id)"
        }
    }

    var name: String {
        switch self {
        case .official(let item): item.name
        case .personal(let place): place.name
        }
    }
}

/// A category-labelled group of `ExplorationDisplayItem`s, ready to
/// render as one `Section`.
struct ExplorationSection: Identifiable {
    let id: String
    let label: String
    let items: [ExplorationDisplayItem]
}

/// Merges official exploration results with nearby personal places into
/// one set of category sections — pure logic, no networking/persistence
/// dependency, so it's unit-testable on its own (same pattern as
/// `NavigationStateBuilder`/`ProximityAnnouncer`).
enum ExplorationMerger {
    /// - Note: official categories key off `ExplorationCategory`'s raw
    ///   value (e.g. "bus_stop"); personal places key off their own
    ///   user-facing `TrackedPlaceCategory.label` (e.g. "Uncategorized")
    ///   — the two taxonomies are different by design (design doc
    ///   section 1.1.3) and are merged only by coincidentally matching
    ///   label text, not a shared category system. A collision between
    ///   an official raw value and a personal label is possible but
    ///   unlikely, and the merged section's items would still render
    ///   correctly either way. Not modelled as a single shared category
    ///   type since that would put words in the design doc's mouth.
    static func merge(
        official: [ExplorationCategory: [ExplorationItem]],
        personalPlaces: [TrackedPlace],
        center: Coordinates,
        radiusMeters: Int
    ) -> [ExplorationSection] {
        var grouped: [String: [ExplorationDisplayItem]] = [:]

        for (category, items) in official {
            grouped[category.rawValue, default: []].append(contentsOf: items.map { .official($0) })
        }

        let nearbyPersonalPlaces = personalPlaces.filter {
            GeoUtils.distanceMeters(from: center, to: $0.location) <= Double(radiusMeters)
        }
        for place in nearbyPersonalPlaces {
            grouped[place.category.label, default: []].append(.personal(place))
        }

        return grouped
            .map { ExplorationSection(id: $0.key, label: $0.key, items: $0.value) }
            .sorted { $0.label < $1.label }
    }
}
