import Foundation

/// A named, geolocated point returned by place search or reverse geocoding.
///
/// Corresponds to the Flutter `Place` model
/// (`app/lib/models/place.dart`) and the `Place` object described in
/// `docs/4.接口文档.md` section 2.2.
struct Place: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let coordinates: Coordinates
    let type: String?
}
