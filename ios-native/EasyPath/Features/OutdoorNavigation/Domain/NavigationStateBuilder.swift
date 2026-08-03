import Foundation

/// Pure domain logic that turns a raw location fix + the active route
/// into a `NavigationState` — no CoreLocation dependency, so this is
/// unit-testable on its own (design doc section 2.2.3, 2.2.5, 2.2.6).
enum NavigationStateBuilder {
    /// Cross-track distance beyond which the user is considered
    /// off-route. Design doc section 2.2.5 warns this must not be overly
    /// sensitive — a single noisy GPS fix should not trigger it; see
    /// `OutdoorNavigationViewModel`'s consecutive-reading requirement
    /// before this flag is surfaced to the user.
    static let offRouteThresholdMeters = 25.0

    static func build(
        location: Coordinates,
        headingDegrees: Double?,
        speedMetersPerSecond: Double?,
        route: RoutePlan,
        functionalPoints: [FunctionalPoint],
        riskPoints: [RiskPoint],
        now: Date = Date()
    ) -> NavigationState {
        let projection = try? GeoUtils.projectOntoRoute(location, route: route.geometry)
        let totalLength = GeoUtils.routeTotalLengthMeters(route.geometry)
        let progress = totalLength > 0
            ? min(max((projection?.distanceAlongRouteMeters ?? 0) / totalLength, 0), 1)
            : 0

        let nextFunctionalPoint = functionalPoints.min { lhs, rhs in
            GeoUtils.distanceMeters(from: location, to: lhs.location)
                < GeoUtils.distanceMeters(from: location, to: rhs.location)
        }
        let nextRiskPoint = riskPoints.min { lhs, rhs in
            GeoUtils.distanceMeters(from: location, to: lhs.location)
                < GeoUtils.distanceMeters(from: location, to: rhs.location)
        }

        let isOffRoute = (projection?.crossTrackDistanceMeters ?? 0) > offRouteThresholdMeters

        return NavigationState(
            currentLocation: location,
            headingDegrees: headingDegrees,
            speedMetersPerSecond: speedMetersPerSecond,
            currentMode: route.mode,
            routeProgress: progress,
            nextFunctionalPoint: nextFunctionalPoint,
            nextRiskPoint: nextRiskPoint,
            isOffRoute: isOffRoute,
            updatedAt: now
        )
    }
}
