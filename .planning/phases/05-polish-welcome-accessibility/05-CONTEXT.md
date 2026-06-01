# Phase 5: Polish, Welcome & Accessibility - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 delivers the app's first impression and finishing layer — completing v1 into a shippable, COPPA-audited product:

1. **Welcome screen** — Patriotic opening screen with an animated USA silhouette (states fill in with random stagger), deep blue gradient background, title text, and a "Start" CTA.
2. **Anthem** — Self-rendered Star-Spangled Banner WAV rendered as part of this phase; replaces `anthem_placeholder.wav`. Auto-plays on welcome screen load with 500ms fade-in; fades out via ~800ms volume ramp before screen transition.
3. **Hints** — Hint button in the HUD zooms the `InteractiveViewer` viewport to the target state's centroid, plays a ~3s yellow-green glow highlight, then leaves the player zoomed in. Each hint adds +5 score penalty (already wired in `useHint()`); 2 per round.
4. **First-launch tutorial** — 4-slide full-screen `PageView` onboarding that runs once after the welcome screen: Welcome → Drag & Drop → Scoring → Hints. Skippable. Subsequent launches skip directly to home.
5. **Session restore** — A "Resume your game" card at the top of the home screen (above mode cards) when a saved session exists. Shows mode, score, elapsed, states placed. Auto-dismisses when a new game starts.
6. **A11y audit** — Every interactive control ≥48×48dp with `Semantics` labels; correct/incorrect outcomes signaled multimodally (haptic + audio + visual), never by color alone; final `aapt dump badging` confirms no `AD_ID` permission (COMP-01/02 re-verification).

**What is NOT in Phase 5:** AdMob or any real ad calls (v2), Mode 5 speed-typing (v2), gated social sharing (v2), any Firebase package (ever).

</domain>

<decisions>
## Implementation Decisions

### Welcome Screen Visual

- **D-W1:** **Animated fill-in USA silhouette via CustomPainter from `usa_states_paths.json`.** States fill in one by one using the same path data already loaded for the game map. No new assets required.
- **D-W2:** **Random stagger order, ~10–30ms delay per state.** Organic, covers the whole map quickly, no implied geographic order. Total animation ~1–2s.
- **D-W3:** **Solid white states on deep blue gradient background.** Background matches Flags' gradient: `[Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)]`. USA silhouette states fill white. Clean, patriotic, premium feel.
- **D-W4:** **Include Alaska and Hawaii insets** using the same inset layout and transforms baked into `usa_states_paths.json`. Reuses existing data; no extra layout work.

### Anthem

- **D-A1:** **Anthem must be rendered as part of Phase 5.** A rights-clean self-rendered WAV is not yet available. Phase 5 includes a task to render the Star-Spangled Banner instrumental (FluidSynth + SF2 soundfont pipeline or equivalent) and replace `assets/audio/anthem_placeholder.wav`.
- **D-A2:** **Volume tween fade-out (~800ms ramp to 0) before stop.** `RealAudioService.stopAnthem()` ramps `AudioPlayer.setVolume()` to 0 over ~800ms, then calls `stop()`. Satisfies WEL-03 "seamless fade-out" requirement. `AudioService` interface gets a `fadeOutAnthem()` method (or `stopAnthem()` is updated to always fade).
- **D-A3:** **Auto-play on welcome screen load with 500ms fade-in.** Anthem starts at volume 0 and ramps to full over 500ms. No tap required. Matches the ROADMAP success criterion: "500ms fade-in."

### Tutorial

- **D-T1:** **Full-screen onboarding `PageView` (4 slides).** Shown after the welcome screen on first launch only. Simple swipe-or-tap-next navigation. Skip button always visible in the top-right corner.
- **D-T2:** **4-step content:**
  - **Slide 1 — Welcome:** "Learn all 50 states!" — introduces the game concept.
  - **Slide 2 — Drag & Drop:** Shows the tray token + map; explains the core mechanic.
  - **Slide 3 — Scoring:** Golf scoring — lower is better; time and errors add points.
  - **Slide 4 — Hints:** Hints zoom to the target state; use them wisely (+5 each, 2 per round).
- **D-T3:** **Navigation flow:** Welcome → Tutorial (first launch only) → Home. On subsequent launches: Welcome → Home. The welcome screen checks `UserPrefsRepository.getTutorialSeen()` after the anthem starts; if false, navigates to `/tutorial`; if true, navigates to `/`. Tutorial completion and skip both call `setTutorialSeen(true)` before `context.go('/')`.

### Hints

- **D-H1:** **`AnimationController` tween on `TransformationController` matrix.** A dedicated `AnimationController` in `MapScreen` drives a `Matrix4Tween` from the current `_controller.value` to a target matrix that centers the target state's centroid on screen at ~2.5× zoom. On animation completion, the glow is active for ~3 seconds.
- **D-H2:** **Stay zoomed in after the glow ends.** The viewport remains at the hint zoom level. The player can pan/zoom freely from there. No reverse animation.
- **D-H3:** **Hint glow color: `0xFFBBFF44` yellow-green.** Direct port of Flags' `HighlightPainter._drawHintHighlight()` color. `UsaMapPainter` gains a `hintPostal: String?` parameter; when non-null, the target state is rendered with the yellow-green fill during the glow window.

### Session Restore

- **D-S1:** **Prominent card at the top of the home screen** (above the mode cards). Shows mode name + icon, current score, elapsed time (MM:SS), and states placed count (e.g., "23 / 50"). Two inline buttons: "Continue" and "Dismiss."
- **D-S2:** **Auto-dismisses when a new game starts.** Tapping any mode card calls `GameStateRepository.clearSession()` (or `startGame()` which clears it) and navigates to `/play`. The home screen reloads after returning from a new game with no saved session, so the card is gone. The card does NOT have a persistent in-memory dismissed flag — it reads from `GameStateRepository.loadSession()` on each home screen build.

### Claude's Discretion
- Exact timing curve for the `Matrix4Tween` zoom animation (e.g., `Curves.easeInOut` or `Curves.fastOutSlowIn`).
- Exact `AnimatedSwitcher` or `AnimatedContainer` transition for the tutorial `PageView` (slide vs. fade).
- Welcome screen title text, subtitle copy, and CTA button label ("GET STARTED" / "START" / "LET'S GO").
- Tutorial slide illustration/icon choices (Material Icons or custom shapes).
- Exact stagger timing distribution (uniform random vs. weighted toward center-first for visual interest).
- `shouldRepaint` logic for the welcome screen `CustomPainter` (driven by animation progress value).
- Whether `fadeOutAnthem()` is a new `AudioService` method or replaces `stopAnthem()` in the interface.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 5 Spec & Requirements
- `.planning/ROADMAP.md` §"Phase 5: Polish, Welcome & Accessibility" — goal, 5 success criteria (the verification target).
- `.planning/REQUIREMENTS.md` — Phase 5 requirements: WEL-01, WEL-02, WEL-03, HINT-01, HINT-02, SESS-04, HOME-03, A11Y-01, A11Y-02.
- `.planning/PROJECT.md` — core value, COPPA constraints, offline requirement.
- `CLAUDE.md` — locked stack/versions, "What NOT to Use", "no spinning globe" constraint.

### Prior Phase Context (locked decisions)
- `.planning/phases/04-full-play-loop/04-CONTEXT.md` — D-H1/H2 from Phase 4: hint button shows `hintsRemaining` count but pressing is a no-op; Phase 5 wires the animation. D-W1: welcome screen is Phase 5. D-T1: tutorial is Phase 5.
- `.planning/phases/02-state-machine-repositories/02-CONTEXT.md` — D-04: `hintsRemaining` starts at 2, `useHint()` applies +5 penalty. D-07: autosave cadence. D-09: `restoreGame()` lands in `GamePhase.paused`.

### Existing This-Repo Code (extend, don't rewrite)
- `lib/core/audio/real_audio_service.dart` — `_anthemPlayer` already set up with `LoopMode.one`; `playAnthem()` / `stopAnthem()` defined. Phase 5 adds volume-ramp fade-out and 500ms fade-in.
- `lib/core/audio/audio_service.dart` — `AudioService` interface; Phase 5 may add `fadeOutAnthem()` or update `stopAnthem()` contract.
- `lib/core/data/user_prefs_repository.dart` — `getTutorialSeen()` / `setTutorialSeen()` already implemented. Phase 5 consumes these.
- `lib/core/data/game_state_repository.dart` — `loadSession()` / `saveSession()` implemented. Phase 5 home screen calls `loadSession()` to render the resume card.
- `lib/features/game/game_session_notifier.dart` — `useHint()` returns `bool`; already applies +5 penalty and decrements `hintsRemaining`. Phase 5 wires the zoom animation in `MapScreen` after a `true` return.
- `lib/features/map/map_screen.dart` — `_controller` (`TransformationController`), `_ivKey`, `_toSceneFromGlobal()`, hint button in HUD (currently no-op). Phase 5 adds `AnimationController` + `Matrix4Tween` zoom, `hintPostal` state, and `HighlightPainter`-equivalent glow in `UsaMapPainter`.
- `lib/features/map/usa_map_painter.dart` — gains `hintPostal: String?` parameter for the yellow-green glow.
- `lib/features/home/home_screen.dart` — gains resume-session card at top of `_buildBody()`, reading from `GameStateRepository.loadSession()`.
- `lib/app.dart` — routing: `/welcome` as initial route, `/tutorial` route added, `/` (home) as post-tutorial destination.

### Reference Codebase (Flags Around the World — port/adapt)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\welcome_screen.dart` — structure to port (gradient background, title, CTA, privacy footer). Replace `_GlobeHero` with USA silhouette `CustomPainter`.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\highlight_painter.dart` — `_drawHintHighlight()` pattern (color `0xFFBBFF44`, fill degenerate vs. path logic). Port the hint glow logic into `UsaMapPainter` directly (no separate painter layer needed for single-state highlight).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`usa_states_paths.json`** (`assets/map/usa_states_paths.json`): Already contains 50 state path strings + centroids + AK/HI inset transforms. Welcome screen `CustomPainter` reuses the same `StateDataService` provider to get the paths — no second data load needed.
- **`RealAudioService._anthemPlayer`** (`lib/core/audio/real_audio_service.dart`): Already a dedicated `AudioPlayer` with `LoopMode.one` and `anthem_placeholder.wav` loaded. Phase 5 swaps the asset file and adds fade logic.
- **`UserPrefsRepository`** (`lib/core/data/user_prefs_repository.dart`): `getTutorialSeen()` / `setTutorialSeen()` are ready. Tutorial screen and welcome screen can call these directly.
- **`GameStateRepository.loadSession()`** (`lib/core/data/game_state_repository.dart`): Returns `({GameSession session, int hintPenalty})?` — null means no saved session. Home screen checks this to show/hide the resume card.
- **`useHint()`** (`lib/features/game/game_session_notifier.dart:195`): Returns `bool` — `true` if hint consumed, `false` if none remaining or not in playing phase. `MapScreen` checks the return value to trigger zoom animation.
- **`TransformationController _controller`** (`lib/features/map/map_screen.dart`): Existing controller with current zoom/pan matrix. `Matrix4Tween` can interpolate from `_controller.value` to a computed target matrix.

### Established Patterns
- **Riverpod `FutureProvider`** for `stateDataProvider`: Welcome screen silhouette `CustomPainter` gets `StateData` list via `ref.watch(stateDataProvider)` — same pattern as `MapScreen`.
- **`ConsumerStatefulWidget` + `TickerProviderStateMixin`**: Required for the welcome screen's stagger `AnimationController` and `MapScreen`'s hint zoom `AnimationController`.
- **`go_router` extra params**: Tutorial seen check happens in welcome screen's `initState` or via a redirect; use `context.go('/tutorial')` vs `context.go('/')`.
- **`OverlayEntry` pattern** (from Phase 4 fly animation): Already established for transient map overlays. Hint glow does NOT need an overlay — it's rendered inside `UsaMapPainter` directly via `hintPostal`.
- **`AnimatedBuilder` + `TransformationController`**: Already used in `MapScreen` for the zoom button label. The hint zoom animation follows the same `AnimatedBuilder` + controller pattern.

### Integration Points
- **`app.dart` routing**: Add `/welcome` as the initial route (replacing `/` as the first screen). Add `/tutorial` route. `/welcome` navigates to `/tutorial` or `/` based on tutorial-seen flag.
- **`MapScreen` hint button**: Currently no-op (from Phase 4). Phase 5 wires `onPressed` to call `ref.read(gameSessionProvider.notifier).useHint()` and, on `true` return, triggers the `_hintZoomController.forward()` animation sequence.
- **`UsaMapPainter`**: Add `hintPostal: String?` parameter. In `paint()`, after drawing matched states, draw the hint highlight if `hintPostal != null`. Pass from `MapScreen`'s `_hintPostal` state variable (set on hint use, cleared after ~3s via `Timer`).
- **`HomeScreen._buildBody()`**: Reads `GameStateRepository.loadSession()` (wrapped in a `FutureBuilder` or `FutureProvider`) and conditionally renders the resume card above the `ListView` of mode cards.

</code_context>

<specifics>
## Specific Ideas

- The welcome screen `CustomPainter` should draw the USA at a comfortable size in the center of the screen (roughly 70–80% of screen width), leaving room above for the title/subtitle and below for the CTA button. The same `viewBox` coordinate system from `usa_states_paths.json` can be scaled to fit via a `canvas.scale()` transform.
- The 500ms anthem fade-in on welcome screen load is specified in the ROADMAP success criterion — it's a hard requirement, not an aesthetic touch.
- The tutorial `PageView` must set `setTutorialSeen(true)` on both "Skip" (any point) and natural completion (last slide next-tap). Neither path should leave the flag unset.
- The resume card's elapsed time should format identically to the in-game HUD (MM:SS) for consistency.
- The hint zoom target matrix: center the state's centroid at screen center and set zoom to ~2.5× (enough to see the state clearly). Clamp to `InteractiveViewer`'s `minScale`/`maxScale` to avoid constraint violations.
- `UsaMapPainter.shouldRepaint` must include `hintPostal` in its comparison — a hint that starts or ends while the user is dragging must trigger a repaint.

</specifics>

<deferred>
## Deferred Ideas

- **AdMob + mediation** — v2 scope. No ad calls in Phase 5. `StubAdService` remains wired.
- **Rewarded-ad hint refill** — v2 scope. Phase 5 hint button shows 0 remaining and is disabled; no "Watch ad for more hints" prompt.
- **Gated social sharing** — v2 scope.
- **Mode 5 Speed Typing** — v2 scope.

</deferred>

---

*Phase: 5-Polish-Welcome-Accessibility*
*Context gathered: 2026-06-01*
