import Foundation

/// Builds the launch `URL` for a given `HandoffTarget`, kept separate
/// from `AppHandoffService`'s actual `UIApplication.open` call so this
/// logic is plain, dependency-free, and unit-testable (see
/// `EasyPathTests/Core/HandoffURLBuilderTests.swift`).
enum HandoffURLBuilder {
    /// - Parameters:
    ///   - callbackScheme: our own app's URL scheme (e.g. `"easypath"`),
    ///     used to build an x-callback-url return address when `target`
    ///     supports one (`HandoffTarget.supportsReturnCallback`).
    ///     Ignored for targets that don't support callbacks.
    static func url(
        for target: HandoffTarget,
        destination: Coordinates,
        destinationName: String?,
        origin: Coordinates?,
        mode: HandoffTravelMode,
        callbackScheme: String
    ) -> URL? {
        switch target {
        case .appleMaps:
            appleMapsURL(destination: destination, origin: origin, mode: mode)
        case .googleMaps:
            googleMapsURL(
                destination: destination,
                origin: origin,
                mode: mode,
                callbackScheme: callbackScheme
            )
        case .moovit:
            moovitURL(destination: destination, destinationName: destinationName, origin: origin)
        }
    }

    private static func appleMapsURL(
        destination: Coordinates,
        origin: Coordinates?,
        mode: HandoffTravelMode
    ) -> URL? {
        var components = URLComponents(string: "maps://")
        var items = [URLQueryItem(name: "daddr", value: coordinateString(destination))]
        if let origin {
            items.append(URLQueryItem(name: "saddr", value: coordinateString(origin)))
        }
        items.append(URLQueryItem(name: "dirflg", value: appleDirectionFlag(for: mode)))
        components?.queryItems = items
        return components?.url
    }

    private static func appleDirectionFlag(for mode: HandoffTravelMode) -> String {
        switch mode {
        case .walking: "w"
        case .driving: "d"
        case .cycling: "c"
        case .transit: "r"
        }
    }

    private static func googleMapsURL(
        destination: Coordinates,
        origin: Coordinates?,
        mode: HandoffTravelMode,
        callbackScheme: String
    ) -> URL? {
        let scheme = "comgooglemaps-x-callback://"
        var components = URLComponents(string: scheme)
        var items = [URLQueryItem(name: "daddr", value: coordinateString(destination))]
        if let origin {
            items.append(URLQueryItem(name: "saddr", value: coordinateString(origin)))
        }
        items.append(URLQueryItem(name: "directionsmode", value: googleDirectionsMode(for: mode)))
        items.append(URLQueryItem(name: "x-success", value: "\(callbackScheme)://handoff/googleMaps"))
        items.append(URLQueryItem(name: "x-source", value: "EasyPath"))
        components?.queryItems = items
        return components?.url
    }

    private static func googleDirectionsMode(for mode: HandoffTravelMode) -> String {
        switch mode {
        case .walking: "walking"
        case .driving: "driving"
        case .cycling: "bicycling"
        case .transit: "transit"
        }
    }

    /// Moovit is transit-only (see `moovit.com/developers/deeplinking/`)
    /// — there is no travel-mode parameter to set.
    private static func moovitURL(
        destination: Coordinates,
        destinationName: String?,
        origin: Coordinates?
    ) -> URL? {
        var components = URLComponents(string: "moovit://directions")
        var items = [
            URLQueryItem(name: "dest_lat", value: String(destination.latitude)),
            URLQueryItem(name: "dest_lon", value: String(destination.longitude)),
            URLQueryItem(name: "partner_id", value: "EasyPath"),
        ]
        if let destinationName {
            items.append(URLQueryItem(name: "dest_name", value: destinationName))
        }
        if let origin {
            items.append(URLQueryItem(name: "orig_lat", value: String(origin.latitude)))
            items.append(URLQueryItem(name: "orig_lon", value: String(origin.longitude)))
        }
        components?.queryItems = items
        return components?.url
    }

    private static func coordinateString(_ coordinates: Coordinates) -> String {
        "\(coordinates.latitude),\(coordinates.longitude)"
    }
}
