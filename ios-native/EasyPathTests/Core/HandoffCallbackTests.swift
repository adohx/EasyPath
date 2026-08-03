import Foundation
import Testing
@testable import EasyPath

struct HandoffCallbackTests {
    @Test func parsesGoogleMapsReturnURL() throws {
        let url = try #require(URL(string: "easypath://handoff/googleMaps"))
        #expect(HandoffCallback(url: url, ownScheme: "easypath") == .googleMapsFinished)
    }

    @Test func rejectsWrongScheme() throws {
        let url = try #require(URL(string: "someotherapp://handoff/googleMaps"))
        #expect(HandoffCallback(url: url, ownScheme: "easypath") == nil)
    }

    @Test func rejectsUnknownPath() throws {
        let url = try #require(URL(string: "easypath://handoff/somethingElse"))
        #expect(HandoffCallback(url: url, ownScheme: "easypath") == nil)
    }
}
