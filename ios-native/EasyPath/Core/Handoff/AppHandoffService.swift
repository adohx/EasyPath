import Foundation
import UIKit

/// Launches a specialized third-party app (Apple Maps, Google Maps,
/// Moovit) with a pre-filled origin/destination instead of building the
/// equivalent navigation/transit-tracking feature in-house.
///
/// This is infrastructure, not a feature — no `Features/*` module calls
/// this yet. It exists so `RoutePlanning`/`OutdoorNavigation` have a
/// ready-made building block if/when the "hand off to a specialized app"
/// direction discussed in `.claude/memory/third_party_deeplink_feasibility.md`
/// is adopted for a specific leg (e.g. handing a bus leg to Moovit
/// instead of tracking it ourselves).
protocol AppHandoffServicing: Sendable {
    /// Whether `target` is installed and can be launched. Always `true`
    /// for `.appleMaps` (a system app). For the others, this depends on
    /// `target.queryScheme` being declared in `LSApplicationQueriesSchemes`
    /// in `Info.plist` (see `project.yml`) — without that declaration,
    /// `canOpenURL` returns `false` even when the app is installed.
    @MainActor func isInstalled(_ target: HandoffTarget) -> Bool

    /// Opens `target` with directions to `destination`. Returns whether
    /// the app was actually launched (`false` if it isn't installed or
    /// the URL couldn't be constructed) — callers should fall back to
    /// `.appleMaps` (always available) or an in-app message on `false`.
    @discardableResult
    @MainActor func openDirections(
        to destination: Coordinates,
        destinationName: String?,
        from origin: Coordinates?,
        mode: HandoffTravelMode,
        in target: HandoffTarget
    ) async -> Bool
}

@MainActor
final class AppHandoffService: AppHandoffServicing {
    /// Our own registered URL scheme (see `CFBundleURLTypes` in
    /// `project.yml`), used as the x-callback-url return address for
    /// targets that support one (currently only `.googleMaps`).
    private let ownCallbackScheme: String

    init(ownCallbackScheme: String = "easypath") {
        self.ownCallbackScheme = ownCallbackScheme
    }

    func isInstalled(_ target: HandoffTarget) -> Bool {
        guard let scheme = target.queryScheme, let probeURL = URL(string: "\(scheme)://") else {
            return true
        }
        return UIApplication.shared.canOpenURL(probeURL)
    }

    @discardableResult
    func openDirections(
        to destination: Coordinates,
        destinationName: String?,
        from origin: Coordinates?,
        mode: HandoffTravelMode,
        in target: HandoffTarget
    ) async -> Bool {
        guard isInstalled(target) else {
            Log.navigation.info("Hand-off target \(target.displayName) is not installed")
            return false
        }
        guard let url = HandoffURLBuilder.url(
            for: target,
            destination: destination,
            destinationName: destinationName,
            origin: origin,
            mode: mode,
            callbackScheme: ownCallbackScheme
        ) else {
            Log.navigation.error("Failed to build hand-off URL for \(target.displayName)")
            return false
        }
        return await UIApplication.shared.open(url)
    }
}
