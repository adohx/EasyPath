import CoreLocation

/// A latitude/longitude pair used throughout the app's domain models.
///
/// Mirrors the Flutter version's `Coordinates` class
/// (`app/lib/models/*`). Kept separate from `CLLocationCoordinate2D` so the
/// domain layer never depends on CoreLocation directly.
struct Coordinates: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// The backend encodes coordinates two different ways depending on
    /// the endpoint: most places send `{"lat": ..., "lon": ...}`, but
    /// `RoutePlan.geometry`'s polyline sends `[lat, lon]` pairs instead
    /// (`docs/4.接口文档.md`'s `geometry` field) — decode either shape
    /// rather than forcing every call site to know which one applies.
    /// `encode(to:)` is left to the synthesized implementation, which
    /// always writes the `{lat, lon}` object shape (correct for every
    /// request body this app sends).
    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let lat = try? keyed.decode(Double.self, forKey: .latitude),
           let lon = try? keyed.decode(Double.self, forKey: .longitude) {
            latitude = lat
            longitude = lon
            return
        }
        var unkeyed = try decoder.unkeyedContainer()
        latitude = try unkeyed.decode(Double.self)
        longitude = try unkeyed.decode(Double.self)
    }
}

extension Coordinates {
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}
