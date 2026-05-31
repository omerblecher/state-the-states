---
phase: 03-map-render-coordinate-transform-spike
plan: 05
subsystem: ui
tags: [flutter, riverpod, interactiveviewer, transformationcontroller, dragtarget, coordinate-transform, spike, kDebugMode]

# Dependency graph
requires:
  - phase: 03-map-render-coordinate-transform-spike
    provides: MapData + stateDataProvider (Plan 03-01), stateHitTest (Plan 03-03), MapScreen with production _zoom() (Plan 03-04)
provides:
  - SpikeMapScreen — ConsumerStatefulWidget with 6 named DragTarget regions (real state bboxes)
  - /spike route in GoRouter guarded by kDebugMode (absent from release builds)
  - 2 widget smoke tests for SpikeMapScreen
  - Criterion 1 manual validation scaffold (TX, CA, FL, NY, AK, HI at 1x/2x/4x zoom)
affects: [04-drag-drop-placement]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SpikeMapScreen: ConsumerStatefulWidget with stateDataProvider, production _zoom(), _toSceneFromGlobal(), assert(kDebugMode)"
    - "DragTarget builder uses named params (not __ double-underscores) to satisfy unnecessary_underscores lint"
    - "kDebugMode route guard: if (kDebugMode) GoRoute(...) inside routes list — Dart collection-if syntax"
    - "Fixture StateData via StateData.fromJson() with minimal path 'M0,0 L1,0 L1,1 Z' — no tester.runAsync() needed for fixture-backed tests"
    - "Positioned.fromRect() for placing named DragTarget regions at real state boundingBox.rect coordinates"

key-files:
  created:
    - lib/features/map/spike_map_screen.dart
    - test/features/map/spike_map_screen_test.dart
  modified:
    - lib/app.dart

key-decisions:
  - "03-05: Use if (kDebugMode) GoRoute(...) (single-element collection-if) not ...if (kDebugMode) [...] (spread) — GoRouter routes list accepts RouteBase, spread of List<GoRoute> triggers type error in current SDK"
  - "03-05: DragTarget builder params named (ctx, candidateData, rejectedData) not (_, __, ___) — flutter_lints 6.0 unnecessary_underscores lint fires on double+triple underscores"
  - "03-05: Fixture-backed tests do not need tester.runAsync() — overrideWith(async => fixture) resolves synchronously in FakeAsync, unlike compute()-backed real provider"

patterns-established:
  - "Pattern: Fixture StateData (no compute()) allows plain pump() x2 in widget tests — no tester.runAsync() needed"
  - "Pattern: kDebugMode collection-if in routes list uses if (kDebugMode) GoRoute(...) (no spread) for clean GoRouter typing"

requirements-completed: [MAP-03, MAP-04]

# Metrics
duration: 15min
completed: 2026-05-31
---

# Phase 3 Plan 05: SpikeMapScreen + /spike Route Summary

**SpikeMapScreen: dev-only ConsumerStatefulWidget with 6 named DragTarget regions using real state bboxes, production _zoom() with setEntry(2,2), _toSceneFromGlobal() Pitfall 6 guard, and kDebugMode-gated /spike route**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-31T17:20:00Z
- **Completed:** 2026-05-31T17:35:00Z
- **Tasks:** 2
- **Files modified:** 3 (1 new widget, 1 modified router, 1 new test)

## Accomplishments

- Created `SpikeMapScreen` (ConsumerStatefulWidget): 6 named DragTarget regions using real `StateData.boundingBox.rect` from `stateDataProvider`
- Production `_zoom()` copied exactly from `map_screen.dart` with `setEntry(2,2)` (Pitfall 1 guard)
- `_toSceneFromGlobal()` applies `globalToLocal` before `toScene()` (Pitfall 6 guard)
- `assert(kDebugMode, ...)` secondary guard in `build()` (Threat T-03-09)
- AK and HI DragTarget regions use `boundingBox.rect` directly — already in inset canvas space from pipeline
- Status bar showing last hit postal, scene coordinates, and live zoom multiplier
- Draggable chip row (6 chips, one per postal) for manual Criterion 1 validation
- `/spike` route wired in `app.dart` with `if (kDebugMode)` collection-if guard (absent from release builds)
- 2 widget smoke tests: renders without exception + zoom buttons present — all pass
- Full flutter test suite: 94 tests pass

## Task Commits

1. **Task 1: Create SpikeMapScreen** — `aa40c68` (feat)
2. **Task 2: Wire /spike route + spike smoke tests** — `0392ef0` (feat)

## Files Created/Modified

- `lib/features/map/spike_map_screen.dart` — Dev-only spike screen; ConsumerStatefulWidget; 6 named DragTarget regions; production _zoom(); _toSceneFromGlobal(); status bar; draggable chips
- `lib/app.dart` — Added `if (kDebugMode) GoRoute(path: '/spike', ...)` after /play route; added imports for kDebugMode and SpikeMapScreen
- `test/features/map/spike_map_screen_test.dart` — 2 widget tests: render smoke test + zoom button presence; fixture StateData via StateData.fromJson()

## Decisions Made

- `if (kDebugMode) GoRoute(...)` (single-element collection-if) used instead of `...if (kDebugMode) [GoRoute(...)]` — the spread form triggers a `list_element_type_not_assignable` error because `List<GoRoute>` cannot be directly spread into `List<RouteBase>` in the current SDK version. The direct collection-if form compiles cleanly.
- DragTarget builder params use named variables (`ctx, candidateData, rejectedData`) rather than `(_, __, ___)` — `flutter_lints ^6.0.0` enforces `unnecessary_underscores` lint, which fires when two or more parameters in the same scope use multi-underscore names.
- Fixture-backed spike tests do not require `tester.runAsync()` — `stateDataProvider.overrideWith((ref) async => fixture)` resolves synchronously under FakeAsync. This is the established distinction from the `compute()`-backed real provider tests in `map_screen_test.dart`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed unnecessary_underscores lint in DragTarget builders**
- **Found during:** Task 1 (dart analyze)
- **Issue:** `builder: (_, __, ___)` pattern triggers `unnecessary_underscores` lint in flutter_lints 6.0
- **Fix:** Renamed builder params to `(ctx, candidateData, rejectedData)` and `(context, _)` as appropriate
- **Files modified:** lib/features/map/spike_map_screen.dart
- **Commit:** aa40c68

**2. [Rule 1 - Bug] Fixed ...if (kDebugMode) spread syntax in routes list**
- **Found during:** Task 2 (dart analyze on app.dart)
- **Issue:** `...if (kDebugMode) [GoRoute(...)]` produces `list_element_type_not_assignable` — spreading `List<GoRoute>` into `List<RouteBase>` fails
- **Fix:** Changed to `if (kDebugMode) GoRoute(...)` (single-element collection-if, no spread)
- **Files modified:** lib/app.dart
- **Commit:** 0392ef0

## Phase 3 Completion Status

Both automated criteria are now met:
- CRITERION 2 (automated): `flutter test test/features/map/hit_detection_test.dart` — 14 tests pass (centroid assertions for RI, DE, CT, NJ, MD at 1x and 4x zoom)
- Full suite: 94 tests pass

CRITERION 1 (manual) remains: run `flutter run` in debug mode, navigate to `/spike`, drag each chip onto its colored region at 1x/2x/4x zoom — zero misidentifications = Criterion 1 passes.

## Known Stubs

None — SpikeMapScreen wires real stateDataProvider data. No placeholder text or hardcoded empty data.

## Threat Surface Scan

No new network endpoints or auth paths introduced. New surface:
- `/spike` route: protected by `if (kDebugMode)` at registration time (T-03-09 mitigated) and `assert(kDebugMode)` inside build() as secondary guard
- `DragTarget.onAcceptWithDetails.offset → stateHitTest`: protected by `_toSceneFromGlobal()` applying `globalToLocal` before `toScene()` (T-03-10 mitigated)
- `debugPrint` output: geographic coordinate data only, no PII, stripped in release builds (T-03-11 accepted)

## Self-Check

- `lib/features/map/spike_map_screen.dart` — FOUND
- `lib/app.dart` — FOUND
- `test/features/map/spike_map_screen_test.dart` — FOUND
- `aa40c68` (feat: SpikeMapScreen) — FOUND
- `0392ef0` (feat: /spike route + tests) — FOUND

## Self-Check: PASSED

---
*Phase: 03-map-render-coordinate-transform-spike*
*Completed: 2026-05-31*
