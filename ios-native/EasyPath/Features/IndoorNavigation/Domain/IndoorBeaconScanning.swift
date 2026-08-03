import Foundation

/// Placeholder domain boundary for indoor positioning (BLE beacon and/or
/// LiDAR/camera-based — see this module's README, the technique is not
/// decided) and Auracast audio broadcast reception — new scope from the
/// product manager's requirements doc
/// (`docs/7.产品经理需求_Hackforge_WayFinding.md`, Module 2.2), not
/// present in the Flutter app at all.
///
/// No implementation exists yet. See this module's README before writing
/// one — there are open questions (including whether this should be
/// built in-house at all, given existing products like Right-Hear and
/// GoodMaps Explore already solve this) to resolve first. Auracast in
/// particular is not implementable on iOS today regardless of approach —
/// see the README for why.
protocol IndoorBeaconScanning: Sendable {
    func startScanning() async throws
    func stopScanning()
}
