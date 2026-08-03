# PersonalPlaces

**Status:** flat list + pause + delete (with confirmation) ported over
SwiftData (design doc section 2.3). Flutter equivalent:
`app/lib/screens/personal_places_screen.dart`,
`app/lib/services/tracked_place_repository.dart` (which used
`SharedPreferences` + a JSON array; this module uses SwiftData instead —
see `Core/Persistence/TrackedPlaceStore.swift`).

## Not yet ported

- **Category/tag filter toggles** at the top of the list (design doc
  section 2.3: "列表顶部提供按分类、按重要程度筛选的开关").
- **Edit sheet** for name/category/tag/location (section 2.3's "编辑名称、
  分类、重要程度或位置"). `PersonalPlacesViewModel` has no update-in-place
  flow for individual fields yet, only the pause toggle.
- **"Add as personal place" flows** from `Exploration` search results
  (design doc section 2.1.3, "行前：搜索结果的双路径") and from a physical
  button press while walking (section 2.1.3, "行中：按键触发的实时捕捉").
  Both are currently only implemented in the Flutter version
  (`track_place_screen.dart`) and need a Swift equivalent — the button
  capture path in particular needs `AVFoundation`'s remote control event
  handling (`MPRemoteCommandCenter`) or Bluetooth accessory input, which
  isn't wired up anywhere yet.
- **Custom category creation** — `TrackedPlaceCategory.isUserDefined`
  exists in the model but there's no UI to create one.

## Where to start

The edit sheet is the most contained next step: a `Form` bound to a
`TrackedPlace` draft, calling `PersonalPlacesRepositoring.update(_:)` on
save (already implemented in
`Data/SwiftDataPersonalPlacesRepository.swift`).
