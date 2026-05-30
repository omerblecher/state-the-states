# Project Research Summary

**Project:** State States
**Domain:** Flutter cross-platform educational drag-and-drop USA map game (ages 8+, COPPA/Families, offline)
**Researched:** 2026-05-30
**Confidence:** HIGH

## Executive Summary

State States is a direct architectural descendant of *Flags Around the World*. All four research threads converge on a single recommendation: port the Flags codebase for the Flutter/Riverpod/CustomPainter core and spend the project's novelty budget on the USA-specific problems Flags never had to solve -- Alaska/Hawaii insets, the Aleutian antimeridian, and the northeastern seaboard micro-state cluster. The stack is nearly identical to Flags (only six package-level deltas, all minor version bumps); the architecture is a direct structural port; and the feature set maps cleanly onto Flags' phase pattern with four game modes in v1 and Mode 5 / sharing / AdMob deferred to v2.

The single highest technical risk -- confirmed independently by all four researchers -- is the tray-outside / DragTargets-inside coordinate transform. The `StateTray` Draggable lives outside `InteractiveViewer` and delivers drop events in global screen space. Every hit test must convert those coordinates through `TransformationController.toScene(ivBox.globalToLocal(offset + kPinAnchor))` to recover scene-space positions. This bug is invisible at 1x zoom and catastrophic at 3-4x, which is exactly where players zoom to place small states. A mandatory spike must gate Phase 3 before any drag-drop game logic is built.

The second non-negotiable constraint is COPPA/Families compliance, which runs across every phase and is not recoverable if missed early. Specifically: `AD_ID` permission must be blocked in `AndroidManifest.xml` from project initialisation (not at ad-integration time), no Firebase package may ever enter the dependency graph, mediation SDKs must not be added to `pubspec.yaml` before v2, and the anthem must be self-rendered from the public-domain composition score -- a downloaded recording, even from a "royalty-free" site, is a separate copyrightable work that can trigger a DMCA takedown after launch.

## Key Findings

### Recommended Stack

The State States stack matches the Flags lockfile almost exactly. Raise the Flutter SDK lower-bound from `>=3.32.0` to `>=3.44.0` (current stable, Dart 3.10) to capture `CustomPainter` and `InteractiveViewer` performance improvements. The six package deltas are all minor: `share_plus` `^10.0.0` to `^13.1.0` (API unchanged, deferred to v2 anyway), `url_launcher` `^6.3.0` to `^6.3.2` (patch), `flutter_lints` `^5.0.0` to `^6.0.0` (new rules added, none removed), `flutter_launcher_icons` `^0.14.3` to `^0.14.4` (patch), Dart SDK lower-bound `>=3.7.0` to `>=3.10.0`. Everything else -- Riverpod 3.3.1, go_router 17.2.3, flutter_svg 2.3.0, path_drawing 1.0.1, just_audio 0.10.5, shared_preferences 2.5.5, google_mobile_ads 8.0.0 and all four mediation packages -- is identical to Flags.

The map data pipeline is a build-time Python script (geopandas + shapely), not a runtime dependency. Source: Natural Earth admin-1 10m (v5.1.1, public domain). Output: `assets/map/usa_states_paths.json` with state abbreviation, SVG path strings, bounding box, centroid, and `insetGroup` metadata. All path coordinates -- including Alaska and Hawaii -- must be pre-transformed into final canvas coordinate space by the pipeline; the Dart side draws every state identically with no coordinate-space special-casing. This is the critical design invariant that makes `hitTest()` work without branching.

**Core technologies:**
- `flutter_riverpod ^3.3.1` + `riverpod_annotation ^4.0.2` + `riverpod_generator ^4.0.3`: state management with codegen -- exact Flags pattern, no delta
- `CustomPainter` + `InteractiveViewer` + `TransformationController`: map rendering and pan/zoom -- locked decision from Flags CLAUDE.md; flutter_map and Syncfusion are explicitly excluded
- `path_drawing ^1.0.1`: converts bundled SVG path strings to `dart:ui Path` objects at startup; single-use, no alternatives
- `just_audio ^0.10.5`: audio playback -- supersedes the PROJECT.md audioplayers mention; audioplayers is excluded for one-stack consistency with Flags
- `shared_preferences ^2.5.5`: all local persistence (scores, prefs, session snapshot) -- fully offline, no accounts, COPPA requirement
- `go_router ^17.2.3`: navigation with onExit back-button guard during active games
- `google_mobile_ads ^8.0.0` (+ four mediation packages): declared in v1 pubspec for structural parity, wired only as StubAdService until v2; mediation packages must NOT be added to pubspec before v2
- Python pipeline (geopandas + shapely): build-time only; produces the JSON asset bundle; not a runtime Flutter dependency
- No Firebase -- ever. Hard constraint. COPPA prohibits the persistent App Instance ID that firebase_core assigns.

### Expected Features

**Must have (table stakes for v1 launch):**
- Interactive USA vector map: mainland + Alaska/Hawaii insets, pan/zoom via InteractiveViewer
- Drag-and-drop state token tray (outside IV) onto DragTarget inside IV with toScene() coordinate transform
- 48dp centroid proximity-snapping for micro-states (RI, DE, CT, NJ, MD, NH, VT) -- PROJECT.md explicit requirement
- Correct-drop feedback: light haptic + success SFX + fly-to-centroid animation (Flags port)
- Wrong-drop feedback: medium haptic + error SFX + bounce + "not quite" snackbar (Flags port)
- Four progressive game modes (Learn / States Master / Geographical Master / Grand Master) with label-visibility matrix driving UsaMapPainter(showLabels) and StateTray(showName) independently
- Golf-style scoring (+1/10s elapsed + 5/error + 5/hint) displayed live in HUD
- Hint system: 2 hints per round, zoom-to-centroid + 3s glow, +5 score penalty per use
- Progress bar (states placed / 50) and elapsed timer MM:SS in HUD
- Pause/resume overlay with auto-pause on AppLifecycleState.paused
- Completion screen: 1-3 stars, personal-best badge, confetti overlay on PB, play-again CTA
- Local best score per mode via shared_preferences
- Session persistence: mid-game app-kill resume via GameStateRepository
- First-launch skippable tutorial (4 steps)
- Patriotic welcome screen + self-rendered Star-Spangled Banner anthem with fade-out
- Mute toggle (HUD + pause screen) persisted via UserPrefsRepository

**Should have (differentiators):**
- Font scaling with InteractiveViewer zoom (fontSize = 11.0 / viewScale) so abbreviations stay legible at all zoom levels -- competitor web games have static labels that become illegible on mobile
- Zoom-floor hint for NE seaboard cluster: "Try zooming in" after two wrong drops on any micro-state
- Continue-saved-game dialog on home screen relaunch showing mode/score/elapsed context -- no competitor offers session continuity
- RepaintBoundary scaffold on completion screen score card (share button hidden in v1, no structural refactor needed for v2)

**Defer to v2+:**
- Mode 5: Speed Typing Challenge -- independent of map engine, PROJECT.md explicit deferral
- Gated social sharing -- requires parental math gate + share_plus + RepaintBoundary screenshot; PROJECT.md explicit deferral
- Full AdMob + mediation (Banner / Interstitial / Rewarded / App Open) -- COPPA-compliant ad config is complex; PROJECT.md explicit deferral
- Rewarded-ad hint refill -- refillHints() already in notifier, just needs ad layer wiring in v2
- Washington D.C. as a placeable entity -- explicitly excluded; canonical set is 50 states

### Architecture Approach

The architecture is a feature-first Flutter project with three layers: `core/` (pure Dart logic, no widgets: models, repositories, audio service, ad service stub), `features/` (presentation: home, game, map, ads shells), and a build-time Python asset pipeline. The state layer is Riverpod `AsyncNotifier<GameSession>` driving a phase state machine (idle to countdown to playing to paused to completed). Two critical rules lock the architecture: (1) `GameSessionNotifier` has zero imports from the ads layer -- the ad walled-garden is enforced at the import level, not by convention -- and (2) all path coordinates in the JSON asset are pre-transformed into final canvas space so `hitTest()` requires no coordinate-space branching.

**Major components:**
1. `UsaMapPainter` (CustomPainter, isComplex=true, no willChange): draws all 50 state paths, inset frame rects, scale-adaptive abbreviation labels; receives matchedAbbrs, showLabels, viewScale as constructor params; no Riverpod dependency
2. `HighlightPainter` (CustomPainter, willChange=true): hover gold fill, target-ring, hint glow; separated from base map so 60fps drag-hover does not trigger a full repaint of 50 paths
3. `GameSessionNotifier` (AsyncNotifier): owns Ticker, elapsed, error count, hint penalty, golf score; zero ads imports; drives phase state machine; persists session snapshot on each correct drop
4. `StateTray` (Draggable outside InteractiveViewer): kPinAnchor offset corrects drop coordinate; cardKey on child only, never on feedback (GlobalKey uniqueness constraint)
5. `hitTest()` (pure function): scene-space Offset to abbreviation or null; scale-aware 48dp centroid expansion; path-contains first, expanded-bbox fallback, centroid tiebreaker; ports hit_detection.dart verbatim with isoCode renamed to abbr and world-wrap modulo removed
6. `StateDataService` (FutureProvider): compute() isolate for JSON decode, chunked main-thread Path construction (30 states per chunk)
7. `AdService` / `StubAdService`: abstract interface; stub returns SizedBox.shrink() and false from all methods; real AdMobAdService wired only in Phase 6

### Critical Pitfalls

1. **toScene() coordinate transform skipped or wrong** -- gate the entire drag system behind a mandatory spike: drag tokens over five DragTargets at 1x, 2x, and 4x zoom and assert the correct target is always hit. The bug is invisible at 1x and catastrophic at 3-4x. Do not build any game mode logic before this spike passes.

2. **Alaska/Hawaii inset paths not pre-transformed in the Python pipeline** -- if StateData.paths and StateData.centroid for AK and HI store geographic (non-inset) coordinates, a token dropped on the visible inset frame hits ocean/Canada in scene space and never matches. The Python pipeline must apply the inset scale+translate transform to path coordinates before emitting JSON. The insetGroup field is metadata only; the Dart side draws every state identically.

3. **Alaska Aleutian Islands crossing the antimeridian** -- Natural Earth's Alaska geometry contains antimeridian-crossing polygon rings. A naive (-180,180) to (0, scene_width) coordinate remap shatters the Aleutian chain into a horizontal line across the full canvas. Use the `antimeridian` Python package to split crossing rings before remapping. Run `shapely.validation.is_valid()` on the Alaska geometry as a pipeline gate.

4. **NE seaboard micro-state hitbox overlap (RI/DE/CT/NJ/MD)** -- at default zoom, five 48dp-expanded hitboxes merge into one blob; the centroid tiebreaker always resolves to the same state, making four of the five effectively unhittable. Prevention: add a zoom-floor check (if the drop point neighbourhood contains 3+ expansion zones, show "zoom in to place" hint). Write golden tests for each of the five micro-states at 1x and 4x zoom before wiring to game logic.

5. **COPPA/Families traps even with ads stubbed** -- google_mobile_ads auto-injects AD_ID into the merged manifest. Add `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:remove="true"/>` from day one. Do not add mediation SDK packages to pubspec.yaml until v2. Never add any firebase_* package -- treat any PR doing so as a hard blocker.

6. **Anthem recording rights** -- the Star-Spangled Banner composition is public domain; a specific recording is not. Self-render from a PD MIDI score using FluidSynth + a free SF2 soundfont; document provenance in a LICENSES file. Resolve in Phase 1 asset sourcing before any audio file is committed to the repo.

7. **just_audio fade-out race on route transition** -- if the anthem fade-out Future.delayed callback fires on a disposed AudioPlayer after the user navigates away, it causes a PlatformException. Make AudioService a singleton Riverpod provider (lifetime exceeds any single screen); hold a Timer reference in state and cancel it in dispose() before calling player.stop() then player.dispose().

## Implications for Roadmap

Research suggests a six-phase build order driven by two hard dependencies: (1) the Python pipeline must produce valid JSON before any Dart rendering or hit-test code is written, and (2) the coordinate-transform spike must pass before any game mode logic is built. This matches the build order recommended in ARCHITECTURE.md and aligns exactly with the v1/v2 scope split in PROJECT.md.

### Phase 1: Foundation -- Pipeline, Models, Services, COPPA Baseline

**Rationale:** Everything else depends on having valid StateData with pre-transformed dart:ui Path objects and verified Alaska/Hawaii inset coordinates. COPPA compliance (manifest, no Firebase, anthem provenance) must be established before any other work to avoid costly late corrections.

**Delivers:**
- Python pipeline: Natural Earth admin-1 to usa_states_paths.json with inset transforms, antimeridian-split Alaska, centroids
- StateData model + StateDataService (FutureProvider, compute isolate, chunked Path construction)
- GameMode / GamePhase enums, GameSession value object
- AudioService abstract interface + RealAudioService skeleton + StubAudioService
- AdService abstract interface + StubAdService (full; never changes until Phase 6)
- ARB baseline with 50 state names
- AD_ID blocked in AndroidManifest.xml; no Firebase; anthem sourced and provenance documented in LICENSES file

**Addresses:** Map canvas dependency, COPPA manifest baseline, anthem rights, audio lifecycle foundation

**Avoids:** Alaska inset coordinate space mismatch (Pitfall 2), Aleutian antimeridian corruption (Pitfall 3), COPPA AD_ID trap (Pitfall 10), anthem DMCA (Pitfall 9), audio dispose race (Pitfall 8)

**Research flag:** LOW -- patterns are direct ports from Flags. Verify adm0_a3/postal field names when downloading the shapefile for the first time (MEDIUM confidence per STACK.md).

### Phase 2: State Machine, Repositories, Data Layer

**Rationale:** GameSessionNotifier is pure Dart with no Flutter dependency. Testing the state machine, golf scoring, and persistence before any widget exists catches bugs that would be expensive to root-cause later. The Stopwatch-based timer pattern must be established here, not retrofitted.

**Delivers:**
- Ticker / RealTicker (Flags port verbatim)
- GameSessionNotifier (AsyncNotifier; isoCode renamed to abbr; Stopwatch + DateTime snapshot elapsed; zero ads imports)
- HighScoreRepository, UserPrefsRepository, GameStateRepository (Flags ports; sequential async read-modify-write)
- Unit tests: state machine transitions, golf scoring formula, timer pause/resume accuracy, persistence race condition

**Addresses:** Golf scoring, session persistence, local best scores

**Avoids:** Golf timer drift on background (Pitfall 6), best-score persistence race (Pitfall 7)

**Research flag:** LOW -- direct Flags port with rename. Copy _zoom() / _fitMapToScreen() / _animateHintZoom() verbatim from Flags map_screen.dart for Matrix4 (2,2) fix; do not reimplement from memory.

### Phase 3: Map Render + Coordinate Transform Spike (GATE)

**Rationale:** The highest-risk phase. The coordinate transform spike is a hard gate: do not build StateTray or drop-handling logic until the spike confirms TransformationController.toScene() produces correct scene coordinates at 1x, 2x, and 4x zoom, including over the AK/HI inset regions.

**Delivers:**
- SpikeMapScreen: 5+ DragTargets including simulated AK/HI inset rects; manual QA at 1x/2x/4x zoom
- UsaMapPainter (CustomPainter, isComplex): mainland fills + borders + inset frame rects + scale-adaptive abbreviation labels; all 4 mode visibility combinations
- HighlightPainter (willChange=true, RepaintBoundary): hover fill, target ring, hint glow (Flags port, abbr rename)
- hitTest() (pure function): path-contains + expanded-bbox fallback + centroid tiebreaker; world-wrap modulo removed; scale-aware 48dp expansion
- Golden tests: RI, DE, CT, NJ, MD drop-at-centroid returns correct abbreviation at 1x and 4x zoom
- MapScreen skeleton with InteractiveViewer + TransformationController + _fitMapToScreen() + _onScaleChanged() threshold gate

**Addresses:** Interactive map rendering, pan/zoom, micro-state hit detection

**Avoids:** toScene() coordinate transform failure (Pitfall 1), micro-state hitbox overlap (Pitfall 4), abbreviation label scaling miscalibration (Pitfall 5), Matrix4 (2,2) sync issue (Pitfall 11)

**Research flag:** HIGH -- this phase contains the project's primary technical risk. The spike is mandatory before any dependent work proceeds. Do not parallelize Phase 4 with this phase.

### Phase 4: Full Game Modes + Play Loop

**Rationale:** Requires Phase 3's painters (rendering verified) and Phase 2's notifier (game logic verified). This is the largest phase -- wiring everything into four complete game modes.

**Delivers:**
- StateTray (Draggable outside IV; kPinAnchor matches feedback geometry exactly; cardKey on child only, never on feedback)
- GameHud (stateless HUD strip: score, elapsed MM:SS, progress bar 0-50, pause button, mute button)
- Full MapScreen._buildMap() with mode-driven showLabels/showName booleans, _handleDrop(), _advanceToNextState(), _animateCorrectDrop() fly-to-centroid overlay
- buildStateSequence() / buildGrandMasterSequence() (Flags port)
- Pause overlay, back-button guard, WidgetsBindingObserver lifecycle auto-pause
- CompletionScreen: stars, PB badge, confetti painter, RepaintBoundary score card (v2 share scaffold built but hidden)
- All four game modes end-to-end playable

**Addresses:** All four game modes, golf scoring live display, correct/wrong multimodal feedback, pause/resume, completion flow

**Avoids:** GlobalKey duplicate on Draggable child/feedback, ads imported from GameSessionNotifier, setState on every pointer move during scale

**Research flag:** LOW to MEDIUM -- heavy phase but patterns are all Flags ports. Validate label visibility matrix (4 modes x 2 booleans) before marking done.

### Phase 5: Polish, Welcome Screen, Anthem, Accessibility, COPPA Audit

**Rationale:** Welcome screen and anthem require stable audio service and routing. Tutorial, hint system, and session restore are polish on a working game loop. COPPA audit is the final gate before any Play Store submission.

**Delivers:**
- WelcomeScreen: patriotic USA silhouette vector, anthem playback with 500ms fade-in on launch and fade-out on navigation
- RealAudioService.playAnthem() / stopAnthem() with Timer-held fade (cancel in dispose); singleton Riverpod provider lifetime
- Tutorial overlay (4-step skippable; UserPrefsRepository.tutorialSeen gate)
- Hint system: zoom-to-centroid animation + 3s HighlightPainter glow + +5 score penalty per use; 2 hints/round, no refill in v1
- Session restore: GameStateRepository continue-game dialog on home screen relaunch
- Accessibility audit: Semantics labels on all interactive controls, 48dp tap target verification, WCAG 4.5:1 colour contrast check
- COPPA final audit: aapt dump badging shows no AD_ID; pubspec.lock shows no firebase_*; LICENSES file documents anthem provenance

**Addresses:** Welcome/audio differentiator, hints, session continuity, tutorial for ages 8+

**Avoids:** Audio dispose race (Pitfall 8, final verification), anthem DMCA (Pitfall 9, final check)

**Research flag:** LOW for game features (Flags ports). MEDIUM for anthem rendering -- FluidSynth + SF2 build pipeline is not in Flags; verify the toolchain before committing Phase 5 timing.

### Phase 6: Ad Layer -- v2, Walled Garden Lifted

**Rationale:** Deferred per PROJECT.md. The walled-garden pattern established in Phase 1 makes this entirely additive: only ad_service_provider.dart switches from StubAdService to AdMobAdService. No game logic changes required.

**Delivers:**
- AdMobAdService real implementation
- ads_initializer.dart: tagForChildDirectedTreatment(true) set on RequestConfiguration before MobileAds.initialize(); same child-directed flag set independently on each mediation SDK
- Mediation SDK packages added to pubspec.yaml (not before this phase)
- Banner on HomeScreen and CompletionScreen; interstitial on game completion only (never mid-round, never on pause)
- Rewarded ad for hint refill (refillHints() already in notifier)
- App Open ad with gameplay suppression in app.dart

**Avoids:** COPPA config-order trap (config before init), mediation SDK identifier collection in v1

**Research flag:** HIGH -- COPPA-compliant ad init sequence and per-SDK child-directed flags require careful documentation; plan a dedicated research sub-task at phase start.

### Phase Ordering Rationale

- Pipeline before painters: StateData.paths in correct coordinate space is a prerequisite for every rendering and hit-test decision; building UsaMapPainter against placeholder data embeds assumptions the real pipeline may invalidate
- State machine before widgets: GameSessionNotifier is pure Dart; testing in isolation prevents scoring and timer bugs from being masked by widget complexity
- Coordinate-transform spike gates Phase 4: if toScene() does not work correctly for AK/HI inset regions, the pipeline output needs redesign before any game mode work begins
- Polish after playable core: tutorial, hints, session restore, and anthem all depend on a stable game loop; introducing them earlier causes churn
- Ads last: the walled-garden pattern makes Phase 6 a purely additive change with zero game-logic modifications

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (coordinate transform spike):** highest technical risk in the project; dedicate a spike task before the phase begins, not as the first task within it
- **Phase 5 (anthem rendering):** FluidSynth + SF2 build pipeline is not in Flags; verify the toolchain before committing Phase 5 timing
- **Phase 6 (AdMob + mediation):** COPPA-compliant ad init sequence and per-SDK child-directed flags require careful documentation; plan a research sub-task at phase start

Phases with standard patterns (skip research-phase):
- **Phase 1 (pipeline + models):** geopandas/shapely pipeline is a direct port of generate_map.py; antimeridian split has a known Python package
- **Phase 2 (state machine):** direct Flags port with field renames; Riverpod AsyncNotifier pattern is thoroughly documented
- **Phase 4 (game modes):** all patterns are Flags ports; complexity is in volume, not novelty

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions verified against pub.dev; Flags lockfile read directly; six minor deltas all confirmed |
| Features | HIGH | Reference codebase read directly; competitor feature sets verified via multiple external sources; PROJECT.md scope is authoritative |
| Architecture | HIGH | Flags source code read line-by-line; all patterns confirmed in production code, not documentation alone |
| Pitfalls | HIGH (ported) / MEDIUM (USA-specific) | Coordinate transform, golf timer, audio dispose, COPPA traps are HIGH -- proven in Flags. Antimeridian split and micro-state cluster are MEDIUM -- well-documented patterns not previously in this codebase |

**Overall confidence:** HIGH

### Gaps to Address

- **Natural Earth shapefile field names** (adm0_a3, postal, name, iso_3166_2): confirmed via community usage patterns (MEDIUM confidence). Verify by inspecting the actual shapefile attribute table on first download before writing the filter logic.
- **Alaska inset scale constants**: ARCHITECTURE.md specifies approximate values (scale ~0.35x, translate to x:0-250, y:430-620 in 1000x620 viewBox) but these must be calibrated visually against a rendered PNG output of the pipeline. Treat as initial estimates, not final values.
- **Anthem rendering toolchain**: FluidSynth + SF2 is the recommended approach but was not executed during research. Verify the build-time rendering step (install, render command, output format, soundfont licence) before committing it as the Phase 5 delivery mechanism.
- **NE seaboard zoom-floor threshold**: the specific number of overlapping expansion zones that triggers the zoom-in hint needs empirical calibration during Phase 3 golden-test work. Start with N >= 3 and adjust based on playtest.
- **SharedPreferences iOS flush race** (flutter/flutter#128368): an open issue where writes may not flush before process kill. Mitigate by calling prefs.reload() before any read at session start; monitor during Phase 2 testing on a physical iOS device.

## Sources

### Primary (HIGH confidence)
- `C:\code\Claude\FlagsRoundTheWorld\pubspec.yaml` -- authoritative Flags lockfile, baseline for all package decisions
- `C:\code\Claude\FlagsRoundTheWorld\CLAUDE.md` -- locked architecture decisions (CustomPainter, no Firebase, no flutter_map, no Syncfusion)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` -- toScene() pattern, Matrix4 (2,2) fix, audio lifecycle
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\hit_detection.dart` -- proximity-snap algorithm, centroid tiebreaker
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\world_map_painter.dart` -- label scaling, viewScale-aware font size
- `C:\code\Claude\FlagsRoundTheWorld\scripts\generate_map.py` -- Python pipeline design
- `C:\code\Claude\StateTheStates\.planning\PROJECT.md` -- scope, v1/v2 split, hard constraints
- pub.dev -- all package versions verified (flutter_riverpod 3.3.1, go_router 17.2.3, flutter_svg 2.3.0, just_audio 0.10.5, google_mobile_ads 8.0.0, shared_preferences 2.5.5, intl 0.20.2, share_plus 13.1.0, flutter_lints 6.0.0)
- Flutter API docs -- https://api.flutter.dev/flutter/widgets/TransformationController/toScene.html
- Natural Earth admin-1 10m v5.1.1 -- https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/ (public domain confirmed)
- Google AdMob Families compliance -- https://support.google.com/admob/answer/6223431
- AdMob child-directed treatment -- https://support.google.com/admob/answer/6219315

### Secondary (MEDIUM confidence)
- Music Modernization Act / sound recording copyright -- https://legalclarity.org/is-the-star-spangled-banner-public-domain/ (self-render approach sidesteps the issue entirely)
- Antimeridian GeoJSON splitting -- https://macwright.com/2016/09/26/the-180th-meridian.html and antimeridian Python package
- Flutter SharedPreferences iOS flush issue -- https://github.com/flutter/flutter/issues/128368 (open issue)
- Flutter timer accuracy in background -- https://medium.com/geekculture/flutter-case-study-timer-precision-a1154b431e8
- Sheppard Software 50 States competitor feature set -- https://www.sheppardsoftware.com/geography/usa/50-states-game-1/

### Tertiary (LOW confidence)
- Natural Earth shapefile field names (adm0_a3, postal) -- confirmed via community usage examples; verify against the actual shapefile before writing pipeline filter logic

---
*Research completed: 2026-05-30*
*Ready for roadmap: yes*
