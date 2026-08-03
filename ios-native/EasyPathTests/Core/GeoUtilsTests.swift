import Testing
@testable import EasyPath

struct GeoUtilsTests {
    @Test func distanceBetweenIdenticalPointsIsZero() {
        let point = Coordinates(latitude: 42.3149, longitude: -83.0364)
        #expect(GeoUtils.distanceMeters(from: point, to: point) == 0)
    }

    @Test func bearingNorthIsZeroDegrees() {
        let origin = Coordinates(latitude: 42.0, longitude: -83.0)
        let north = Coordinates(latitude: 42.01, longitude: -83.0)
        let bearing = GeoUtils.initialBearingDegrees(from: origin, to: north)
        #expect(bearing < 1 || bearing > 359)
    }

    @Test func compassDirectionLabelWrapsAroundNorth() {
        #expect(GeoUtils.compassDirectionLabel(359) == "north")
        #expect(GeoUtils.compassDirectionLabel(1) == "north")
        #expect(GeoUtils.compassDirectionLabel(90) == "east")
    }

    @Test func projectOntoRouteThrowsForShortRoute() {
        let point = Coordinates(latitude: 42.0, longitude: -83.0)
        #expect(throws: GeoUtils.GeoError.self) {
            try GeoUtils.projectOntoRoute(point, route: [point])
        }
    }
}
