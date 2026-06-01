# Roadmap: State States

## Overview

State States is built in five phases driven by two hard dependencies: the Python build-time pipeline must produce valid pre-transformed state path data before any rendering or hit-test code is written, and the coordinate-transform spike must pass before any game-mode logic is built. Phase 1 lays the COPPA-compliant foundation and pipeline. Phase 2 builds the pure-Dart game logic (testable in isolation). Phase 3 renders the map and gates all drag-drop work behind a mandatory spike. Phase 4 wires everything into a fully playable four-mode game. Phase 5 adds the welcome screen, anthem, hints, tutorial, session restore, and a COPPA audit — delivering a shippable v1 core.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Python pipeline + data models + service stubs + COPPA baseline (completed 2026-05-31)
- [x] **Phase 2: State Machine & Repositories** - Pure-Dart game logic, scoring, lifecycle, and persistence (completed 2026-05-31)
- [x] **Phase 3: Map Render + Coordinate Transform Spike** - CustomPainter map + mandatory toScene() spike gate (completed 2026-05-31)
- [x] **Phase 4: Full Play Loop** - Four game modes end-to-end: tray, drag-drop, HUD, completion, home screen (completed 2026-06-01)
- [ ] **Phase 5: Polish, Welcome & Accessibility** - Welcome screen, anthem, hints, tutorial, session restore, a11y audit

## Phase Details

### Phase 1: Foundation

**Goal**: The project has a valid, COPPA-compliant skeleton and a build-time pipeline that produces correct `usa_states_paths.json` — the single prerequisite every other phase depends on.
**Depends on**: Nothing (first phase)
**Requirements**: DATA-01, DATA-02, COMP-01, COMP-02, COMP-03, COMP-04, SESS-05
**Success Criteria** (what must be TRUE):

  1. Running `python scripts/generate_states.py` produces `assets/map/usa_states_paths.json` containing 50 state records; Alaska passes `shapely.validation.is_valid()` and renders without an antimeridian smear in a standalone PNG output.
  2. Alaska and Hawaii path coordinates in the JSON are pre-transformed into final inset canvas space — a manual visual check shows AK in the bottom-left inset frame and HI in the bottom-center frame, not at their geographic latitudes.
  3. The Flutter app builds and runs with `google_mobile_ads` declared but `StubAdService` wired; `GameSessionNotifier` has zero ad imports; `aapt dump badging` shows the `AD_ID` permission is absent.
  4. No `firebase_*` package appears in `pubspec.yaml` or `pubspec.lock`; the LICENSES file documents anthem provenance with explicit source, rendering tool, and soundfont.
  5. `StateDataService` loads and parses `usa_states_paths.json` in a compute isolate; the Flutter debug app renders a blank `CustomPaint` canvas without error, confirming the data pipeline is end-to-end wired.

**Plans**: 4 plans
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — COPPA Flutter scaffold: locked pubspec (no Firebase), AndroidManifest AD_ID block, App ID + G/PG, audio assets, LICENSES anthem provenance
- [x] 01-02-PLAN.md — Python pipeline: three-CRS Albers + antimeridian split + inset baking → usa_states_paths.json (50 placeable + DC), with pipeline tests

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-03-PLAN.md — Dart data layer: StateData model, StateDataService compute-isolate loader + provider, blank CustomPaint MapScreen proof, Dart tests

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-04-PLAN.md — Ads/audio walled garden + main/app/home wiring; COPPA build verification (no AD_ID, zero reachable ad imports)

### Phase 2: State Machine & Repositories

**Goal**: All game logic — scoring, timer, state machine transitions, and local persistence — is implemented in pure Dart and unit-tested before any widget depends on it.
**Depends on**: Phase 1
**Requirements**: SCORE-01, SCORE-02, SCORE-05, SESS-01, SESS-02, SESS-03, WEL-04
**Success Criteria** (what must be TRUE):

  1. Unit tests confirm golf scoring: +1 per 10 elapsed seconds + 5 per wrong drop + 5 per hint used, with elapsed computed via `Stopwatch` + `DateTime` snapshots (not `Timer.periodic` tick counting).
  2. Pausing the app for 30 seconds and resuming adds 0 seconds to elapsed time; auto-pause fires on `AppLifecycleState.paused` and the timer does not advance in the background.
  3. A completed game writes its best score to `SharedPreferences`; a cold-launch re-read returns the same value; the mute preference persists across sessions.
  4. A mid-game session snapshot written by `GameStateRepository` can be deserialized back to an identical `GameSession` value object, including mode, score, elapsed, and matched abbreviations.
  5. `RealAudioService` initializes, plays correct/error SFX, and disposes without leaked players; `StubAudioService` is a no-op and passes all the same interface assertions.

**Plans**: 4 plans
Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Core pure-Dart contracts: GamePhase/GameMode enums, GameSession value object (postal renames), Ticker seam + GameSession tests
- [x] 02-04-PLAN.md — WEL-04 audio hardening: document unconditional dispose + leak-free init/play/dispose & StubAudioService interface-parity tests

**Wave 2** *(blocked on 02-01 completion)*

- [x] 02-02-PLAN.md — Repositories: GameStateRepository (explicit hintPenalty, silent-discard), HighScoreRepository (lower-wins, statesMaster key), UserPrefsRepository (mute) + tests

**Wave 3** *(blocked on 02-01 + 02-02 completion)*

- [x] 02-03-PLAN.md — GameSessionNotifier (Stopwatch-as-truth, explicit hintPenalty, restore-to-paused) + GameLifecycleObserver (.paused/.hidden only) + tests

### Phase 3: Map Render + Coordinate Transform Spike

**Goal**: The interactive USA map renders correctly at all zoom levels and the coordinate-transform spike proves that `toScene()` returns accurate scene coordinates — gating all drag-drop work.
**Depends on**: Phase 2
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04
**Success Criteria** (what must be TRUE):

  1. The spike screen (`SpikeMapScreen`) with 5+ named `DragTarget` regions (including simulated AK/HI inset rects) correctly identifies the drop target at 1×, 2×, and 4× zoom with zero misidentifications across all five regions.
  2. Golden tests confirm that a drop at the geometric centroid of each NE seaboard micro-state (RI, DE, CT, NJ, MD) returns the correct abbreviation at both 1× and 4× zoom — five states × two zoom levels = ten assertions all pass.
  3. All 50 state paths render as filled polygons with borders; Alaska renders in the bottom-left inset frame and Hawaii in the bottom-center frame; inset frame rectangles are drawn around each group.
  4. Zoom-in and zoom-out buttons (outside the `InteractiveViewer`) change the scale by the expected factor; after a programmatic zoom, `controller.value.getMaxScaleOnAxis()` matches the visual scale (Matrix4 entry (2,2) is kept in sync).

**Plans**: 5 plans
Plans:
**Wave 1**

- [x] 03-01-PLAN.md — StateDataService → MapData wrapper (states + insetFrameRects from JSON) + hit_detection.dart (stateHitTest pure-Dart port)

**Wave 2** *(blocked on 03-01 completion)*

- [x] 03-02-PLAN.md — UsaMapPainter full implementation (fill + border + inset frame passes) + painter smoke tests
- [x] 03-03-PLAN.md — hit_detection_test.dart: 10 centroid assertions (RI, DE, CT, NJ, MD × scale 1.0 and 4.0) — Criterion 2 hard gate

**Wave 3** *(blocked on 03-02 + 03-03 completion)*

- [x] 03-04-PLAN.md — MapScreen full ConsumerStatefulWidget (InteractiveViewer + AnimatedBuilder + zoom controls) + map_screen_test.dart

**Wave 4** *(blocked on 03-04 completion)*

- [x] 03-05-PLAN.md — SpikeMapScreen (6-region dev-only spike) + app.dart /spike route + spike_map_screen_test.dart — Criterion 1 hard gate

**UI hint**: yes

### Phase 4: Full Play Loop

**Goal**: A player can select any of the four game modes, drag all 50 state tokens to the map, see live scoring and feedback, pause and resume, and reach a completion screen with star ratings — the complete playable core.
**Depends on**: Phase 3
**Requirements**: DRAG-01, DRAG-02, DRAG-03, DRAG-04, DRAG-05, MODE-01, MODE-02, MODE-03, MODE-04, SCORE-03, SCORE-04, SCORE-06, SCORE-07, HOME-01, HOME-02
**Success Criteria** (what must be TRUE):

  1. A player can play all four modes end-to-end: Learn shows abbreviations on map + name in tray; States Master shows name in tray + blank map; Geographical Master shows abbreviations on map + blank tray; Grand Master shows nothing.
  2. Correct drops fill the placed state, play a success sound plus light haptic, and animate a fly-to-centroid confirmation; incorrect drops play an error sound plus medium haptic, show a "not quite" snackbar, and bounce the token back to the tray.
  3. The HUD displays live golf score, elapsed time (MM:SS), and a states-placed progress indicator (0/50 → 50/50) throughout play; pause and resume work with a back-button guard during active sessions.
  4. The completion screen shows the final score, a 1–3 star rating, a personal-best badge when the score beats the stored record, and a confetti overlay on a personal best; a play-again call to action returns to mode selection.
  5. The home screen lists all four mode cards, each showing the player's best score and star rating for that mode (or a blank state if never played).

**Plans**: 6 plans
Plans:
**Wave 1**

- [x] 04-01-PLAN.md — Routing foundation: /play GameMode extra + /complete route + CompletionScreen stub + three Wave 0 test file stubs

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-02-PLAN.md — MapScreen game core: TickerProviderStateMixin, GameLifecycleObserver mount, sequence init (DC filtered, shuffled 50), DragTarget + _handleDrop, PopScope guard, countdown overlay, mode→showLabels mapping
- [x] 04-03-PLAN.md — StateTray widget: port FlagTray with mode-driven card face, bounce animation, GlobalKey discipline, kPinAnchor; state_tray_test MODE-01/04 assertions

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 04-04-PLAN.md — GameHud + fly-to-centroid OverlayEntry: full HUD wired, AnimatedSwitcher StateTray, _animateCorrectDrop, _advanceToNextPostal → /complete navigation

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 04-05-PLAN.md — Full CompletionScreen: star formula, PB badge, confetti overlay, score card, both CTAs; completion_screen_test widget tests
- [x] 04-06-PLAN.md — HomeScreen mode cards: 4 gradient _ModeCard widgets, FutureBuilder scores, tap-to-play navigation; home_screen_test assertions

**UI hint**: yes

### Phase 5: Polish, Welcome & Accessibility

**Goal**: The app opens with a patriotic welcome screen and anthem, players have hints and a first-launch tutorial, in-progress sessions survive app kills, and every interactive control is accessible — delivering a shippable, COPPA-audited v1.
**Depends on**: Phase 4
**Requirements**: WEL-01, WEL-02, WEL-03, HINT-01, HINT-02, SESS-04, HOME-03, A11Y-01, A11Y-02
**Success Criteria** (what must be TRUE):

  1. On first launch, a patriotic opening screen featuring a stylized USA vector silhouette is shown; the "Star-Spangled Banner" instrumental plays with a 500ms fade-in, then fades out seamlessly on navigation to the home screen, with no `PlatformException` in logs during or after the transition.
  2. Using a hint zooms the viewport to the target state's centroid with a ~3-second highlight glow; each hint use adds +5 to the golf score; a round starts with exactly 2 hints and no ad-refill prompt in v1.
  3. Killing and relaunching the app mid-game presents a "continue game" dialog on the home screen showing mode, current score, elapsed time, and states placed; accepting it restores the session exactly.
  4. A 4-step skippable tutorial runs exactly once on first launch and never repeats; a second cold launch skips it entirely.
  5. Every interactive control (HUD buttons, mode cards, tray token) is at least 48×48dp and carries a `Semantics` label; correct/incorrect outcomes are signaled by haptic + audio + visual change — never by color alone; final `aapt dump badging` confirms no `AD_ID` permission.

**Plans**: 7 plans
Plans:
**Wave 0** *(off-device, no Flutter dependency)*

- [x] 05-01-PLAN.md — Anthem rendering: FluidSynth + GeneralUser GS SF2 → assets/audio/anthem.wav; LICENSES provenance update

**Wave 1** *(parallel — 05-02 and 05-03 share no files)*

- [x] 05-02-PLAN.md — Audio service refactor: playAnthem/stopAnthem → fadeInAnthem/fadeOutAnthem (Timer.periodic, 500ms/800ms); anthem.wav path wired in RealAudioService
- [x] 05-03-PLAN.md — app.dart routing + WelcomeScreen: /welcome initial route, /tutorial stub route, stagger USA silhouette CustomPainter, anthem fade-in/out CTA

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 05-04-PLAN.md — TutorialScreen: 4-slide PageView, _completeTutorial() shared by Skip + Done, setTutorialSeen wired; tutorial_screen_test skip/done paths
- [x] 05-05-PLAN.md — Hint animation: MapScreen _hintZoomController + Matrix4Tween, _computeHintMatrix, _onHintPressed; UsaMapPainter hintPostal glow
- [ ] 05-06-PLAN.md — Session restore card: SessionRestoreCard widget + HomeScreen FutureBuilder; home_screen_test HOME-03 coverage

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 05-07-PLAN.md — Accessibility audit: Semantics labels on all Phase 5 controls, androidTapTargetGuideline tests, aapt dump badging COMP-01/02 re-verification

**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete   | 2026-05-31 |
| 2. State Machine & Repositories | 4/4 | Complete   | 2026-05-31 |
| 3. Map Render + Coordinate Transform Spike | 5/5 | Complete   | 2026-05-31 |
| 4. Full Play Loop | 6/6 | Complete   | 2026-06-01 |
| 5. Polish, Welcome & Accessibility | 4/7 | In Progress|  |
