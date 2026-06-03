---
phase: 08-full-admob-layer
plan: "04"
status: complete
completed: "2026-06-03"
subsystem: ads
tags: [admob, banner, interstitial, rewarded, hint-guard, state-tray, coppa]
requires: [08-02]
provides: [banner-slot-home, interstitial-completion, rewarded-hint-dialog, state-tray-d08]
affects:
  - lib/features/game/state_tray.dart
  - lib/features/map/map_screen.dart
  - lib/features/home/home_screen.dart
  - lib/features/map/completion_screen.dart
  - test/features/map/state_tray_test.dart
  - test/features/map/completion_screen_test.dart
tech_stack:
  added: []
  patterns: [rewarded-ad-dialog, future-delayed-interstitial, post-frame-banner-load, enabled-guard-change]
key_files:
  created: []
  modified:
    - lib/features/game/state_tray.dart
    - lib/features/map/map_screen.dart
    - lib/features/home/home_screen.dart
    - lib/features/map/completion_screen.dart
    - test/features/map/state_tray_test.dart
    - test/features/map/completion_screen_test.dart
decisions:
  - "D-08: state_tray.dart enabled condition is widget.onHintPressed != null only (no hintsRemaining > 0 guard)"
  - "Future.delayed(1s) creates a pending fake timer in tests — all test callers must pump(1100ms) to drain it"
  - "buildScreen in completion_screen_test.dart always wraps with ProviderScope + StubAdService for ref safety"
  - "Walled-garden rule preserved: GameSessionNotifier has zero ad imports; refillHints/useHint called from widget layer"
metrics:
  duration: 18min
  completed: "2026-06-03"
  tasks: 2
  files: 6
---

# Phase 08 Plan 04: UI Ad Call Sites — StateTray, MapScreen, HomeScreen, CompletionScreen Summary

## What Was Built

All four UI ad call sites wired. StateTray hint button now enabled at hintsRemaining==0 (D-08). MapScreen forks on zero-hints to show a rewarded-ad AlertDialog; on earn calls refillHints()+useHint(); on failure shows the D-09 Snackbar. HomeScreen loads banner via addPostFrameCallback in initState and renders getBannerWidget() below the mode-card ListView. CompletionScreen fires showInterstitialAd() after a 1-second delay in initState for all modes. Walled-garden rule (GameSessionNotifier has zero ad imports) preserved throughout.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 RED | StateTray/MapScreen RED tests | 1ff354c | state_tray_test.dart |
| 1 GREEN | StateTray hint guard + MapScreen rewarded dialog | 4f3ea9f | state_tray.dart, map_screen.dart |
| 2 RED | CompletionScreen AD-04 RED test | 3a78dea | completion_screen_test.dart |
| 2 GREEN | HomeScreen banner + CompletionScreen interstitial | 0cbd343 | home_screen.dart, completion_screen.dart, completion_screen_test.dart |

## Verification Results

```
flutter test test/features/map/completion_screen_test.dart — 18 passed
flutter test test/features/map/map_screen_test.dart — 12 passed
flutter test test/features/map/state_tray_test.dart — 6 passed (3 pre-existing SVG failures)
flutter analyze lib/features/ — No issues found

state_tray.dart enabled condition: widget.onHintPressed != null (no hintsRemaining > 0) — confirmed
map_screen.dart contains _showRewardedHintDialog() — confirmed
map_screen.dart contains refillHints() call inside earned branch — confirmed
map_screen.dart contains Snackbar "No ad available right now — try again later." — confirmed
home_screen.dart contains loadBannerForWidth in addPostFrameCallback — confirmed
home_screen.dart contains getBannerWidget() in Column — confirmed
completion_screen.dart contains showInterstitialAd() in Future.delayed(1s) — confirmed
```

## Key Decisions

1. **D-08 enabled condition** — Removed `widget.hintsRemaining > 0` from `_buildHintButton`'s `enabled` variable. The zero-hint fork lives in `MapScreen._onHintPressed`, not in StateTray. This keeps the button enabled so the rewarded-ad prompt can trigger at hintsRemaining==0.

2. **Future.delayed(1s) timer in tests** — Adding `Future.delayed(const Duration(seconds: 1), ...)` in `CompletionScreen.initState` creates a pending fake timer. The Flutter test framework asserts `!timersPending` on tearDown. All existing completion_screen tests updated to: (a) wrap with ProviderScope+StubAdService so `ref.read` doesn't throw, and (b) pump 1100ms at the end to drain the timer before the test ends.

3. **buildScreen always uses ProviderScope** — Updated `buildScreen` in completion_screen_test.dart to always wrap with ProviderScope overriding adServiceProvider with StubAdService. The optional `adService` param allows the spy service for AD-04 tests.

4. **Walled-garden preserved** — `refillHints()` and `useHint()` are called from `_showRewardedHintDialog()` in the widget layer. GameSessionNotifier has no ad imports at any point.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Future.delayed timer causes "timer still pending" assertion in existing tests**
- **Found during:** Task 2 GREEN verification (completion_screen_test.dart)
- **Issue:** `Future.delayed(const Duration(seconds: 1), ...)` in `CompletionScreen.initState` creates a pending fake timer. When the widget is disposed before 1 second of fake time elapses, Flutter's test framework throws "A Timer is still pending even after the widget tree was disposed."
- **Fix:** Updated `buildScreen` to always wrap with ProviderScope+StubAdService, and added `await tester.pump(const Duration(milliseconds: 1100))` at the end of all 11 existing tests to drain the timer before teardown.
- **Files modified:** test/features/map/completion_screen_test.dart
- **Commit:** 0cbd343

## Known Stubs

None — all four ad placements are fully wired to RealAdService via adServiceProvider. No placeholder values in any modified files.

## Threat Flags

No new security surface introduced beyond what was planned.

| Flag | File | Description |
|------|------|-------------|
| None | — | All ad calls remain behind AdService interface; GameSessionNotifier walled-garden preserved; T-08-04-01 mitigated (refillHints/useHint only on earned==true) |

## Self-Check: PASSED

- lib/features/game/state_tray.dart enabled condition = `widget.onHintPressed != null`: confirmed
- `hintsRemaining > 0` NOT in state_tray.dart _buildHintButton: confirmed
- lib/features/map/map_screen.dart contains `_showRewardedHintDialog`: confirmed
- lib/features/map/map_screen.dart contains `refillHints()`: confirmed
- lib/features/map/map_screen.dart contains Snackbar D-09 text: confirmed
- lib/features/home/home_screen.dart contains `loadBannerForWidth`: confirmed
- lib/features/home/home_screen.dart contains `getBannerWidget()`: confirmed
- lib/features/map/completion_screen.dart contains `showInterstitialAd()`: confirmed
- Task commits 1ff354c, 4f3ea9f, 3a78dea, 0cbd343 all exist: confirmed
- No file deletions in any commit: confirmed
- flutter analyze lib/features/ exits 0: confirmed
