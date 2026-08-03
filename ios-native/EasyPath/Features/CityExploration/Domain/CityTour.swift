import Foundation

/// Placeholder domain model for a predefined, narrated walking tour —
/// new scope from the product manager's requirements doc
/// (`docs/7.产品经理需求_Hackforge_WayFinding.md`, Module 3), distinct
/// from `Exploration`'s live nearby-POI browsing. Not present in the
/// Flutter app at all.
///
/// See this module's README before implementing anything here — the
/// scope (game-like exploration vs. narrated tours vs. both) needs a
/// product decision first.
struct CityTour: Identifiable, Sendable {
    let id: String
    let title: String
    let stops: [Coordinates]
}
