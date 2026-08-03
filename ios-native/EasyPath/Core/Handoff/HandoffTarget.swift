import Foundation

/// A third-party app this project can hand a journey leg off to instead
/// of building the equivalent feature in-house.
///
/// See `.claude/memory/third_party_deeplink_feasibility.md` for the
/// research behind this: Apple Maps, Google Maps, and Moovit all support
/// launching with a pre-filled origin/destination; BlindSquare does not
/// (no public integration surface was found), which is why it has no
/// case here.
enum HandoffTarget: String, Sendable, CaseIterable, Identifiable {
    case appleMaps
    case googleMaps
    case moovit

    var id: String { rawValue }

    /// The custom URL scheme iOS uses to probe whether this app is
    /// installed via `canOpenURL`. `nil` for Apple Maps, which is a
    /// system app and always reachable through `maps://` without
    /// needing an `LSApplicationQueriesSchemes` declaration.
    var queryScheme: String? {
        switch self {
        case .appleMaps: nil
        case .googleMaps: "comgooglemaps"
        case .moovit: "moovit"
        }
    }

    /// Whether this app supports the x-callback-url convention to
    /// return control to us once the user finishes there. Only Google
    /// Maps does, via `comgooglemaps-x-callback://` — see the research
    /// memory referenced above.
    var supportsReturnCallback: Bool {
        self == .googleMaps
    }

    var displayName: String {
        switch self {
        case .appleMaps: "Apple Maps"
        case .googleMaps: "Google Maps"
        case .moovit: "Moovit"
        }
    }
}

/// Travel mode for a hand-off. Moovit is transit-only and ignores this
/// (see `HandoffURLBuilder`); Apple Maps and Google Maps use it to pick
/// the right `dirflg`/`directionsmode` parameter.
enum HandoffTravelMode: Sendable {
    case walking
    case driving
    case cycling
    case transit
}
