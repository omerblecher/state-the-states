---
phase: 01-foundation
plan: "03"
subsystem: dart-data-layer
tags: [dart, riverpod, model, compute-isolate, custompaint, state-data]
dependency_graph:
  requires:
    - plan 01-01 (Flutter scaffold + pubspec: flutter_riverpod, path_drawing)
    - plan 01-02 (assets/map/usa_states_paths.json — the data file consumed here)
  provides:
    - StateData model (postal/name/isPlaceable/insetGroup + parseSvgPathData), BoundingBox, InsetGroup enum
    - StateDataService compute-isolate loader + stateDataProvider (FutureProvider)
    - Blank-canvas MapScreen (ConsumerWidget) + UsaMapPainter (CustomPainter)
  affects:
    - plan 01-04 (app.dart registers /play → MapScreen; HomeScreen can import stateDataProvider)
    - Phase 3 (real map rendering replaces the blank UsaMapPainter; hit detection consumes StateData)
tech_stack:
  added: []
  patterns:
    - Flags CountryData → StateData (isoCode→postal, +name/isPlaceable/insetGroup, −isDegenerate)
    - Flags CountryDataService compute-isolate loader (rootBundle.loadString + compute(_decodeJson))
    - Riverpod top-level FutureProvider (no codegen, per project convention)
    - JSON key is 'states' not 'countries' (Pitfall 7)
    - AsyncValue.when loading/error/data in ConsumerWidget
key_files:
  created:
    - lib/core/models/state_data.dart
    - lib/core/data/state_data_service.dart
    - lib/features/map/map_screen.dart
    - lib/features/map/usa_map_painter.dart
    - test/core/models/state_data_test.dart
    - test/core/data/state_data_service_test.dart
  modified: []
decisions:
  - "D-03 confirmed: DC parsed as isPlaceable:false; provider resolves 51 records / 50 placeable"
  - "D-08 confirmed: insetGroup enum (alaska/hawaii); real AK centroid asserted inside the alaska inset frame"
  - "Pitfall 7 confirmed: _decodeJson reads data['states']; loadCountryNames/countryNamesProvider dropped (names bundled in JSON)"
  - "isDegenerate field dropped — US state geometry is never degenerate (PATTERNS delta)"
  - "Phase 1 MapScreen/UsaMapPainter are an intentional blank-canvas end-to-end proof; real rendering is Phase 3"
metrics:
  duration_minutes: 8
  completed_date: "2026-05-31T06:05:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 6
  files_modified: 0
requirements_satisfied: [DATA-01, DATA-02]
execution_note: "Executed inline by the orchestrator. The first background executor agent dispatch returned an immediate Bash-permission denial (no tool calls), so per the workflow's inline-fallback contract the orchestrator executed the plan directly with atomic per-task commits."
---

# Phase 1 Plan 3: Dart Data Layer Summary

**One-liner:** The Dart side of DATA-01/DATA-02 — a `StateData` value model (`postal`/`name`/`isPlaceable`/`insetGroup` + `parseSvgPathData`), a `StateDataService` compute-isolate loader exposed as `stateDataProvider`, and a blank-canvas `MapScreen`/`UsaMapPainter` that proves the JSON → isolate → provider → painter pipeline wires end-to-end without crashing.

## What Was Built

1. **`lib/core/models/state_data.dart`** — `BoundingBox` (verbatim from Flags), `enum InsetGroup { alaska, hawaii }`, and `class StateData` ported from Flags `CountryData`: `isoCode`→`postal`, added `name` (full state name from JSON), `isPlaceable` (defaults true; DC false per D-03), `insetGroup` (AK/HI per D-08). `fromJson` calls `parseSvgPathData` per path string and `_parseInsetGroup` maps the string to the enum. The Flags `isDegenerate` field is intentionally dropped.

2. **`lib/core/data/state_data_service.dart`** — `StateDataService.loadMapData()` loads `assets/map/usa_states_paths.json`, decodes off-thread via `compute(_decodeJson)`, builds `StateData` on the main thread yielding `Future.delayed(Duration.zero)` every 30 items. `_decodeJson` reads `data['states']` (Pitfall 7 — not `'countries'`). Top-level `stateDataProvider = FutureProvider<List<StateData>>(...)`. Flags' `loadCountryNames`/`countryNamesProvider` removed (names are bundled in the JSON).

3. **`lib/features/map/usa_map_painter.dart`** — `UsaMapPainter extends CustomPainter` taking `List<StateData> states`, empty `paint`, `shouldRepaint => false`. The Phase 1 end-to-end proof, not the real renderer (Phase 3).

4. **`lib/features/map/map_screen.dart`** — `MapScreen extends ConsumerWidget` watches `stateDataProvider` and renders `AsyncValue.when`: loading → `CircularProgressIndicator`, error → message, data → `CustomPaint(painter: UsaMapPainter(states: states), child: SizedBox.expand())`.

5. **Tests** — `test/core/models/state_data_test.dart` (8 tests: fromJson field parsing, isPlaceable default, DC non-placeable, AK/HI/mainland insetGroup, BoundingBox round-trip, and `testAlaskaCentroidInset` loading the real JSON and asserting the AK centroid lies inside `insetFrames['alaska']`). `test/core/data/state_data_service_test.dart` (2 tests: provider resolves 51 records / 50 placeable; DC non-placeable). All 10 pass.

## Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | StateData model + test | `056d44e` | lib/core/models/state_data.dart, test/core/models/state_data_test.dart |
| 2 | StateDataService + provider + test | `d49952a` | lib/core/data/state_data_service.dart, test/core/data/state_data_service_test.dart |
| 3 | Blank MapScreen + UsaMapPainter | `1099e82` | lib/features/map/map_screen.dart, lib/features/map/usa_map_painter.dart |

## Deviations from Plan

**1. [Orchestrator inline execution] Plan executed inline, not by a worktree subagent**
- **Found during:** Wave 2 dispatch
- **Issue:** The first background `gsd-executor` agent dispatched for 01-03 returned after a single step reporting it had no Bash access (a hard permission denial, distinct from 01-02's test-file commit block), doing no work and creating no worktree.
- **Fix:** Per the workflow's inline-fallback contract for unreliable Agent dispatch, the orchestrator executed the plan directly on `main` with atomic per-task commits and the same verify gates. No worktree merge was needed.
- **Files modified:** none beyond the plan's declared files.

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| Empty `UsaMapPainter.paint` | `lib/features/map/usa_map_painter.dart` | Blank canvas by design; real fills/borders/insets/labels are Phase 3. |
| Minimal `MapScreen` (no InteractiveViewer/HUD/tray/drag) | `lib/features/map/map_screen.dart` | Phase 1 proves pipeline wiring only; the interactive drag-drop map is Phase 3. The `/play` route is registered in 01-04. |

## Threat Flags

- T-03-01 (DoS on malformed JSON): compute-isolate decode + `AsyncValue.error` branch surface failures instead of crashing; service test round-trips the real asset — MITIGATED
- T-03-02 (wrong 'countries' key): `_decodeJson` reads `data['states']`; service test asserts 51 resolved records — MITIGATED
- T-03-03 (info disclosure): N/A — bundled build-time asset, no network/PII — ACCEPTED

## Self-Check: PASSED

Files verified:
- `lib/core/models/state_data.dart`: FOUND (class StateData, enum InsetGroup, no isDegenerate)
- `lib/core/data/state_data_service.dart`: FOUND (FutureProvider, data['states'], no loadCountryNames)
- `lib/features/map/map_screen.dart`: FOUND (ConsumerWidget, CustomPaint, AsyncValue.when)
- `lib/features/map/usa_map_painter.dart`: FOUND (CustomPainter, empty paint)
- `test/core/models/state_data_test.dart` + `test/core/data/state_data_service_test.dart`: FOUND

Checks verified:
- `flutter analyze`: No issues found
- `flutter test test/core/`: 10 passed
