# OutdoorNavigation

**Status:** basic live tracking, route progress, and confirmed-off-route
detection ported (design doc sections 2.2.2, 2.2.3, 2.2.5, 2.2.6). Flutter
equivalent: `app/lib/screens/navigation_screen.dart`,
`app/lib/services/navigation/`.

`Domain/NavigationStateBuilder.swift` is pure logic (no CoreLocation
dependency) built on `Core/Extensions/GeoUtils.swift`'s route-projection
math — it's the piece to unit test first if you're picking this module
up.

## Known simplifications (not bugs, just not done yet)

- **"Next" functional/risk point is nearest by straight-line distance**,
  not "nearest ahead of the user along the route." A point just passed
  can still show as "next" until the user is far enough past it. Fixing
  this needs the points to carry (or be matched to) a position along the
  route's cumulative distance, the same way
  `GeoUtils.RouteProjection.distanceAlongRouteMeters` works.
- **`OutdoorNavigationViewModel` depends on `CLLocation` directly**
  (via `LocationProviding.locationUpdates() -> AsyncStream<CLLocation>`),
  so its own tests need a fake that produces `CLLocation` values rather
  than a plain data type. Consider introducing a
  `Core/Location`-owned plain struct if this becomes a real testing
  pain point.
- **GPS smoothing, outlier filtering, and true map matching** (design doc
  section 6, "定位增强", Phase 6) are not implemented — this uses raw
  `CLLocation` fixes as-is.
- **Vibration and speech priority integration is minimal**: only the
  off-route case is wired to `HapticsPlaying`/`SpeechOutputting`.
  Approaching-functional-point announcements (section 2.2.8) and the
  bus/taxi alight reminder (section 2.2.7) are not implemented.
- **Experimental crosswalk-signal assist** (section 2.2.9) has no
  scaffold at all yet — it's a research spike (camera-based signal
  detection or an OKO app hand-off), not a straightforward port.

## Where to start

Approaching-functional-point announcements (section 2.2.8) is the most
valuable next slice: extend `OutdoorNavigationViewModel.handle(location:)`
to check `state.nextFunctionalPoint`'s distance against
`FunctionalPoint.triggerDistanceMeters` and call `speechOutput.speak(...)`
with the appropriate `AnnouncementPriorityTier` from
`Core/Models/AnnouncementPriority.swift`.

## Reference implementation worth reading before building announcements/GPS smoothing

Microsoft's Soundscape (discontinued 2023, open-sourced MIT at
`github.com/microsoft/soundscape`) solved almost exactly this module's
remaining problems for the same audience — see
`.claude/memory/soundscape_open_source_reference.md` and
`docs/9.第三方生态调研与集成可行性.md` section 4. It's UIKit-era Swift,
so not directly portable as code, but three pieces are worth reading
before designing from scratch: `Code/Audio/AudioEngine.swift`
(`AVAudioEnvironmentNode`-based spatial-audio beaconing — could make
functional/risk-point announcements directional instead of flat TTS),
`Code/Sensors/Filters/Kalman Filter/` (GPS/heading smoothing, relevant to
the "GPS smoothing, outlier filtering" gap below), and
`Code/Behaviors/Route Guidance/Callouts/` (a clean
arrival/departure/distance-callout split — a good model for structuring
this module's proximity-announcement throttling/deduping). MIT license
permits porting algorithms directly if a copyright-notice comment is
kept on the copied portion.

## Possible future direction: hand off instead of self-building

`Core/Handoff/AppHandoffService.swift` (added 2026-07-27) can launch
Apple Maps, Google Maps, or Moovit with a pre-filled origin/destination —
see `.claude/memory/third_party_deeplink_feasibility.md` and
`docs/8.iOS原生架构设计.md`'s Handoff section. If the project moves toward
"hand specialized legs off to a specialized app" instead of self-building
full navigation/transit-tracking, this module's live-tracking loop could
shrink considerably (e.g. hand a bus leg to Moovit instead of tracking it
ourselves). Not decided yet — nothing here currently calls
`AppHandoffService`.
