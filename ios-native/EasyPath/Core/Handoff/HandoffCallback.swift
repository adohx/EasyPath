import Foundation

/// Parses an incoming `easypath://handoff/...` URL — the x-callback-url
/// return address we hand to Google Maps in `HandoffURLBuilder`
/// (`x-success=easypath://handoff/googleMaps`). Received via `.onOpenURL`
/// in `App/RootView.swift` and routed through `AppContainer`.
///
/// No feature currently reacts to this — it's logged so the mechanism is
/// verifiable end-to-end. A future `OutdoorNavigation` integration that
/// hands a leg off to Google Maps would use this to resume the in-app
/// flow (e.g. advance to the next leg) once the user returns.
enum HandoffCallback: Sendable, Equatable {
    case googleMapsFinished

    init?(url: URL, ownScheme: String) {
        guard url.scheme == ownScheme, url.host == "handoff" else { return nil }
        switch url.path {
        case "/googleMaps": self = .googleMapsFinished
        default: return nil
        }
    }
}
