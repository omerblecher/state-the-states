---
phase: 05-polish-welcome-accessibility
plan: 05
subsystem: ui
tags: [flutter, animation, matrix4, timer, custom-painter, hint, accessibility]

# Dependency graph
requires:
  - phase: 05-02
    provides: [audio fade interface — fadeInAnthem/fadeOutAnthem]
  - phase: 04-01
    provides: [GameSessionNotifier.useHint() returning bool with +5 penalty]
  - phase: 04-02
    provides: [MapScreen TransformationController, _fitMapToScreen Matrix4 pattern]
  - phase: 03-02
    provides: [UsaMapPainter CustomPainter base with shouldRepaint pattern]

provides:
  - "UsaMapPainter.hintPostal: String? parameter with yellow-green 0xFFBBFF44 glow in paint()"
  - "MapScreen _hintZoomController AnimationController driving Matrix4Tween zoom at 2.5x"
  - "_computeHintMatrix() centering target state centroid with setEntry(2,2) guard"
  - "_onHintPressed() wiring useHint() → animation → 3s glow Timer"
  - "_hintGlowTimer cancelled in dispose() (T-05-10 mitigation)"

affects: [map, game, 05-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AnimationController + Matrix4Tween + CurvedAnimation → TransformationController.value pattern for map zoom"
    - "dart:async Timer for 3s glow window (same pattern as RealAudioService fade)"
    - "Listener-based animation tick: _hintZoomController.addListener(_onHintZoomTick)"
    - "setEntry(2,2,newScale) in every Matrix4 construction — Pitfall 1 established invariant"
    - "hintGlowTimer?.cancel() in dispose() before _controller.dispose() — T-05-10 pattern"

key-files:
  modified:
    - lib/features/map/usa_map_painter.dart
    - lib/features/map/map_screen.dart
    - test/features/map/usa_map_painter_test.dart

key-decisions:
  - "Curves.easeInOut chosen for Matrix4Tween (Claude's discretion per RESEARCH.md §Pattern 4)"
  - "cast<StateData?>().firstWhere orElse pattern used instead of collection.firstWhereOrNull — collection is only a transitive dep not declared in pubspec.yaml"
  - "Hint glow drawn as Step 5 in paint() — AFTER label pass — so glow overlays labels when active"
  - "_hintGlowTimer cancelled before _hintZoomController in dispose() — matches RESEARCH.md Pitfall 4 ordering"

patterns-established:
  - "Pattern: AnimationController listener drives TransformationController.value (not addListener on animation object)"
  - "Pattern: Timer? _glowTimer used for timed UI state; always cancelled in dispose() before parent controller"

requirements-completed: [HINT-01, HINT-02]

# Metrics
duration: 10min
completed: 2026-06-01
---

# Phase 5 Plan 5: Hint Zoom Animation and Glow — Summary

**AnimationController-driven Matrix4Tween zoom to target state centroid at 2.5x, with 3-second yellow-green (0xFFBBFF44) glow via UsaMapPainter.hintPostal**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-01T15:23:00Z
- **Completed:** 2026-06-01T15:26:54Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `hintPostal: String?` to `UsaMapPainter` with shouldRepaint guard and yellow-green fill step in paint()
- Wired `_hintZoomController` (400ms `AnimationController`) in `MapScreen` driving `Matrix4Tween` via listener
- Implemented `_computeHintMatrix()` with mandatory `setEntry(2,2,newScale)` guard (Pitfall 1 / T-05-12)
- `_hintGlowTimer` cancelled in `dispose()` before controller disposes (T-05-10 / RESEARCH.md Pitfall 4)
- All 12 existing map_screen_test and 7 usa_map_painter_test tests pass with 3 new hintPostal glow tests added

## Task Commits

Each task was committed atomically:

1. **Task 1: Add hintPostal parameter to UsaMapPainter with yellow-green glow pass** - `7166f0b` (feat)
2. **Task 2: Wire hint animation in MapScreen** - `9136043` (feat)

**Plan metadata:** see final commit below

## Files Created/Modified

- `lib/features/map/usa_map_painter.dart` — Added `hintPostal: String?` constructor param, field, shouldRepaint guard, paint() Step 5 glow
- `lib/features/map/map_screen.dart` — Added dart:async import, 4 new fields, updated initState/dispose, added _onHintZoomTick/_computeHintMatrix/_onHintPressed, wired painter + button
- `test/features/map/usa_map_painter_test.dart` — Added `hintPostal glow` test group (3 tests: shouldRepaint detection × 2, widget smoke test)

## Decisions Made

1. **cast<StateData?>().firstWhere**: `collection.firstWhereOrNull` not used because `collection` is only a transitive dependency not declared in pubspec.yaml; cast pattern is equivalent and safe.
2. **Curves.easeInOut**: chosen for the Matrix4Tween (RESEARCH.md lists this as Claude's discretion).
3. **Glow drawn after labels (Step 5)**: ensures hint highlight is visually on top of postal abbreviations — more legible for users.
4. **Timer cancel order in dispose()**: `_hintGlowTimer?.cancel()` fires before `_hintZoomController.removeListener()` and `_hintZoomController.dispose()` — follows RESEARCH.md Pitfall 4 pattern.

## Deviations from Plan

None — plan executed exactly as written. The only minor adaptation was using the cast pattern instead of `firstWhereOrNull` for the `collection` package availability reason above, which matches the alternative noted in the plan's Task 1 action block.

## Known Stubs

None — hint zoom and glow are fully implemented. `useHint()` already deducts the +5 penalty (Phase 2 implementation). The zoom animation fires live against the real `TransformationController`.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `lib/features/map/usa_map_painter.dart` — contains `hintPostal`, `Color(0xFFBBFF44)`, `old.hintPostal != hintPostal`
- `lib/features/map/map_screen.dart` — contains `_hintZoomController`, `_hintGlowTimer`, `_hintGlowTimer?.cancel()`, `_computeHintMatrix`, `setEntry(2, 2, newScale)`, `useHint()`, `hintPostal: _hintPostal`, `_onHintPressed`
- `test/features/map/usa_map_painter_test.dart` — contains group `'hintPostal glow'` with 3 tests
- `flutter test test/features/map/usa_map_painter_test.dart` — 7/7 passed
- `flutter test test/features/map/map_screen_test.dart` — 12/12 passed
- `flutter analyze lib/features/map/` — No issues found
- Commits 7166f0b and 9136043 verified in git log

---
*Phase: 05-polish-welcome-accessibility*
*Completed: 2026-06-01*
