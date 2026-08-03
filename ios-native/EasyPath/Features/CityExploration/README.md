# CityExploration

**Status:** not implemented. New scope, requested by product manager
David Best's requirements doc
(`docs/7.产品经理需求_Hackforge_WayFinding.md`, Module 3) — this has no
Flutter equivalent to port from, and is broader than the existing
`Exploration` module (live nearby-POI browsing by category).

## The PM doc actually bundles three different things under "Module 3"

Researched 2026-07-27 (see `.claude/memory/existing_app_landscape_module_coverage.md`).
"Users can find their way around Windsor through game play, predefined
walking tours, and personal investigation" turns out to name three
distinct presentation forms, each with a different existing reference
and a different build cost:

1. **Predefined walking tours** — a curated sequence of stops with
   narration at each one, like a museum audio guide. **This is the
   cheapest to build**: it reuses `RoutePlanning`'s existing
   route-playback infrastructure almost as-is, just with authored
   narration content instead of live-generated route steps. No new
   interaction model needed.
2. **Virtual/simulated exploration** — moving a virtual position through
   a non-physical, audio-rendered map (arrow keys / swipe gestures +
   spatial audio callouts), so a user can "walk" an area without
   actually being there. **Audiom** (linked in the PM doc) is a real,
   WCAG Triple-A product doing exactly this. Notably, **BlindSquare
   already does a version of this too** — David's own "Live
   Demonstration" section in the PM doc describes using BlindSquare's
   "simulate location" + "Look Around" feature for exactly this purpose.
   Given two existing products (one of which is already in this
   project's own reference workflow) do this, building our own version
   would have to justify itself against both.
3. **Full game layer** (badges, city-building engagement, etc.) —
   **Geopogo Cities: Windsor-Detroit** (linked in the PM doc) turns out,
   on inspection, to **not be an accessibility product at all**: it's a
   mainstream 3D city-builder game (Unreal Engine, on Steam/Epic Games
   Store) using real Windsor-Detroit map data, aimed at general players.
   Its own "accessibility" roadmap is generic UI/UX polish, not
   blind/low-vision-specific design. It's likely referenced for its
   Windsor civic-engagement angle (public interest, possible city
   partnership/cross-promotion) rather than as a reusable accessibility
   exploration pattern. `audiogames.net` (the third reference) is just a
   directory of existing accessible audio games generally, not a single
   product to align with either.

## Recommendation if this module gets prioritized

Start with **predefined walking tours** — it's the only one of the three
without an existing, already-adequate product covering it (Audiom and
BlindSquare's own simulate/Look-Around feature already cover #2; Geopogo
isn't actually an accessibility tool and isn't ours to emulate for #3).
It's also the one that reuses the most existing infrastructure.

## Open questions before writing code here

1. **Confirm the "predefined tours" direction with the product side**
   before building — this README's recommendation is an engineering
   read of the PM doc, not a confirmed decision.
2. **Content authoring** — predefined walking tours need someone to
   define stops and narration per tour. Is there a content pipeline, or
   would tours be authored directly as data (see `CityTour` in
   `Domain/CityTour.swift`, currently just a title + ordered stop
   coordinates with no narration model yet)?
3. **Relationship to `Exploration`** — should tour stops reuse
   `ExplorationItem`/`TrackedPlace`, or are they a separate concept? The
   current `CityTour.stops` being plain `Coordinates` (not
   `ExplorationItem`) is a placeholder, not a settled decision.

## Where to start

If the "predefined tours" direction is confirmed: add a `narration:
String` field (and probably an ordered stop-narration pairing type) to
`CityTour`, then build a `Presentation/CityTourPlayerView.swift` that
plays through stops the same way `RoutePlanning`'s step playback would
(see that module's README) — sequential TTS narration with
next/previous/repeat, not a new interaction model.
