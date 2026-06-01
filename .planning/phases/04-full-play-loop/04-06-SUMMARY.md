---
phase: 04-full-play-loop
plan: 06
subsystem: ui
tags: [flutter, home-screen, mode-cards, future-builder, widget-test, tdd]

# Dependency graph
requires:
  - phase: 04-04
    provides: HighScoreRepository with getBestScore(mode) — FutureProvider, SharedPreferences-backed
  - phase: 04-01
    provides: GameMode enum (learn/statesMaster/geographicalMaster/grandMaster)
provides:
  - HomeScreen full implementation: 4 gradient mode cards with live best-score display and tap-to-play
  - _ModeCard: press animation, FutureBuilder score/stars, gradient + shadow
  - _starsForScore: <=80=3 stars, <=150=2 stars, >150=1 star
  - home_screen_test.dart: 4 widget tests (names, Not played, Best:N, loading state)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "HomeScreen: ConsumerStatefulWidget + ref.watch(highScoreRepositoryProvider).when()"
    - "_ModeCard: StatefulWidget + SingleTickerProviderStateMixin for 80ms/150ms scale press animation"
    - "FutureBuilder<int?> score display: snap.hasData && snap.data != null for Not played vs Best:N"
    - "ListView with SizedBox(height:12) gaps between cards — no Dividers"
    - "context.go('/play', extra: mode) — GameMode passed as extra to /play route"
    - "Widget test double-pump: pump() + pump() lets FutureProvider emit then FutureBuilder resolve"
    - "Completer<HighScoreRepository>().future for loading-state test — completed in test body to avoid leak"

key-files:
  created:
    - .planning/phases/04-full-play-loop/04-06-SUMMARY.md
  modified:
    - lib/features/home/home_screen.dart
    - test/features/home/home_screen_test.dart

key-decisions:
  - "Icons.map (not Icons.public) used for header icon — UI-SPEC specifies map icon for State States"
  - "22sp header font size (not 28sp) — 28sp is for CompletionScreen; home header uses 22sp per Flags pattern"
  - "No url_launcher in Privacy Policy footer — Phase 5 (HOME-03) scope; stub onPressed: () {} acceptable for v1"

requirements-completed: [HOME-01, HOME-02]

# Metrics
duration: 2min
completed: 2026-06-01
---

# Phase 4 Plan 06: HomeScreen Full Implementation Summary

**HomeScreen replaced: 4 gradient mode cards with live best-score display, press animation, and tap-to-play navigation; 4 widget tests passing; 125/125 full suite**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-06-01T13:02:25Z
- **Completed:** 2026-06-01
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `HomeScreen` fully implemented — replaces Phase 1 placeholder ('State the States' title + Play button) with: map icon header (Icons.map, 28dp, #1565C0), 22sp w800 title (#0D2E6B), 'Choose a mode' subtitle, Expanded ListView of 4 `_ModeCard` widgets, Privacy Policy footer
- 4 `_ModeCard` instances: Learn (green #2E7D32, Icons.explore), States Master (blue #1565C0, Icons.flag), Geographical Master (deep orange #BF360C, Icons.compass_calibration), Grand Master (purple #4A148C, Icons.emoji_events)
- Each card: `LinearGradient` (cardColor → lerp(black, 0.2)), `BoxShadow` (alpha 0.4, blurRadius 12), `BorderRadius.circular(16)`, press animation (scale 0.97, 80ms forward / 150ms reverse)
- `FutureBuilder<int?>` score display: 'Not played' for null, 'Best: N' for non-null; 3 star icons (amber filled / white outline)
- `_starsForScore`: <=80=3 stars, <=150=2 stars, >150=1 star
- `context.go('/play', extra: mode)` on card tap — GameMode passed as route extra
- 4 widget tests: all 4 mode names rendered, Not played for null scores, Best:50 for Learn score=50, CircularProgressIndicator in loading state
- 125/125 full suite tests pass (4 new + 121 prior)

## Task Commits

1. **Task 1: Full HomeScreen implementation** - `3806b3c` (feat)
2. **Task 2: home_screen_test.dart widget tests** - `db6ce0d` (test)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `lib/features/home/home_screen.dart` — full HomeScreen: _buildBody, 4 _ModeCard instances, Privacy Policy footer; _ModeCard: press animation, _buildCard, _starsForScore, FutureBuilder
- `test/features/home/home_screen_test.dart` — 4 widget tests in 'HomeScreen mode cards' group; buildHomeScreen() helper; MockHighScoreRepository preserved

## Decisions Made

- `Icons.map` used for header icon — UI-SPEC specifies map icon (not Flags' `Icons.public`) for State States branding
- `22sp` header font — 28sp is reserved for CompletionScreen 'Well done!' title; home header matches Flags pattern (22sp in _buildBody)
- Privacy Policy `onPressed: () {}` — `url_launcher` integration is HOME-03 scope (Phase 5); stub is intentional for v1 per threat model T-04-09

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `Privacy Policy` footer `onPressed: () {}` — intentional Phase 4 stub; `url_launcher` launch is HOME-03 scope deferred to Phase 5. The footer renders correctly; only the tap action is a no-op.

## Threat Flags

None — HomeScreen reads only `HighScoreRepository.getBestScore()` (local SharedPreferences, no PII); navigation passes app-internal `GameMode` enum as route extra.

## Self-Check: PASSED

- `lib/features/home/home_screen.dart` exists with 4 _ModeCard instances ✓
- `test/features/home/home_screen_test.dart` has 4 widget tests in 'HomeScreen mode cards' group ✓
- `flutter analyze lib/features/home/home_screen.dart` exits 0 ✓
- `flutter test test/features/home/home_screen_test.dart` shows 4/4 passing ✓
- Full suite 125/125 tests pass — no regressions ✓
- Commits `3806b3c`, `db6ce0d` exist ✓
- No url_launcher, no google_mobile_ads, no ad imports ✓

---
*Phase: 04-full-play-loop*
*Completed: 2026-06-01*
