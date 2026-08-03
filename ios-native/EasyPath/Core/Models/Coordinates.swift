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
