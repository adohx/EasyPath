# IndoorNavigation

**Status:** not implemented. New scope, requested by product manager
David Best's requirements doc
(`docs/7.产品经理需求_Hackforge_WayFinding.md`, Module 2.2) — this has no
Flutter equivalent to port from.

**Competitive landscape (researched 2026-07-27, see
`.claude/memory/existing_app_landscape_module_coverage.md`):** this
capability is not a technical gap so much as a "which existing product do
we align with" decision — two different commercial products already do
indoor wayfinding for blind/low-vision users, using two different
techniques:

- **Right-Hear** (linked in the PM doc) — BLE beacon-based.
- **GoodMaps Explore** (linked in the PM doc's Project Resources) — does
  **not** use beacons at all. It relies on a venue being pre-scanned with
  LiDAR to build a 3D map, then does camera-based AR positioning against
  that map (~1m accuracy in good conditions). Actively deployed in real
  venues as of 2026 (e.g. York University's Glendon Campus, May 2026).

Auracast (broadcast Bluetooth LE Audio reception) is the other half of
the PM doc's Module 2.2 ask, but as of 2026 **iOS has no native Auracast
support at all** — Android 16 does, iPhones can only reach Auracast
broadcasts through a compatible hearing aid acting as a bridge. This
isn't a "not built yet" gap we can close with app code; it requires
Apple to expose the capability at the OS/CoreBluetooth level first, which
hasn't happened.

## Scope (from the PM doc)

- Indoor positioning (BLE beacon and/or LiDAR/camera-based — see above,
  this is now an open technology-choice question, not a given).
- Auracast broadcast audio reception — **currently blocked at the
  platform level on iOS**, not just unimplemented.

## Open questions before writing code here

These need answers before `Domain/IndoorBeaconScanning.swift`'s single
placeholder protocol can turn into a real implementation:

1. **Build vs. align with an existing product**: given Right-Hear and
   GoodMaps Explore already solve this for blind/low-vision users, is
   there a case for building our own indoor positioning at all, versus
   a partnership/hand-off approach (similar to the deep-link hand-off
   idea explored for Module 1/2.1 — see
   `.claude/memory/third_party_deeplink_feasibility.md`)? Neither
   Right-Hear nor GoodMaps' deep-link/API surface has been researched
   yet — that would need to happen before ruling this in or out.
2. **If building in-house — which technique**: BLE beacon ranging
   (`CoreLocation`'s `CLBeaconRegion`, or raw `CoreBluetooth` for a
   vendor-specific protocol) vs. GoodMaps' LiDAR/camera-based approach
   (which would need ARKit + a venue-scanning pipeline we don't have any
   infrastructure for today).
3. **Auracast**: not buildable on iOS right now regardless of approach —
   revisit only if/when Apple adds platform-level support. Don't spend
   engineering time on this until that changes.
4. **Venue data**: where would beacon-to-location or LiDAR-scan-to-location
   mappings live? Likely a new backend concept (a venue registry), not
   something Overpass or MOTIS provide today — see `docs/4.接口文档.md`
   for what the backend currently exposes.
5. **Hardware/venue access**: this needs either physical beacons or a
   LiDAR-scanned venue to test against; a pure-simulator development loop
   isn't possible for this module the way it is for the others.

## Where to start

Don't start writing any ranging/positioning code without first answering
question 1 — whether this module should be a from-scratch build at all,
versus pointing users at Right-Hear/GoodMaps the way Module 1 might hand
off to BlindSquare. That's a product decision, not an engineering one.
