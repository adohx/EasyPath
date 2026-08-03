import Testing
@testable import EasyPath

struct HandoffURLBuilderTests {
    private let destination = Coordinates(latitude: 42.3192, longitude: -83.0391)
    private let origin = Coordinates(latitude: 42.3149, longitude: -83.0364)

    @Test func appleMapsIncludesDestinationOriginAndWalkingFlag() throws {
        let url = try #require(HandoffURLBuilder.url(
            for: .appleMaps,
            destination: destination,
            destinationName: nil,
            origin: origin,
            mode: .walking,
            callbackScheme: "easypath"
        ))

        #expect(url.scheme == "maps")
        #expect(url.absoluteString.contains("daddr=42.3192,-83.0391"))
        #expect(url.absoluteString.contains("saddr=42.3149,-83.0364"))
        #expect(url.absoluteString.contains("dirflg=w"))
    }

    @Test func appleMapsOmitsSaddrWhenOriginIsNil() throws {
        let url = try #require(HandoffURLBuilder.url(
            for: .appleMaps,
            destination: destination,
            destinationName: nil,
            origin: nil,
            mode: .walking,
            callbackScheme: "easypath"
        ))

        #expect(!url.absoluteString.contains("saddr"))
    }

    @Test func googleMapsUsesXCallbackSchemeWithReturnAddress() throws {
        let url = try #require(HandoffURLBuilder.url(
            for: .googleMaps,
            destination: destination,
            destinationName: nil,
            origin: origin,
            mode: .transit,
            callbackScheme: "easypath"
        ))

        #expect(url.scheme == "comgooglemaps-x-callback")
        #expect(url.absoluteString.contains("directionsmode=transit"))
        #expect(url.absoluteString.contains("x-success=easypath://handoff/googleMaps"))
    }

    @Test func moovitIncludesDestinationNameAndPartnerId() throws {
        let url = try #require(HandoffURLBuilder.url(
            for: .moovit,
            destination: destination,
            destinationName: "Windsor Public Library",
            origin: origin,
            mode: .transit,
            callbackScheme: "easypath"
        ))

        #expect(url.scheme == "moovit")
        #expect(url.absoluteString.contains("dest_name=Windsor%20Public%20Library"))
        #expect(url.absoluteString.contains("partner_id=EasyPath"))
        #expect(url.absoluteString.contains("orig_lat=42.3149"))
    }
}
