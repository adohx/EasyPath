# Exploration

**Status:** category-grouped nearby-places browsing ported (design doc
section 2.1.2). Flutter equivalent: `app/lib/screens/exploration_screen.dart`,
`app/lib/services/explore_center_controller.dart`.

This module only surfaces **official** exploration points (from
Overpass/map data via the backend). It does not know about the user's
saved `TrackedPlace`s — that's `PersonalPlaces`.

## Not yet ported

- **Merging official + personal places by category** (design doc section
  2.1.2: "官方探索点与用户已保存的个人地点按分类混合展示"). Needs a
  view-level composition of this module's `ExplorationViewModel` output
  with `PersonalPlaces`' repository output — see that module's README for
  the other half.
- **Sequential voice playback** (next/previous/jump-by-number through a
  category) — section 2.1.2's "按类别逐一播放" requirement. Flutter
  reference: `explore_center_controller.dart`'s playback state.
- **Save-to-personal-place action** from a search result (section
  2.1.3's "加入追踪" path) — this is the boundary where `Exploration`
  hands a result to `PersonalPlaces` to persist; that flow doesn't exist
  yet on either side.

## Where to start

The category/personal-place merge is the natural next step and mostly a
`Presentation`-layer change: inject `PersonalPlaces`' repository
alongside this module's, and combine the two `[ExplorationCategory:
[ExplorationItem]]`-shaped outputs before rendering.
