import Foundation
import Testing
@testable import EasyPath

struct CoordinatesTests {
    @Test func decodesFromKeyedObjectShape() throws {
        let json = #"{"lat": 42.3149, "lon": -83.0364}"#
        let coordinates = try JSONDecoder().decode(Coordinates.self, from: Data(json.utf8))

        #expect(coordinates.latitude == 42.3149)
        #expect(coordinates.longitude == -83.0364)
    }

    /// `RoutePlan.geometry` (`docs/4.接口文档.md`) encodes each point as
    /// a `[lat, lon]` pair instead of `{lat, lon}` — this is the shape
    /// that broke route planning on 2026-08-03 with a
    /// `DecodingError.typeMismatch` before `Coordinates` learned to
    /// decode both.
    @Test func decodesFromUnkeyedArrayShape() throws {
        let json = "[42.3149, -83.0364]"
        let coordinates = try JSONDecoder().decode(Coordinates.self, from: Data(json.utf8))

        #expect(coordinates.latitude == 42.3149)
        #expect(coordinates.longitude == -83.0364)
    }

    @Test func decodesArrayOfMixedGeometryPoints() throws {
        let json = "[[42.3149, -83.0364], [42.315, -83.037]]"
        let points = try JSONDecoder().decode([Coordinates].self, from: Data(json.utf8))

        #expect(points.count == 2)
        #expect(points[0].latitude == 42.3149)
        #expect(points[1].longitude == -83.037)
    }

    @Test func encodesAsKeyedObjectShape() throws {
        let coordinates = Coordinates(latitude: 42.3149, longitude: -83.0364)
        let data = try JSONEncoder().encode(coordinates)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"lat\""))
        #expect(json.contains("\"lon\""))
    }
}
