# Requirements — State States

**Milestone:** v1 — Playable Core
**Defined:** 2026-05-30
**Scope source:** PROJECT.md + `.planning/research/` (SUMMARY, FEATURES, ARCHITECTURE, PITFALLS)

Golf-style scoring (lowest wins). Canonical entity set = **50 states** (no D.C.). Fully offline. COPPA / Families compliant from day one. Architecture baselined on *Flags Around the World*.

---

## v1 Requirements

### Welcome & Audio

- [ ] **WEL-01**: On launch, the app shows a premium opening screen featuring a stylized vector silhouette of the USA (no spinning globe).
- [x] **WEL-02**: The app programmatically plays a self-rendered, rights-clean "Star-Spangled Banner" instrumental on the opening screen.
- [x] **WEL-03**: The anthem fades out seamlessly when transitioning from the opening screen into the menu.
- [ ] **WEL-04**: An audio service (`just_audio`) safely loads, plays, and releases audio across lifecycle events, with no leaked players on dispose.

### Home & Navigation

- [x] **HOME-01**: The home screen presents one selectable card per game mode.
- [x] **HOME-02**: Each mode card displays the player's best score and star rating (1–3) for that mode.
- [ ] **HOME-03**: On relaunch with a saved session, the home screen offers a "continue game" dialog showing mode, score, elapsed time, and states placed.

### Map Canvas & Data

- [x] **MAP-01**: The map renders a vector representation of all 50 U.S. states via CustomPainter from bundled pre-processed JSON (not runtime SVG parsing).
- [x] **MAP-02**: Alaska and Hawaii render inside dedicated inset frames, with inset transforms baked into canvas coordinate space by the build-time pipeline.
- [x] **MAP-03**: The map supports high-performance pan and zoom via `InteractiveViewer`, with the token tray outside the viewer and DragTargets inside it.
- [x] **MAP-04**: Explicit zoom in / zoom out buttons are available outside the `InteractiveViewer`.
- [ ] **DATA-01**: A build-time Python pipeline converts Natural Earth admin-1 (public domain) data into a bundled `usa_states_paths.json` containing path data, per-state centroids, and Alaska/Hawaii inset transforms.
- [ ] **DATA-02**: The pipeline splits Alaska's Aleutian antimeridian geometry so Alaska renders correctly (no horizontal smear) and passes shapely validity.

### Drag-and-Drop Interaction

- [ ] **DRAG-01**: The player drags a state token from the tray and drops it on the map; drop coordinates are recovered via `TransformationController.toScene()` (correct under zoom/pan).
- [x] **DRAG-02**: A correct drop fills the placed state and plays a fly-to-centroid confirmation animation.
- [ ] **DRAG-03**: Micro-states use an invisible 48dp radial proximity-snapping hit-box around their centroid (RI, DE, CT, NJ, MD, NH, VT), with deterministic tiebreaking between adjacent small states.
- [x] **DRAG-04**: Correct drops produce light haptic feedback plus a success sound effect.
- [x] **DRAG-05**: Incorrect drops produce medium haptic feedback, an error sound, a "not quite — try again" snackbar, and a token bounce.

### Game Modes (label visibility matrix)

- [ ] **MODE-01**: **Learn** — state abbreviations are visible on the map and the full state name appears beneath the token tray; on-map font scales dynamically with the canvas matrix transform.
- [ ] **MODE-02**: **States Master** — the full state name appears only beneath the tray; the map shows no labels or abbreviations.
- [ ] **MODE-03**: **Geographical Master** — abbreviations appear on the map and scale with zoom thresholds; tray tokens show no text clues.
- [ ] **MODE-04**: **Grand Master** — total blackout: no names in the tray and no labels/abbreviations on the map.

### Scoring & Records

- [ ] **SCORE-01**: Golf scoring adds +1 point for every 10 seconds elapsed.
- [ ] **SCORE-02**: Golf scoring adds +5 points for each token placed on an incorrect state path.
- [x] **SCORE-03**: The HUD displays the live score and elapsed time during play.
- [x] **SCORE-04**: The HUD shows a progress indicator (states placed / 50).
- [ ] **SCORE-05**: The best (lowest) score for each mode is stored locally via `SharedPreferences`.
- [x] **SCORE-06**: A completion screen shows the final score, a 1–3 star rating, and a play-again call to action.
- [x] **SCORE-07**: Beating the stored best score shows a personal-best badge and a confetti overlay on the completion screen.

### Hints

- [ ] **HINT-01**: The player has 2 hints per round; using one animates a zoom to the target state's centroid with a ~3-second highlight glow.
- [ ] **HINT-02**: Each hint used adds a +5 score penalty (no rewarded-ad refill in v1).

### Session & Lifecycle

- [ ] **SESS-01**: The player can pause and resume; the game auto-pauses when the app is backgrounded (timer stops).
- [ ] **SESS-02**: A mute toggle is available in the HUD and on the pause screen; the preference persists across sessions.
- [ ] **SESS-03**: An in-progress session persists and can be resumed mid-game after relaunch.
- [ ] **SESS-04**: A skippable 4-step first-launch tutorial runs once; a "seen" flag persists so it does not repeat.
- [ ] **SESS-05**: The game is fully offline — all assets and data are bundled, with no network dependency for any core feature.

### Compliance & Accessibility (COPPA / Families)

- [ ] **COMP-01**: No Firebase and no persistent device identifiers are used anywhere in the app.
- [ ] **COMP-02**: The `AD_ID` permission is blocked in `AndroidManifest.xml` (`tools:remove`) from the first commit.
- [ ] **COMP-03**: The ad layer exists but is stubbed (`AdLoadState.failed`) as a walled garden; `GameSessionNotifier` has zero imports from the ads module.
- [ ] **COMP-04**: The app builds under App ID `com.otis.brooke.state.the.state` and is configured for a maximum content rating of G/PG.
- [ ] **A11Y-01**: All interactive controls are ≥48×48dp and carry `Semantics` labels (HUD buttons, mode cards, tray tokens).
- [ ] **A11Y-02**: Correct/incorrect outcomes are signaled multimodally (haptic + audio + visual), never by color alone; on-map abbreviations respect a legibility floor.

---

## v2 Requirements (Deferred)

- [ ] **Mode 5 — Speed Typing Challenge**: no map viewport; top text field forcing UPPERCASE; scrolling grid of found states; on valid+new match → success SFX, green "V" checkmark flash (1–2s), clear field, append to grid; ends when all 50 states typed.
- [ ] **Gated social sharing**: beating a best score unlocks a `share_plus` share of a watermarked screenshot ("New lowest score in [Level Name] level!"), gated behind a randomized 2-digit × 1-digit math parental challenge.
- [ ] **Full AdMob + mediation**: Banner, Interstitial, Rewarded Interstitial (hint refills), and App Open placements with Unity/AppLovin/ironSource/InMobi mediation, all with `tagForChildDirectedTreatment(true)` per SDK and G/PG content limits.
- [ ] **Rewarded-ad hint refill**: wire `refillHints()` to the rewarded ad callback.

---

## Out of Scope

- **Washington D.C. as a placeable/typeable entity** — entity set is the 50 states; matches the "all 50 states" end condition.
- **Firebase (Analytics/Crashlytics)** — collects persistent identifiers; COPPA-prohibited. Use Android Vitals.
- **Online accounts, cloud sync, leaderboards, multiplayer** — app is offline by design; accounts imply persistent identifiers.
- **In-app purchases / premium unlock** — Families Policy restricts IAP UX for child-directed apps.
- **State trivia / capitals / flags quiz modes** — different product surface; dilutes the map-placement focus.

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| DATA-01 | Phase 1 | Pending |
| DATA-02 | Phase 1 | Pending |
| COMP-01 | Phase 1 | Pending |
| COMP-02 | Phase 1 | Pending |
| COMP-03 | Phase 1 | Pending |
| COMP-04 | Phase 1 | Pending |
| SESS-05 | Phase 1 | Pending |
| SCORE-01 | Phase 2 | Pending |
| SCORE-02 | Phase 2 | Pending |
| SCORE-05 | Phase 2 | Pending |
| SESS-01 | Phase 2 | Pending |
| SESS-02 | Phase 2 | Pending |
| SESS-03 | Phase 2 | Pending |
| WEL-04 | Phase 2 | Pending |
| MAP-01 | Phase 3 | Complete |
| MAP-02 | Phase 3 | Complete |
| MAP-03 | Phase 3 | Complete |
| MAP-04 | Phase 3 | Complete |
| DRAG-01 | Phase 4 | Pending |
| DRAG-02 | Phase 4 | Complete (04-04) |
| DRAG-03 | Phase 4 | Complete (04-03) |
| DRAG-04 | Phase 4 | Complete (04-04) |
| DRAG-05 | Phase 4 | Complete (04-04) |
| MODE-01 | Phase 4 | Pending |
| MODE-02 | Phase 4 | Pending |
| MODE-03 | Phase 4 | Pending |
| MODE-04 | Phase 4 | Pending |
| SCORE-03 | Phase 4 | Complete (04-04) |
| SCORE-04 | Phase 4 | Complete (04-04) |
| SCORE-06 | Phase 4 | Complete (04-05) |
| SCORE-07 | Phase 4 | Complete (04-05) |
| HOME-01 | Phase 4 | Complete |
| HOME-02 | Phase 4 | Complete |
| WEL-01 | Phase 5 | Pending |
| WEL-02 | Phase 5 | Complete |
| WEL-03 | Phase 5 | Complete |
| HINT-01 | Phase 5 | Pending |
| HINT-02 | Phase 5 | Pending |
| SESS-04 | Phase 5 | Pending |
| HOME-03 | Phase 5 | Pending |
| A11Y-01 | Phase 5 | Pending |
| A11Y-02 | Phase 5 | Pending |
