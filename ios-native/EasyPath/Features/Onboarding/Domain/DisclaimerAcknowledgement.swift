import Foundation

/// Tracks whether the user has acknowledged the safety disclaimer
/// required by design doc section 8 ("安全边界"): this app provides
/// navigation assistance only and does not guarantee that a route,
/// crossing, or area is safe.
protocol DisclaimerAcknowledging: Sendable {
    func hasAcknowledged() -> Bool
    func acknowledge()
}
