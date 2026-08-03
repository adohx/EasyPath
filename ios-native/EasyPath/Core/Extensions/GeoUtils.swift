import Foundation

/// Haversine distance/bearing math and route-projection helpers, ported
/// from the Flutter app's `app/lib/core/geo_utils.dart`. Shared by
/// `OutdoorNavigation` (off-route detection, proximity distance/bearing)
/// and `Exploration` (distance/bearing to nearby POIs).
enum GeoUtils {
    static let earthRadiusMeters = 6_371_000.0

    private static func degToRad(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func radToDeg(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Great-circle distance between two coordinates, in metres.
    static func distanceMeters(from a: Coordinates, to b: Coordinates) -> Double {
        let phi1 = degToRad(a.latitude)
        let phi2 = degToRad(b.latitude)
        let deltaPhi = degToRad(b.latitude - a.latitude)
        let deltaLambda = degToRad(b.longitude - a.longitude)

        let sinHalfPhi = sin(deltaPhi / 2)
        let sinHalfLambda = sin(deltaLambda / 2)
        let h = sinHalfPhi * sinHalfPhi
            + cos(phi1) * cos(phi2) * sinHalfLambda * sinHalfLambda
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))
        return earthRadiusMeters * c
    }

    /// Initial bearing from `a` to `b`, in degrees `[0, 360)`, 0 = north.
    static func initialBearingDegrees(from a: Coordinates, to b: Coordinates) -> Double {
        let phi1 = degToRad(a.latitude)
        let phi2 = degToRad(b.latitude)
        let deltaLambda = degToRad(b.longitude - a.longitude)

        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        let theta = atan2(y, x)
        return (radToDeg(theta) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Smallest signed difference `b - a` in degrees, in the range
    /// `(-180, 180]`. Positive means `b` is clockwise from `a`.
    static func signedBearingDifferenceDegrees(_ a: Double, _ b: Double) -> Double {
        var diff = (b - a).truncatingRemainder(dividingBy: 360)
        if diff > 180 { diff -= 360 }
        if diff <= -180 { diff += 360 }
        return diff
    }

    private static let compassDirectionNames = [
        "north", "northeast", "east", "southeast",
        "south", "southwest", "west", "northwest",
    ]

    /// The nearest of the 8 cardinal/intercardinal direction names for
    /// `degrees` (e.g. "north", "northeast").
    static func compassDirectionLabel(_ degrees: Double) -> String {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        let index = Int(((normalized + 22.5) / 45).rounded(.down)) % 8
        return compassDirectionNames[(index + 8) % 8]
    }

    /// Result of projecting a point onto a polyline route.
    struct RouteProjection {
        /// Perpendicular ("cross-track") distance from the point to the
        /// route, in metres.
        let crossTrackDistanceMeters: Double
        /// Cumulative distance along the route to the projected point, in
        /// metres.
        let distanceAlongRouteMeters: Double
        /// Index of the polyline segment (between `route[segmentIndex]`
        /// and `route[segmentIndex + 1]`) that the point projects onto.
        let segmentIndex: Int
        /// Bearing of the route at the projected segment, in degrees
        /// `[0, 360)`.
        let segmentBearingDegrees: Double
    }

    enum GeoError: Error {
        case routeTooShort
    }

    /// Projects `point` onto the polyline `route` (at least 2 points),
    /// returning the closest segment, the perpendicular distance to it,
    /// and the cumulative along-route distance to the projection.
    ///
    /// Uses a flat-earth equirectangular projection per segment, accurate
    /// enough at the city-block scale this app operates at. GPS
    /// smoothing, outlier filtering, and true map matching are deferred to
    /// a later phase (design doc section 6, "定位增强").
    static func projectOntoRoute(_ point: Coordinates, route: [Coordinates]) throws -> RouteProjection {
        guard route.count >= 2 else { throw GeoError.routeTooShort }

        var bestCrossTrack = Double.infinity
        var bestDistanceAlong = 0.0
        var bestSegmentIndex = 0
        var bestSegmentBearing = 0.0
        var cumulativeBefore = 0.0

        for i in 0..<(route.count - 1) {
            let start = route[i]
            let end = route[i + 1]
            let segmentLength = distanceMeters(from: start, to: end)

            let meanLatRad = degToRad((start.latitude + end.latitude) / 2)
            let metresPerDegreeLat = earthRadiusMeters * .pi / 180
            let metresPerDegreeLon = metresPerDegreeLat * cos(meanLatRad)

            let dx = (end.longitude - start.longitude) * metresPerDegreeLon
            let dy = (end.latitude - start.latitude) * metresPerDegreeLat
            let px = (point.longitude - start.longitude) * metresPerDegreeLon
            let py = (point.latitude - start.latitude) * metresPerDegreeLat

            let segmentLengthSquared = dx * dx + dy * dy
            let t = segmentLengthSquared == 0
                ? 0.0
                : min(max((px * dx + py * dy) / segmentLengthSquared, 0.0), 1.0)

            let projectedLat = start.latitude + (end.latitude - start.latitude) * t
            let projectedLon = start.longitude + (end.longitude - start.longitude) * t
            let crossTrack = distanceMeters(
                from: point,
                to: Coordinates(latitude: projectedLat, longitude: projectedLon)
            )

            if crossTrack < bestCrossTrack {
                bestCrossTrack = crossTrack
                bestDistanceAlong = cumulativeBefore + segmentLength * t
                bestSegmentIndex = i
                bestSegmentBearing = initialBearingDegrees(from: start, to: end)
            }

            cumulativeBefore += segmentLength
        }

        return RouteProjection(
            crossTrackDistanceMeters: bestCrossTrack,
            distanceAlongRouteMeters: bestDistanceAlong,
            segmentIndex: bestSegmentIndex,
            segmentBearingDegrees: bestSegmentBearing
        )
    }

    /// Total length of `route` in metres, summing consecutive segment
    /// distances.
    static func routeTotalLengthMeters(_ route: [Coordinates]) -> Double {
        guard route.count >= 2 else { return 0 }
        return (0..<(route.count - 1)).reduce(0.0) { total, i in
            total + distanceMeters(from: route[i], to: route[i + 1])
        }
    }
}
