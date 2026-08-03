import Foundation

/// A snapshot of the user's live navigation status, produced client-side
/// from CoreLocation/CoreMotion input during real-time navigation.
///
/// Mirrors section 7.4 of
/// `docs/1.无障碍出行辅助系统_产品与技术设计文档.md`. Unlike the other
/// models in this folder, this one is never decoded from the backend — it
/// is assembled locally by `OutdoorNavigation/Domain` from sensor readings.
struct NavigationState: Hashable, Sendable {
    let currentLocation: Coordinates
    let headingDegrees: Double?
    let speedMetersPerSecond: Double?
    let currentMode: TravelMode
    let routeProgress: Double
    let nextFunctionalPoint: FunctionalPoint?
    let nextRiskPoint: RiskPoint?
    let isOffRoute: Bool
    let updatedAt: Date
}
