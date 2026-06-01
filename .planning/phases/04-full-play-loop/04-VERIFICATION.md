---
phase: 04-full-play-loop
verified: 2026-06-01T13:16:22Z
status: gaps_found
score: 3/5 must-haves verified
overrides_applied: 0
gaps:
  - truth: "A player can play Learn mode with abbreviations visible on the map (SC-1 partial: on-map label rendering)"
    status: failed
    reason: "UsaMapPainter.paint() contains only a stub comment 'Phase 4: label pass (showLabels / mode) goes here' at line 105. No TextPainter, no canvas.drawText, no label rendering of any kind. showLabels is accepted as a parameter and passed correctly from MapScreen, but the painter ignores it entirely in the actual paint() method. Learn mode (MODE-01) and Geographical Master (MODE-03) both require visible abbreviations on the map canvas — neither works."
    artifacts:
      - path: "lib/features/map/usa_map_painter.dart"
        issue: "paint() method (line 66–106) has no text/label rendering. Line 105 is a comment stub. The only grep match for any text rendering in lib/features/map/ is in spike_map_screen.dart, not the production painter."
    missing:
      - "Implement the label pass in UsaMapPainter.paint(): when showLabels == true, iterate states and draw TextPainter abbreviations at state centroids, scaled by viewScale"
      - "Add a test verifying that CustomPaint with showLabels:true produces drawn text (or that UsaMapPainter.paint is called with the correct showLabels value in mode tests)"

  - truth: "No null-crash in _advanceToNextPostal on final drop (CR-03 force-unwrap)"
    status: failed
    reason: "map_screen.dart line 255 uses force-unwrap: ref.read(gameSessionProvider).value! — throws Null check operator used on a null value if provider is in error/null state at the moment the last state is placed. Code review CR-03 identified this; it was not fixed. The fix (null guard + early return) is documented in 04-REVIEW.md."
    artifacts:
      - path: "lib/features/map/map_screen.dart"
        issue: "Line 255: final sessionBeforeComplete = ref.read(gameSessionProvider).value!; — unguarded force-unwrap can crash on final drop under adverse lifecycle conditions"
    missing:
      - "Replace force-unwrap with null guard: if (sessionBeforeComplete == null) return;"

  - truth: "Star rating on HomeScreen is consistent with CompletionScreen formula"
    status: failed
    reason: "HomeScreen._starsForScore uses absolute thresholds (<=80=3, <=150=2, >150=1) while CompletionScreen uses the D-11 relative formula (score<previousBest=3, within 20%=2, otherwise=1). A player who earns 3 stars on CompletionScreen (score 195 vs previousBest 200) sees only 1 star on HomeScreen (195>150). Code review CR-02 identified this inconsistency. Both files exist and have tests that pass, but the tests validate the current divergent behavior, not correctness."
    artifacts:
      - path: "lib/features/home/home_screen.dart"
        issue: "Lines 187-192: _starsForScore uses hardcoded absolute thresholds, inconsistent with computeStarCount D-11 formula in completion_screen.dart"
    missing:
      - "Align _starsForScore with computeStarCount, or replace home screen star display with a unified formula, or document intentional design choice with tests that validate the design decision"

human_verification:
  - test: "Verify that Learn mode and Geographical Master mode show abbreviations on the map canvas during active gameplay"
    expected: "State abbreviations (2-letter postal codes) should appear on each state polygon when showLabels is true; they should scale with zoom level"
    why_human: "UsaMapPainter.paint() has no label code — this is a programmatic gap, not a UI behavior question. The gap must be implemented first before human verification is meaningful. Once the label pass is added, a human must confirm the labels render correctly at multiple zoom levels."
  - test: "Verify that tapping a mode card on HomeScreen navigates to /play with the correct GameMode"
    expected: "Tapping 'Learn' navigates to game with Learn mode (abbreviations on map); tapping 'Grand Master' shows no labels anywhere"
    why_human: "Navigation with GoRouter cannot be reliably tested in widget tests without a full router setup; the tests use MaterialApp which swallows navigation calls"
---

# Phase 4: Full Play Loop Verification Report

**Phase Goal:** Full interactive drag-drop play loop — players can pick a game mode, drag all 50 state tokens onto the map, see live score/timer/progress, receive visual feedback on correct/incorrect drops, and reach a star-rated completion screen with personal best tracking.
**Verified:** 2026-06-01T13:16:22Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Learn shows abbreviations on map + name in tray; States Master name in tray + blank map; Geographical Master abbreviations on map + blank tray; Grand Master nothing | PARTIAL | Tray behavior correct (StateTray mode matrix verified). On-map labels absent: UsaMapPainter.paint() has no label rendering (line 105 is a stub comment). showLabels flag is wired through MapScreen but ignored by painter. |
| SC-2 | Correct drops fill state, play success SFX + light haptic, fly-to-centroid animation; incorrect drops play error SFX + medium haptic, "not quite" snackbar, token bounce | VERIFIED | _handleDrop in map_screen.dart (lines 278-314) wires all paths. _animateCorrectDrop creates 500ms OverlayEntry. StateTray.triggerBounce() called on incorrect drop. AudioService.playCorrect/playError wired. HapticFeedback.lightImpact/mediumImpact called. |
| SC-3 | HUD shows live golf score, elapsed time MM:SS, states-placed progress; pause and resume work; back-button guard active during sessions | VERIFIED | GameHud wired with session?.score, session?.elapsed, _matchedPostals.length/50. PopScope with onPopInvokedWithResult. _onBackPressed routes to pause overlay for active sessions. GameLifecycleObserver mounted in initState. NOTE: Force-unwrap at line 255 is a runtime crash risk on final drop (CR-03). |
| SC-4 | Completion screen: final score, 1-3 star rating, PB badge when score beats record, confetti overlay on PB, play-again CTA | VERIFIED | completion_screen.dart full implementation: computeStarCount D-11 formula, _isNewPb detection, _pbController 2000ms confetti, Back to Menu / Play Again CTAs. 11/11 completion tests pass. |
| SC-5 | Home screen lists 4 mode cards, each showing player's best score and star rating (or blank if never played) | VERIFIED (with WARNING) | HomeScreen 4 _ModeCard instances, FutureBuilder score display, 'Not played' for null. 4/4 home tests pass. WARNING: _starsForScore uses absolute thresholds (<=80=3, <=150=2) inconsistent with CompletionScreen's D-11 relative formula (CR-02). |

**Score:** 3/5 truths fully verified (SC-2, SC-3, SC-4 pass; SC-1 partially fails on map labels; SC-5 passes with logic inconsistency warning)

### Deferred Items

None — the on-map label rendering is not deferred to a later phase. Phase 5 (Polish, Welcome & Accessibility) covers WEL-01/02/03, HINT-01/02, SESS-04, HOME-03, A11Y-01/02 — none of those address the label pass in UsaMapPainter.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/app.dart` | /play extracts GameMode; /complete route to CompletionScreen | VERIFIED | Line 22-36: /play uses `state.extra as GameMode? ?? GameMode.learn`; /complete extracts session+previousBest from Map. NOTE: /complete cast is unguarded (CR-01 — crashes if extra is null). |
| `lib/features/map/completion_screen.dart` | Full CompletionScreen with computeStarCount, stars, PB badge, confetti, CTAs | VERIFIED | 381 lines. computeStarCount exported. _ConfettiPainter with Random(42), 40 particles. Back to Menu + Play Again CTAs. No share_plus or google_mobile_ads imports. |
| `lib/features/game/state_tray.dart` | StateTray with Draggable, bounce, mode-driven card face, kPinAnchor=Offset(45,70) | VERIFIED | 266 lines. kPinAnchor const = Offset(45, 70). triggerBounce() on StateTrayState. GlobalKey only on Draggable.child (not feedback/childWhenDragging). |
| `lib/features/game/game_hud.dart` | GameHud: score, elapsed, progress bar, mute/pause buttons | VERIFIED | 127 lines. LinearProgressIndicator value=matchedCount/totalFlags. FontFeature.tabularFigures timer. Semantics labels on progress bar and buttons. 48x48dp touch targets. |
| `lib/features/map/map_screen.dart` | Full game screen: DragTarget, _handleDrop, _startSequence, PopScope, countdown, StateTray, GameHud | VERIFIED (with CR-03) | 659 lines. TickerProviderStateMixin. DC filtered shuffle. stateHitTest wired. PopScope canPop:false. Countdown overlay. AnimatedSwitcher FadeTransition. Force-unwrap at line 255 (CR-03). |
| `lib/features/home/home_screen.dart` | 4 _ModeCard instances, FutureBuilder scores, tap-to-play | VERIFIED (with CR-02) | 331 lines. 4 mode cards wired. context.go('/play', extra: mode) on tap. 'Not played' / 'Best: N' display. _starsForScore inconsistent with D-11 (CR-02). |
| `lib/features/map/usa_map_painter.dart` | showLabels flag renders abbreviations on map canvas (MODE-01/03) | STUB | paint() method contains no label rendering. Line 105: stub comment only. showLabels parameter accepted but unused in paint(). |
| `test/features/map/completion_screen_test.dart` | 11 tests: 4 unit + 7 widget | VERIFIED | 11/11 pass. computeStarCount unit tests, widget tests for stars/PB/score/CTAs. |
| `test/features/map/state_tray_test.dart` | 7 tests: MODE-01/04, hint, Draggable.data, bounce | VERIFIED | 7/7 pass. All 4 mode card-face tests, hint count, Draggable.data, triggerBounce smoke. |
| `test/features/map/map_screen_test.dart` | 12 tests: existing + mode visibility + DragTarget + PopScope + GameHud + AnimatedSwitcher | VERIFIED | 12/12 pass. Mode→showLabels matrix validated at UsaMapPainter level (parameter passing), but painter itself does not render labels. |
| `test/features/home/home_screen_test.dart` | 4 widget tests: mode names, Not played, Best:N, loading | VERIFIED | 4/4 pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `lib/app.dart` | `lib/features/map/completion_screen.dart` | GoRoute /complete builder | WIRED | CompletionScreen imported; builder extracts session+previousBest from extra map |
| `lib/app.dart` | `lib/features/map/map_screen.dart` | GoRoute /play builder | WIRED | MapScreen(mode: mode) called with extracted GameMode |
| `lib/features/map/map_screen.dart _handleDrop` | `lib/features/map/hit_detection.dart stateHitTest` | stateHitTest(rawScene, _states, scale:) | WIRED | Line 288: stateHitTest called with TransformationController scale |
| `lib/features/map/map_screen.dart` | `lib/features/game/game_session_notifier.dart` | ref.watch(gameSessionProvider) | WIRED | Line 490: sessionAsync watched; notifier accessed for startGame, recordDrop, completeGame |
| `lib/features/map/map_screen.dart _startSequence` | `lib/features/game/game_session_notifier.dart startGame` | ref.read(gameSessionProvider.notifier).startGame(widget.mode) | WIRED | Line 200: startGame called after sequence initialized |
| `lib/features/map/map_screen.dart _animateCorrectDrop` | Flutter Overlay | Overlay.of(context).insert(_activeOverlay!) | WIRED | Line 398: OverlayEntry inserted; disposed in whenComplete with mounted guard |
| `lib/features/map/map_screen.dart _advanceToNextPostal` | `lib/core/data/high_score_repository.dart` | ref.read(highScoreRepositoryProvider.future) | WIRED | Lines 257-258: getBestScore called before navigating to /complete |
| `lib/features/map/map_screen.dart` | `lib/features/game/game_hud.dart` | GameHud(score:, elapsed:, matchedCount:, totalFlags:50) | WIRED | Lines 557-565: real session data passed to GameHud |
| `lib/features/map/map_screen.dart showLabels` | `lib/features/map/usa_map_painter.dart` | UsaMapPainter(showLabels:) | PARTIAL | showLabels IS passed to painter (line 591) but painter's paint() ignores it (no label rendering code) |
| `lib/features/home/home_screen.dart _ModeCard` | `lib/core/data/high_score_repository.dart` | FutureBuilder(future: widget.bestScoreFuture) | WIRED | repo.getBestScore(mode) called; FutureBuilder displays result |
| `lib/features/home/home_screen.dart` | `lib/app.dart /play route` | context.go('/play', extra: mode) | WIRED | Each card onTap calls context.go with correct GameMode |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `GameHud` | score, elapsed, matchedCount | MapScreen session?.score, session?.elapsed, _matchedPostals.length | Yes — GameSession from gameSessionProvider (Riverpod notifier) | FLOWING |
| `CompletionScreen` | session.score, _starCount, _isNewPb | widget.session (passed from _advanceToNextPostal), previousBest from highScoreRepositoryProvider | Yes — real session data + real stored high score | FLOWING |
| `HomeScreen _ModeCard` | bestScoreFuture | repo.getBestScore(mode) — SharedPreferences-backed | Yes — real async read from SharedPreferences | FLOWING |
| `UsaMapPainter labels` | N/A — showLabels parameter | Passed correctly from MapScreen | N/A — data never consumed in paint() | DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| computeStarCount unit tests | `flutter test test/features/map/completion_screen_test.dart` | 11/11 pass, exit 0 | PASS |
| StateTray mode matrix tests | `flutter test test/features/map/state_tray_test.dart` | 7/7 pass, exit 0 | PASS |
| MapScreen DragTarget + PopScope + GameHud tests | `flutter test test/features/map/map_screen_test.dart` | 12/12 pass, exit 0 | PASS |
| HomeScreen mode card tests | `flutter test test/features/home/home_screen_test.dart` | 4/4 pass (note: state_tray_test also verified, 22 total) | PASS |
| Full test suite | `flutter test` | 124/124 pass, exit 0 | PASS |
| On-map label rendering (showLabels=true) | Inspect UsaMapPainter.paint() for TextPainter usage | Zero text rendering calls in production painter | FAIL — labels not rendered |

### Probe Execution

Step 7c: SKIPPED — no probe scripts declared in PLAN files or found at scripts/*/tests/probe-*.sh.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| HOME-01 | 04-01, 04-06 | Home screen presents one card per game mode | SATISFIED | 4 _ModeCard instances in home_screen.dart; 4 mode names rendered in tests |
| HOME-02 | 04-01, 04-06 | Each mode card shows player's best score and star rating | SATISFIED (with WARNING CR-02) | FutureBuilder shows 'Best: N' / 'Not played'; _starsForScore logic diverges from D-11 |
| DRAG-01 | 04-02 | Drop coordinates recovered via TransformationController.toScene() | SATISFIED | _toSceneFromGlobal at line 181: `_controller.toScene(box.globalToLocal(globalOffset))`. REQUIREMENTS.md traceability table not updated but code is implemented. |
| DRAG-02 | 04-04 | Correct drop fills state, fly-to-centroid animation | SATISFIED | _animateCorrectDrop: OverlayEntry with 500ms pos/scale/opacity Tween; state filled in _matchedPostals |
| DRAG-03 | 04-03 | Micro-states use 48dp proximity-snapping hit-box, deterministic tiebreaking | SATISFIED | hit_detection.dart: _kMinScreenArea=2304 expansion for small-bbox states; centroid-distance tiebreaker |
| DRAG-04 | 04-02, 04-04 | Correct drops: light haptic + success SFX | SATISFIED | _handleDrop line 293-295: HapticFeedback.lightImpact() + audioServiceProvider.playCorrect() |
| DRAG-05 | 04-02, 04-04 | Incorrect drops: medium haptic + error SFX + snackbar + bounce | SATISFIED | _handleDrop lines 298-313: mediumImpact, playError, SnackBar floating, triggerBounce() |
| MODE-01 | 04-02, 04-03 | Learn: abbreviations visible on map, full state name beneath tray | BLOCKED | Tray: stateName shown (showName:true for Learn — verified). Map: UsaMapPainter.paint() has no label rendering. On-map abbreviations absent. |
| MODE-02 | 04-02, 04-03 | States Master: name beneath tray; map blank | SATISFIED (by absence) | Tray: showName:true passes stateName. Map: no labels ever drawn, satisfies "blank map" requirement. |
| MODE-03 | 04-02, 04-03 | Geographical Master: abbreviations on map; blank tray | BLOCKED | Tray: showName:false (blank tray — satisfied). Map: UsaMapPainter.paint() has no label rendering. Abbreviations absent. |
| MODE-04 | 04-02, 04-03 | Grand Master: no names in tray, no labels on map | SATISFIED (by absence) | Tray: showName:false + grandMaster palette color (no text). Map: no labels drawn. |
| SCORE-03 | 04-04 | HUD displays live score and elapsed time | SATISFIED | GameHud shows 'Score: N' and MM:SS timer with tabular figures |
| SCORE-04 | 04-04 | HUD shows progress indicator (states placed / 50) | SATISFIED | GameHud LinearProgressIndicator value=matchedCount/totalFlags |
| SCORE-06 | 04-01, 04-05 | Completion screen: final score, 1-3 star rating, play-again CTA | SATISFIED | CompletionScreen full implementation: star row, score card, Play Again button |
| SCORE-07 | 04-01, 04-05 | Beating stored best: PB badge + confetti overlay | SATISFIED | _isNewPb detection; _pbController 2000ms confetti; amber badge |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/app.dart` | 30 | Unguarded cast `state.extra as Map<String, dynamic>` | Blocker (CR-01) | Direct navigation to /complete without extra crashes app with TypeError |
| `lib/features/map/map_screen.dart` | 255 | Force-unwrap `ref.read(gameSessionProvider).value!` | Blocker (CR-03) | Null crash on final drop if provider is in null/error state during lifecycle event |
| `lib/features/home/home_screen.dart` | 187-192 | `_starsForScore` uses absolute thresholds, diverges from D-11 | Warning (CR-02) | Home screen stars mislead players who earned 3 stars on completion screen |
| `lib/features/map/map_screen.dart` | 530-532 | State mutation (`_states =`, `_startSequence`) inside `build()` | Warning (WR-02) | Anti-pattern; currently guarded by `_sequenceInitialized` but fragile |
| `lib/features/map/map_screen.dart` | 219-225 | `setMuted` future not awaited, synchronous try/catch only | Warning (WR-03) | Async errors silently discarded; UI/audio mute state can desync |
| `lib/features/home/home_screen.dart` | 258-300 | New `Future` created on every parent rebuild (WR-04) | Warning | Causes FutureBuilder flash-to-loading on every HomeScreen rebuild |
| `lib/features/map/map_screen.dart` | 284 | `Offset(45, 70)` literal duplicates `StateTray.kPinAnchor` | Info (WR-01) | Divergence risk if kPinAnchor changes |
| `test/features/map/map_screen_test.dart` | 57-59 | `// TODO(phase-3):` in test file | Info (IN-03) | Stale TODO from phase 3; precise scale assertions still untested |

**Debt marker gate:** No TBD/FIXME/XXX markers found in any Phase 4 files.

### Human Verification Required

### 1. On-map label rendering for Learn and Geographical Master modes

**Test:** After implementing the label pass in UsaMapPainter.paint(), launch the app, select Learn mode, and verify that 2-letter state abbreviations appear inside each state polygon on the map canvas.
**Expected:** All 50 state abbreviations rendered on the map; labels scale with zoom level (larger at higher zoom); Learn mode shows both labels on map AND state name beneath the tray token; Geographical Master shows only labels on map with no name in tray.
**Why human:** This is currently a code gap (no label rendering in production painter), not a behavior question. Must be implemented before verification is meaningful.

### 2. End-to-end game completion flow

**Test:** Play a complete game in any mode by dragging all 50 state tokens to the map. Verify that after the 50th correct drop the completion screen appears with the correct session data.
**Expected:** Completion screen shows the actual final score, elapsed time, and correct star count. Play Again button starts a new game in the same mode. Back to Menu returns to HomeScreen.
**Why human:** The force-unwrap bug (CR-03) could cause a crash at the 50th drop. This needs real device testing to confirm the happy path works and to catch the race condition edge case.

### 3. Mode card tap navigation

**Test:** Tap each of the 4 mode cards on the HomeScreen. Verify each starts the game in the correct mode.
**Expected:** Learn mode shows abbreviations on map (once label rendering is implemented); States Master starts with blank map; the correct mode is reflected in the CompletionScreen AppBar title.
**Why human:** GoRouter navigation with typed extras cannot be reliably verified in widget tests without full router integration; the widget tests use MaterialApp which does not exercise the GoRouter extra-passing mechanism.

### Gaps Summary

**Two blockers prevent full phase goal achievement:**

1. **On-map label rendering absent (MODE-01, MODE-03, SC-1 partial):** The `UsaMapPainter.paint()` method contains only a stub comment `// Phase 4: label pass (showLabels / mode) goes here` with no actual text rendering. The `showLabels` parameter is correctly wired from MapScreen through the entire call chain, but the painter does nothing with it. Learn mode (MODE-01) and Geographical Master (MODE-03) cannot function as specified — they both require state abbreviations visible on the map canvas. This is the most impactful gap and the primary reason the phase goal is not fully achieved.

2. **Force-unwrap crash risk on game completion (CR-03):** `map_screen.dart` line 255 force-unwraps `ref.read(gameSessionProvider).value!` in `_advanceToNextPostal`. Under adverse lifecycle conditions (lifecycle event during the last drop), this will throw a null-pointer exception instead of navigating to the completion screen. The fix is a one-line null guard, but it is not applied.

**One additional warning (CR-02):** HomeScreen star rating uses different thresholds than the CompletionScreen D-11 formula, creating a misleading UX where players who earned 3 stars on the completion screen may see 1 star on the HomeScreen for the same score.

The label rendering gap is the sole ROADMAP SC-1 failure. Everything else in the phase — tray widget, HUD, fly-to-centroid animation, completion screen, home screen, routing, audio/haptic feedback, back-button guard, pause overlay, countdown — is correctly implemented and verified by 124 passing tests.

---

_Verified: 2026-06-01T13:16:22Z_
_Verifier: Claude (gsd-verifier)_
