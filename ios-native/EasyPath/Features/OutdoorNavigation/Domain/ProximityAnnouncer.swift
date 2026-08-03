import Foundation

/// Decides which functional/risk point (if any) should be announced for
/// the current location — design doc section 2.2.4 and 2.2.8.
///
/// Priority tiers are fixed and never reorder based on proximity (a
/// closer lower-tier point never jumps ahead of a farther higher-tier
/// one that's also in range): risk point, then required functional
/// point, then navigation functional point. Within a tier, the nearest
/// candidate wins. A point that already fired once is never repeated
/// (`alreadyAnnouncedIDs` — design doc: "探索点不能无限重复播报").
///
/// No CoreLocation dependency, so this is unit-testable on its own, the
/// same pattern as `NavigationStateBuilder`.
enum ProximityAnnouncer {
    struct Announcement: Equatable {
        let pointID: String
        let text: String
        let priority: AnnouncementPriorityTier
        let hapticPattern: HapticPattern
    }

    static func nextAnnouncement(
        location: Coordinates,
        functionalPoints: [FunctionalPoint],
        riskPoints: [RiskPoint],
        alreadyAnnouncedIDs: Set<String>
    ) -> Announcement? {
        let required = functionalPoints.filter { $0.importance == .required }
        let navigation = functionalPoints.filter { $0.importance == .navigation }

        if let nearest = nearestInRange(riskPoints, from: location, excluding: alreadyAnnouncedIDs) {
            return announcement(nearest, prefix: "Caution: ", priority: .riskPoint, haptic: .longPulse)
        }
        if let nearest = nearestInRange(required, from: location, excluding: alreadyAnnouncedIDs) {
            return announcement(
                nearest, prefix: "", priority: .requiredFunctionalPoint,
                haptic: hapticPattern(for: nearest.point.type)
            )
        }
        if let nearest = nearestInRange(navigation, from: location, excluding: alreadyAnnouncedIDs) {
            return announcement(nearest, prefix: "", priority: .navigationOrExploration, haptic: .shortTap)
        }
        return nil
    }

    private static func announcement<Point: ProximityCandidate>(
        _ nearest: (point: Point, distance: Double),
        prefix: String,
        priority: AnnouncementPriorityTier,
        haptic: HapticPattern
    ) -> Announcement {
        Announcement(
            pointID: nearest.point.id,
            text: "\(prefix)\(nearest.point.description), "
                + "approximately \(Int(nearest.distance)) metres ahead.",
            priority: priority,
            hapticPattern: haptic
        )
    }

    /// 短震加长震 for the transit board/alight/transfer moments the
    /// design doc calls out by name; a plain building entrance is closer
    /// in feel to an ordinary navigation cue.
    private static func hapticPattern(for type: FunctionalPointType) -> HapticPattern {
        switch type {
        case .busBoard, .busAlight, .busTransfer: .shortThenLong
        case .buildingEntrance, .turn, .landmark, .unknown: .shortTap
        }
    }

    private static func nearestInRange<Point: ProximityCandidate>(
        _ points: [Point],
        from location: Coordinates,
        excluding announcedIDs: Set<String>
    ) -> (point: Point, distance: Double)? {
        points
            .filter { !announcedIDs.contains($0.id) }
            .compactMap { point -> (Point, Double)? in
                let distance = GeoUtils.distanceMeters(from: location, to: point.location)
                return distance <= point.triggerDistanceMeters ? (point, distance) : nil
            }
            .min { $0.1 < $1.1 }
    }
}

private protocol ProximityCandidate {
    var id: String { get }
    var location: Coordinates { get }
    var triggerDistanceMeters: Double { get }
    var description: String { get }
}

extension RiskPoint: ProximityCandidate {}
extension FunctionalPoint: ProximityCandidate {}
