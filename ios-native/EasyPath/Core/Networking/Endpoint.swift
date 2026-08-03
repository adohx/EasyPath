import Foundation

/// Describes one call to the FastAPI backend (`docs/4.接口文档.md`).
///
/// Keeping the path/method/query-building logic in one enum means each
/// feature's repository only has to describe *what* it wants, not *how*
/// to build the request.
enum Endpoint {
    case searchPlaces(query: String)
    case reversePlace(coordinates: Coordinates)
    case planRoutes(origin: Coordinates, destination: Coordinates, originName: String?, destinationName: String?)
    case nearbyExploration(center: Coordinates, radiusMeters: Int)

    var path: String {
        switch self {
        case .searchPlaces: "/api/places/search"
        case .reversePlace: "/api/places/reverse"
        case .planRoutes: "/api/routes/plan"
        case .nearbyExploration: "/api/exploration/nearby"
        }
    }

    var method: String {
        switch self {
        case .planRoutes: "POST"
        default: "GET"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .searchPlaces(query):
            [URLQueryItem(name: "q", value: query)]
        case let .reversePlace(coordinates):
            [
                URLQueryItem(name: "lat", value: String(coordinates.latitude)),
                URLQueryItem(name: "lon", value: String(coordinates.longitude)),
            ]
        case .planRoutes:
            []
        case let .nearbyExploration(center, radiusMeters):
            [
                URLQueryItem(name: "lat", value: String(center.latitude)),
                URLQueryItem(name: "lon", value: String(center.longitude)),
                URLQueryItem(name: "radius_meters", value: String(radiusMeters)),
            ]
        }
    }

    /// JSON-encodable body for `POST` requests; `nil` for `GET` endpoints.
    var body: Encodable? {
        switch self {
        case let .planRoutes(origin, destination, originName, destinationName):
            PlanRoutesRequestBody(
                origin: origin,
                destination: destination,
                originName: originName,
                destinationName: destinationName
            )
        default:
            nil
        }
    }
}

private struct PlanRoutesRequestBody: Encodable {
    let origin: Coordinates
    let destination: Coordinates
    let originName: String?
    let destinationName: String?

    enum CodingKeys: String, CodingKey {
        case origin, destination
        case originName = "origin_name"
        case destinationName = "destination_name"
    }
}
