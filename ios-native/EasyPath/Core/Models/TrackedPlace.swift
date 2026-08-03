import Foundation

/// A place the user has deliberately saved for the long term, as opposed
/// to a transient `ExplorationItem` search result.
///
/// Mirrors section 7.5 of
/// `docs/1.无障碍出行辅助系统_产品与技术设计文档.md`. This is the plain
/// domain type used by `Domain`/`Presentation` code; the SwiftData-backed
/// storage entity lives in `Core/Persistence/TrackedPlaceStore.swift` and
/// is mapped to/from this struct by `PersonalPlaces/Data`.
struct TrackedPlace: Codable, Hashable, Sendable, Identifiable {
    let id: String
    var name: String
    var location: Coordinates
    var category: TrackedPlaceCategory
    var tag: PlaceTag
    var isPaused: Bool
    let addedVia: AddedVia
    let createdAt: Date
}

enum AddedVia: String, Codable, Sendable {
    case search
    case buttonCapture = "button_capture"
}

struct TrackedPlaceCategory: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let label: String
    let isUserDefined: Bool

    static let uncategorized = TrackedPlaceCategory(
        id: "uncategorized",
        label: "Uncategorized",
        isUserDefined: false
    )
}

/// The three preset importance levels a user can attach to a
/// `TrackedPlace`. Users pick from this fixed set — they cannot define
/// new tags or change what tier each one maps to (design doc section
/// 1.1.3).
enum PlaceTag: String, Codable, Sendable, CaseIterable {
    case remindIfConvenient = "remind_if_convenient"
    case mustRemindNearby = "must_remind_nearby"
    case urgentAlert = "urgent_alert"

    /// Maps this user-facing tag onto the fixed announcement tiers from
    /// section 2.2.4, so a `TrackedPlace` competes fairly with official
    /// risk/functional points for the same L1/L2/L3 slot.
    var priorityTier: AnnouncementPriorityTier {
        switch self {
        case .urgentAlert: .riskPoint
        case .mustRemindNearby: .requiredFunctionalPoint
        case .remindIfConvenient: .navigationOrExploration
        }
    }
}
