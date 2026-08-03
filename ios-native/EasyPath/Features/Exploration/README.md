# Exploration

**Status:** category-grouped nearby-places browsing, merged with nearby
personal places, ported (design doc section 2.1.2). Flutter equivalent:
`app/lib/screens/exploration_screen.dart`,
`app/lib/services/explore_center_controller.dart`.

This module reads **official** exploration points (from Overpass/map
data via the backend) and merges in the user's saved `TrackedPlace`s that
fall within the same search radius — see
`Domain/ExplorationDisplayItem.swift`'s `ExplorationMerger`, which is
pure logic and unit-tested independently of both repositories
(`EasyPathTests/Features/Exploration/ExplorationMergerTests.swift`). The
default search radius comes from `Settings`' `alertRadiusMeters`
preference unless a caller passes one explicitly. `PersonalPlaces` still
owns all writes (add/edit/pause/delete) — this module only reads.

## Not yet ported

- **Sequential voice playback** (next/previous/jump-by-number through a
  category) — section 2.1.2's "按类别逐一播放" requirement. Flutter
  reference: `explore_center_controller.dart`'s playback state.
- **Save-to-personal-place action** from a search result (section
  2.1.3's "加入追踪" path) — this is the boundary where `Exploration`
  hands a result to `PersonalPlaces` to persist; that flow doesn't exist
  yet on either side.

## Where to start

Sequential voice playback is the natural next step: `ExplorationViewModel`
already exposes `sections: [ExplorationSection]` in a stable order: add
current-index state and next/previous/repeat methods that speak
`ExplorationDisplayItem.name` (plus distance/bearing for the `.official`
case) through `SpeechOutputting`.
