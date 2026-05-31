---
phase: 03-map-render-coordinate-transform-spike
reviewed: 2026-05-31T17:32:25Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - lib/core/data/state_data_service.dart
  - lib/features/map/hit_detection.dart
  - lib/features/map/usa_map_painter.dart
  - lib/features/map/map_screen.dart
  - lib/features/map/spike_map_screen.dart
  - lib/app.dart
  - test/features/map/hit_detection_test.dart
  - test/features/map/usa_map_painter_test.dart
  - test/features/map/map_screen_test.dart
  - test/features/map/spike_map_screen_test.dart
findings:
  critical: 0
  warning: 7
  info: 2
  total: 9
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-05-31T17:32:25Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed the phase 3 map render and coordinate-transform spike: `StateDataService`, `UsaMapPainter`, `MapScreen`, `SpikeMapScreen`, `app.dart`, and the four test files. No critical bugs (data loss, crashes in production paths, or COPPA violations) were found. The primary concerns are:

- A dead state field (`_mapPaintReady`) that is accumulated but never read by any widget subtree, combined with a pattern that accumulates redundant `postFrameCallback` registrations on repeated builds before the flag flips.
- A loose `List<dynamic>` signature on `_buildMapStack` that silently erases type safety and uses a runtime `.cast()` downstream.
- A fragile reliance on JSON map insertion order for the inset-frame rect ordering that is never validated at runtime.
- Two Wave 0 test requirements called out in `03-VALIDATION.md` are not met: the bbox-expansion edge-case tests (Criterion 2 hard gate) and the `entry(2,2)` == `getMaxScaleOnAxis()` assertion after zoom (Criterion 4 hard gate) are both absent.
- An unguarded `firstWhere` in `SpikeMapScreen` that throws if any of the six fixed postal codes is missing from the loaded data.

---

## Warnings

### WR-01: `_mapPaintReady` is set but never read — dead state variable

**File:** `lib/features/map/map_screen.dart:47-172`

**Issue:** `_mapPaintReady` is declared and flipped to `true` inside a `postFrameCallback` registered in `_buildMapStack`, but neither `build()` nor `_buildMapStack()` gates any widget on its value. The intent (delay rendering until `_fitMapToScreen` has run) is documented in a comment, but the implementation is incomplete — the flag changes state that no consumer observes, so it has zero effect on the rendered UI. Every `setState(() => _mapPaintReady = true)` is a spurious rebuild.

**Fix:** Either gate the InteractiveViewer on the flag (e.g., wrap in `Visibility`/`Opacity`) or remove the field and the callback entirely if the flash-of-wrong-scale is not an observed problem:

```dart
// Option A: remove dead state entirely
// Delete: bool _mapPaintReady = false;
// Delete the entire if (!_mapPaintReady) block in _buildMapStack.

// Option B: use it as originally intended
child: Opacity(
  opacity: _mapPaintReady ? 1.0 : 0.0,
  child: InteractiveViewer(...),
),
```

---

### WR-02: Redundant `postFrameCallback` registrations on repeated builds

**File:** `lib/features/map/map_screen.dart:168-172`

**Issue:** The guard `if (!_mapPaintReady)` inside `_buildMapStack` registers a new callback on *every* `build` call while `_mapPaintReady` is `false`. If any rebuild is triggered before the first callback fires (e.g., a parent widget passes new `matchedPostals` during the loading-to-data transition), multiple callbacks pile up. Each fires a separate `setState(() => _mapPaintReady = true)`, scheduling unnecessary repaints. The final value is correct, but the redundant repaints are avoidable.

**Fix:** Register the callback only once in `initState` (after `_fitMapToScreen` has completed), or use a local guard variable that is only set inside a callback once:

```dart
// In initState:
WidgetsBinding.instance.addPostFrameCallback((_) {
  _fitMapToScreen();
  // Second callback fires after the fit has been applied:
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() => _mapPaintReady = true);
  });
});

// Remove the if (!_mapPaintReady) block from _buildMapStack entirely.
```

---

### WR-03: `_buildMapStack` typed `List<dynamic>` — erases type safety

**File:** `lib/features/map/map_screen.dart:163`

**Issue:** `_buildMapStack` declares its `states` parameter as `List<dynamic>`. The call site at line 157 passes `mapData.states` which is `List<StateData>`. The only downstream use is `states.cast()` at line 199 before handing to `UsaMapPainter`. Using `List<dynamic>` and then `.cast()` bypasses static analysis: if the call site passes the wrong type, the error is deferred to a runtime `CastError` during painting instead of being caught at compile time.

**Fix:**

```dart
Widget _buildMapStack(
  List<StateData> states,   // was List<dynamic>
  List<Rect> insetFrameRects,
) {
  // ...
  states: states,           // remove .cast()
```

---

### WR-04: Inset-frame rect order depends on JSON map insertion order — no runtime guard

**File:** `lib/core/data/state_data_service.dart:63-64`

**Issue:** `_decodeJson` extracts inset frame rects by calling `.values` on the `insetFrames` map object returned by `jsonDecode`. The comment says "Return values in insertion order: alaska first (x≈0), hawaii second (x≈255)." Dart's `jsonDecode` does use `LinkedHashMap` and preserves JSON key insertion order, so this works *if* the pipeline always writes `"alaska"` before `"hawaii"` in the JSON. This contract is:

1. Not validated at runtime (no check that index 0 has `x≈0`).
2. Silent on failure — if the order flips, `MapData.insetFrameRects[0]` will silently be the Hawaii frame and vice versa, causing both inset boxes to be drawn in the wrong position with no error or warning.

**Fix:** Access by key rather than by position, or add a validation assertion:

```dart
// Option A: access by key (eliminates ordering dependency)
final frames = [
  insetFrames['alaska'] as Map<String, dynamic>,
  insetFrames['hawaii'] as Map<String, dynamic>,
];

// Option B: keep values() order but add a runtime guard
final frames = insetFrames.values.cast<Map<String, dynamic>>().toList();
assert(
  frames.length == 2 && (frames[0]['x'] as num) < (frames[1]['x'] as num),
  'insetFrames must be alaska (x≈0) first, hawaii (x≈255) second',
);
```

---

### WR-05: Wave 0 hard gate unmet — bbox expansion edge cases absent from `hit_detection_test.dart`

**File:** `test/features/map/hit_detection_test.dart`

**Issue:** `03-VALIDATION.md` line 52 explicitly lists "expansion edge cases (Criterion 2 HARD GATE)" as a Wave 0 requirement for `hit_detection_test.dart`. The submitted test file contains:

- 10 centroid-hit tests across 5 micro-states at two scales (present)
- 1 ocean-null test (present)
- 2 large-state centroid tests (TX, CA) (present)

Missing:
- No test exercises the `_kMinScreenArea` circular-expansion branch (the path where `screenArea < 2304` triggers `Rect.fromCenter` with `expansionRadius`).
- No test drops a point *outside* the actual SVG path but *inside* the expanded bbox of a small state to confirm the expansion correctly catches it.
- No test for the degenerate-diagonal guard (`diagonal < 1e-6`).

Without these, the Criterion 2 hard gate cannot be considered met by automated tests.

**Fix:** Add at minimum:

```dart
test('point near RI but outside exact path hits RI via bbox expansion', () {
  final s = states.firstWhere((s) => s.postal == 'RI');
  // Drop 20 scene-units outside the actual path, still within expanded bbox
  final nearPoint = s.centroid + const Offset(20.0, 0.0);
  expect(stateHitTest(nearPoint, states, scale: 1.0), equals('RI'));
});

test('very small state at scale 0.1 still resolves via area expansion', () {
  final s = states.firstWhere((s) => s.postal == 'RI');
  expect(stateHitTest(s.centroid, states, scale: 0.1), equals('RI'));
});
```

---

### WR-06: Wave 0 hard gate unmet — `entry(2,2)` sync assertion absent from `map_screen_test.dart` (Criterion 4)

**File:** `test/features/map/map_screen_test.dart:52-56`

**Issue:** `03-VALIDATION.md` line 54 requires "`getMaxScaleOnAxis()` == entry(0,0) after zoom (MAP-03, MAP-04, Criterion 4)" as a Wave 0 test. The submitted test has a TODO comment:

> "Precise scale assertion … is validated via SpikeMapScreen manual testing in Plan 05 where the controller is directly observable via debugPrint output (Criterion 4 hard gate)."
> "TODO(phase-3): Expose _controller via @visibleForTesting for precise scale assertions once entry(2,2) sync is verified via SpikeMapScreen (Criterion 4)."

The Criterion 4 gate has no automated coverage. The `_zoom()` entry(2,2) sync is the most critical correctness property of the whole coordinate-transform system — a regression silently breaks all subsequent scale calculations. Deferring it to manual testing is not acceptable for a hard gate.

**Fix:** Expose `_controller` via `@visibleForTesting` and add an assertion:

```dart
// In _MapScreenState:
@visibleForTesting
TransformationController get testController => _controller;

// In map_screen_test.dart — after zoom tap:
final state = tester.state<_MapScreenState>(find.byType(MapScreen));
final m = state.testController.value;
final maxScale = m.getMaxScaleOnAxis();
expect(m.entry(0, 0), closeTo(maxScale, 1e-6));
expect(m.entry(2, 2), closeTo(maxScale, 1e-6));
```

---

### WR-07: Unguarded `firstWhere` in `SpikeMapScreen.build()` throws on missing postal

**File:** `lib/features/map/spike_map_screen.dart:148`

**Issue:** `mapData.states.firstWhere((s) => s.postal == p)` has no `orElse` clause. If the loaded JSON is missing any of the six hard-coded postals (`TX`, `CA`, `FL`, `NY`, `AK`, `HI`), the call throws `StateError: No element`. Since the spike screen is dev-only, this isn't a production risk, but it will crash the spike test suite (including automated `spike_map_screen_test.dart`) with an opaque error if the fixture data ever omits one of those states. The fixture in the test file happens to include all six, but a future edit could accidentally miss one.

**Fix:**

```dart
final regions = _regionPostals
    .map((p) => mapData.states.firstWhere(
          (s) => s.postal == p,
          orElse: () => throw StateError(
              'SpikeMapScreen: required postal "$p" not found in map data'),
        ))
    .toList();
```

This converts the opaque `StateError: No element` into a descriptive message that immediately tells the developer which postal is missing.

---

## Info

### IN-01: `assert(kDebugMode)` secondary guard is misleading — asserts are stripped in release

**File:** `lib/features/map/spike_map_screen.dart:138`

**Issue:** `assert(kDebugMode, 'SpikeMapScreen must not appear in release builds')` is documented as a "secondary guard." The intent is correct (belt-and-suspenders after the route guard), but an `assert` is *also* stripped in release mode, so this statement never executes in release builds. The message "must not appear in release builds" suggests the assertion will enforce that — it won't. The primary guard (`if (kDebugMode)` in `app.dart`) is the only real enforcement.

**Fix:** Either remove the assert (it adds no protection), or replace it with a check that survives release compilation:

```dart
// Option A: remove it — the route guard in app.dart is sufficient
// (delete line 138)

// Option B: use a compile-time constant expression that survives release
// This still does nothing in release builds, but doesn't imply it does:
if (kReleaseMode) {
  throw UnsupportedError('SpikeMapScreen must not appear in release builds');
}
```

Note: Option B would itself be dead code because `kDebugMode` gates route registration. Only document the intent clearly.

---

### IN-02: Unused import `kDebugMode` in `map_screen.dart` kept via `assert` workaround

**File:** `lib/features/map/map_screen.dart:3,147-151`

**Issue:** `kDebugMode` is imported but only referenced inside an `assert(() { ... kDebugMode; return true; }())` block. The comment says "kDebugMode import kept for parity with Flags port." This is dead code silenced by an `assert` closure — the approach works but is unusual. When Phase 4 wires up the DragTarget, the `assert` trick should be removed and the real usage added. Until then this is a mild code smell.

**Fix:** Remove the `import 'package:flutter/foundation.dart' show kDebugMode'` and the assert block for now; re-add when Phase 4 actually needs `kDebugMode`.

---

_Reviewed: 2026-05-31T17:32:25Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
