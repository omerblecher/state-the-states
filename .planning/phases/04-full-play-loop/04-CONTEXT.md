# Phase 4: Full Play Loop - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 wires the foundations from Phases 1–3 into a complete, playable game. It delivers:

1. **Token tray** — a fixed bottom strip showing one draggable state token at a time; hint button alongside.
2. **Drag-and-drop game loop** — `DragTarget`s over the `InteractiveViewer` child, `stateHitTest()` for hit detection, correct/incorrect feedback (haptic + audio + visual), fly-to-centroid overlay animation on correct drop, bounce animation on incorrect drop.
3. **HUD** — live golf score, MM:SS elapsed, states-placed progress bar (0/50); pause + mute buttons.
4. **Mode-specific label visibility** — MODE-01 through MODE-04 fully wired (abbreviations on map, name in tray, both, or neither per mode).
5. **Completion screen** — final score, 1–3 star rating, personal-best badge + confetti on new best, play-again CTA.
6. **Home screen** — 4 mode cards (vertical list) each with mode name + one-line description + star rating + best score; tap-to-launch directly into the game.

**What is NOT in Phase 4:** welcome screen, anthem, hints (Phase 5 wires UI; logic hooks already exist), first-launch tutorial, session-restore "continue game" dialog, and COPPA/a11y audit. Those are Phase 5.

</domain>

<decisions>
## Implementation Decisions

### State Token Design
- **D-01:** **Styled card (port Flags' `FlagTray` card widget, text in place of flag image).** Rounded card, ~90×100dp. The card face and label beneath vary by mode:
  - **Learn** (MODE-01): abbreviation large on card face + full state name label beneath the card.
  - **States Master** (MODE-02): full state name large on card face + name label beneath (no map abbreviations).
  - **Geographical Master** (MODE-03): abbreviation large on card face + no label beneath (map shows abbreviations; tray shows no text clues per requirement).
  - **Grand Master** (MODE-04): solid palette-color card face (one of the 6 map palette colors, no text or decoration), no label beneath.
- **D-02:** **Grand Master token = solid color, no text, no embossed shape.** The token's only identity is its color. The player must use map knowledge alone.
- **D-03:** **Abbreviation large on face, name beneath** (when shown). Mirrors the Flags two-layer information pattern: content on the card, label below.

### Tray Structure
- **D-04:** **One token at a time, random order — direct port of Flags' tray pattern.** The tray occupies a fixed bottom strip (~120dp full-width). A single state token card is displayed. After a correct placement a new token slides in (AnimatedSwitcher, matching Flags' `_trayKey` re-creation pattern). Order is randomized at game-start from the 50 placeable states.
- **D-05:** **Tray position: bottom strip, full width.** HUD at top, map fills the middle, tray at bottom — the proven vertical stack from Flags.
- **D-06:** **Progress indicator in HUD only (SCORE-04).** The tray stays clean: token card + hint button. No counter duplicated in the tray.

### Game Screen Architecture
- **D-07:** **Extend `MapScreen` into the full game screen — direct port of the Flags `map_screen.dart` monolith approach.** `MapScreen` gains `DragTarget` widgets inside the `InteractiveViewer` child, the tray, the HUD, and the pause overlay — all in one `ConsumerStatefulWidget`. This keeps the `_toSceneFromGlobal()` / `_controller` / `_ivKey` private state co-located with the drag-drop logic that needs it, exactly as in Flags. The `/play` route receives the `GameMode` as a required parameter (previously defaulted to null; Phase 4 makes it required).
- **D-08:** **`GameLifecycleObserver` (built in Phase 2) is mounted on `MapScreen` in Phase 4.** It is added/removed in `initState`/`dispose` via `WidgetsBinding.instance.addObserver(this)`, matching the Flags pattern from `game_session_notifier.dart`.

### Correct Drop Animation
- **D-09:** **Port Flags' `OverlayEntry` fly-to-centroid animation exactly.** On a correct drop: (1) compute the centroid scene position → screen position via `_controller.toScene()` inverse + `localToGlobal`; (2) insert an `OverlayEntry` that runs a `TweenAnimationBuilder` moving the token widget from tray position to centroid screen position; (3) fade out after landing; (4) state fills matched grey color in the painter; (5) remove the overlay entry. Reference: `FlagsRoundTheWorld/lib/features/map/flag_sequence.dart` + `highlight_painter.dart`.
- **D-10:** **Incorrect drop snackbar duration: short (1.5–2s).** Child-friendly — doesn't block the map while the player wants to try again.

### Completion Screen
- **D-11:** **Port Flags' `completion_screen.dart` star-rating formula:** `score < previousBest → 3 stars`; `score ≤ (previousBest × 1.20).ceil() → 2 stars`; otherwise 1 star. First-time completion always 3 stars (no baseline to compare against).
- **D-12:** **Personal-best badge + confetti overlay** when `score < previousBest`. Port Flags' `AnimationController`-driven PB overlay.
- **D-13:** No `share_plus` or AdMob interstitial on completion in v1 (both are v2 scope). The completion screen's CTA goes straight back to home/mode selection — no ad, no share sheet.

### Home Screen
- **D-14:** **Vertical ListView of 4 mode cards — direct port of Flags' home screen layout.**
- **D-15:** **Each card shows: mode name + one-line description + star rating (1–3 filled/empty stars) + best score (or "—" if never played).** Content hierarchy: name (prominent) → description → stars + score (secondary).
- **D-16:** **Tap card → navigate directly to game screen.** The 5-second countdown (Phase 2 D-01) gives the player time to orient. No intermediate mode-detail screen.

### Claude's Discretion
- Exact palette color assignment for Grand Master token (whether it cycles by alphabetical position, random-per-session, or fixed per state).
- Exact `DragTarget` hit area strategy: one large `DragTarget` covering the entire InteractiveViewer child (dispatch via `stateHitTest()` in `onAcceptWithDetails`) vs. one `DragTarget` per state polygon. Research should evaluate which Flags uses and whether it applies cleanly.
- Pause overlay design (buttons, layout) — port from Flags.
- Countdown animation (3-2-1-GO overlay) — port from Flags.
- Exact `AnimatedSwitcher` transition for new tray token appearance (fade, slide, or scale).
- `shouldRepaint` fields for `UsaMapPainter` when `matchedPostals` grows (set equality vs. length comparison).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 4 Spec & Requirements
- `.planning/ROADMAP.md` §"Phase 4: Full Play Loop" — goal, 5 success criteria (the verification target).
- `.planning/REQUIREMENTS.md` — Phase 4 requirements: DRAG-01, DRAG-02, DRAG-03, DRAG-04, DRAG-05, MODE-01, MODE-02, MODE-03, MODE-04, SCORE-03, SCORE-04, SCORE-06, SCORE-07, HOME-01, HOME-02.
- `.planning/PROJECT.md` — core value ("smooth, forgiving, rewarding above all"), COPPA constraints, 50 placeable states canonical set.
- `CLAUDE.md` — locked stack/versions, "What NOT to Use."

### Prior Phase Context (locked decisions)
- `.planning/phases/03-map-render-coordinate-transform-spike/03-CONTEXT.md` — D-09: MapScreen constructor params (`matchedPostals`, `showLabels`, `mode`). D-01/02: palette colors + matched grey. D-12/13: AnimatedBuilder + viewScale border formula.
- `.planning/phases/02-state-machine-repositories/02-CONTEXT.md` — D-01: 5s countdown. D-02: Stopwatch-as-truth. D-04: `hintsRemaining` starts at 2, `useHint()` applies +5. D-07: autosave cadence. D-09: restore into `paused`. D-10/11: `GameLifecycleObserver` pauses on `.paused` and `.hidden` only.

### Existing This-Repo Code (extend, don't rewrite)
- `lib/features/map/map_screen.dart` — the Phase 3 production MapScreen; Phase 4 extends it with DragTargets, tray, HUD, pause overlay. `_toSceneFromGlobal()` is already defined here.
- `lib/features/map/hit_detection.dart` — `stateHitTest(scenePoint, states, {scale})` is spike-validated; wire directly into `onAcceptWithDetails`.
- `lib/features/map/usa_map_painter.dart` — accepts `matchedPostals: Set<String>`. Phase 4 passes live session state.
- `lib/features/game/game_session_notifier.dart` — `AsyncNotifier` with `placeState()`, `reportError()`, `useHint()`, `pauseGame()`, `resumeGame()`, `completeGame()`. Phase 4 calls these from the map screen.
- `lib/features/game/game_lifecycle_observer.dart` — built in Phase 2; mount to MapScreen in Phase 4 via `WidgetsBinding.instance.addObserver(this)`.
- `lib/features/home/home_screen.dart` — Phase 1 placeholder; Phase 4 replaces body with real mode cards.
- `lib/core/data/high_score_repository.dart` — `getBestScore(mode)` / `saveBestScore(mode, score)` (lower-wins guard); used by home screen to display stars + score, and by completion screen to detect PB.
- `lib/app.dart` — routing; `/play` route needs `GameMode` parameter added; completion screen route needed.

### Reference Codebase (Flags Around the World — port directly)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` — the monolithic game screen (DragTargets, tray integration, HUD, pause overlay, lifecycle observer, hint zoom). Primary port template for Phase 4.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\flag_tray.dart` — `FlagTray` widget: card widget, bounce animation (`_bounceController`), `triggerBounce()`, `kPinAnchor` offset. Replace flag `SvgPicture` with text content per D-01.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_hud.dart` — `GameHud` stateless widget: score, elapsed, progress bar, mute toggle, pause button. Port with 50 states total count.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart` — star formula, PB detection, confetti overlay, play-again CTA. Omit `share_plus` + AdMob (v2 only).
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\flag_sequence.dart` — fly-to-centroid overlay animation pattern (D-09). Adapt for state token.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\highlight_painter.dart` — highlight painter (hint glow; Phase 5) and any drop confirmation visual. Study for overlay animation pattern.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\home_screen.dart` — mode card list layout, `_checkSavedSession()` pattern (omit the ad-loading calls in v1; `_checkSavedSession` is Phase 5 HOME-03).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`MapScreen`** (`lib/features/map/map_screen.dart`): Phase 3 production widget with `_controller`, `_ivKey`, `_toSceneFromGlobal()`, `_zoom()`, zoom buttons, and `AnimatedBuilder`. Phase 4 adds DragTargets, HUD, tray, and pause overlay directly into this widget.
- **`stateHitTest()`** (`lib/features/map/hit_detection.dart`): spike-validated 3-pass hit-test (exact path → expanded bbox → centroid tiebreaker). Takes `scenePoint` and `states` list; returns postal abbreviation. Wire into `onAcceptWithDetails`.
- **`UsaMapPainter`** (`lib/features/map/usa_map_painter.dart`): accepts `matchedPostals: Set<String>`, `showLabels: bool`, `mode: GameMode?`. Phase 4 passes live session state.
- **`GameSessionNotifier`** (`lib/features/game/game_session_notifier.dart`): `AsyncNotifier` with full state machine + scoring. Phase 4 is the first Flutter widget consumer.
- **`GameLifecycleObserver`** (`lib/features/game/game_lifecycle_observer.dart`): auto-pauses on `.paused`/`.hidden`; Phase 4 mounts it.
- **`HighScoreRepository`** (`lib/core/data/high_score_repository.dart`): lower-wins best score per mode; used by both home and completion screens.

### Established Patterns
- Riverpod 3.x + codegen; `ref.watch(gameSessionProvider)` in the game screen; `ref.read(...).future` for repositories.
- `ConsumerStatefulWidget` + `TickerProviderStateMixin` for animation controllers (Flags `_MapScreenState`).
- `OverlayEntry` for fly animation; `Overlay.of(context).insert()` / `remove()`.
- `go_router` navigation: `context.go('/play', extra: mode)` from home screen; `context.go('/complete', extra: session)` from game screen after completion.
- `GlobalKey<FlagTrayState>` re-created on each token advance so `AnimatedSwitcher` can animate the transition (Flags `_trayKey` pattern).

### Integration Points
- **`MapScreen` → `GameSessionNotifier`:** `ref.watch(gameSessionProvider)` drives `matchedPostals`, `showLabels`, `mode`. `onAcceptWithDetails` calls `ref.read(gameSessionProvider.notifier).placeState(postal)`.
- **`MapScreen` → tray token sequence:** The screen holds `_remainingPostals` (shuffled at game start) and `_currentPostal`. On correct drop, advance to next postal and re-create `_trayKey`.
- **`HomeScreen` → `HighScoreRepository`:** watches all 4 mode scores to display star ratings.
- **`CompletionScreen` → `HighScoreRepository`:** reads pre-game best score to detect PB and compute star count.
- **`app.dart`:** `/play` route needs `GameMode` extra; `/complete` route with `GameSession` extra.

</code_context>

<specifics>
## Specific Ideas

- The "forgiving above all" core value directly constrains Phase 4: the short snackbar (D-10) means a child's incorrect drop doesn't block them from trying again. The bounce animation is playful, not punitive.
- Grand Master token as a solid color card (D-02): the palette color should still feel intentional — consider cycling by the state's index in the shuffled sequence so it changes each game, giving no geographic cue from a fixed color-per-state.
- The tray's `kPinAnchor` offset (from Flags `FlagTray`) must be carried through to `DragTargetDetails.offset + kPinAnchor` to recover the true drop coordinate under zoom — this is the exact coordinate-transform invariant the spike validated.
- No "continue game" dialog on the home screen in Phase 4 — that is HOME-03, a Phase 5 requirement. The home screen simply shows mode cards.

</specifics>

<deferred>
## Deferred Ideas

- **"Continue game" dialog** (HOME-03) — Phase 5 requirement. Phase 4 home screen shows no saved session prompt.
- **Hint UI** (HINT-01/02) — Phase 5 wires the zoom-to-centroid / glow animation. Phase 4 shows the hint button count (from `GameSession.hintsRemaining`) but pressing it is a no-op or deferred to Phase 5.
- **Welcome screen + anthem** (WEL-01, WEL-02, WEL-03) — Phase 5.
- **A11y audit** (A11Y-01, A11Y-02) — Phase 5, though Phase 4 should add `Semantics` labels to all interactive controls as it builds them.
- **AdMob completion interstitial** — v2 only. Completion screen in v1 omits the `showInterstitialAd()` call that Flags has.

</deferred>

---

*Phase: 4-Full Play Loop*
*Context gathered: 2026-06-01*
