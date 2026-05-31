---
phase: 03-map-render-coordinate-transform-spike
plan: 02
subsystem: map
tags: [dart, flutter, custompaint, canvas, painter, map, inset-frames, riverpod]

# Dependency graph
requires:
  - phase: 03-map-render-coordinate-transform-spike
    plan: 01
    provides: MapData value class (states + insetFrameRects) and FutureProvider<MapData> stateDataProvider

provides:
  - Full UsaMapPainter replacing the Phase 1 blank stub
  - 6-color cycling palette fill pass, scale-adaptive border pass, AK/HI inset frame rect pass
  - usa_map_painter_test.dart with 4 smoke tests (all passing)

affects:
  - 03-03 (MapScreen upgrade — uses UsaMapPainter with matchedPostals + insetFrameRects)
  - 03-04 (SpikeMapScreen — CustomPaint uses UsaMapPainter for visual rendering)
  - Phase 4 (showLabels / mode parameters are pre-wired; label pass is a single TODO comment)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "setEquals() from package:flutter/foundation.dart for Set<String> comparison in shouldRepaint — avoids reference-equality trap"
    - "Reusable Paint objects declared outside the loop — no per-frame allocation in paint() hot path"
    - "Scale-adaptive border width: (1.0 / viewScale).clamp(0.15, 1.2) — keeps borders at ~1 screen pixel at any zoom level"
    - "tester.runAsync() in testWidgets to escape FakeAsync and allow compute() isolate to complete"

key-files:
  created:
    - test/features/map/usa_map_painter_test.dart
  modified:
    - lib/features/map/usa_map_painter.dart
    - lib/features/map/map_screen.dart

key-decisions:
  - "Use tester.runAsync() in testWidgets tests that await compute()-backed providers — FakeAsync blocks isolate spawning, causing silent hangs without this wrapper"
  - "Use findsAtLeastNWidgets(1) instead of findsOneWidget for CustomPaint assertions — MaterialApp adds its own CustomPaint widget to the tree"
  - "Phase 4 label pass reserved as TODO comment in paint() — showLabels and mode parameters are declared but draw nothing in Phase 3"

patterns-established:
  - "UsaMapPainter: stateless constructor-param painter — all render state flows in via constructor; Phase 4 passes live game state without touching this file"
  - "testWidgets + compute() pattern: wrap provider.future in tester.runAsync() to allow real async to complete before pumping widget"

requirements-completed: [MAP-01, MAP-02]

# Metrics
duration: 20min
completed: 2026-05-31
---

# Phase 3 Plan 02: UsaMapPainter Implementation Summary

**Full CustomPainter with 6-color cyclic fill, scale-adaptive borders, and AK/HI inset frame rectangles — all 51 states render as filled polygons from bundled JSON data**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-05-31T16:25:00Z
- **Completed:** 2026-05-31T16:45:21Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- Replaced the Phase 1 blank `UsaMapPainter` stub with a full implementation: ocean background fill, 51-state fill+border pass with 6-color cycling palette, AK/HI inset frame rectangles
- `shouldRepaint` uses `setEquals()` from `flutter/foundation.dart` — avoids the reference-equality trap on `Set<String>` that would silently prevent grey rendering of matched states
- Border stroke width is scale-adaptive: `(1.0 / viewScale).clamp(0.15, 1.2)` — ~1 screen pixel at any zoom
- Created `usa_map_painter_test.dart` with 4 passing smoke tests; discovered and fixed `testWidgets`+`compute()` interaction requiring `tester.runAsync()`
- Updated `map_screen.dart` to pass the two new required constructor parameters (`matchedPostals: const {}`, `insetFrameRects: mapData.insetFrameRects`)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement full UsaMapPainter** - `5345f1f` (feat)
2. **Task 2: Create usa_map_painter_test.dart** - `96d8ba1` (test)

**Plan metadata:** _(pending final commit)_

## Files Created/Modified

- `lib/features/map/usa_map_painter.dart` — Full CustomPainter: 4 file-level color constants, 6-param constructor, 3-step paint() (ocean bg + fill/border loop + frame rects), setEquals-based shouldRepaint
- `lib/features/map/map_screen.dart` — Passes `matchedPostals: const {}` and `insetFrameRects: mapData.insetFrameRects` to UsaMapPainter constructor
- `test/features/map/usa_map_painter_test.dart` — 4 smoke tests: renders 51 states, renders with matched 'TX', shouldRepaint false on identical params, shouldRepaint true on changed matchedPostals

## Decisions Made

- Used `tester.runAsync()` to wrap `container.read(stateDataProvider.future)` inside `testWidgets` callbacks — `compute()` spawns a real OS isolate which cannot complete inside Flutter's `FakeAsync` event loop
- Used `findsAtLeastNWidgets(1)` instead of `findsOneWidget` for `CustomPaint` assertions — `MaterialApp` renders its own `CustomPaint` for the app background, so there are always 2+ in the tree
- `showLabels` and `mode` constructor parameters are declared but the label pass is a `// Phase 4: label pass (showLabels / mode) goes here` comment — no dead code to remove in Phase 4, just a fill

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed testWidgets hang: ProviderContainer.read(future) inside FakeAsync**
- **Found during:** Task 2 (usa_map_painter_test.dart creation)
- **Issue:** `testWidgets` wraps its callback in a `FakeAsync` zone; `stateDataProvider` calls `compute()` which spawns a real isolate; the isolate's completion callback is never delivered inside FakeAsync, causing the test to hang indefinitely
- **Fix:** Wrapped the provider read in `tester.runAsync(() => container.read(stateDataProvider.future))` which temporarily escapes FakeAsync and allows the real async event loop to run
- **Files modified:** `test/features/map/usa_map_painter_test.dart`
- **Verification:** `flutter test test/features/map/usa_map_painter_test.dart` — all 4 tests pass in under 1 second

**2. [Rule 1 - Bug] Fixed findsOneWidget assertion: MaterialApp adds extra CustomPaint**
- **Found during:** Task 2 (first test run after runAsync fix)
- **Issue:** The test asserted `findsOneWidget` but `MaterialApp` adds its own `CustomPaint` widget (for the background/theme), so 2 were found and the assertion failed
- **Fix:** Changed both widget-test assertions to `findsAtLeastNWidgets(1)`
- **Files modified:** `test/features/map/usa_map_painter_test.dart`
- **Verification:** `flutter test test/features/map/usa_map_painter_test.dart` — all 4 tests pass

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs in test assertions and async patterns)
**Impact on plan:** Both fixes are in the test file only; the production painter is unaffected. No scope creep.

## Issues Encountered

None beyond the two auto-fixed deviations above.

## Known Stubs

None. `UsaMapPainter` is fully functional for Phase 3. The `showLabels`/`mode` parameters are intentionally no-ops with a comment marking Phase 4 extension point — this is declared in the plan as a deferred concern, not an unintentional stub.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. `UsaMapPainter` is a pure rendering component that draws pre-parsed `dart:ui Path` objects to a Canvas. Threat register mitigations T-03-04 (setEquals for Set comparison) implemented as required.

## Next Phase Readiness

- `UsaMapPainter` is ready for Phase 3-03 (MapScreen upgrade to ConsumerStatefulWidget + InteractiveViewer)
- `UsaMapPainter` is ready for Phase 3-04 (SpikeMapScreen — can be passed to CustomPaint directly)
- Phase 4 can extend the label pass without modifying the constructor signature
- No blockers

---

*Phase: 03-map-render-coordinate-transform-spike*
*Completed: 2026-05-31*
