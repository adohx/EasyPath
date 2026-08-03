import Testing
@testable import EasyPath

struct ProximityAnnouncerTests {
    private let userLocation = Coordinates(latitude: 42.3149, longitude: -83.0364)

    private func riskPoint(id: String = "risk-1", metersAway: Double, trigger: Double = 100) -> RiskPoint {
        RiskPoint(
            id: id,
            type: .intersection,
            location: offset(from: userLocation, metersEast: metersAway),
            description: "Signalled intersection",
            severity: .high,
            source: "overpass",
            updatedAt: nil,
            triggerDistanceMeters: trigger
        )
    }

    private func functionalPoint(
        id: String = "fp-1",
        type: FunctionalPointType = .busBoard,
        importance: FunctionalPointImportance = .required,
        metersAway: Double,
        trigger: Double = 80
    ) -> FunctionalPoint {
        FunctionalPoint(
            id: id,
            type: type,
            location: offset(from: userLocation, metersEast: metersAway),
            description: "Bus stop",
            importance: importance,
            triggerDistanceMeters: trigger,
            requiresConfirmation: false
        )
    }

    /// Rough metres-to-degrees offset, accurate enough for these
    /// small-scale test distances.
    private func offset(from origin: Coordinates, metersEast: Double) -> Coordinates {
        Coordinates(
            latitude: origin.latitude,
            longitude: origin.longitude + metersEast / 111_000
        )
    }

    @Test func riskPointOutranksClosertRequiredFunctionalPoint() throws {
        let risk = riskPoint(metersAway: 90)
        let required = functionalPoint(id: "fp-close", metersAway: 10)

        let result = try #require(ProximityAnnouncer.nextAnnouncement(
            location: userLocation,
            functionalPoints: [required],
            riskPoints: [risk],
            alreadyAnnouncedIDs: []
        ))

        #expect(result.pointID == "risk-1")
        #expect(result.priority == .riskPoint)
    }

    @Test func requiredFunctionalPointOutranksClosestNavigationPoint() throws {
        let required = functionalPoint(id: "fp-required", importance: .required, metersAway: 60)
        let navigation = functionalPoint(id: "fp-nav", importance: .navigation, metersAway: 5)

        let result = try #require(ProximityAnnouncer.nextAnnouncement(
            location: userLocation,
            functionalPoints: [required, navigation],
            riskPoints: [],
            alreadyAnnouncedIDs: []
        ))

        #expect(result.pointID == "fp-required")
        #expect(result.priority == .requiredFunctionalPoint)
    }

    @Test func nearestWinsWithinSameTier() throws {
        let far = riskPoint(id: "risk-far", metersAway: 80)
        let near = riskPoint(id: "risk-near", metersAway: 20)

        let result = try #require(ProximityAnnouncer.nextAnnouncement(
            location: userLocation,
            functionalPoints: [],
            riskPoints: [far, near],
            alreadyAnnouncedIDs: []
        ))

        #expect(result.pointID == "risk-near")
    }

    @Test func alreadyAnnouncedPointIsNeverRepeated() {
        let risk = riskPoint(metersAway: 20)

        let result = ProximityAnnouncer.nextAnnouncement(
            location: userLocation,
            functionalPoints: [],
            riskPoints: [risk],
            alreadyAnnouncedIDs: ["risk-1"]
        )

        #expect(result == nil)
    }

    @Test func nilWhenNothingWithinTriggerDistance() {
        let farRisk = riskPoint(metersAway: 500, trigger: 100)

        let result = ProximityAnnouncer.nextAnnouncement(
            location: userLocation,
            functionalPoints: [],
            riskPoints: [farRisk],
            alreadyAnnouncedIDs: []
        )

        #expect(result == nil)
    }

    @Test func busBoardUsesShortThenLongHaptic() throws {
        let point = functionalPoint(type: .busBoard, importance: .required, metersAway: 10)

        let result = try #require(ProximityAnnouncer.nextAnnouncement(
            location: userLocation,
            functionalPoints: [point],
            riskPoints: [],
            alreadyAnnouncedIDs: []
        ))

        #expect(result.hapticPattern == .shortThenLong)
    }

    @Test func buildingEntranceUsesShortTapHaptic() throws {
        let point = functionalPoint(
            id: "fp-entrance", type: .buildingEntrance, importance: .required, metersAway: 10
        )

        let result = try #require(ProximityAnnouncer.nextAnnouncement(
            location: userLocation,
            functionalPoints: [point],
            riskPoints: [],
            alreadyAnnouncedIDs: []
        ))

        #expect(result.hapticPattern == .shortTap)
    }
}
