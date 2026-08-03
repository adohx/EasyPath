import Foundation

/// The three fixed priority tiers used to order proximity announcements
/// during real-time navigation.
///
/// Defined in section 2.2.4 of
/// `docs/1.无障碍出行辅助系统_产品与技术设计文档.md`: tiers never
/// reorder relative to each other (risk always outranks required, which
/// always outranks navigation/exploration) — only items within the same
/// tier are ordered by distance, regardless of whether they come from
/// official map data or a user's `TrackedPlace`.
enum AnnouncementPriorityTier: Int, Comparable, Sendable {
    case riskPoint = 0
    case requiredFunctionalPoint = 1
    case navigationOrExploration = 2

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
