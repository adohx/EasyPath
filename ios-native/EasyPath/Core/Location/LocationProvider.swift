import CoreLocation

/// Streams the user's location and heading, wrapping `CLLocationManager`
/// behind an `AsyncSequence` so `Domain` code never touches the delegate
/// pattern directly.
///
/// Mirrors the responsibilities of the Flutter `location_service.dart`
/// and part of `services/navigation/` (section 2.2.2 of the design doc:
/// GPS + compass + gyroscope fusion). This first pass only wraps raw
/// CoreLocation updates — smoothing, outlier filtering and map matching
/// (design doc section 6, "定位增强" Phase 6) are follow-up work.
///
/// - Warning: `CLLocationManager` has a single `delegate`, but
/// `locationUpdates()` and `headingUpdates()` each install their own — the
/// second call on the same provider instance wins. Fine for the current
/// single-consumer `OutdoorNavigation` use case; needs a shared
/// multiplexing delegate before more than one caller streams from the
/// same provider at once.
protocol LocationProviding: Sendable {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func locationUpdates() -> AsyncStream<CLLocation>
    func headingUpdates() -> AsyncStream<HeadingReading>
}

/// `Sendable` snapshot of the fields `OutdoorNavigation` actually needs
/// from a `CLHeading` reading. `CLHeading` itself isn't `Sendable`, so it
/// cannot be yielded directly from an `AsyncStream` under Swift 6 strict
/// concurrency — this is extracted at the delegate callback instead.
struct HeadingReading: Sendable {
    let trueHeadingDegrees: Double
    let magneticHeadingDegrees: Double
    let headingAccuracyDegrees: Double

    init(_ heading: CLHeading) {
        trueHeadingDegrees = heading.trueHeading
        magneticHeadingDegrees = heading.magneticHeading
        headingAccuracyDegrees = heading.headingAccuracy
    }
}

final class CoreLocationProvider: NSObject, LocationProviding, @unchecked Sendable {
    private let manager: CLLocationManager
    /// Kept alive for as long as a stream is active; also sidesteps
    /// capturing a non-`Sendable` local `delegate` inside the `@Sendable`
    /// `continuation.onTermination` closures below (only `self`, which is
    /// `@unchecked Sendable`, is captured there).
    private var activeDelegate: LocationStreamDelegate?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 1
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func locationUpdates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            let delegate = LocationStreamDelegate(
                onLocation: { continuation.yield($0) },
                onHeading: nil
            )
            activeDelegate = delegate
            manager.delegate = delegate
            manager.startUpdatingLocation()
            continuation.onTermination = { [weak self] _ in
                self?.manager.stopUpdatingLocation()
                self?.activeDelegate = nil
            }
        }
    }

    func headingUpdates() -> AsyncStream<HeadingReading> {
        AsyncStream { continuation in
            let delegate = LocationStreamDelegate(
                onLocation: nil,
                onHeading: { continuation.yield(HeadingReading($0)) }
            )
            activeDelegate = delegate
            manager.delegate = delegate
            manager.startUpdatingHeading()
            continuation.onTermination = { [weak self] _ in
                self?.manager.stopUpdatingHeading()
                self?.activeDelegate = nil
            }
        }
    }
}

private final class LocationStreamDelegate: NSObject, CLLocationManagerDelegate {
    private let onLocation: ((CLLocation) -> Void)?
    private let onHeading: ((CLHeading) -> Void)?

    init(onLocation: ((CLLocation) -> Void)?, onHeading: ((CLHeading) -> Void)?) {
        self.onLocation = onLocation
        self.onHeading = onHeading
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.last.map { onLocation?($0) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        onHeading?(newHeading)
    }
}
