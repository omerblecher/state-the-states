# Phase 4: Full Play Loop - Research

**Researched:** 2026-06-01
**Domain:** Flutter drag-and-drop game loop, Riverpod state integration, widget port from FlagsRoundTheWorld
**Confidence:** HIGH

---

## Summary

Phase 4 is predominantly a structured port from `FlagsRoundTheWorld` with well-understood
customisations. Every major component (tray, HUD, completion screen, home screen, fly-to-centroid
animation, pause overlay, DragTarget dispatch) has a direct Flags equivalent that has already been
read and analysed. The coordinate-transform spike (Phase 3) validated the drop-coordinate math that
Phase 4 depends on. The game-logic layer (Phase 2) is complete and tested. The map renderer
(Phase 3) already accepts `matchedPostals`, `showLabels`, and `mode`.

The principal effort in Phase 4 is wiring these layers together in `MapScreen`, replacing
`SvgPicture.asset` with mode-driven text content in the tray, replacing 196-country constants with
50-state ones, and stripping the Flags-specific features that are out of scope (ads, share, tutorial,
session restore, hint zoom). There are no unknown algorithms to invent.

**Primary recommendation:** Follow the Flags monolith port exactly for `MapScreen`, pruning the
out-of-scope features, then layer the mode-specific token content on top of the `FlagTray` shell.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Styled card (port Flags' `FlagTray` card widget). Rounded card ~90×100dp. Face + label varies by mode (Learn: abbrev + name; States Master: name + name; Geographical Master: abbrev + no label; Grand Master: solid palette color + no label).
- **D-02:** Grand Master token = solid color, no text, no embossed shape.
- **D-03:** Abbreviation large on face, name beneath (when shown).
- **D-04:** One token at a time, random order — direct port of Flags tray pattern. Single state token card. `AnimatedSwitcher` + `_trayKey` re-creation on correct drop.
- **D-05:** Tray position: bottom strip, full width, 120dp height.
- **D-06:** Progress indicator in HUD only.
- **D-07:** Extend `MapScreen` into full game screen — direct port of Flags monolith approach. All drag-drop logic, tray, HUD, pause overlay in one `ConsumerStatefulWidget`.
- **D-08:** `GameLifecycleObserver` mounted on `MapScreen` in Phase 4 via `WidgetsBinding.instance.addObserver(this)` in `initState`/`dispose`.
- **D-09:** Port Flags' `OverlayEntry` fly-to-centroid animation exactly.
- **D-10:** Incorrect drop snackbar duration: 1500ms.
- **D-11:** Star formula — `previousBest == null` → 3 stars; `score < previousBest` → 3 stars (PB); `score <= (previousBest * 1.20).ceil()` → 2 stars; else → 1 star.
- **D-12:** Personal-best badge + confetti overlay on `_isNewPb`. Port Flags' `AnimationController`-driven PB overlay.
- **D-13:** No `share_plus` or AdMob on completion screen in v1.
- **D-14:** Vertical ListView of 4 mode cards — direct port of Flags home screen layout.
- **D-15:** Each card shows mode name + one-line description + star rating + best score ("—" if never played).
- **D-16:** Tap card → navigate directly to game screen.

### Claude's Discretion

- Exact palette color assignment for Grand Master token: RESOLVED in UI-SPEC — assign by `palette[sequenceIndex % 6]` (sequence index in the shuffled order for that game session).
- Exact `DragTarget` hit area strategy: RESOLVED in UI-SPEC — one large `DragTarget` covering the entire InteractiveViewer child, dispatch via `stateHitTest()`. One DragTarget per state is NOT the Flags pattern.
- Pause overlay design: port from Flags `_buildPauseOverlay()` unchanged.
- Countdown animation (3-2-1-GO): full-screen semi-transparent overlay, large centered text, dismissed automatically when `GamePhase.playing`.
- Exact `AnimatedSwitcher` transition for new tray token: `FadeTransition` ONLY (not slide — slide causes unreachable Draggable during transition, Flags `map_screen.dart` line 942 comment).
- `shouldRepaint` for `UsaMapPainter` when `matchedPostals` grows: spread into new Set on each advance (`{...old, newPostal}`) so `shouldRepaint` receives distinct object references. This is the Flags pattern.

### Deferred Ideas (OUT OF SCOPE)

- "Continue game" dialog (HOME-03) — Phase 5.
- Hint UI zoom (HINT-01/02) — Phase 5. Hint button visible but no-op in Phase 4.
- Welcome screen + anthem (WEL-01/02/03) — Phase 5.
- A11y audit (A11Y-01/02) — Phase 5. Phase 4 must build Semantics labels but no formal audit.
- AdMob completion interstitial — v2 only.
- `share_plus` — v2 only.
- Session restore — Phase 5.
- Tutorial overlay — Phase 5.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DRAG-01 | Player can drag state token onto the map; correct drop is detected and acknowledged | `stateHitTest()` spike-validated; `DragTarget<String>` + `onAcceptWithDetails` pattern confirmed from Flags |
| DRAG-02 | Correct drop triggers: state fills grey, fly-to-centroid animation, success SFX, light haptic | `_animateCorrectDrop()` + `OverlayEntry` pattern read from Flags; `HapticFeedback.lightImpact()` confirmed |
| DRAG-03 | Incorrect drop triggers: bounce animation, error SFX, medium haptic, "not quite" snackbar | `triggerBounce()` on `_trayKey.currentState`; `HapticFeedback.mediumImpact()` confirmed from Flags |
| DRAG-04 | One token shown at a time; advances on correct drop | `_remainingPostals` list + `_currentPostal` + `_trayKey` re-creation pattern confirmed |
| DRAG-05 | Token order is randomized at game start | `buildFlagSequence()` equivalent needed; shuffle from 50 postal abbreviations |
| MODE-01 | Learn: abbreviations on map, state name in tray | `showLabels: true`, `showName: true`; token face = abbrev 28sp, label = name |
| MODE-02 | States Master: full name in tray, blank map | `showLabels: false`, token face = full name 17sp; map has no labels |
| MODE-03 | Geographical Master: abbreviations on map, blank tray | `showLabels: true`, `showName: false`; token face = abbrev; no label beneath |
| MODE-04 | Grand Master: no labels anywhere | `showLabels: false`, `showName: false`; token face = solid palette color |
| SCORE-03 | HUD shows live golf score and elapsed time | `GameHud` stateless widget reads from `gameSessionProvider`; Stopwatch-as-truth already implemented |
| SCORE-04 | Progress bar shows states placed (0/50 → 50/50) | `LinearProgressIndicator` value = `matchedCount / 50`; port `GameHud` with `totalFlags: 50` |
| SCORE-06 | Pause and resume work during active session | `pauseGame()` / `resumeGame()` on notifier; back-button guard via `PopScope` |
| SCORE-07 | Completion screen shows final score + star rating + PB | `CompletionScreen` port from Flags; star formula D-11; `HighScoreRepository.getBestScore()` |
| HOME-01 | Home screen lists 4 mode cards | `HomeScreen` body replacement; `_ModeCard` port from Flags |
| HOME-02 | Each card shows best score + star rating for that mode | `FutureBuilder<int?>` reads `HighScoreRepository.getBestScore(mode)` for each card |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Drop coordinate resolution | MapScreen (widget state) | `stateHitTest()` (pure Dart) | `_toSceneFromGlobal()` + `_controller` are private to `_MapScreenState`; hit-test is a pure function called from there |
| Token sequence management | MapScreen (widget state) | GameSessionNotifier | `_remainingPostals` + `_currentPostal` live in widget state; notifier owns phase/score |
| Score + timer | GameSessionNotifier | GameHud (display only) | Stopwatch-as-truth is notifier-owned; HUD is a stateless display consumer |
| Correct-drop animation | MapScreen (widget state) | Flutter Overlay | `OverlayEntry` lifecycle managed by `_MapScreenState._animateCorrectDrop()` |
| Bounce animation | StateTray (widget state) | — | `_bounceController` lives in `StateTrayState`; called via `GlobalKey` from MapScreen |
| Mode-based label visibility | UsaMapPainter + StateTray | MapScreen (passes flags) | Both painter and tray receive `mode`/`showLabels`/`showName` params computed in MapScreen |
| Persistence (scores) | HighScoreRepository | — | SharedPreferences via repository; no cloud, no Firebase (COPPA) |
| Star rating computation | CompletionScreen | — | Pure local comparison; previousBest read before `completeGame()` call |
| Routing / navigation | app.dart (GoRouter) | — | `/play` needs GameMode; `/complete` needs GameSession |
| Countdown overlay | MapScreen (widget state) | GameSessionNotifier | Notifier ticks the countdown; MapScreen observes `GamePhase.countdown` |

---

## Flags Port Mapping

### What Ports Verbatim (zero/minimal changes)

| Flags Source | State States Target | Changes |
|---|---|---|
| `_buildPauseOverlay()` in `map_screen.dart` | `_buildPauseOverlay()` in `MapScreen` | None — layout identical; hardcoded strings replace `AppLocalizations` |
| `_DownTriangle` clipper in `flag_tray.dart` | Same in `StateTray` | None |
| `_pinAnchorStrategy` in `flag_tray.dart` | Same in `StateTray` | None — `kPinAnchor = Offset(45, 70)` unchanged |
| Bounce animation controller in `FlagTrayState` | `StateTrayState` | None — 500ms elasticOut, `Offset(20, -10)`, `triggerBounce()` identical |
| `_buildPauseOverlay()` End Game wiring | Same | Navigate to `/` (same route) |
| `_ConfettiPainter` in `completion_screen.dart` | `CompletionScreen` | None — 40 particles, seed 42, 6 colors, radius 6dp |
| `_centroidToScreen()` helper | `MapScreen` | None — `MatrixUtils.transformPoint` + `localToGlobal` |
| `_onPausePressed()` / `_dismissPauseOverlay()` | `MapScreen` | None |
| `FlagTray` card shell dimensions (90×60dp) | `StateTray` `_cardShell` | None — only card face content changes |

### What Requires Mode-Aware Changes

| Flags Source | Change Required | Reason |
|---|---|---|
| `FlagTray._cardShell()` — `SvgPicture.asset` | Replace with mode-driven text/color content | State tokens have no SVG; content varies by mode (D-01/02) |
| `FlagTray` constructor — `currentIsoCode`, `countryName` | Add `mode: GameMode`, `sequenceIndex: int` | Grand Master color computed from index; tray content varies |
| `GameHud` — `totalFlags: 196` | Change to `totalFlags: 50` | 50 states, not 196 countries |
| `_animateCorrectDrop()` — `SvgPicture.asset` in overlay | Replace with `_cardShell()` equivalent | Overlay animates a state token card, not a flag SVG |
| `_buildMap()` — `showLabels` / `showName` logic | Swap mode constants (Learn/GeographicalMaster vs. FlagsMaster) | State States `GameMode` enum values differ from Flags |
| `HomeScreen` mode card list | Replace country-game modes with 4 state-game modes | Mode names, descriptions, icons, colors all differ |
| `CompletionScreen` — share/AdMob calls | Omit entirely | v2 scope; D-13 |
| `_buildMap()` `initSequence` / `_checkTutorial` | Omit tutorial branch; build sequence directly | Tutorial is Phase 5 |
| `MapScreen` constructor | `required GameMode mode` (no default) | Phase 4 makes mode mandatory per D-07 |

### What Does NOT Exist in Flags (new in State States)

| New Capability | Approach |
|---|---|
| Countdown overlay (3-2-1-GO!) | New widget: `_buildCountdownOverlay()`. Observe `GamePhase.countdown` + `notifier.countdownSecondsRemaining`. Full-screen `Colors.black54` + centered large text. |
| Grand Master solid-color token | In `_cardShell()`: when `mode == GameMode.grandMaster`, fill with `palette[sequenceIndex % 6]`, no text. |
| Mode-specific token content | `StateTray` `_cardShell()` switches on `mode`; Flags had a single SVG content path. |
| `/complete` route | New `GoRoute` in `app.dart`; `CompletionScreen` receives `GameSession` + `previousBest` via `extra`. |

---

## DragTarget Strategy

**Confirmed approach:** One `DragTarget<String>` covering the entire `SizedBox(1000, 628)` child of `InteractiveViewer`. This is the exact Flags pattern (Flags `map_screen.dart` lines 851–901).

**Drop coordinate recovery under zoom:**

```dart
// In onAcceptWithDetails:
final rawScene = _toSceneFromGlobal(details.offset + StateTray.kPinAnchor);
if (rawScene == null) return;
final scenePoint = rawScene; // no world-wrap needed (USA is single canvas)
final scale = _controller.value.getMaxScaleOnAxis();
final hitPostal = stateHitTest(scenePoint, states, scale: scale);
final isCorrect = hitPostal == _currentPostal;
```

`StateTray.kPinAnchor = Offset(45, 70)` — the pin tip offset within the feedback widget (45 = card half-width; 60 = card height + 10 = pin triangle tip). This is unchanged from Flags.

`DragTargetDetails.offset` is already `pointer_global - kPinAnchor` (Flutter subtracts the `dragAnchorStrategy` offset). Adding `kPinAnchor` back recovers the true pointer-global position. The spike (Phase 3) validated that `_toSceneFromGlobal` correctly transforms this to scene coordinates at 1×, 2×, and 4× zoom.

**Why NOT one DragTarget per state polygon:** Per-polygon DragTargets would require Z-order management for overlapping states (NE seaboard micro-states), cannot use the spike-validated `stateHitTest()` logic, and would make the InteractiveViewer layout significantly more complex. Single DragTarget + hit-test dispatch is the proven Flags pattern.

**`onWillAcceptWithDetails`:** In State States, this can return `true` unconditionally (no hover highlight needed in Phase 4). Flags used it to drive the hover glow; Phase 4 omits hover highlight to reduce complexity.

---

## Routing Changes

**Current `app.dart` `/play` route:**
```dart
GoRoute(
  path: '/play',
  builder: (context, state) => const MapScreen(),
),
```

**Required changes:**

1. Change `/play` to `/play` with `extra: GameMode` parameter:
```dart
GoRoute(
  path: '/play',
  builder: (context, state) {
    final mode = state.extra as GameMode;
    return MapScreen(mode: mode);
  },
  onExit: (context, goState) async {
    // Back-button guard: if playing/paused, show pause overlay
    // Return false to suppress navigation; let MapScreen handle it via PopScope
    return true; // Actual guard is in MapScreen PopScope._onBackPressed()
  },
),
```

2. Add `/complete` route:
```dart
GoRoute(
  path: '/complete',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return CompletionScreen(
      session: extra['session'] as GameSession,
      previousBest: extra['previousBest'] as int?,
    );
  },
),
```

3. `HomeScreen` navigates to play:
```dart
context.go('/play', extra: mode); // mode is GameMode enum value
```

4. `MapScreen._advanceToNextPostal()` navigates on completion:
```dart
context.go('/complete', extra: {
  'session': completedSession,
  'previousBest': previousBest,
});
```

**Back-button guard:** `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) _onBackPressed(); })` wraps the `MapScreen` Scaffold. `_onBackPressed()` replicates the Flags pattern: if `GamePhase.playing` → call `pauseGame()` + show pause overlay; if `GamePhase.paused` → show pause overlay; otherwise navigate to `/`.

**`MapScreen` constructor change:** `mode` becomes `required GameMode mode` (no default). The `/play` route must always receive a `GameMode` extra. The Phase 3 `const MapScreen()` call in tests will need updating to supply a mode.

---

## Key Implementation Risks

### Risk 1: `TickerProviderStateMixin` vs. `SingleTickerProviderStateMixin`
**What goes wrong:** `MapScreen` currently uses no mixin. Phase 4 needs multiple `AnimationController` instances (fly-to-centroid creates a new controller per correct drop; bounce is in `StateTray`; PB confetti is in `CompletionScreen`). `SingleTickerProviderStateMixin` allows only one vsync — using it with multiple controllers throws a `FlutterError`.

**Resolution:** `_MapScreenState` must mix in `TickerProviderStateMixin` (multi-ticker variant). The fly-to-centroid controller is created inside `_animateCorrectDrop()` on each call and disposed in its `whenComplete` callback — it never lives past the animation, so there is no leak risk.

### Risk 2: `animateCorrectDrop` AnimationController leak on dispose
**What goes wrong:** If the user navigates away (End Game) during a fly-to-centroid animation, the `AnimationController` created inside `_animateCorrectDrop()` will call its `whenComplete` callback on a disposed widget, leading to a `setState after dispose` error.

**Resolution:** Check `mounted` in the `whenComplete` callback before calling `_advanceToNextPostal()`. Store the controller reference in `_activeOverlayController` and cancel in `dispose()` (matching Flags `_activeOverlay?.remove()` pattern). The Flags `_animateCorrectDrop()` already disposes the controller in `whenComplete` — carry this pattern exactly.

### Risk 3: `_trayKey` GlobalKey duplicate during AnimatedSwitcher transition
**What goes wrong:** `AnimatedSwitcher` mounts old and new `StateTray` simultaneously during the transition. If both use the same `GlobalKey`, Flutter throws a duplicate-GlobalKey error.

**Resolution:** Re-create BOTH `_trayKey` (a `GlobalKey<StateTrayState>`) AND `_trayCardKey` (a `GlobalKey`) on each token advance, creating new instances. This is explicit in Flags (`map_screen.dart` lines 394–397). The new keys must be assigned in `setState` AFTER `_animateCorrectDrop()` starts (so the overlay captures the old key's render box before the key is replaced).

### Risk 4: `onAcceptWithDetails` called before `_currentPostal` is set
**What goes wrong:** If a player drops a token before `_startSequence()` assigns `_currentPostal`, `stateHitTest()` returns null and `isCorrect` is always false.

**Resolution:** Guard `onAcceptWithDetails` with `if (_currentPostal.isEmpty) return;`. Initialize `_currentPostal` synchronously in `_startSequence()` before calling `startGame()` (the Flags `buildFlagSequence()` pattern returns synchronously for non-Grand-Master modes).

### Risk 5: Countdown overlay blocks DragTarget during countdown
**What goes wrong:** The countdown overlay (`Colors.black54` + large text) must block user interaction during the 5-second countdown. If the DragTarget receives drops during countdown, the game state machine transitions incorrectly.

**Resolution:** Guard `onAcceptWithDetails` with `if (session?.phase != GamePhase.playing) return;`. The countdown overlay can be built without an `AbsorbPointer` wrapper (the phase guard in the DragTarget handler is sufficient and more robust).

### Risk 6: `snackbar` floating above the 120dp tray
**What goes wrong:** Default `SnackBar` appears at the bottom of the Scaffold, which puts it behind or overlapping the 120dp tray strip, making it invisible.

**Resolution:** Use `SnackBarBehavior.floating` with `margin: EdgeInsets.fromLTRB(16, 0, 16, 136)` — 120dp tray + 16dp gap. This is explicit in the Flags source (`map_screen.dart` line 324).

### Risk 7: `MapScreen` constructor change breaks Phase 3 tests
**What goes wrong:** `map_screen_test.dart` and `spike_map_screen_test.dart` call `const MapScreen()` without a `mode` argument. Making `mode` required breaks these existing tests.

**Resolution:** Two options: (a) keep `mode` optional with a default of `GameMode.learn` for test convenience, or (b) update the test files. Option (a) is simpler and matches the Phase 3 `MapScreen` backward-compat contract. Use `GameMode? mode` with a non-null default in the constructor.

### Risk 8: `stateHitTest()` signature mismatch
**What goes wrong:** Phase 3 implemented `stateHitTest(scenePoint, states, {scale})`. Phase 4 must call it with `List<StateData>` from `mapData.states`. If the call site passes a `Map` (indexed form) or the wrong type, it silently fails.

**Resolution:** `_buildMapStack` in Phase 3 already receives `List<StateData> states`. Store as `_states` field (equivalent to Flags `_countries`). Pass directly to `stateHitTest()`.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + `mocktail` 1.0.5 |
| Config file | None (standard flutter test runner) |
| Quick run command | `flutter test test/features/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DRAG-01 | Correct drop returns matching postal from `stateHitTest` | unit | `flutter test test/features/map/hit_detection_test.dart` | YES (Phase 3) |
| DRAG-01 | DragTarget `onAcceptWithDetails` calls `placeState()` on notifier | widget | `flutter test test/features/map/map_screen_test.dart` | YES (needs new tests) |
| DRAG-03 | Incorrect drop calls `triggerBounce()` on tray key | widget | `flutter test test/features/map/map_screen_test.dart` | YES (needs new tests) |
| MODE-01 | Learn mode: `showLabels: true`, tray shows name | widget | `flutter test test/features/map/map_screen_test.dart` | YES (needs new tests) |
| MODE-02 | States Master: `showLabels: false`, tray shows name | widget | `flutter test test/features/map/map_screen_test.dart` | YES (needs new tests) |
| MODE-03 | Geographical Master: `showLabels: true`, tray hides name | widget | `flutter test test/features/map/map_screen_test.dart` | YES (needs new tests) |
| MODE-04 | Grand Master: `showLabels: false`, tray hides name | widget | `flutter test test/features/map/map_screen_test.dart` | YES (needs new tests) |
| SCORE-03 | Score increments on error drop; timer advances | unit | `flutter test test/features/game/game_session_notifier_test.dart` | YES (Phase 2) |
| SCORE-04 | Progress bar value = `matchedCount / 50` | widget | `flutter test test/features/game/map_screen_test.dart` | YES (needs new tests) |
| SCORE-06 | Pause/resume: `pauseGame()` stops stopwatch; `resumeGame()` restarts | unit | `flutter test test/features/game/game_session_notifier_test.dart` | YES (Phase 2) |
| SCORE-07 | Star formula: first-game = 3 stars; PB = 3 stars + badge | unit | `flutter test test/features/map/completion_screen_test.dart` | NO — Wave 0 gap |
| HOME-01 | Home screen shows 4 mode cards | widget | `flutter test test/features/home/home_screen_test.dart` | NO — Wave 0 gap |
| HOME-02 | Mode card shows `getBestScore()` result | widget | `flutter test test/features/home/home_screen_test.dart` | NO — Wave 0 gap |

### Sampling Rate
- **Per task commit:** `flutter test test/features/map/hit_detection_test.dart test/features/game/game_session_notifier_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/features/map/completion_screen_test.dart` — covers SCORE-07 star formula (unit-testable pure logic; widget test for PB badge visibility)
- [ ] `test/features/home/home_screen_test.dart` — covers HOME-01 (4 cards rendered), HOME-02 (`getBestScore` FutureBuilder mock)
- [ ] `test/features/map/state_tray_test.dart` — covers DRAG-03 (bounce triggered on incorrect), mode-specific card content (MODE-01 through MODE-04 label visibility)

---

## Plan Decomposition Suggestion

Recommended wave structure for the planner:

### Wave 1 — Foundation Wiring (no new features, cleans up for Phase 4)
- **04-01-PLAN:** `app.dart` routing changes: `/play` receives `GameMode` extra, `/complete` route added, `MapScreen` constructor makes `mode` required (or default `GameMode.learn`). Add `CompletionScreen` stub (navigates home on primary CTA only). Wave 0 test files created.
- **Rationale:** Every subsequent plan depends on correct routing. CompletionScreen stub unblocks integration testing without waiting for full star logic.

### Wave 2 — Game Screen Core (blocked on Wave 1)
- **04-02-PLAN:** `MapScreen` gains `TickerProviderStateMixin`, `WidgetsBindingObserver` mount (D-08), `_remainingPostals` / `_currentPostal` sequence, `startGame()` call, `PopScope` back-button guard, countdown overlay (`_buildCountdownOverlay()`), and DragTarget wired to `stateHitTest()`.
- **04-03-PLAN:** `StateTray` widget (port `FlagTray`): `_cardShell` with mode-driven content, bounce animation, `kPinAnchor`, `Draggable<String>`, `AnimatedSwitcher` in `MapScreen`.

### Wave 3 — HUD + Feedback (blocked on Wave 2)
- **04-04-PLAN:** `GameHud` (port from Flags, `totalFlags: 50`), correct-drop flow (`_animateCorrectDrop()` with `OverlayEntry`, advance token, `placeState()`), incorrect-drop flow (bounce + snackbar + `reportError()`), complete-game flow (`completeGame()` + navigate to `/complete`).

### Wave 4 — Completion + Home (blocked on Wave 3)
- **04-05-PLAN:** Full `CompletionScreen` (star formula, PB badge, confetti painter, both CTAs), `HighScoreRepository` integration.
- **04-06-PLAN:** `HomeScreen` body replacement: `_ModeCard` list (4 modes, gradient cards, `FutureBuilder` for scores), privacy footer, tap-to-navigate.

**Total: 6 plans across 4 waves.** Wave 1 and Wave 4 can be partially parallelized (home screen does not depend on game screen internals, only on `HighScoreRepository` which is already built).

---

## Common Pitfalls

### Pitfall 1: AnimatedSwitcher + SlideTransition makes Draggable unreachable
**What goes wrong:** Using `SlideTransition` as the `AnimatedSwitcher` `transitionBuilder` moves the widget's hit-test area during the transition. The `Draggable` widget cannot be grabbed while it is sliding in.

**How to avoid:** Use `FadeTransition` exclusively. The tray widget stays at its final laid-out position; opacity changes but hit-test bounds do not. Flags `map_screen.dart` line 942 documents this as Bug 1.

**Warning signs:** Player cannot drag the new token for ~300ms after a correct drop.

### Pitfall 2: Shared GlobalKey between `child` and `feedback` in Draggable
**What goes wrong:** `_trayCardKey` must only be assigned to the `child` of `Draggable`, not to `feedback` or `childWhenDragging`. During a drag, all three are in the widget tree simultaneously; a shared key throws `Multiple widgets used the same GlobalKey`.

**How to avoid:** Flags `flag_tray.dart` line 141 comment documents this. In `_buildDraggableCard()`: `child: _cardShell(key: widget.cardKey)`, feedback and childWhenDragging call `_cardShell()` without a key argument.

### Pitfall 3: Snackbar hidden behind tray
**What goes wrong:** Default `SnackBar` appears at the very bottom of the Scaffold, behind the 120dp `StateTray`.

**How to avoid:** `SnackBarBehavior.floating` + `margin: EdgeInsets.fromLTRB(16, 0, 16, 136)`. The margin bottom = tray height (120) + gap (16).

### Pitfall 4: `OverlayEntry` not removed on widget dispose
**What goes wrong:** If the user taps "End Game" during a fly animation, `_activeOverlay` is still alive. The overlay references widget state that has been disposed, leading to a use-after-free crash on the next render.

**How to avoid:** In `dispose()`: `_activeOverlay?.remove(); _activeOverlay = null;`. Flags `_MapScreenState.dispose()` line 140 does this explicitly.

### Pitfall 5: Zip-to-centroid fires before `_fitMapToScreen` runs
**What goes wrong:** `_centroidToScreen()` uses `_controller.value` to transform scene coordinates. If called before `_fitMapToScreen()` has set the initial transform (i.e., before the first `addPostFrameCallback` fires), it returns wrong screen coordinates.

**How to avoid:** The fly animation only fires from `_animateCorrectDrop()`, which is called from `_handleDrop()`, which is called from `onAcceptWithDetails`. By the time the player can drag anything, `_fitMapToScreen` has already run. No guard needed, but document the dependency.

### Pitfall 6: `placeState()` vs `recordDrop()` — notifier API mismatch
**What goes wrong:** The CONTEXT.md refers to `placeState(postal)` as the notifier method for correct drops. The actual Phase 2 implementation is `recordDrop(postal, isCorrect: true)`. Using the wrong name causes a compile error or silent no-op.

**How to avoid:** The correct Phase 2 API is:
- `recordDrop(postal, isCorrect: true)` — correct drop
- `recordDrop(postal, isCorrect: false)` — incorrect drop
- `completeGame()` — all 50 placed
- `pauseGame()` / `resumeGame()` / `startGame(mode)`

The CONTEXT.md `placeState()` is aspirational naming from design; the implementation uses `recordDrop`. The planner must use the implemented API.

### Pitfall 7: `mapData.states` list length vs. postal set
**What goes wrong:** `usa_states_paths.json` contains 51 records (50 states + DC). The game plays 50 states (DC excluded). If `_remainingPostals` is built from `mapData.states` without filtering, DC will appear as a token.

**How to avoid:** Build the shuffled sequence by filtering `mapData.states` to exclude `postal == 'DC'` (or equivalently, by using only the 50 known postal abbreviations). The pipeline's `placeable` field in the JSON can be used as the filter if Phase 1 set it correctly.

---

## Code Examples

### Correct Drop Handler (adapted from Flags)
```dart
// Source: FlagsRoundTheWorld/lib/features/map/map_screen.dart _handleDrop()
void _handleDrop(DragTargetDetails<String> details) {
  final session = ref.read(gameSessionProvider).value;
  if (session?.phase != GamePhase.playing) return;

  final rawScene = _toSceneFromGlobal(details.offset + StateTray.kPinAnchor);
  if (rawScene == null) return;
  final scale = _controller.value.getMaxScaleOnAxis();
  final hitPostal = stateHitTest(rawScene, _states, scale: scale);
  final isCorrect = hitPostal == _currentPostal;

  if (isCorrect) {
    ref.read(gameSessionProvider.notifier).recordDrop(hitPostal!, isCorrect: true);
    HapticFeedback.lightImpact();
    ref.read(audioServiceProvider).playCorrect();
    _animateCorrectDrop(_currentPostal);
  } else {
    ref.read(gameSessionProvider.notifier).recordDrop(
      hitPostal ?? _currentPostal, isCorrect: false);
    HapticFeedback.mediumImpact();
    ref.read(audioServiceProvider).playError();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('Not quite — try again'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 136),
      ));
    _trayKey.currentState?.triggerBounce();
  }
}
```

### Advance Token (adapted from Flags)
```dart
// Source: FlagsRoundTheWorld/lib/features/map/map_screen.dart _advanceToNextFlag()
Future<void> _advanceToNextPostal() async {
  setState(() {
    _matchedPostals = {..._matchedPostals, _currentPostal};  // new Set = shouldRepaint fires
    _remainingPostals.removeAt(0);
  });
  if (_remainingPostals.isEmpty) {
    final sessionBeforeComplete = ref.read(gameSessionProvider).value!;
    final repo = await ref.read(highScoreRepositoryProvider.future);
    final previousBest = await repo.getBestScore(sessionBeforeComplete.mode);
    await ref.read(gameSessionProvider.notifier).completeGame();
    if (!mounted) return;
    final completedSession = ref.read(gameSessionProvider).value;
    if (completedSession == null) return;
    context.go('/complete', extra: {
      'session': completedSession,
      'previousBest': previousBest,
    });
  } else {
    setState(() {
      _currentPostal = _remainingPostals.first;
      _trayKey = GlobalKey<StateTrayState>();
      _trayCardKey = GlobalKey();
    });
  }
}
```

### Star Formula (from UI-SPEC D-11)
```dart
// Source: FlagsRoundTheWorld/lib/features/map/completion_screen.dart
int _computeStars(int score, int? previousBest) {
  if (previousBest == null) return 3;      // first game
  if (score < previousBest) return 3;     // personal best
  if (score <= (previousBest * 1.20).ceil()) return 2;
  return 1;
}

bool _isNewPb(int score, int? previousBest) =>
    previousBest != null && score < previousBest;
```

### Mode-Driven Tray Content
```dart
// StateTray._cardFace() — new in State States (no Flags equivalent)
Widget _cardFace() {
  switch (widget.mode) {
    case GameMode.grandMaster:
      final color = _palette[widget.sequenceIndex % 6];
      return Container(
        width: 90, height: 60,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      );
    case GameMode.statesMaster:
      return Center(child: Text(widget.stateName,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis, maxLines: 1));
    case GameMode.learn:
    case GameMode.geographicalMaster:
      return Center(child: Text(widget.postal,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)));
  }
}

static const _palette = [
  Color(0xFF8DB87F), Color(0xFFD4B483), Color(0xFFE8A055),
  Color(0xFFE89090), Color(0xFFA07EC8), Color(0xFFE8D870),
];
```

---

## Package Legitimacy Audit

Phase 4 installs **no new packages**. All packages in use were established in Phases 1–3 and are documented in `CLAUDE.md`. No registry audit required for this phase.

---

## Environment Availability

Step 2.6: Flutter environment confirmed working from Phase 3 completion. No new external dependencies introduced.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All widgets | YES | >=3.44.0 | — |
| `flutter_riverpod` | Provider watching | YES | 3.3.1 | — |
| `just_audio` | SFX playback | YES | 0.10.5 | `StubAudioService` |
| `shared_preferences` | HighScoreRepository | YES | 2.5.5 | — |
| `go_router` | Routing | YES | 17.2.3 | — |

---

## Security Domain

Phase 4 adds no new network calls, no new storage of personally identifiable data, and no new permissions. The COPPA posture from Phase 1 is unchanged. No ASVS categories are newly applicable.

| ASVS Category | Applies | Notes |
|---------------|---------|-------|
| V2 Authentication | No | No accounts, no auth |
| V3 Session Management | No | No server sessions |
| V4 Access Control | No | Single-user local app |
| V5 Input Validation | Low | `state.extra as GameMode` — must use `as` with null guard; invalid extra crashes, not a security issue |
| V6 Cryptography | No | No encryption needed |

**COPPA carry-through:** `CompletionScreen` must not add any tracking, analytics, or network calls. The `_scoreCardKey` (`RepaintBoundary` for screenshot) from Flags is omitted in Phase 4 (no share button in v1).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `usa_states_paths.json` has a `placeable: true` field (or DC can be identified by `postal == 'DC'`) to filter the play sequence to 50 states | Pitfall 7 | DC would appear as a token; play would require 51 drops; success criteria would not match "50 states" |
| A2 | `stateHitTest()` function signature is `stateHitTest(Offset scenePoint, List<StateData> states, {double scale})` | DragTarget Strategy | Incorrect signature causes compile error |
| A3 | `audioServiceProvider` exposes `playCorrect()` and `playError()` methods (matching the Flags `RealAudioService` pattern) | Correct Drop Handler | Wrong method names cause compile errors |

**A1 mitigation:** Read `lib/features/map/hit_detection.dart` or `usa_states_paths.json` before implementing `_buildSequence()`. If no `placeable` field, filter by hardcoded postal set.

---

## Open Questions

1. **DC in play sequence (A1 above)**
   - What we know: Phase 1 pipeline produces 50 state records + DC per the ROADMAP.md success criterion ("50 state records"). Phase 2 `GameSession.matchedPostals` is typed as a list without a defined length cap.
   - What's unclear: Does `usa_states_paths.json` include DC with a `placeable: false` flag, or must the play sequence filter DC by postal code?
   - Recommendation: The implementer reads `usa_states_paths.json` or the `StateData` model before building `_buildSequence()`. Use `postal != 'DC'` as the fallback filter.

2. **`audioServiceProvider` exact method names**
   - What we know: Phase 2 built `RealAudioService` with a `just_audio` pattern; `StubAudioService` passes interface parity tests.
   - What's unclear: Whether the correct/error methods are named `playCorrect()` / `playError()` or something else.
   - Recommendation: The implementer reads `lib/core/audio/` before wiring SFX calls.

---

## Sources

### Primary (HIGH confidence)
- `C:\code\Claude\StateTheStates\.planning\phases\04-full-play-loop\04-CONTEXT.md` — locked decisions, canonical refs
- `C:\code\Claude\StateTheStates\.planning\phases\04-full-play-loop\04-UI-SPEC.md` — component specs, spacing, typography, color
- `C:\code\Claude\StateTheStates\lib\features\map\map_screen.dart` — Phase 3 production MapScreen (read directly)
- `C:\code\Claude\StateTheStates\lib\app.dart` — current routing (read directly)
- `C:\code\Claude\StateTheStates\lib\features\game\game_session_notifier.dart` — Phase 2 notifier API (read directly)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` — Flags monolith port template (read directly, lines 1–1049)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\flag_tray.dart` — Flags tray widget (read directly)

### Secondary (MEDIUM confidence)
- `C:\code\Claude\StateTheStates\.planning\ROADMAP.md` — Phase 4 success criteria
- `CLAUDE.md` (project) — locked stack, COPPA constraints, "What NOT to Use"

---

## Metadata

**Confidence breakdown:**
- Flags Port Mapping: HIGH — source files read directly
- DragTarget Strategy: HIGH — Flags pattern confirmed from source + Phase 3 spike
- Routing Changes: HIGH — `app.dart` read directly
- Implementation Risks: HIGH — sourced from direct code reading + Flags source comments
- Validation Architecture: HIGH — existing test infrastructure confirmed from `test/` directory scan
- Plan Decomposition: MEDIUM — dependency ordering is clear; specific task granularity is a planning-phase decision

**Research date:** 2026-06-01
**Valid until:** 2026-07-01 (stable library stack; no fast-moving dependencies)
