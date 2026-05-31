# Phase 3: Map Render + Coordinate Transform Spike — Research

**Researched:** 2026-05-31
**Domain:** Flutter CustomPainter map rendering, InteractiveViewer coordinate transforms, hit detection
**Confidence:** HIGH — all findings verified directly from the reference codebase (Flags Around the World), the actual bundled JSON (`usa_states_paths.json`), and existing Phase 1/2 code. No training-data-only claims in critical areas.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Map Color Design**
- D-01: Cycling 6-color palette (`palette[i % 6]` by list index). Colors: soft green `#8DB87F`, tan `#D4B483`, orange `#E8A055`, pink `#E89090`, purple `#A07EC8`, yellow `#E8D870`.
- D-02: Matched states turn grey `#AAAAAA`. `UsaMapPainter` accepts `matchedPostals: Set<String>` constructor parameter.
- D-03: D.C. (`isPlaceable: false`) uses same palette color as any other state. Never a token or drop target.
- D-04: Thin border rectangles around AK and HI inset groups, derived from JSON inset-group bounding boxes.
- D-05: Ocean background `#A8D5E8`, state borders `#555555`, matched fill `#AAAAAA`.

**Screen Architecture**
- D-06: Two separate screens: `SpikeMapScreen` (dev-only) and `MapScreen` (production). Spike is deleted or hidden behind `--dart-define=SPIKE=true` after Criteria 1–2 pass.
- D-07: Spike uses real state bounding boxes from the JSON. 5+ named `DragTarget` regions use actual state bboxes; AK/HI inset rects derived from `insetGroup == InsetGroup.alaska/hawaii`.
- D-08: "Golden tests" for Criterion 2 = unit tests of `stateHitTest()` with known centroid inputs, NOT Flutter screenshot golden files.
- D-09: `MapScreen` interface for Phase 4: `MapScreen({matchedPostals: Set<String>, showLabels: bool, mode: GameMode?})`.

**Zoom Range & Controls**
- D-10: Min zoom = fit-to-width (computed at layout time). Max zoom = 4× relative to fit-to-width.
- D-11: Zoom buttons use 1.5× per press. Pinch-to-zoom enabled, clamped to same min/max as buttons.

**Painter viewScale Architecture**
- D-12: `AnimatedBuilder` on `TransformationController` drives painter rebuilds. Wraps only `CustomPaint` subtree.
- D-13: Border width formula: `strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2)` (direct port of Flags formula).

### Claude's Discretion
- Exact `shouldRepaint` logic for `UsaMapPainter` — researcher/planner choose minimal fields to compare.
- Exact inset frame rect geometry (tight bounding box of inset-group states + small padding constant, e.g. 5–8 scene units).
- Routing: how `SpikeMapScreen` is registered (debug-only route or `--dart-define` flag).
- The `stateHitTest()` function signature, mirroring Flags' `hitTest()` but with `StateData`.

### Deferred Ideas (OUT OF SCOPE)
- Label rendering (on-map abbreviations scaling with viewScale) — Phase 4 concern (MODE-01, MODE-03).
- `showLabels` parameter is declared in Phase 3 but draws nothing until Phase 4 wires in the label pass.
- Token tray, drag-and-drop game flow, HUD, scoring display, game mode label visibility, completion screen — Phase 4.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAP-01 | The map renders a vector representation of all 50 U.S. states via CustomPainter from bundled pre-processed JSON (not runtime SVG parsing). | `UsaMapPainter.paint()` fills using `StateData.paths` (already `dart:ui Path` objects from `parseSvgPathData()` at load time). Pattern: Flags `WorldMapPainter` direct port. |
| MAP-02 | Alaska and Hawaii render inside dedicated inset frames, with inset transforms baked into canvas coordinate space by the build-time pipeline. | JSON confirms AK bbox=(0,462,250,134) and HI bbox=(255,534,130,61) are already in inset canvas space. Painter draws both using their pre-baked path coordinates. Inset frame rects from `insetFrames` key in JSON. |
| MAP-03 | The map supports high-performance pan and zoom via `InteractiveViewer`, with the token tray outside the viewer and DragTargets inside it. | `InteractiveViewer(constrained: false)` + `TransformationController` + `GlobalKey` on IV. Flags `MapScreen` is the direct template. Token tray is Phase 4; Phase 3 establishes the IV architecture. |
| MAP-04 | Explicit zoom in / zoom out buttons are available outside the `InteractiveViewer`. | `_zoom(factor)` helper (viewport-centre-anchored Matrix4 mutation) from Flags spike + production screen. Buttons are `FloatingActionButton.small` in a `Positioned` overlay outside the IV. |
</phase_requirements>

---

## Summary

Phase 3 is the highest-risk technical phase in the project — the coordinate-transform spike must pass before Phase 4 can begin, and all the rendering patterns are being proven for the first time. Fortunately, the Flags Around the World reference codebase provides near-complete port templates for every deliverable: `WorldMapPainter` → `UsaMapPainter`, `spike_map_screen.dart` → `SpikeMapScreen`, `hit_detection.dart` → `stateHitTest()`, and the production `MapScreen` IV + AnimatedBuilder architecture.

The actual `usa_states_paths.json` is present and verified. It has a 1000×628 viewBox, 51 records (50 placeable + DC), real AK/HI inset coordinates already baked into canvas space, and an `insetFrames` top-level key containing pre-computed frame rects for both groups. This eliminates the inset geometry guessing the planner might otherwise need to do — the inset frame rects can be read directly from the JSON rather than computed from state bounding boxes.

The `stateHitTest()` 3-pass algorithm from Flags handles all five NE micro-states correctly. At fit-to-width scale (~0.39×), every micro-state's on-screen bounding box area is below `_kMinScreenArea` (2304 px²), triggering centroid-based circular expansion. At 4× zoom, RI and DE still trigger expansion while CT, NJ, and MD become large enough to match via path/bbox alone. The planner must ensure the unit tests cover both zoom levels for all five states.

**Primary recommendation:** Port the four Flags reference files directly with the mechanical substitutions listed below. Do not architect new solutions for any of the core technical problems — the reference implementations are proven and the deviations from Flags for US states are small (no `isDegenerate` branch, single landmass per record, `insetGroup` instead of world-map dual-copy rendering).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| State path rendering (fills, borders) | CustomPainter / Canvas | — | Paths are `dart:ui Path` objects; only the Canvas API can draw them at frame rate. Widget layer has no path-drawing primitive. |
| Inset frame rectangles (AK/HI boxes) | CustomPainter / Canvas | — | Drawn as `canvas.drawRect()` in the same pass as fills/borders. |
| Pan & zoom interaction | InteractiveViewer (Flutter widget) | TransformationController | IV handles gesture recognition and matrix accumulation; controller exposes the matrix for read-back. |
| Coordinate transform (global → scene) | TransformationController.toScene() | RenderBox.globalToLocal() | The two-step conversion: RenderBox converts global → IV-local, then toScene() applies the inverse transform. Must happen in the IV's RenderBox context, not the full widget tree. |
| Hit detection logic | Pure-Dart function (`stateHitTest`) | — | No Flutter imports — testable without widget harness. Takes scene point + states list; returns postal string or null. |
| Scale-adaptive border width | CustomPainter / Canvas | TransformationController | `viewScale` passed to painter via `AnimatedBuilder` listener. Border is a Canvas stroke, not a widget border. |
| Zoom button behavior | StatefulWidget (MapScreen state) | FloatingActionButton | Programmatic `_zoom()` mutates `_controller.value` directly (Matrix4). Must update entry (2,2) = entry (0,0) to keep `getMaxScaleOnAxis()` accurate. |
| Spike route registration | go_router (app.dart) | — | A `/spike` route in debug mode; Phase 4 deletes or gates it. |
| Fit-to-width initialization | StatefulWidget.initState / postFrameCallback | RenderBox | Must run after layout (layout needed to know viewport size). Uses `WidgetsBinding.addPostFrameCallback`. |

---

## Standard Stack

Phase 3 adds **no new packages** beyond what is already in `pubspec.yaml`. All needed capabilities are provided by the locked stack.

### Core (already in pubspec.yaml)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter` SDK | >=3.44.0 | `InteractiveViewer`, `TransformationController`, `CustomPainter`, `Matrix4` | Core framework — all map rendering primitives are built-in. |
| `flutter_riverpod` | ^3.3.1 | `stateDataProvider` (FutureProvider) watching in `MapScreen` (ConsumerStatefulWidget) | Established pattern; Phase 3 extends Phase 1 provider. |
| `path_drawing` | ^1.0.1 | `parseSvgPathData()` converts bundled path strings to `dart:ui Path` at load time | Already called in `StateData.fromJson()`; Phase 3 painter uses the pre-built Path objects. |
| `flutter/foundation` | SDK | `setEquals()` for `shouldRepaint` Set comparison | Built-in; imported in Flags `WorldMapPainter`. |
| `go_router` | ^17.2.3 | Spike route registration at `/spike` | Already wired in `app.dart`. |

### No New Packages Required
[VERIFIED: direct codebase inspection] All capabilities needed for Phase 3 — coordinate transforms, CustomPainter, InteractiveViewer, Matrix4 math, DragTarget, FloatingActionButton — are part of the Flutter SDK already locked in pubspec.yaml. The spike and production map require zero new dependencies.

## Package Legitimacy Audit

> Phase 3 installs NO new external packages. This section confirms that finding.

| Package | Registry | Status |
|---------|----------|--------|
| (none) | — | No new packages added in Phase 3. |

**Packages removed due to slopcheck:** none
**Packages flagged as suspicious:** none

---

## Architecture Patterns

### System Architecture Diagram

```
usa_states_paths.json (asset)
        |
        v
StateDataService.loadMapData()   [compute isolate: JSON decode]
        |                        [main thread: parseSvgPathData()]
        v
stateDataProvider (FutureProvider<List<StateData>>)
        |
        +---> MapScreen (ConsumerStatefulWidget)
        |        |
        |        +-- TransformationController (_controller)
        |        |        |
        |        |        +-- AnimatedBuilder
        |        |               |
        |        |               v
        |        |         UsaMapPainter(states, matchedPostals,
        |        |                       viewScale=controller.getMaxScaleOnAxis())
        |        |                       --> canvas fill pass (all 51 records)
        |        |                       --> canvas border pass (strokeWidth=1/viewScale)
        |        |                       --> canvas inset frame rects (AK, HI)
        |        |
        |        +-- InteractiveViewer (key=_ivKey, constrained:false)
        |        |        |
        |        |        +-- SizedBox(1000x628)  [scene space]
        |        |               |
        |        |               +-- CustomPaint(UsaMapPainter)
        |        |               +-- DragTarget [Phase 4 wires this]
        |        |
        |        +-- Positioned zoom buttons (outside IV)
        |
        +---> SpikeMapScreen (StatefulWidget — dev-only)
                 |
                 +-- TransformationController (_controller)
                 +-- InteractiveViewer (key=_ivKey, constrained:false)
                 |        |
                 |        +-- SizedBox(1000x628)
                 |               +-- 5 named DragTarget regions (real state bboxes)
                 |               +-- outer DragTarget (catch-all)
                 |
                 +-- _toSceneFromGlobal(globalOffset)
                 |        = _controller.toScene(
                 |            _ivKey.currentContext.findRenderObject().globalToLocal(globalOffset))
                 |
                 +-- Zoom buttons (1.5x factor, same _zoom() helper)

stateHitTest(scenePoint, states, {scale}) [pure Dart, lib/features/map/hit_detection.dart]
        |
        +-- Pass 1: exact path.contains(scenePoint) -> candidates
        +-- Pass 2: _expandedBbox(scale) contains scenePoint -> candidates
        +-- Pass 3 (fallback): expanded bbox all states -> pool
        +-- Tiebreaker: closest effective centroid wins
                        (_kMinScreenArea expansion for RI/DE/CT/NJ/MD)
```

### Recommended Project Structure (Phase 3 adds to existing)

```
lib/
├── app.dart                    # Add /spike route (debug-only)
├── features/
│   └── map/
│       ├── map_screen.dart         # REPLACE Phase 1 stub with IV+AnimatedBuilder
│       ├── usa_map_painter.dart    # FILL paint() body; add constructor params
│       ├── spike_map_screen.dart   # NEW — dev-only spike screen
│       └── hit_detection.dart      # NEW — stateHitTest() pure Dart
test/
└── features/
    └── map/
        ├── hit_detection_test.dart  # NEW — 10 centroid assertions (5 states × 2 scales)
        └── spike_map_screen_test.dart  # NEW — widget test zoom button scale assertions
```

---

### Pattern 1: `_toSceneFromGlobal()` — Global-to-Scene Coordinate Transform

**What:** Converts a pointer/drop global position (from `DragTarget.onAcceptWithDetails.details.offset`) to scene coordinates in the `InteractiveViewer`'s child space.

**Why critical:** `details.offset` is in global screen coordinates. `toScene()` expects IV-local coordinates. Missing the `globalToLocal()` step causes systematic offset errors that grow with widget position on screen. This is the exact pitfall the spike validates.

**Source:** [VERIFIED: direct read `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\spike_map_screen.dart` line 37–39 and `map_screen.dart` line 437–441]

```dart
// Source: Flags spike_map_screen.dart lines 37-39 (exact port)
Offset _toSceneFromGlobal(Offset globalOffset) {
  final box = _ivKey.currentContext!.findRenderObject()! as RenderBox;
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```

**Production variant (nullable guard):**
```dart
// Source: Flags map_screen.dart lines 437-441 (production pattern)
Offset? _toSceneFromGlobal(Offset globalOffset) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```

---

### Pattern 2: `_zoom()` — Viewport-Centre-Anchored Programmatic Zoom

**What:** Zooms the `TransformationController` by a factor while keeping the viewport centre fixed. Critically sets Matrix4 entry (2,2) = entry (0,0) so `getMaxScaleOnAxis()` returns the correct 2-D scale.

**Why critical:** Without syncing entry (2,2), `getMaxScaleOnAxis()` reads the untouched Z-axis value (1.0 at init) after scale goes below 1×, then pressing "+" causes a wild jump. This is documented in the Flags production `map_screen.dart` inline comment. [VERIFIED: direct read `map_screen.dart` line 421–425]

```dart
// Source: Flags map_screen.dart lines 406-428 (production _zoom — USE THIS, not the spike version)
void _zoom(double factor) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  final double cx = box.size.width / 2;
  final double cy = box.size.height / 2;

  final Matrix4 m = _controller.value.clone();
  final double currentScale = m.getMaxScaleOnAxis();
  final double newScale = (currentScale * factor).clamp(minScale, maxScale);
  final double actualFactor = newScale / currentScale;
  if ((actualFactor - 1.0).abs() < 1e-6) return;

  final double tx = m.entry(0, 3);
  final double ty = m.entry(1, 3);
  m.setEntry(0, 0, newScale);
  m.setEntry(1, 1, newScale);
  m.setEntry(2, 2, newScale);  // CRITICAL: keeps getMaxScaleOnAxis() accurate
  m.setEntry(0, 3, cx + (tx - cx) * actualFactor);
  m.setEntry(1, 3, cy + (ty - cy) * actualFactor);
  _controller.value = m;
}
```

**Note:** The spike's `_zoom()` omits the `m.setEntry(2, 2, newScale)` line. Use the **production** version from `map_screen.dart` for both screens.

---

### Pattern 3: `AnimatedBuilder` + `TransformationController` for Scale-Reactive Painter

**What:** Wraps only the `CustomPaint` subtree in `AnimatedBuilder(animation: _controller, ...)` so it rebuilds on every transform change without rebuilding the whole widget tree.

**Why standard:** `TransformationController` extends `ValueNotifier<Matrix4>`, which extends `Listenable` — compatible with `AnimatedBuilder` directly. No explicit `addListener`/`removeListener` needed. Only the `viewScale` parameter changes per frame; rebuilding the whole `MapScreen` would be wasteful. [VERIFIED: Flags map_screen.dart lines 817-830]

```dart
// Source: Flags map_screen.dart (adapted) — Phase 3 uses SizedBox(1000, 628) not (4000, 1000)
AnimatedBuilder(
  animation: _controller,
  builder: (_, __) => CustomPaint(
    isComplex: true,
    painter: UsaMapPainter(
      states: states,
      matchedPostals: _matchedPostals,
      showLabels: _showLabels,
      viewScale: _controller.value.getMaxScaleOnAxis(),
    ),
    size: const Size(1000, 628),  // matches viewBox from JSON
  ),
),
```

---

### Pattern 4: Fit-to-Width Initialization

**What:** On first frame after layout, set `_controller.value` to a Matrix4 that scales the 1000×628 scene to fill the viewport width (or height, whichever is binding), centered. Called via `WidgetsBinding.addPostFrameCallback`.

**Why:** Before `_fitMapToScreen()` runs, the map renders at 1:1 scale (1000 scene units wide), which is far too large for any phone. The user would see a tiny cropped corner. Phase 3 must establish the same "loading screen stays up until first paint is correct" pattern from Flags. [VERIFIED: Flags map_screen.dart lines 251-267]

```dart
// Source: Flags map_screen.dart lines 251-267 (adapted for 1000x628 viewBox)
void _fitMapToScreen() {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  const mapW = 1000.0;  // viewBox.width from JSON
  const mapH = 628.0;   // viewBox.height from JSON
  final scale = math.min(box.size.width / mapW, box.size.height / mapH)
      .clamp(0.08, 1.0);
  final tx = (box.size.width - mapW * scale) / 2;
  final ty = (box.size.height - mapH * scale) / 2;
  final m = Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(2, 2, scale)  // CRITICAL: keep in sync
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
  _controller.value = m;
}
```

On a 390px-wide phone, fit-to-width scale ≈ 0.39×. Max zoom = 0.39 × 4 = 1.56×. [VERIFIED: computed from actual JSON viewBox 1000×628]

---

### Pattern 5: `UsaMapPainter.paint()` — Fill + Border Pass

**What:** Two-pass approach: fill all state polygons, then draw all borders. For Phase 3, the degenerate-dot pass from Flags is omitted (US states are never degenerate). Inset frame rectangles drawn as a third step.

**Source:** [VERIFIED: direct read `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\world_map_painter.dart`]

```dart
// Source: WorldMapPainter._drawWorldCopy() — adapted for UsaMapPainter.paint()
@override
void paint(Canvas canvas, Size size) {
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _oceanColor);

  final fillPaint = Paint()..style = PaintingStyle.fill;
  final borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = _borderColor
    ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);

  // Pass 1: fills + borders (no isDegenerate branch for US states)
  for (int i = 0; i < states.length; i++) {
    final state = states[i];
    final isMatched = matchedPostals.contains(state.postal);
    fillPaint.color = isMatched ? _matchedColor : _palette[i % _palette.length];
    for (final path in state.paths) {
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  // Pass 2: inset frame rectangles
  final framePaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = _borderColor
    ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);
  for (final frameRect in insetFrameRects) {
    canvas.drawRect(frameRect, framePaint);
  }
}
```

**Note on inset frame rects:** The JSON's top-level `insetFrames` key provides exact frame rects already: alaska `{x:0, y:462.38, w:250, h:134.24}` and hawaii `{x:255, y:533.88, w:130, h:61.24}`. These can be read from the JSON at `StateDataService` load time and passed directly to `UsaMapPainter` rather than computed from state bounding boxes. This is a simpler approach than deriving them from inset-group state bboxes.

---

### Pattern 6: `stateHitTest()` — 3-Pass Algorithm

**What:** Port of Flags `hitTest()` with `CountryData` → `StateData`, `isoCode` → `postal`, and `isDegenerate` branch removed. The `_kMinScreenArea` expansion path handles all five NE micro-states (RI, DE, CT, NJ, MD) without the degenerate flag.

**Source:** [VERIFIED: direct read `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\hit_detection.dart`]

**Key behavioral insight from computed data:**
- At fit-to-width (~0.39×): all 5 micro-states are below `_kMinScreenArea = 2304 px²` — all get centroid-based circular expansion.
- At 4× zoom from fit (scale = 1.56×): RI (area=771 px²) and DE (area=1634 px²) still expand; CT (2562), NJ (3635), MD (9093) are large enough to match normally.
- Expansion radius at scale s = `sqrt(2304 / π) / s` ≈ `27.1 / s` scene units (e.g. 17.4 scene-units at 4× fit).

[VERIFIED: computed from actual JSON bounding box data]

```dart
// Source: Flags hit_detection.dart (adapted — remove isDegenerate branch)
String? stateHitTest(Offset scenePoint, List<StateData> states,
    {double scale = 1.0}) {
  final minSceneDiag = _kMinScreenDiagonal / scale;

  final candidates = states
      .where((s) => _primaryContains(s, scenePoint, minSceneDiag, scale: scale))
      .toList();

  final pool = candidates.isNotEmpty
      ? candidates
      : states
          .where((s) => _expandedBbox(s, minSceneDiag, scale: scale).contains(scenePoint))
          .toList();

  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.postal;

  pool.sort((a, b) {
    final aDist = (_effectiveCentroid(a, scenePoint) - scenePoint).distanceSquared;
    final bDist = (_effectiveCentroid(b, scenePoint) - scenePoint).distanceSquared;
    return aDist.compareTo(bDist);
  });

  return pool.first.postal;
}

Rect _expandedBbox(StateData state, double minSceneDiag, {double scale = 1.0}) {
  final rect = state.boundingBox.rect;
  final screenArea = rect.width * rect.height * scale * scale;
  if (screenArea < _kMinScreenArea) {
    // Circular expansion to guarantee 48dp tap target
    final expansionRadius = sqrt(_kMinScreenArea / pi) / scale;
    return Rect.fromCenter(
      center: state.centroid,
      width: expansionRadius * 2,
      height: expansionRadius * 2,
    );
  }
  final diagonal = sqrt(rect.width * rect.width + rect.height * rect.height);
  if (diagonal >= minSceneDiag) return rect;
  final scaleFactor = minSceneDiag / diagonal;
  return Rect.fromCenter(
    center: state.centroid,
    width: rect.width * scaleFactor,
    height: rect.height * scaleFactor,
  );
}
// NOTE: No isDegenerate branch — US states are never degenerate.
// NOTE: effectiveCentroid still uses polygon bbox center for exact-path hits.
```

---

### Pattern 7: `shouldRepaint` for `UsaMapPainter`

**What:** Minimal comparison to avoid spurious repaints. Flags uses `setEquals` for the Set, identity check for the names map, and scalar equality for the others. [VERIFIED: Flags world_map_painter.dart lines 42-46]

**Recommendation (Claude's Discretion):**

```dart
// Adapted from Flags WorldMapPainter.shouldRepaint (lines 42-46)
@override
bool shouldRepaint(UsaMapPainter old) =>
    !setEquals(old.matchedPostals, matchedPostals) ||
    old.showLabels != showLabels ||
    old.mode != mode ||
    (old.viewScale - viewScale).abs() > 0.001;  // threshold avoids sub-pixel thrash
```

`setEquals` is from `package:flutter/foundation.dart` — already an implicit dependency. A delta threshold on `viewScale` (0.001) avoids repainting when scale changes by a fraction of a pixel — cosmetic for the border width formula at any practical scale.

---

### Pattern 8: Inset Frame Rect Source

**What:** The `insetFrames` key in `usa_states_paths.json` provides ready-made frame rects. Pass them to the painter as a `List<Rect>`.

**Source:** [VERIFIED: direct inspection of `assets/map/usa_states_paths.json`]

```
insetFrames.alaska: {x:0.0, y:462.38, w:250.0, h:134.24}
insetFrames.hawaii: {x:255.0, y:533.88, w:130.0, h:61.24}
```

These are the exact rects Phase 3 should draw. Two implementation options:
1. **Read from JSON at load time:** `StateDataService` returns a small `MapData` wrapper containing `states` + `insetFrames`. Passes `List<Rect> insetFrameRects` to `UsaMapPainter`.
2. **Derive at runtime:** Filter states by `insetGroup`, union their bboxes, add padding. More code, same result — the JSON approach is simpler and already computed.

**Recommendation (Claude's Discretion):** Add an `insetFrameRects` parameter to `UsaMapPainter`. Populate from the `insetFrames` JSON key in `StateDataService`. The planner chooses whether to return a `(List<StateData>, List<Rect>)` tuple or a thin wrapper class from `stateDataProvider`.

---

### Pattern 9: SpikeMapScreen Region Selection

**What:** D-07 says the 5+ named regions must use real state bounding boxes. Suggested region choices:

| Region | Postal | BBox (scene) | Rationale |
|--------|--------|-------------|-----------|
| Texas | TX | (293.9, 358.3, 268.2, 261.3) | Large central state — easy baseline |
| California | CA | (0.0, 155.7, 154.2, 262.4) | Large western state |
| Florida | FL | (683.7, 479.1, 174.0, 148.8) | Large eastern |
| New York | NY | (796.8, 111.3, 145.7, 109.7) | Northeast anchor |
| Alaska (inset) | AK | (0.0, 462.4, 250.0, 134.2) | AK inset region |
| Hawaii (inset) | HI | (255.0, 533.9, 130.0, 61.2) | HI inset region |

This gives 6 regions covering mainland + both insets, satisfying Criterion 1's "including simulated AK/HI inset rects." [VERIFIED: coords from actual JSON]

---

### Pattern 10: SpikeMapScreen Routing Decision

**Claude's Discretion — two valid approaches:**

| Approach | Implementation | Tradeoff |
|----------|---------------|----------|
| Debug-only route | `if (kDebugMode) GoRoute(path: '/spike', ...)` in `app.dart` | Simple; no build flag needed; spike is always accessible in debug, always absent in release. Matches Flags' `kDebugMode` guard pattern (used in `MapScreen` for the skip-to-end FAB). |
| `--dart-define=SPIKE=true` | `const bool _kSpikeEnabled = bool.fromEnvironment('SPIKE'); if (_kSpikeEnabled) GoRoute(...)` | Allows enabling spike in release build for QA; extra complexity not needed here. |

**Recommendation:** Use `kDebugMode` guard (same pattern as Flags). The spike is a developer tool; it should never appear in a release build regardless of runtime flags.

---

### Anti-Patterns to Avoid

- **Using the spike `_zoom()` instead of the production `_zoom()`:** The spike version (Flags `spike_map_screen.dart` line 64) does NOT set `m.setEntry(2, 2, newScale)`. Use the production version from `map_screen.dart` for both screens — it fixes the `getMaxScaleOnAxis()` bug. [VERIFIED: Flags map_screen.dart line 421-425]
- **Hardcoding viewBox dimensions:** The actual JSON viewBox is 1000×628, not 1000×620 (CLAUDE.md example) or 2000×1000 (Flags). Use 1000×628 everywhere. [VERIFIED: JSON inspection]
- **Computing inset frame rects from state bboxes:** The JSON already provides `insetFrames` with exact rects. Use those directly.
- **Adding any `isDegenerate` branch to `stateHitTest()`:** US states have real geometry; none are degenerate. The `_kMinScreenArea` path already handles small-on-screen states correctly.
- **Calling `_fitMapToScreen()` before layout completes:** Must be inside `WidgetsBinding.addPostFrameCallback`. Calling it in `initState()` gives `box == null`.
- **Attaching `AnimatedBuilder` to the whole `Scaffold`:** Only wrap the `CustomPaint` subtree. Wrapping the Scaffold rebuilds the entire widget tree (including zoom buttons, Riverpod watches, etc.) on every frame during pan/zoom.
- **Loading JSON fields under the key `'countries'`:** The `StateDataService` correctly reads `data['states']`. Do not regress this — it's documented as Pitfall 7 in the service file.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scene coordinate conversion | Custom matrix math | `TransformationController.toScene()` + `RenderBox.globalToLocal()` | The Flags pattern is a 2-line, proven implementation. Rolling your own matrix inverse will have precision errors. |
| Micro-state tap target expansion | Custom radius lookup | `_kMinScreenArea` path in `_expandedBbox()` (Flags hit_detection.dart) | Covers all 5 micro-states at any zoom via a single formula; no per-state configuration needed. |
| Zoom matrix mutation | Custom translate+scale | `_zoom(factor)` from Flags production `map_screen.dart` | Viewport-center anchoring and entry (2,2) sync are non-obvious; Flags has already solved the bug. |
| Fit-to-width calculation | Custom projection fitting | `_fitMapToScreen()` from Flags production `map_screen.dart` | min(width/mapW, height/mapH) pattern with `WidgetsBinding.addPostFrameCallback` is the correct approach. |
| Inset frame rects | Computing from state bboxes | Read `insetFrames` from JSON directly | The Python pipeline already computed and serialized the exact rects; re-deriving at runtime is redundant. |

**Key insight:** The Flags codebase already solved every hard problem in this phase. The value of Phase 3 is proving the coordinate-transform assumptions hold for a 1000×628 US-map scene, not inventing new solutions.

---

## Common Pitfalls

### Pitfall 1: Missing `m.setEntry(2, 2, newScale)` in Zoom
**What goes wrong:** `getMaxScaleOnAxis()` reads the maximum of all three diagonal entries. At init, (2,2) = 1.0. If (0,0) and (1,1) go below 1.0 (zooming out), then (2,2) is still 1.0, so `getMaxScaleOnAxis()` returns 1.0 instead of the actual 2-D scale. Pressing "+" then computes `factor = newScale / 1.0 = newScale`, jumping to an unexpected zoom level.
**Why it happens:** The Flags spike version omits this sync. Only the production `map_screen.dart` version includes it.
**How to avoid:** Always use the production `_zoom()` template. Test: after programmatic zoom out to 0.5×, `_controller.value.getMaxScaleOnAxis()` must equal 0.5, not 1.0.
**Warning signs:** Zoom button behavior feels erratic after zooming all the way out; visual scale and reported scale mismatch.
[VERIFIED: Flags map_screen.dart inline comment, line 421-425]

### Pitfall 2: Calling `_fitMapToScreen()` Too Early
**What goes wrong:** `_ivKey.currentContext?.findRenderObject()` returns `null` before the widget tree is laid out. The controller stays at the default identity matrix (1:1 scale), rendering the map 1000 scene-units wide — far too large.
**Why it happens:** `initState()` runs before layout; the RenderBox is not yet attached.
**How to avoid:** Always call `_fitMapToScreen()` inside `WidgetsBinding.addPostFrameCallback`. The Flags production pattern calls it in two places: after sequence init and after tutorial dismissed. Use the same pattern.
**Warning signs:** Map appears as a tiny sliver in the top-left corner on first load.

### Pitfall 3: Wrong ViewBox Dimensions
**What goes wrong:** Using 1000×620, 1000×625, or 2000×1000 as the scene size instead of the actual 1000×628. The `SizedBox` child of `InteractiveViewer` must match the actual scene dimensions, or the ocean background leaves a gap at the bottom.
**Why it happens:** CLAUDE.md suggests "~620–625"; the Flags world map uses 2000×1000. The actual generated JSON has viewBox.height = 628.
**How to avoid:** Use 628.0 — the exact value from the JSON's `viewBox.height` field. [VERIFIED: JSON inspection]
**Warning signs:** Ocean background ends before the inset frames; HI bbox bottom (y=595) clips against the canvas edge.

### Pitfall 4: `stateHitTest()` Regression on Micro-States at 4× Zoom
**What goes wrong:** At 4× zoom from fit (effective scale ≈ 1.56), RI and DE are still below `_kMinScreenArea`. If the `_expandedBbox()` expansion is accidentally removed or the scale parameter is not passed, drops near RI and DE fail to register.
**Why it happens:** The `scale` parameter is easy to forget or hardcode to 1.0.
**How to avoid:** The unit tests in `hit_detection_test.dart` cover `scale: 4.0` for all five micro-states. If any of the 10 assertions fail, this bug is present.
**Warning signs:** Drops at the centroid of RI or DE return `null` at 4× zoom in the spike screen.

### Pitfall 5: `shouldRepaint` Using Reference Equality on `Set<String>`
**What goes wrong:** If `shouldRepaint` uses `old.matchedPostals == matchedPostals` (reference equality), the painter never repaints when matched states change — because the parent rebuilds the painter with a new Set object every time, but reference equality always returns false for different Set instances.
**Why it happens:** Common Flutter mistake — `==` on collections compares identity, not content.
**How to avoid:** Use `setEquals(old.matchedPostals, matchedPostals)` from `package:flutter/foundation.dart`. Flags uses this pattern. [VERIFIED: Flags world_map_painter.dart line 43]
**Warning signs:** States that were placed (should turn grey) remain their original color.

### Pitfall 6: `DragTarget` Inside `InteractiveViewer` Missing Correct Offset
**What goes wrong:** `details.offset` in `onAcceptWithDetails` is the **global** position, not the IV-local position. Passing it directly to `toScene()` returns incorrect scene coordinates.
**Why it happens:** The Flutter `DragTarget.onAcceptWithDetails` API provides global coordinates.
**How to avoid:** The two-step conversion: `box.globalToLocal(details.offset)` then `_controller.toScene(...)`. This is what `_toSceneFromGlobal()` does. Spike verifies this works at all zoom levels.
**Warning signs:** Hit test fails at regions near the edges of the screen but works near the center.

### Pitfall 7: `insetFrameRects` Not Passed to Painter
**What goes wrong:** Painter draws no inset frame rectangles. Roadmap Criterion 3 requires them.
**Why it happens:** `UsaMapPainter` starts as a blank stub — easy to forget to add the parameter.
**How to avoid:** Add `required this.insetFrameRects` to `UsaMapPainter` constructor. Source from JSON `insetFrames` key.
**Warning signs:** No border rectangles around AK/HI groups at any zoom level.

---

## Runtime State Inventory

Phase 3 is a greenfield feature addition (no rename or refactor). No runtime state inventory required.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All map rendering | ✓ (Phase 1 confirmed) | >=3.44.0 | — |
| Dart SDK | All Dart code | ✓ (Phase 1 confirmed) | >=3.10.0 | — |
| `usa_states_paths.json` | StateDataProvider, SpikeMapScreen, hit tests | ✓ | 51 records, viewBox 1000×628, insetFrames present | — |
| `flutter_test` SDK | Unit tests, widget tests | ✓ (pubspec.yaml) | SDK | — |
| `mocktail` | Mocking in tests | ✓ (pubspec.yaml, ^1.0.5) | 1.0.5 | — |
| `path_drawing` | `parseSvgPathData()` in StateData.fromJson | ✓ (pubspec.yaml, ^1.0.1) | 1.0.1 | — |

**Missing dependencies with no fallback:** None.
**All required dependencies are present and confirmed.**

---

## Validation Architecture

> `workflow.nyquist_validation` is true in `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) |
| Config file | None (standard Flutter test runner) |
| Quick run command | `flutter test test/features/map/hit_detection_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MAP-01 | All 50 state paths render as filled polygons from bundled JSON | Widget (smoke) | `flutter test test/features/map/usa_map_painter_test.dart` | No — Wave 0 |
| MAP-02 | AK in bottom-left inset, HI in bottom-center; inset frame rects drawn | Widget (smoke) + manual visual | `flutter test test/features/map/usa_map_painter_test.dart` | No — Wave 0 |
| MAP-03 | `InteractiveViewer` pan/zoom wired; DragTarget inside IV | Widget | `flutter test test/features/map/map_screen_test.dart` | No — Wave 0 |
| MAP-04 | Zoom buttons change scale by 1.5×; `getMaxScaleOnAxis()` matches visual scale | Widget | `flutter test test/features/map/map_screen_test.dart` | No — Wave 0 |
| Criterion 1 | SpikeMapScreen identifies drop target at 1×, 2×, 4× zoom (zero misidentifications) | Widget + manual | `flutter test test/features/map/spike_map_screen_test.dart` | No — Wave 0 |
| Criterion 2 | `stateHitTest()` at centroid of RI, DE, CT, NJ, MD at scale 1.0 and 4.0 = correct postal | Unit | `flutter test test/features/map/hit_detection_test.dart` | No — Wave 0 |
| Criterion 4 | After `_zoom(1.5)`, `_controller.value.getMaxScaleOnAxis()` = prev × 1.5 | Unit/Widget | `flutter test test/features/map/map_screen_test.dart` | No — Wave 0 |

### Testable Dimensions and Required Test Types

**Dimension 1: Coordinate Transform Accuracy (Criterion 1 — HARD GATE)**
- Type: Widget test with `WidgetTester` + `pumpWidget`
- Approach: Create a `SpikeMapScreen`, pump it, programmatically set controller to known zoom matrices (1×, 2×, 4× fit-to-width), then verify `_toSceneFromGlobal()` converts known global positions to the expected scene bboxes.
- Edge cases REQUIRED before Phase 4:
  - At 1× (identity matrix): offset passes through unchanged.
  - At 2× zoom with non-zero translation: translation offset is correctly subtracted.
  - At 4× zoom: same correctness requirement.
  - With controller at non-centred pan: point in top-left of IV maps to correct scene point.

**Dimension 2: `stateHitTest()` Accuracy — Micro-States (Criterion 2 — HARD GATE)**
- Type: Unit tests — pure Dart, no widget harness, fast.
- 10 mandatory assertions:
  ```
  stateHitTest(ri.centroid, states, scale: 1.0) == 'RI'
  stateHitTest(ri.centroid, states, scale: 4.0) == 'RI'
  stateHitTest(de.centroid, states, scale: 1.0) == 'DE'
  stateHitTest(de.centroid, states, scale: 4.0) == 'DE'
  stateHitTest(ct.centroid, states, scale: 1.0) == 'CT'
  stateHitTest(ct.centroid, states, scale: 4.0) == 'CT'
  stateHitTest(nj.centroid, states, scale: 1.0) == 'NJ'
  stateHitTest(nj.centroid, states, scale: 4.0) == 'NJ'
  stateHitTest(md.centroid, states, scale: 1.0) == 'MD'
  stateHitTest(md.centroid, states, scale: 4.0) == 'MD'
  ```
- Context: tests run in isolation using the StateData list built from test fixtures (same minimal JSON pattern used in `state_data_test.dart`), not the full JSON asset. This keeps tests hermetic and fast.
- Edge cases REQUIRED:
  - RI centroid at scale 1.0 (below _kMinScreenArea, expansion active): must return 'RI' despite no path.contains() hit.
  - DE centroid at scale 4.0 (still below _kMinScreenArea): must return 'DE'.
  - CT centroid at scale 4.0 (above _kMinScreenArea): must return 'CT' via normal path/bbox.
  - A point in the ocean (far from any state): must return null.

**Dimension 3: Painter Rendering (Criterion 3 — visual)**
- Type: Widget smoke test (verify no exception thrown) + manual visual inspection.
- Automated: Pump `UsaMapPainter` with 51 real StateData objects; assert no exception and `CustomPaint` renders to a non-zero size.
- Manual: Visual check in app — AK bottom-left with frame, HI bottom-center with frame, all states have palette colors, matched states turn grey.
- Note: Flutter golden-file tests for `CustomPainter` are brittle across devices — the decision (D-08) correctly specifies unit tests for hit detection, not screenshot goldens.

**Dimension 4: Zoom Button Scale Accuracy (Criterion 4)**
- Type: Widget test.
- Approach: Pump `MapScreen`, pump to first frame, get initial scale from `_controller.value.getMaxScaleOnAxis()`. Press zoom-in button once. Assert new scale = old × 1.5 (within floating-point tolerance 1e-6). Assert `getMaxScaleOnAxis()` == `_controller.value.entry(0, 0)` (entry (2,2) sync).
- Edge case REQUIRED: zoom out to min, then zoom in — `getMaxScaleOnAxis()` must return correct value throughout (tests the entry (2,2) sync fix).

### Sampling Rate
- **Per task commit:** `flutter test test/features/map/hit_detection_test.dart` (< 5 seconds)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`. Criteria 1 and 2 verified manually in the spike screen before Phase 4 begins.

### Wave 0 Gaps (must create before implementation)
- [ ] `test/features/map/hit_detection_test.dart` — 10 centroid assertions + ocean null + expansion edge cases (Criteria 2 HARD GATE)
- [ ] `test/features/map/usa_map_painter_test.dart` — smoke: painter renders without exception (MAP-01, MAP-02)
- [ ] `test/features/map/map_screen_test.dart` — zoom button 1.5× assertion + getMaxScaleOnAxis() sync (MAP-03, MAP-04, Criterion 4)
- [ ] `test/features/map/spike_map_screen_test.dart` — coordinate transform at 1×/2×/4× (Criterion 1 HARD GATE)

---

## Code Examples

### Full `stateHitTest()` Signature
```dart
// Source: Flags hit_detection.dart line 35 (adapted)
// Location: lib/features/map/hit_detection.dart
// No Flutter imports — pure Dart, unit-testable without widget harness
import 'dart:math' show max, sqrt, pi;
import 'dart:ui' show Offset, Rect;
import '../../core/models/state_data.dart';

const double _kMinScreenDiagonal = 40.0;
const double _kMinScreenArea = 2304.0;

String? stateHitTest(
  Offset scenePoint,
  List<StateData> states, {
  double scale = 1.0,
}) { ... }
```

### `UsaMapPainter` Constructor (Phase 3 target)
```dart
// Adapted from Flags WorldMapPainter (world_map_painter.dart lines 26-38)
class UsaMapPainter extends CustomPainter {
  const UsaMapPainter({
    required this.states,
    required this.matchedPostals,
    required this.insetFrameRects,  // from JSON insetFrames key
    this.showLabels = false,         // declared now, used in Phase 4
    this.mode,
    this.viewScale = 1.0,
  });

  final List<StateData> states;
  final Set<String> matchedPostals;
  final List<Rect> insetFrameRects;
  final bool showLabels;
  final GameMode? mode;
  final double viewScale;
  ...
}
```

### `MapScreen` Constructor (Phase 4 handoff interface — D-09)
```dart
// Declares Phase 4 parameters now so Phase 4 just fills them in
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    this.matchedPostals = const {},
    this.showLabels = false,
    this.mode,
  });

  final Set<String> matchedPostals;
  final bool showLabels;
  final GameMode? mode;
  ...
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flags world map: 2000×1000 px scene, dual-copy for date-line wrap | State States: 1000×628 px scene (single copy, Albers projection, no wrap needed) | Phase 1 pipeline decision | All IV geometry, fit-to-width, and inset frame coordinates are based on 1000×628, not 2000×1000. |
| Flags: `isDegenerate` branch for micro-state dot rendering | State States: no degenerate states; `_kMinScreenArea` expansion handles small states | Phase 3 adaptation | Simpler `_expandedBbox()` function; no dot-drawing pass in painter. |
| Flags: `isoCode`, `matchedIsoCodes`, `countryNames` map | State States: `postal`, `matchedPostals`, no separate name map (name bundled in `StateData.name`) | Phase 1 schema | Rename propagates through painter, hit detection, session notifier. |
| Flags: dual-world-copy paint (`_drawWorldCopy` × 2) | State States: single `paint()` — mainland + inset transforms baked in JSON | Phase 1 pipeline | Simpler painter; no translation needed; inset states paint at their baked scene coordinates. |

**Deprecated/outdated:**
- Phase 1 `UsaMapPainter` blank stub: completely replaced in Phase 3.
- Phase 1 `MapScreen` `ConsumerWidget`: replaced with `ConsumerStatefulWidget` for `TransformationController` lifecycle.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `_zoom()` missing `m.setEntry(2,2, newScale)` in the Flags spike file is an intentional omission in the spike (less code) that was fixed in production `map_screen.dart` | Pitfall 1 / Pattern 2 | If wrong, the production pattern also has the bug — but direct reading of `map_screen.dart` line 421 confirms `setEntry(2,2,newScale)` is present there. [VERIFIED via source read] |
| A2 | The fit-to-width scale of ~0.39 is representative; actual phones vary from 360px to 430px wide | Pattern 4 / Validation | Actual min/max scale bounds clamped to (0.08, 4× fit) make this robust across phone widths; the exact fit-to-width value is computed at runtime from the actual viewport. Low risk. |

**Both assumptions are supported by code reads. The log is nearly empty — all critical claims are VERIFIED.**

---

## Open Questions

1. **`stateDataProvider` return type: does it need to expose `insetFrames`?**
   - What we know: `stateDataProvider` currently returns `List<StateData>`. The JSON has a top-level `insetFrames` key. `UsaMapPainter` needs the frame rects.
   - What's unclear: Whether to (a) return a wrapper class `{states, insetFrameRects}` from the provider, (b) add a separate `insetFramesProvider`, or (c) embed the inset rects as a static constant derived from the known JSON values.
   - Recommendation: The planner chooses. Option (c) is simplest — the inset rects are stable constants derived from the pipeline; hard-coding `Rect.fromLTWH(0, 462.38, 250.0, 134.24)` and `Rect.fromLTWH(255, 533.88, 130.0, 61.24)` in `UsaMapPainter` as constants avoids the provider change. If the JSON ever changes, the pipeline would regenerate and these constants would need updating. However this is a valid trade-off for v1 simplicity. Using the JSON key is the "correct" approach but requires a provider API change.

2. **SpikeMapScreen widget test: how to pump with real `StateData` objects?**
   - What we know: Widget tests can call `tester.pumpWidget()` but `path_drawing.parseSvgPathData()` requires `dart:ui`, which works in flutter_test. The spike loads states via `stateDataProvider`.
   - What's unclear: Whether to mock `stateDataProvider` with a small set of known states, or use the real JSON asset via `rootBundle` (which requires `flutter test` with asset mocking).
   - Recommendation: Mock `stateDataProvider` with 6 hand-crafted `StateData` fixtures (TX, CA, FL, NY, AK, HI) using `ProviderContainer` override. This is the established pattern in Phase 2 tests. The 10 centroid unit tests in `hit_detection_test.dart` use all 51 real states (loaded from actual JSON) since they're pure Dart and can read the file directly.

---

## Project Constraints (from CLAUDE.md)

All the following directives apply to Phase 3 work:

| Directive | Impact on Phase 3 |
|-----------|------------------|
| No Firebase anywhere | No impact — Phase 3 has no network or analytics. |
| No `flutter_map` | No impact — using `CustomPainter` + `InteractiveViewer`. |
| No runtime SVG parsing for map | `UsaMapPainter` uses pre-built `dart:ui Path` objects from `StateData.paths`. Do not add any SVG parsing call in Phase 3 code. |
| No `audioplayers` | No impact — Phase 3 has no audio. |
| `just_audio` for all audio | No impact — Phase 3 has no audio. |
| `InteractiveViewer` + `CustomPainter` | This IS the Phase 3 architecture. |
| `shared_preferences` for persistence | No impact — Phase 3 has no persistence changes. |
| COPPA: no persistent identifiers | No impact — Phase 3 code is stateless rendering logic. |
| App ID `com.otis.brooke.state.the.state` | No impact on Phase 3 code. |
| Baseline architecture from Flags | Phase 3 ports four Flags files directly — fully compliant. |

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED] `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\world_map_painter.dart` — `WorldMapPainter` pattern (fill pass, border pass, palette, `shouldRepaint`, `strokeWidth` formula)
- [VERIFIED] `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\spike_map_screen.dart` — spike template (`_toSceneFromGlobal`, `_hitTest`, `_zoom` spike version, zoom buttons)
- [VERIFIED] `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\hit_detection.dart` — full `hitTest()` algorithm (`_kMinScreenArea`, `_expandedBbox`, `_effectiveCentroid`, 3-pass structure)
- [VERIFIED] `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` — production `_zoom()` (entry 2,2 fix), `_fitMapToScreen()`, `AnimatedBuilder`, `_toSceneFromGlobal()` nullable variant
- [VERIFIED] `C:\code\Claude\StateTheStates\assets\map\usa_states_paths.json` — viewBox 1000×628, 51 records, insetFrames keys with exact rects, NE micro-state bboxes and centroids
- [VERIFIED] `C:\code\Claude\StateTheStates\lib\core\models\state_data.dart` — `StateData` schema, `InsetGroup` enum, `BoundingBox`, `isPlaceable`
- [VERIFIED] `C:\code\Claude\StateTheStates\lib\core\data\state_data_service.dart` — `stateDataProvider` (FutureProvider<List<StateData>>), `StateDataService`
- [VERIFIED] `C:\code\Claude\StateTheStates\lib\features\map\usa_map_painter.dart` — Phase 1 blank stub (extent of what Phase 3 fills)
- [VERIFIED] `C:\code\Claude\StateTheStates\lib\features\map\map_screen.dart` — Phase 1 `ConsumerWidget` placeholder (Phase 3 replaces with `ConsumerStatefulWidget`)
- [VERIFIED] `C:\code\Claude\StateTheStates\lib\app.dart` — current route registration (`/play` → `MapScreen`)
- [VERIFIED] `C:\code\Claude\StateTheStates\pubspec.yaml` — locked dependencies (all Phase 3 needs are present)
- [VERIFIED] `C:\code\Claude\StateTheStates\.planning\config.json` — `nyquist_validation: true`

### Secondary (MEDIUM confidence)
- Computed values: fit-to-width scale ~0.39, micro-state screen areas at 1× and 4× zoom — derived programmatically from actual JSON data.

### Tertiary (LOW confidence)
- None in this research.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all libraries already in pubspec.yaml
- Architecture patterns: HIGH — all patterns verified from direct Flags source reads
- Canvas/transform specifics: HIGH — entry (2,2) sync verified from inline comment in production code
- JSON data dimensions: HIGH — directly inspected `usa_states_paths.json`
- Hit detection behavior: HIGH — algorithm read from source + expansion computed from real data
- Pitfalls: HIGH — most pitfalls verified from inline comments or test structure in Flags

**Research date:** 2026-05-31
**Valid until:** 2026-09-30 (stable Flutter SDK APIs; `TransformationController` and `InteractiveViewer` APIs are stable and unlikely to change in a minor Flutter version)
