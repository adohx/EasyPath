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

extension LocationProviding {
    /// Waits for a single location fix, with a hard timeout. Used by any
    /// one-shot "where am I right now" call (`RoutePlanning`'s
    /// destination selection, `Exploration`'s nearby-places load) —
    /// without the timeout this hangs forever whenever no fix ever
    /// arrives: the user still sitting on the system permission prompt,
    /// the iOS Simulator's location set to "None" (its default), or
    /// (before `CoreLocationProvider` handled `didFailWithError`) a
    /// denied permission. `OutdoorNavigation`'s continuous tracking uses
    /// `locationUpdates()` directly instead — a timeout doesn't make
    /// sense for a stream that's meant to keep running.
    ///
    /// - Important: the location-fetching child task below is pinned to
    /// `@MainActor`. `TaskGroup.addTask` child tasks do **not** inherit
    /// the caller's actor context the way a plain `Task { }` does — left
    /// unannotated, `locationUpdates()` (and so `CLLocationManager.
    /// startUpdatingLocation()`) would run on a background executor,
    /// where `CLLocationManager` reliably never delivers delegate
    /// callbacks. That bug looked exactly like "no GPS fix ever arrives"
    /// (a clean timeout every time, regardless of permission status or
    /// GPS conditions) rather than a crash, which is what made it easy
    /// to misdiagnose as a permissions or signal problem.
    @MainActor
    func currentLocation(timeout: Duration = .seconds(10)) async -> CLLocation? {
        Log.location.debug(
            "currentLocation: requesting, authorizationStatus=\(String(describing: authorizationStatus)), mainThread=\(Thread.isMainThread)"
        )
        requestWhenInUseAuthorization()

        let result = await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { await self.firstLocationUpdate() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        if let result {
            Log.location.debug("currentLocation: got fix \(result.coordinate.latitude), \(result.coordinate.longitude)")
        } else {
            Log.location.error("currentLocation: timed out after \(timeout) with no fix and no denial")
        }
        return result
    }

    @MainActor
    private func firstLocationUpdate() async -> CLLocation? {
        for await update in locationUpdates() {
            return update
        }
        return nil
    }
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
            Log.location.debug(
                "locationUpdates: starting CLLocationManager, mainThread=\(Thread.isMainThread), authorizationStatus=\(String(describing: self.manager.authorizationStatus)), locationServicesEnabled=\(CLLocationManager.locationServicesEnabled())"
            )
            let delegate = LocationStreamDelegate(
                onLocation: { continuation.yield($0) },
                onHeading: nil,
                onDenied: { continuation.finish() }
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
    private let onDenied: (() -> Void)?

    init(
        onLocation: ((CLLocation) -> Void)?,
        onHeading: ((CLHeading) -> Void)?,
        onDenied: (() -> Void)? = nil
    ) {
        self.onLocation = onLocation
        self.onHeading = onHeading
        self.onDenied = onDenied
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Log.location.debug("didUpdateLocations: \(locations.count) location(s), mainThread=\(Thread.isMainThread)")
        locations.last.map { onLocation?($0) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        onHeading?(newHeading)
    }

    /// Only `.denied` ends the stream — CoreLocation's other error cases
    /// (e.g. `.locationUnknown`) are transient, and Apple's own guidance
    /// is to keep waiting for the next callback rather than give up, so
    /// ending the stream on those would cut off long-running consumers
    /// like `OutdoorNavigation` over a blip that would have recovered.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("didFailWithError: \(error), code=\(String(describing: (error as? CLError)?.code))")
        guard (error as? CLError)?.code == .denied else { return }
        onDenied?()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Log.location.debug(
            "locationManagerDidChangeAuthorization: \(String(describing: manager.authorizationStatus))"
        )
    }
}
