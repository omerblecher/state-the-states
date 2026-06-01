---
plan: "05-03"
phase: "05-polish-welcome-accessibility"
status: complete
completed: "2026-06-01"
duration: "15min"
tasks_completed: 2
files_modified: 5
subsystem: welcome-screen
tags: [welcome, animation, CustomPainter, anthem, routing, TDD, A11Y]
dependency_graph:
  requires: ["05-01", "05-02"]
  provides: ["/welcome initial route", "WelcomeScreen stagger animation", "anthem fade-in/out on nav", "TutorialScreen stub", "/tutorial route"]
  affects:
    - lib/app.dart
    - lib/features/welcome/welcome_screen.dart
    - lib/features/welcome/usa_welcome_painter.dart
    - lib/features/tutorial/tutorial_screen.dart
    - test/features/welcome/welcome_screen_test.dart
tech_stack:
  added: []
  patterns:
    - "ConsumerStatefulWidget + TickerProviderStateMixin for stagger AnimationController"
    - "addPostFrameCallback for post-frame anthem fade-in"
    - "fire-and-forget fadeOutAnthem() + Future.delayed 850ms navigation (Pitfall 5)"
    - "UsaWelcomePainter shouldRepaint 0.001 abs threshold (Pitfall 6)"
    - "canvas.save/translate/scale/restore for viewBox fitting"
    - "staggerOrder List.generate + shuffle for random state fill order"
key_files:
  modified:
    - lib/app.dart
    - lib/features/welcome/welcome_screen.dart
  created:
    - lib/features/welcome/usa_welcome_painter.dart
    - lib/features/tutorial/tutorial_screen.dart
    - test/features/welcome/welcome_screen_test.dart
decisions:
  - "TutorialScreen stub is ConsumerStatefulWidget (not bare StatelessWidget) so it can read userPrefsRepositoryProvider in _completeTutorial() — forward-compatible with Plan 04"
  - "staggerOrder initialized lazily inside stateDataProvider.when data callback — avoids List.generate(0) when provider is still loading"
  - "error callback named (_, e) not (_, __) to satisfy no_leading_underscores_for_local_identifiers and unnecessary_underscores lints"
  - "child parameter named 'child' in AnimatedBuilder builder to avoid unnecessary_underscores lint"
metrics:
  duration: "15min"
  completed_date: "2026-06-01"
---

# Phase 5 Plan 3: WelcomeScreen + UsaWelcomePainter — Summary

## What Was Built

/welcome is now the app's initial route. `WelcomeScreen` shows a deep-blue gradient background with a white USA silhouette that fills in state-by-state with random stagger over 1.5s. Anthem fade-in fires on first frame via `addPostFrameCallback`. GET STARTED fires `fadeOutAnthem()` (fire-and-forget) then navigates to `/tutorial` or `/` after 850ms based on `getTutorialSeen()`. A smoke test, GET STARTED text test, and `androidTapTargetGuideline` A11Y test all pass.

## Key Files

### Modified
- `lib/app.dart` — `initialLocation` changed from `'/'` to `'/welcome'`; two new GoRoutes added (`/welcome` → `WelcomeScreen`, `/tutorial` → `TutorialScreen`)

### Created
- `lib/features/welcome/welcome_screen.dart` — Full WelcomeScreen implementation: `ConsumerStatefulWidget` + `TickerProviderStateMixin`; `AnimationController` 1500ms stagger; `fadeInAnthem()` in `addPostFrameCallback`; `_onStartPressed` fire-and-forget `fadeOutAnthem()` + 850ms delayed navigation; gradient background; USA silhouette hero; GET STARTED button with Semantics wrapper; privacy footer
- `lib/features/welcome/usa_welcome_painter.dart` — `UsaWelcomePainter extends CustomPainter`; `shouldRepaint` uses 0.001 abs threshold; `paint()` scales 1000×628 viewBox with `canvas.save/translate/scale/restore`; stagger-gated white fill loop
- `lib/features/tutorial/tutorial_screen.dart` — Stub `ConsumerStatefulWidget` with `_completeTutorial()` that calls `setTutorialSeen(true)` and navigates to `/`; Plan 04 will implement the full PageView onboarding flow
- `test/features/welcome/welcome_screen_test.dart` — TDD suite: smoke test, GET STARTED text assertion, `androidTapTargetGuideline` A11Y check; provider overrides for `audioServiceProvider` (stub), `stateDataProvider` (2-state minimal `MapData`), `userPrefsRepositoryProvider` (stub)

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| Task 1 | app.dart routing: /welcome initial route, /tutorial stub route | 6252ea7 |
| Task 2 RED | Failing tests for WelcomeScreen (smoke, GET STARTED, A11Y) | cbf074b |
| Task 2 GREEN | Full WelcomeScreen + UsaWelcomePainter implementation | a6f62cf |

## Verification

- `flutter test test/features/welcome/welcome_screen_test.dart` — 3/3 tests pass
- `flutter analyze lib/features/welcome/ lib/app.dart` — No issues found

## Decisions Made

1. **TutorialScreen stub uses ConsumerStatefulWidget (not StatelessWidget):** Forward-compatible with Plan 04's PageView onboarding, which will need Riverpod reads. The plan allowed a simple StatelessWidget but a ConsumerStatefulWidget compiles without issue and avoids a refactor later.

2. **staggerOrder initialized lazily in data callback:** `if (_staggerOrder.isEmpty)` guard means the shuffle runs once on first successful MapData load, not in `initState` where `stateDataProvider` may not have resolved yet. This avoids a crash if data is still loading.

3. **Lint fixes (unnecessary_underscores and no_leading_underscores_for_local_identifiers):** Changed `(_, __) =>` to `(_, e) =>` and `builder: (_, __)` to `builder: (_, child)` to satisfy flutter_lints 6.0.0 rules. No behavior change.

4. **Privacy Policy onPressed is an empty closure (not null):** Mirrors the Flags pattern — url_launcher is deferred to v2. An empty closure gives a visible press affordance without crashing (null would disable the button entirely, failing the A11Y tap target test).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Lint] Fixed unnecessary_underscores and no_leading_underscores lint violations**
- **Found during:** Task 2 GREEN verify (`flutter analyze`)
- **Issue:** `(_, __)` lambda params in error callback and AnimatedBuilder builder triggered `unnecessary_underscores` and `no_leading_underscores_for_local_identifiers` lint warnings under flutter_lints 6.0.0
- **Fix:** Renamed `__` to `e` (error callback) and `child` (AnimatedBuilder builder)
- **Files modified:** `lib/features/welcome/welcome_screen.dart`
- **Commit:** a6f62cf (included in GREEN commit)

## TDD Gate Compliance

- RED gate: `test(05-03)` commit `cbf074b` — Test 2 (GET STARTED text) failed on stub (confirmed)
- GREEN gate: `feat(05-03)` commit `a6f62cf` — All 3 tests pass on full implementation

## Known Stubs

- `lib/features/tutorial/tutorial_screen.dart` — Intentional stub. Shows "Tutorial" text + "Get Started" button that sets `tutorialSeen=true` and navigates to `/`. Plan 04 will implement the full 3-page PageView onboarding flow. This stub satisfies the `/tutorial` route registration and WelcomeScreen navigation target.
- Privacy Policy `onPressed` is an empty closure (url_launcher link deferred to v2).

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. Privacy Policy onPressed is an empty closure (no URL transmitted in v1).

## Self-Check: PASSED

- `lib/app.dart` — contains `initialLocation: '/welcome'`, GoRoute for `/welcome`, GoRoute for `/tutorial`
- `lib/features/welcome/welcome_screen.dart` — contains `fadeInAnthem`, `fadeOutAnthem`, `Future.delayed(const Duration(milliseconds: 850)`, `UsaWelcomePainter`
- `lib/features/welcome/usa_welcome_painter.dart` — contains `UsaWelcomePainter`, `shouldRepaint` with `0.001`, `canvas.save()`, `canvas.restore()`
- `lib/features/tutorial/tutorial_screen.dart` — contains `TutorialScreen` as compilable ConsumerStatefulWidget
- `test/features/welcome/welcome_screen_test.dart` — contains smoke test, GET STARTED test, `androidTapTargetGuideline` test
- Commits 6252ea7, cbf074b, a6f62cf verified in git log
