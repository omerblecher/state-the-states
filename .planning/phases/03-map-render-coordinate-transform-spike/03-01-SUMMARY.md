---
phase: 03-map-render-coordinate-transform-spike
plan: 01
subsystem: map
tags: [dart, flutter, riverpod, hit-detection, state-data, map-data, inset-frames]

# Dependency graph
requires:
  - phase: 02-data-pipeline
    provides: usa_states_paths.json with insetFrames top-level key and states array

provides:
  - MapData value class (states + insetFrameRects) in state_data_service.dart
  - FutureProvider<MapData> stateDataProvider replacing FutureProvider<List<StateData>>
  - hit_detection.dart with pure-Dart stateHitTest() — no Flutter dependency

affects:
  - 03-02 (UsaMapPainter uses MapData.insetFrameRects for AK/HI inset borders)
  - 03-03 (MapScreen reads stateDataProvider as MapData)
  - 03-04 (SpikeMapScreen hit-test loop calls stateHitTest)
  - 03-05 (Coordinate-transform spike tests verify stateHitTest at scale)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dart record return type ({List<Map<String,dynamic>> states, List<Map<String,dynamic>> frames}) from compute() isolate"
    - "MapData wrapper bundles both states list and insetFrameRects in one FutureProvider value"
    - "hit_detection.dart is pure-Dart (dart:math + dart:ui only) — unit-testable without widget harness"
    - "insetFrames JSON order (alaska first, hawaii second) preserved as Rect order in insetFrameRects"

key-files:
  created:
    - lib/features/map/hit_detection.dart
  modified:
    - lib/core/data/state_data_service.dart
    - lib/features/map/map_screen.dart
    - test/core/data/state_data_service_test.dart

key-decisions:
  - "Drop max() from hit_detection.dart imports — only used in removed isDegenerate branch; dropping avoids lint warning"
  - "Remove dart:ui redundant import from state_data_service.dart — Rect already provided by flutter/services.dart"
  - "insetFrameRects order guaranteed by JSON Map<String,dynamic>.values insertion order (alaska, hawaii)"

patterns-established:
  - "MapData: wrapper pattern for FutureProvider returning multiple related datasets"
  - "hit_detection.dart: pure-Dart module pattern — dart:ui imports only; no flutter/material.dart"

requirements-completed: [MAP-01, MAP-02]

# Metrics
duration: 15min
completed: 2026-05-31
---

# Phase 3 Plan 01: Map Data Contracts Summary

**MapData wrapper with stateDataProvider<MapData> and pure-Dart stateHitTest() 3-pass algorithm — the data contracts all subsequent Phase 3 plans depend on**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-31T19:15:00Z
- **Completed:** 2026-05-31T19:32:57Z
- **Tasks:** 2
- **Files modified:** 4 (1 created)

## Accomplishments

- Added `MapData` value class bundling 51 `StateData` records and 2 `Rect` inset frames (alaska, hawaii)
- Changed `stateDataProvider` from `FutureProvider<List<StateData>>` to `FutureProvider<MapData>`; `_decodeJson` now returns a Dart record with both `states` and `frames` from the background isolate
- Created `lib/features/map/hit_detection.dart` as a pure-Dart file (no Flutter imports) with `stateHitTest()` — a direct port of Flags' `hitTest()` with `CountryData→StateData`, `isoCode→postal`, and the `isDegenerate` branch removed
- All 3 `state_data_service_test.dart` tests pass including new test for 2 inset frame rects; `flutter analyze lib/` and `dart analyze hit_detection.dart` both clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend StateDataService to expose MapData** - `5ace2c5` (feat)
2. **Task 2: Create hit_detection.dart — pure-Dart stateHitTest() port** - `c73b766` (feat)

**Plan metadata:** _(pending final commit)_

## Files Created/Modified

- `lib/core/data/state_data_service.dart` — Added `MapData` class; `_decodeJson` returns record; `loadMapData()` returns `Future<MapData>`; `stateDataProvider` is `FutureProvider<MapData>`
- `lib/features/map/hit_detection.dart` — New pure-Dart file; `stateHitTest(Offset, List<StateData>, {double scale})` 3-pass algorithm; all helpers underscore-prefixed
- `lib/features/map/map_screen.dart` — Updated `data` callback from `states =>` to `mapData =>`, passes `mapData.states` to `UsaMapPainter`
- `test/core/data/state_data_service_test.dart` — Updated to read `.states` from `MapData`; added inset frame rects test

## Decisions Made

- Dropped `max` from `dart:math` imports in `hit_detection.dart` — `max` was only used in the removed `isDegenerate` branch; keeping it would cause an unused-import lint warning
- Removed `import 'dart:ui' show Rect;` from `state_data_service.dart` — `flutter/services.dart` already re-exports `Rect`, making the explicit `dart:ui` import redundant (lint: `unnecessary_import`)
- `insetFrameRects` order guaranteed by JSON `Map.values` insertion order matching the JSON key order (`alaska` before `hawaii`)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated map_screen.dart data callback for MapData type change**
- **Found during:** Task 1 (after changing stateDataProvider return type)
- **Issue:** `map_screen.dart` passed `states` (now typed `MapData`) directly to `UsaMapPainter(states: states)` where `UsaMapPainter` still expects `List<StateData>` — type mismatch would cause compile error
- **Fix:** Changed `data: (states) => CustomPaint(painter: UsaMapPainter(states: states))` to `data: (mapData) => CustomPaint(painter: UsaMapPainter(states: mapData.states))`
- **Files modified:** `lib/features/map/map_screen.dart`
- **Verification:** `flutter analyze lib/` — No issues found
- **Committed in:** `5ace2c5` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking type mismatch)
**Impact on plan:** Auto-fix necessary for correct compilation. No scope creep — single-line change to Phase 1 stub screen.

## Issues Encountered

None beyond the blocking deviation above.

## Known Stubs

None in files modified by this plan. `hit_detection.dart` is fully functional. `map_screen.dart` remains a Phase 1 stub but its stub nature is intentional and pre-existing.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. `hit_detection.dart` is a pure computation module. `MapData` reads from the same bundled JSON asset already analyzed in the threat model (T-03-01, T-03-02 — both accepted).

## Next Phase Readiness

- `MapData` contract is established — Plans 03-02 through 03-05 can import `stateDataProvider` and get both states and insetFrameRects
- `stateHitTest()` is ready for the hit-detection test suite in Plan 03-05
- No blockers; all verification criteria met

---

*Phase: 03-map-render-coordinate-transform-spike*
*Completed: 2026-05-31*
