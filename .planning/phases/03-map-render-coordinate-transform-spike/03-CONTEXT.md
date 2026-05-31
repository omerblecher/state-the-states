# Phase 3: Map Render + Coordinate Transform Spike - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 delivers two tightly coupled things:

1. **The coordinate-transform spike** (`SpikeMapScreen`) — a dev-only screen that
   proves `TransformationController.toScene()` returns accurate scene coordinates
   at 1×, 2×, and 4× zoom, using real state bounding boxes from the bundled JSON.
   This is a hard gate: Phase 4 must not begin until Criteria 1–2 pass.

2. **The production `MapScreen`** — a fully interactive, zoom-capable screen that
   renders all 50 U.S. state paths as filled polygons with borders, correct AK/HI
   insets, and zoom-in/out buttons. This replaces the Phase 1 blank-canvas stub
   and is the foundation Phase 4 extends.

Also delivered: `stateHitTest()` — a port of Flags' `hitTest()` — for the
micro-state proximity golden tests (Criterion 2). Phase 4 wires it into the
actual drag-drop game logic.

**What is NOT in Phase 3:** token tray, drag-and-drop game flow, HUD, scoring
display, game mode label visibility logic, completion screen. Those are Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Map Color Design
- **D-01:** Use a **cycling 6-color palette (`palette[i % 6]` by list index)** —
  direct port of Flags' `WorldMapPainter` palette constants. The 6 colors (soft
  green #8DB87F, tan #D4B483, orange #E8A055, pink #E89090, purple #A07EC8,
  yellow #E8D870) happen to distribute well geographically for US states since
  Natural Earth record order roughly follows regional groupings.
- **D-02:** **Matched states turn grey (#AAAAAA)** — direct port of Flags'
  `_matchedColor` constant. `UsaMapPainter` accepts a `matchedPostals: Set<String>`
  constructor parameter so Phase 4 can pass live session state without touching
  the painter.
- **D-03:** **Washington D.C. (`isPlaceable: false`) uses the same palette color
  as any other state** — treated as a normal map polygon by the painter. It
  is never a tray token or drop target, but it fills the mid-Atlantic gap without
  any visual distinction from placeable states.
- **D-04:** **Thin border rectangles around the AK and HI inset groups** — drawn
  in the painter around the bounding box of each inset region (as required by
  Roadmap Criterion 3). The exact rect is derived from the JSON's inset-group
  state bounding boxes.
- **D-05:** **Painter color constants** (Flags defaults, direct port):
  - Ocean background: `#A8D5E8`
  - State borders: `#555555`
  - Matched state fill: `#AAAAAA`

### Screen Architecture
- **D-06:** **Two separate screens: `SpikeMapScreen` (dev-only) and `MapScreen`
  (production).** After Criteria 1–2 pass, `SpikeMapScreen` is deleted (or
  hidden behind `--dart-define=SPIKE=true`). This keeps the spike's test harness
  separate from production rendering code. Phase 4 extends `MapScreen` directly.
- **D-07:** **The spike uses real state bounding boxes from the JSON** (not abstract
  hardcoded rects). The 5+ named `DragTarget` regions use actual state bounding
  box coords; the AK and HI inset rects are derived from states where
  `insetGroup == InsetGroup.alaska` and `insetGroup == InsetGroup.hawaii`.
  This tests real map geometry, not stand-ins.
- **D-08:** **"Golden tests" for Criterion 2 = unit tests of `stateHitTest()`
  with known centroid inputs** — NOT Flutter screenshot golden files. Port Flags'
  `hitTest()` to `stateHitTest(scenePoint, states, {double scale})`. Parametric
  unit tests assert `stateHitTest(state.centroid, states, scale: 1.0) == state.postal`
  and `stateHitTest(state.centroid, states, scale: 4.0) == state.postal` for each
  NE micro-state (RI, DE, CT, NJ, MD). Hermetic, no image files, fast CI.
- **D-09:** **`MapScreen` interface for Phase 4 handoff:**
  `MapScreen({matchedPostals: Set<String>, showLabels: bool, mode: GameMode?})`
  Phase 4 passes live session state from `GameSessionNotifier`. The painter is
  stateless and driven entirely by these parameters.

### Zoom Range & Controls
- **D-10:** **Min zoom = fit-to-width (computed at layout time), max zoom = 4×
  relative to fit-to-width.** The fit-to-width factor ensures the map always fills
  the viewport at minimum zoom; 4× matches Roadmap Criterion 2's test scale and
  is enough to clearly see RI/DE (~50×40 scene-units at 4× ≈ 200 screen-pixels tall).
- **D-11:** **Zoom buttons use 1.5× per press** (direct port from Flags spike).
  From fit-to-width: three taps reach ~3.4× (close enough to 4× for playtesting).
  **Pinch-to-zoom enabled** (InteractiveViewer default, clamped to the same
  min/max bounds as the buttons). Children expect pinch; disabling it would feel
  broken.

### Painter viewScale Architecture
- **D-12:** **`AnimatedBuilder` on `TransformationController` drives painter
  rebuilds.** Wrap `CustomPaint` in `AnimatedBuilder(animation: _controller,
  builder: (_, __) => CustomPaint(painter: UsaMapPainter(..., viewScale: _controller.value.getMaxScaleOnAxis())))`.
  This is the Flags approach: only the painter subtree rebuilds on each transform
  change, not the whole widget. `TransformationController` is already a `Listenable`.
- **D-13:** **Border width formula: `strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2)`**
  (Flags formula, direct port). At 1×: ~1px; at 4×: 0.25px (clamped above 0.15px).
  Borders never visually swamp Rhode Island or Delaware at high zoom.

### Claude's Discretion
- Exact `shouldRepaint` logic for `UsaMapPainter` — researcher/planner choose
  the minimal set of fields to compare (matchedPostals set equality, showLabels,
  mode, viewScale delta threshold).
- Exact inset frame rect geometry (the tight bounding box of the inset-group
  states, plus a small padding constant — e.g. 5–8 scene units).
- Routing: how `SpikeMapScreen` is registered (debug-only route or
  `--dart-define` flag) — planner decides.
- The `stateHitTest()` function signature, exactly mirroring Flags' `hitTest()`
  but with `StateData` instead of `CountryData`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specs (this repo)
- `.planning/ROADMAP.md` §"Phase 3: Map Render + Coordinate Transform Spike" —
  goal + 4 success criteria (the verification target). Criteria 1–2 are the spike
  gate; Criteria 3–4 are the production rendering gate.
- `.planning/REQUIREMENTS.md` — Phase 3 requirements: MAP-01, MAP-02, MAP-03, MAP-04.
- `.planning/PROJECT.md` — core value ("smooth, forgiving, rewarding above all"),
  Context § (reference codebase path, baseline architecture).
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-01/02 (Albers projection,
  per-landmass conic insets baked in pipeline), D-07/08 (AK/HI inset layout,
  ~0.45× AK scale, lower-left ocean overlay), D-03/04 (D.C. as non-placeable
  filler, 51 records = 50 placeable + DC).
- `CLAUDE.md` — locked stack/versions, "What NOT to Use", Map Data Pipeline
  section (pre-processed JSON, not runtime SVG).

### Existing Phase 1 Code (this repo — extend, don't rewrite)
- `lib/features/map/usa_map_painter.dart` — Phase 1 blank stub; Phase 3 replaces
  `paint()` body with real fill+border+inset rendering.
- `lib/features/map/map_screen.dart` — Phase 1 non-interactive placeholder;
  Phase 3 replaces with `InteractiveViewer` + `AnimatedBuilder` architecture.
- `lib/core/models/state_data.dart` — production schema: `postal`, `name`,
  `paths`, `centroid`, `boundingBox`, `isPlaceable`, `insetGroup`. All fields
  the painter and hit-test need are present.
- `lib/core/data/state_data_service.dart` — provides `stateDataProvider`
  (`FutureProvider<List<StateData>>`); `MapScreen` already watches this.

### Reference Codebase (Flags Around the World — port directly)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\world_map_painter.dart` —
  direct port template: 6-color palette, fill pass, border pass (viewScale-aware
  strokeWidth), `shouldRepaint` logic. Replace `CountryData` → `StateData`,
  `isoCode` → `postal`, `matchedIsoCodes` → `matchedPostals`; drop degenerate-dot
  pass (US states are never degenerate); add inset frame rect drawing.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\spike_map_screen.dart` —
  port template: `TransformationController`, 5 abstract regions → real state
  bboxes, `_toSceneFromGlobal()`, `_hitTest()`, zoom buttons (1.5× factor). AK/HI
  inset rects derived from `InsetGroup` states instead of hardcoded.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\hit_detection.dart` —
  port to `stateHitTest(scenePoint, states, {scale})`. Adapting: `CountryData`
  → `StateData`, `isoCode` → `postal`, remove `isDegenerate` branch (not
  applicable for US states; use bbox-area-based expansion for micro-states via
  the `_kMinScreenArea` path, which already handles US micro-state RI/DE/etc).
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` — study
  for `AnimatedBuilder` + `TransformationController` integration pattern if used
  in Flags production.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`StateData`** (`lib/core/models/state_data.dart`): production-ready schema
  with `paths` (dart:ui Path list), `centroid` (Offset), `boundingBox` (BoundingBox
  → Rect), `insetGroup` (nullable enum, alaska/hawaii/null). All Phase 3 rendering
  and hit-testing is driven from this model.
- **`stateDataProvider`** (`lib/core/data/state_data_service.dart`): already
  wired and proven end-to-end in Phase 1. `MapScreen` watches it via Riverpod.
- **Flags `WorldMapPainter`**: 190-line direct port template. Fill pass, border
  pass (viewScale strokeWidth), label pass (skip for Phase 3 — labels are Phase 4
  MODE-01/03 concern). Replaces Flags' `CountryData` references with `StateData`.
- **Flags `SpikeMapScreen`**: 181-line port template. `toScene()` + `hitTest()`
  + zoom buttons fully working. Only change: abstract regions → real state bboxes.
- **Flags `hit_detection.dart`**: `hitTest()` port to `stateHitTest()`. 3-pass
  algorithm (exact path → expanded bbox → centroid tiebreaker) already handles
  micro-state proximity expansion via `_kMinScreenArea`.
- **`GameMode` enum** (`lib/features/game/game_mode.dart`): available for the
  `MapScreen(mode: GameMode?)` parameter in Phase 4 prep (import already exists
  in lib/features/game/).

### Established Patterns
- Riverpod 3.x + codegen; `stateDataProvider` is `FutureProvider<List<StateData>>`;
  `MapScreen` is a `ConsumerWidget` watching it.
- Feature-first layout: map code under `lib/features/map/`, hit detection as a
  pure-Dart file (no Flutter imports) so it's unit-testable without a widget harness.
- `AnimatedBuilder` on `TransformationController` (Flags pattern for viewScale)
  — wraps only the `CustomPaint` subtree, not the whole screen.

### Integration Points
- `MapScreen` replaces the Phase 1 placeholder at the `/play` route (registered
  in `lib/app.dart` plan 01-04).
- `GameMode` enum (`lib/features/game/`) is the Phase 4 handoff parameter — Phase 3
  declares it in `MapScreen`'s constructor; Phase 4 passes the live session mode.
- `matchedPostals: Set<String>` — Phase 3 initializes empty `{}` in the screen
  for display; Phase 4 passes `session.matchedPostals` from `GameSessionNotifier`.

</code_context>

<specifics>
## Specific Ideas

- The "all-recommended" decisions in this phase reflect a deliberate strategy:
  Phase 3 is the riskiest technical phase (coordinate transforms + hit detection
  gate Phase 4). Staying close to the proven Flags patterns minimizes new unknowns
  so the spike can pass quickly.
- Micro-state hit test: the `_kMinScreenArea` path in Flags' `_expandedBbox()`
  already handles RI/DE/CT/NJ/MD expansion correctly without the `isDegenerate`
  flag — this is the right path for US states even though they aren't degenerate
  (they have real geometry that's just very small on screen).
- The `SpikeMapScreen` using real JSON bounding boxes means Criterion 1 is testing
  actual map geometry from day one, not abstract proxies. The spike passes
  only when the coordinate transform works on real data.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 3 scope.

Label rendering (on-map abbreviations scaling with viewScale) is Mode 1/3
concern from Phase 4 (MODE-01, MODE-03). Phase 3's painter renders fill + borders
+ inset frames only; `showLabels` parameter is declared but draws nothing until
Phase 4 wires in the label pass.

</deferred>

---

*Phase: 3-Map Render + Coordinate Transform Spike*
*Context gathered: 2026-05-31*
