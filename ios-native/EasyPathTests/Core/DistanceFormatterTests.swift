import Testing
@testable import EasyPath

struct DistanceFormatterTests {
    @Test func metricUnderOneKilometreShowsMetres() {
        #expect(DistanceFormatter.string(meters: 450, unit: .metric) == "450m")
    }

    @Test func metricOverOneKilometreShowsKilometres() {
        #expect(DistanceFormatter.string(meters: 1_500, unit: .metric) == "1.5 km")
    }

    @Test func imperialUnderOneMileShowsFeet() {
        #expect(DistanceFormatter.string(meters: 100, unit: .imperial) == "328ft")
    }

    @Test func imperialOverOneMileShowsMiles() {
        #expect(DistanceFormatter.string(meters: 2_000, unit: .imperial) == "1.2 mi")
    }
}
