import Foundation

/// Thin `URLSession` wrapper for the FastAPI backend described in
/// `docs/4.接口文档.md`. Every feature repository depends on the
/// `APIClientProtocol`, not this concrete type, so tests can inject
/// `FakeAPIClient` instead.
protocol APIClientProtocol: Sendable {
    func searchPlaces(query: String) async throws -> [Place]
    func reversePlace(coordinates: Coordinates) async throws -> ReverseGeocodeResult
    func planRoutes(
        origin: Coordinates,
        destination: Coordinates,
        originName: String?,
        destinationName: String?
    ) async throws -> [RoutePlan]
    func nearbyExploration(
        center: Coordinates,
        radiusMeters: Int
    ) async throws -> [ExplorationCategory: [ExplorationItem]]
}

struct ReverseGeocodeResult: Codable, Hashable, Sendable {
    let coordinates: Coordinates
    let address: String
    let confidence: Confidence

    enum Confidence: String, Codable, Sendable {
        case high, low
    }
}

enum APIError: Error {
    case invalidResponse
    case http(statusCode: Int)
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func searchPlaces(query: String) async throws -> [Place] {
        let response: SearchPlacesResponse = try await send(.searchPlaces(query: query))
        return response.results
    }

    func reversePlace(coordinates: Coordinates) async throws -> ReverseGeocodeResult {
        try await send(.reversePlace(coordinates: coordinates))
    }

    func planRoutes(
        origin: Coordinates,
        destination: Coordinates,
        originName: String?,
        destinationName: String?
    ) async throws -> [RoutePlan] {
        let response: PlanRoutesResponse = try await send(
            .planRoutes(
                origin: origin,
                destination: destination,
                originName: originName,
                destinationName: destinationName
            )
        )
        return response.routes
    }

    func nearbyExploration(
        center: Coordinates,
        radiusMeters: Int
    ) async throws -> [ExplorationCategory: [ExplorationItem]] {
        let response: NearbyExplorationResponse = try await send(
            .nearbyExploration(center: center, radiusMeters: radiusMeters)
        )
        return response.categories
    }

    private func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems

        guard let url = components?.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method

        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.http(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(Response.self, from: data)
    }
}

private struct SearchPlacesResponse: Decodable {
    let query: String
    let results: [Place]
}

private struct PlanRoutesResponse: Decodable {
    let routes: [RoutePlan]
}

private struct NearbyExplorationResponse: Decodable {
    let center: Coordinates
    let radiusMeters: Int
    let categories: [ExplorationCategory: [ExplorationItem]]

    enum CodingKeys: String, CodingKey {
        case center, categories
        case radiusMeters = "radius_meters"
    }
}
