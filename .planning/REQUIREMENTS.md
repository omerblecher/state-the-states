# Requirements — State States

**Current Milestone:** v2.0 — Monetization & Speed Mode
**v2 Defined:** 2026-06-02
**Scope source:** PROJECT.md + `.planning/research/` (SUMMARY, FEATURES, ARCHITECTURE, PITFALLS)

**v1 Milestone:** Playable Core (Phases 1–5)
**v1 Defined:** 2026-05-30

Golf-style scoring (lowest wins). Canonical entity set = **50 states** (no D.C.). Fully offline. COPPA / Families compliant from day one. Architecture baselined on *Flags Around the World*.

---

## v1 Requirements

### Welcome & Audio

- [x] **WEL-01**: On launch, the app shows a premium opening screen featuring a stylized vector silhouette of the USA (no spinning globe).
- [x] **WEL-02**: The app programmatically plays a self-rendered, rights-clean "Star-Spangled Banner" instrumental on the opening screen.
- [x] **WEL-03**: The anthem fades out seamlessly when transitioning from the opening screen into the menu.
- [ ] **WEL-04**: An audio service (`just_audio`) safely loads, plays, and releases audio across lifecycle events, with no leaked players on dispose.

### Home & Navigation

- [x] **HOME-01**: The home screen presents one selectable card per game mode.
- [x] **HOME-02**: Each mode card displays the player's best score and star rating (1–3) for that mode.
- [x] **HOME-03**: On relaunch with a saved session, the home screen offers a "continue game" dialog showing mode, score, elapsed time, and states placed.

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

- [x] **HINT-01**: The player has 2 hints per round; using one animates a zoom to the target state's centroid with a ~3-second highlight glow.
- [x] **HINT-02**: Each hint used adds a +5 score penalty (no rewarded-ad refill in v1).

### Session & Lifecycle

- [ ] **SESS-01**: The player can pause and resume; the game auto-pauses when the app is backgrounded (timer stops).
- [ ] **SESS-02**: A mute toggle is available in the HUD and on the pause screen; the preference persists across sessions.
- [ ] **SESS-03**: An in-progress session persists and can be resumed mid-game after relaunch.
- [x] **SESS-04**: A skippable 4-step first-launch tutorial runs once; a "seen" flag persists so it does not repeat.
- [ ] **SESS-05**: The game is fully offline — all assets and data are bundled, with no network dependency for any core feature.

### Compliance & Accessibility (COPPA / Families)

- [ ] **COMP-01**: No Firebase and no persistent device identifiers are used anywhere in the app.
- [ ] **COMP-02**: The `AD_ID` permission is blocked in `AndroidManifest.xml` (`tools:remove`) from the first commit.
- [ ] **COMP-03**: The ad layer exists but is stubbed (`AdLoadState.failed`) as a walled garden; `GameSessionNotifier` has zero imports from the ads module.
- [ ] **COMP-04**: The app builds under App ID `com.otis.brooke.state.the.state` and is configured for a maximum content rating of G/PG.
- [ ] **A11Y-01**: All interactive controls are ≥48×48dp and carry `Semantics` labels (HUD buttons, mode cards, tray tokens).
- [ ] **A11Y-02**: Correct/incorrect outcomes are signaled multimodally (haptic + audio + visual), never by color alone; on-map abbreviations respect a legibility floor.

---

## v2 Requirements

### Speed Typing Mode (TYPING)

- [ ] **TYPING-01**: Mode 5 (Speed Typing) appears on the home screen as a selectable card displaying the player's best score (or blank state if never played).
- [ ] **TYPING-02**: Tapping the Mode 5 card navigates to `SpeedTypingScreen`.
- [x] **TYPING-03**: `SpeedTypingScreen` has a text field that auto-capitalizes input to UPPERCASE.
- [ ] **TYPING-04**: On entering a valid, previously unseen state name or its 2-letter postal code and pressing Enter, the game plays a success SFX, adds a green checkmark chip to the found-states grid, and clears the field.
- [ ] **TYPING-05**: On entering a non-matching string and pressing Enter, +5 points are added to the golf score.
- [x] **TYPING-06**: The found-states grid scrolls and shows all matched states as chips.
- [ ] **TYPING-07**: The game ends when all 50 states have been found.
- [ ] **TYPING-08**: Golf scoring applies: +1 per 10 seconds elapsed + +5 per wrong submission; timer auto-pauses when the app is backgrounded.
- [ ] **TYPING-09**: Best (lowest) score for Speed Typing mode is stored locally via `SharedPreferences`.

### Gated Sharing Completion (SHARE)

- [ ] **SHARE-01**: The Share button on `CompletionScreen` is only visible when the player has beaten their personal best (`_isNewPb == true`).
- [ ] **SHARE-02**: Pressing Share captures the score card via `RenderRepaintBoundary.toImage()` and attaches the PNG as an `XFile` to the share sheet.
- [ ] **SHARE-03**: The share message reads "New lowest score in [Mode Name]! Score: [N] — State the States 🇺🇸" with the screenshot attached.
- [ ] **SHARE-04**: The parental math gate is upgraded from single-digit addition to 2-digit × 1-digit multiplication.

### AdMob + Mediation (AD)

- [ ] **AD-01**: `RequestConfiguration` with `tagForChildDirectedTreatment: yes` and `maxAdContentRating: g` is set before `MobileAds.instance.initialize()`.
- [ ] **AD-02**: Unity, ironSource, and InMobi mediation adapters are initialized with their own per-SDK COPPA/child-directed flags in `ads_initializer.dart`. AppLovin remains disabled (`kAppLovinEnabled = false`).
- [ ] **AD-03**: A banner ad is shown at the bottom of `HomeScreen`.
- [ ] **AD-04**: An interstitial ad is triggered once on `CompletionScreen.initState()` (post-game, not mid-round or on pause).
- [ ] **AD-05**: An App Open ad is shown on cold app launch; it is suppressed when an active game session exists.
- [ ] **AD-06**: The `AD_ID` permission remains blocked in the merged manifest after all mediation adapter AARs are included; verified via `aapt dump badging`.

### Rewarded Hint Refill (HINT)

- [ ] **HINT-03**: When `hintsRemaining == 0` and the player taps the hint button, a "Watch an ad for 2 more hints?" prompt is shown.
- [ ] **HINT-04**: If the player watches the rewarded ad to completion, `refillHints()` resets `hintsRemaining` to 2 and the hint is immediately used.
- [ ] **HINT-05**: The reward is granted in `onUserEarnedReward` only — never in `onAdDismissedFullScreenContent`.

---

## Out of Scope

- **Washington D.C. as a placeable/typeable entity** — entity set is the 50 states; matches the "all 50 states" end condition.
- **Firebase (Analytics/Crashlytics)** — collects persistent identifiers; COPPA-prohibited. Use Android Vitals.
- **Online accounts, cloud sync, leaderboards, multiplayer** — app is offline by design; accounts imply persistent identifiers.
- **In-app purchases / premium unlock** — Families Policy restricts IAP UX for child-directed apps.
- **State trivia / capitals / flags quiz modes** — different product surface; dilutes the map-placement focus.
- **AppLovin MAX mediation** — SDK 13.0+ explicitly refuses to initialize in child-directed apps; `kAppLovinEnabled = false` guard must not be reversed until AppLovin re-enters the Families Self-Certified Ads SDK Program.
- **Designed for Families program enrollment** — app is general audience + `tagForChildDirectedTreatment(true)`; not enrolled in the Families program (App Open ads require this distinction).

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
| WEL-01 | Phase 5 | Complete |
| WEL-02 | Phase 5 | Complete |
| WEL-03 | Phase 5 | Complete |
| HINT-01 | Phase 5 | Complete |
| HINT-02 | Phase 5 | Complete |
| SESS-04 | Phase 5 | Complete |
| HOME-03 | Phase 5 | Complete |
| A11Y-01 | Phase 5 | Pending |
| A11Y-02 | Phase 5 | Pending |
| TYPING-01 | Phase 6 (v2) | Pending |
| TYPING-02 | Phase 6 (v2) | Pending |
| TYPING-03 | Phase 6 (v2) | Complete |
| TYPING-04 | Phase 6 (v2) | Pending |
| TYPING-05 | Phase 6 (v2) | Pending |
| TYPING-06 | Phase 6 (v2) | Complete |
| TYPING-07 | Phase 6 (v2) | Pending |
| TYPING-08 | Phase 6 (v2) | Pending |
| TYPING-09 | Phase 6 (v2) | Pending |
| SHARE-01 | Phase 7 (v2) | Pending |
| SHARE-02 | Phase 7 (v2) | Pending |
| SHARE-03 | Phase 7 (v2) | Pending |
| SHARE-04 | Phase 7 (v2) | Pending |
| AD-01 | Phase 8 (v2) | Pending |
| AD-02 | Phase 8 (v2) | Pending |
| AD-03 | Phase 8 (v2) | Pending |
| AD-04 | Phase 8 (v2) | Pending |
| AD-05 | Phase 8 (v2) | Pending |
| AD-06 | Phase 8 (v2) | Pending |
| HINT-03 | Phase 8 (v2) | Pending |
| HINT-04 | Phase 8 (v2) | Pending |
| HINT-05 | Phase 8 (v2) | Pending |
