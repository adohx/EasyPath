# RoutePlanning

**Status:** destination search + route option comparison ported (design
doc sections 2.1.1, 2.1.6, 2.1.8), plus voice search input (section
3.1.1.1) and third-party hand-off buttons per leg (see the last section
below). Flutter equivalents: `app/lib/screens/home_screen.dart`,
`route_selection_screen.dart`.

Voice input: `RoutePlanningViewModel.startVoiceInput()`/
`stopVoiceInputAndSearch()` wrap `Core/Speech/SpeechRecognizer.swift`,
surfaced as a tap-to-toggle microphone button in `RoutePlanningView`
(`VoiceInputButton`) rather than the design doc's press-and-hold, since a
hold gesture isn't reliably discoverable with VoiceOver. Recognized text
fills `viewModel.query` and searches immediately.

## Not yet ported

- **Waypoints** (section 2.1.4) — adding/removing stops before the final
  destination. Needs a request-shape change to `/api/routes/plan`
  (currently only takes a single origin/destination pair — see
  `docs/4.接口文档.md` section 2.4) on both this client and the backend.
- **Exploration points on a route** (section 2.1.3) — checking whether a
  saved exploration point lies on the planned route and announcing the
  detour cost if not. Depends on `Exploration`/`PersonalPlaces` being
  wired in.
- **Step-by-step route detail playback** (section 2.1.10) — currently
  only the route summary is shown/spoken; per-step "Step 2 of 7..."
  playback with next/previous/repeat is not built. Flutter reference:
  `app/lib/screens/route_detail_screen.dart`.
- **Accessibility score explanation** (section 2.1.9) — `AccessibilitySummary`
  is decoded (`Core/Models/AccessibilitySummary.swift`) but not yet
  rendered/announced with its inputs.

## Where to start

The step-by-step playback item is the most self-contained: it only needs
`RoutePlan.legs[].steps` (already modelled) and a new
`Presentation/RouteDetailView.swift` + `RouteDetailViewModel.swift` pair
that plays through `NavigationStep`s, mirroring
`route_detail_screen.dart`'s behavior.

## Third-party hand-off (implemented, secondary path)

`RouteSummaryRow`/`LegHandoffRow` in `RoutePlanningView.swift` show
"open in Apple Maps / Google Maps / Moovit" buttons per leg, via
`RoutePlanningViewModel.openLegInThirdPartyApp(_:target:)` and
`Core/Handoff/AppHandoffService.swift` — see
`.claude/memory/third_party_deeplink_feasibility.md` and
`docs/9.第三方生态调研与集成可行性.md` section six for why this stays a
secondary, opt-in action rather than the default path (it loses our
accessibility annotations, and most targets don't hand control back).
