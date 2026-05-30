# Feature Research

**Domain:** U.S. Geography Educational Drag-and-Drop Map Game (Ages 8+, COPPA/Families)
**Researched:** 2026-05-30
**Confidence:** HIGH (reference codebase read directly; competitor feature sets verified via multiple sources)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that parents and children assume exist. Missing any of these and the product feels incomplete or broken for the genre.

| Feature | Why Expected | Complexity | v1 / v2 | Notes |
|---------|--------------|------------|---------|-------|
| Interactive USA vector map (mainland + AK/HI insets) | Core mechanic; no map = no game | HIGH | v1 | Pan/zoom via InteractiveViewer; pre-processed JSON paths (locked from Flags) |
| Drag-and-drop state token onto map | The primary interaction loop — the entire UX premise | HIGH | v1 | Tray outside IV, DragTargets inside, `toScene()` coordinate transform |
| Correct-drop confirmation (visual + audio + haptic) | Players need instant, unambiguous "got it" signal | MEDIUM | v1 | Light haptic + success sound + fly-to-centroid animation (direct port from Flags) |
| Wrong-drop feedback (visual + audio + haptic) | Players need to know immediately when they mis-drop | LOW | v1 | Medium haptic + error sound + snackbar "not quite" + token bounce (Flags pattern) |
| Proximity-snapping hit-box for micro-states | Rhode Island / Delaware finger-target frustration is a known UX failure mode for this genre | MEDIUM | v1 | 48dp radial centroid snap; PROJECT.md requirement; prevents "I dropped it right there!" rage quits |
| Progress indicator during round (states placed / 50) | Children need to see how far they've come — no indicator = feels like a never-ending chore | LOW | v1 | Linear progress bar in HUD; already in Flags' `GameHud` |
| Elapsed-time display in HUD | Supports golf-style scoring comprehension | LOW | v1 | MM:SS counter in HUD; already in Flags |
| Golf-style score display in HUD | Players must understand lower = better during play | LOW | v1 | Score: +1/10s elapsed + 5/error; already modelled in `GameSessionNotifier` |
| Four progressive difficulty modes | The stated product spec; "Learn → Grand Master" is the core educational arc | HIGH | v1 | Learn, States Master, Geographical Master, Grand Master |
| Local best-score record per mode | Kids track personal progress; parents check improvement; no record = no replayability | LOW | v1 | `shared_preferences` via `HighScoreRepository` (direct Flags port) |
| Pause / resume game | Children are interrupted constantly (parents, siblings, school bell) | LOW | v1 | Pause overlay with Resume / Mute / End Game; auto-pause on app background (Flags pattern) |
| "Continue saved game" on relaunch | Children quit mid-game routinely; losing progress is demoralising | MEDIUM | v1 | `GameStateRepository` session persistence (Flags port); shown on `HomeScreen` on load |
| Mute toggle (in-game and on pause screen) | Required for classroom use; also for children who play without headphones | LOW | v1 | `UserPrefsRepository` persists mute preference (Flags port) |
| Mode selection home screen with best scores visible | Players choose difficulty and see their records without navigating away | LOW | v1 | Mode cards showing stars + best score; adapts Flags' `HomeScreen._ModeCard` |
| Completion / results screen | Every round needs a definitive end — score, time, star rating, play-again CTA | MEDIUM | v1 | Stars (1-3), personal-best banner, confetti overlay on PB; adapts Flags' `CompletionScreen` |
| Zoom in / out buttons on map | Touch-only pan/zoom is unintuitive for ages 8; explicit buttons are expected | LOW | v1 | Fixed FAB zoom +/- outside InteractiveViewer (Flags pattern) |
| Audio on/off (anthem and SFX) | Children use in school/library; parents want control | LOW | v1 | Single mute flag covers all audio via `just_audio` service |
| Offline play | Families app users expect no-WiFi playability; also COPPA best practice | LOW | v1 | All assets bundled; `shared_preferences` for scores; no network dependency |
| First-launch tutorial overlay | Ages 8 do not read app store instructions; they need in-app guidance | MEDIUM | v1 | 4-step skippable tutorial; `UserPrefsRepository.tutorialSeen` flag (Flags port) |

---

### Differentiators (Competitive Advantage)

Features that distinguish this product from Seterra, Stack the States, and Sheppard Software. Not assumed, but valued when discovered.

| Feature | Value Proposition | Complexity | v1 / v2 | Notes |
|---------|-------------------|------------|---------|-------|
| Patriotic welcome screen + self-rendered Star-Spangled Banner | Emotionally primes the learning context; strong first-impression differentiator for U.S. audience | MEDIUM | v1 | Vector USA silhouette; anthem self-rendered from PD score (PROJECT.md requirement); fades out into menu |
| Progressive label-hiding across 4 modes (abbreviations → full name → abbrev-on-map → total blackout) | Industry-standard in concept (Sheppard Software does 7 difficulty tiers) but this four-mode structure is clean and teachable; mode names are memorable | MEDIUM | v1 | Learn / States Master / Geographical Master / Grand Master; label visibility matrix drives HUD and tray rendering |
| Font scales with InteractiveViewer zoom (abbreviations stay readable at all zoom levels) | Competitor web games use static labels that become illegible when zoomed out on mobile | HIGH | v1 (Learn + Geo Master modes) | `viewScale` passed to `WorldMapPainter` via `TransformationController` listener; already implemented in Flags' `WorldMapPainter` |
| Centroid proximity-snapping specifically for small-state frustration | Seterra and Sheppard Software have notoriously mis-registering Rhode Island / Delaware clicks; explicit 48dp centroid snap solves this definitively | MEDIUM | v1 | `hitTest()` with scale-aware proximity radius; PROJECT.md explicit requirement |
| Hint-with-zoom: uses one hint charge to animate zoom to state centroid + 3s highlight | More immersive than text-only "here's a clue"; spatial memory reinforcement | MEDIUM | v1 | `_animateHintZoom()` + `HighlightPainter` hint glow; direct port from Flags |
| Personal-best confetti + PB badge on completion screen | Immediate recognition of improvement; children remember the confetti moment | LOW | v1 | `_ConfettiPainter` custom painter; PB overlay from `CompletionScreen` (Flags port) |
| Star rating (1-3) on completion screen tied to PB comparison | Maps to universal mobile game vocabulary children already know from other games | LOW | v1 | `computeStarCount()` logic: beat PB = 3 stars, within 20% = 2, else 1 (direct port) |
| Stars displayed on mode-selection cards | Shows achievement state at a glance; motivates replaying lower-scored modes | LOW | v1 | `_ModeCard` FutureBuilder stars display (Flags port) |
| Alaska + Hawaii inset projections in dedicated frames | Competitors often omit or awkwardly place these; correct geographic context is an educational differentiator | HIGH | v1 | Pre-processed inset transforms baked into JSON pipeline at build time |
| Session restore on relaunch with mode/score/elapsed context | No competitor in this genre offers session continuity; children often close apps mid-round | MEDIUM | v1 | Continue dialog shows mode, score, time, states placed (adapts Flags' `HomeScreen._showContinueDialog`) |
| Fly-to-centroid animation on correct drop | Satisfying visual confirmation that the state "snapped home"; more rewarding than a static green flash | MEDIUM | v1 | Overlay `AnimatedBuilder` scaling token from tray to map centroid (Flags port) |

---

### Anti-Features (Deliberately Not Building)

| Feature | Why Requested | Why Excluded | What We Do Instead |
|---------|---------------|--------------|-------------------|
| Washington D.C. as a placeable entity | "Should include the capital!" | PROJECT.md explicit exclusion; canonical entity set = 50 states; D.C. is not a state; complicates the "all 50 states" end condition | Game copy explicitly says "50 states"; no D.C. token, no D.C. snapping target |
| Firebase Analytics / Crashlytics | Standard "crash reporting" tooling | Collects persistent device identifiers (App Instance ID, Crashlytics UUID) — COPPA-prohibited. PROJECT.md hard constraint. | Android Vitals for crash data; Flutter `FlutterError.onError` for local debug logging |
| Online leaderboards / cloud sync / accounts | Children want to compare scores | Requires accounts = persistent identifiers = COPPA violation; also conflicts with offline-first design | Local best-score per mode displayed on mode cards |
| Social sharing (v1) | Parents want to share kids' achievement | Requires parental gate (math challenge) + screenshot watermarking + `share_plus` integration; independent of core loop | Deferred to v2 (PROJECT.md); share infrastructure (`RepaintBoundary` score card) can be back-ported from Flags' `CompletionScreen` |
| Full AdMob monetization (v1) | Revenue | COPPA-compliant ad config is complex; walled-garden stub keeps v1 scope clean | Ad layer stubbed as `AdLoadState.failed` in v1 (Flags pattern); full mediation in v2 |
| Mode 5 Speed Typing Challenge (v1) | Natural progression after map mastery | Independent of map engine; text-input driven; separate UX surface | Deferred to v2 (PROJECT.md) |
| In-app purchases / premium unlock | Monetization | Google Play Families Policy restricts IAP UX patterns for child-directed apps; complex compliance surface | Out of scope for v1 and v2; not in PROJECT.md |
| Timed countdown before game start (separate UX) | "Get ready" signal | Adds latency before the core loop; children are impatient | Game starts as soon as the tutorial is dismissed or "play" is tapped; timer in HUD is sufficient |
| State trivia / capitals / flags quiz modes | "More content!" (Stack the States model) | Different product surface; dilutes the clean map-placement focus; adds data and UI complexity not in scope | Out of scope; the four drag-drop modes cover the educational arc without trivia |
| Real-time multiplayer | "Play with friends" | Requires network, accounts, and server infra; all COPPA risk surfaces | Fully offline by design |
| Parental controls / time-limiting | "Limit screen time" | Out of product scope; OS-level controls (Android Digital Wellbeing) serve this | Documented in privacy policy; not in-app |
| Rewarded ads to refill hints (v1) | Revenue + hint loop | Ad layer is stubbed in v1; rewarded ad callback (`refillHints()`) already exists in notifier for v2 | Hints limited to 2 per round in v1; no refill mechanic surfaced to user |

---

## Feature Dependencies

```
Welcome Screen + Anthem
    └──plays on──> App Launch
                       └──fades into──> Home Screen

Home Screen
    └──requires──> HighScoreRepository (best scores per mode on mode cards)
    └──requires──> GameStateRepository (continue-game dialog on load)
    └──triggers──> Mode Selection → Map Screen

Map Screen
    └──requires──> USA States JSON (centroids, paths, inset transforms)
    └──requires──> InteractiveViewer + TransformationController (pan/zoom/coordinate transform)
    └──requires──> GameSessionNotifier (score, elapsed, phase, matchedIsoCodes)
        └──requires──> Ticker (1-second heartbeat for score/time updates)
    └──requires──> FlagTray (token display; pin-anchor drag strategy)
    └──requires──> GameHud (score, time, progress bar, mute, pause)
    └──requires──> HitDetection (proximity snap for micro-states)
        └──requires──> Centroid data in USA States JSON

Hint System
    └──requires──> GameSessionNotifier.useHint() (deducts hintsRemaining, adds penalty)
    └──requires──> HighlightPainter (3s hint glow on hinted state)
    └──requires──> _animateHintZoom() (zoom to centroid on hint use)
    └──note──> v1: 2 hints/round, no refill. v2: rewarded ad refill via refillHints()

Completion Screen
    └──requires──> GameSessionNotifier.completeGame() (stops ticker, saves best score)
    └──requires──> HighScoreRepository (previousBest for star calculation)
    └──contains──> _ConfettiPainter (PB celebration overlay)
    └──v2 only──> Share button (RepaintBoundary score card + parental gate + share_plus)

Difficulty Modes (label visibility matrix)
    Learn:                abbrevs ON map + full name in tray
    States Master:        NO map labels + full name in tray
    Geographical Master:  abbrevs ON map (scale-adaptive) + NO tray text
    Grand Master:         NO map labels + NO tray text

    └──drives──> WorldMapPainter(showLabels, viewScale)
    └──drives──> FlagTray(showName)
    └──drives──> HighlightPainter(targetIsoCode: only in Learn mode)

Golf Score Formula:
    score = (elapsedSeconds ~/ 10) + (errorCount × 5) + hintPenalty
    └──requires──> Ticker (elapsed)
    └──requires──> recordDrop(isCorrect: false) (errorCount)
    └──requires──> useHint() (hintPenalty)
```

### Dependency Notes

- **Map Screen requires USA States JSON**: the entire drag loop cannot be built until the Python data pipeline produces `usa_states_paths.json` with centroids, Path data, and Alaska/Hawaii inset transforms.
- **HitDetection requires centroid data**: the 48dp proximity-snapping hit-box is computed against centroids baked into the JSON; this is not derivable at runtime.
- **Difficulty modes drive two separate visibility booleans**: `showLabels` (WorldMapPainter) and `showName` (FlagTray) are independent flags; Grand Master sets both false.
- **Completion Screen requires GameSessionNotifier.completeGame()** to have already been called before navigation; race conditions here caused bugs in Flags and must be guarded.
- **Share feature (v2) depends on RepaintBoundary score card**: the `_scoreCardKey` / `RepaintBoundary` scaffold on the completion screen should be built in v1 even though the share button is hidden, so v2 requires no structural refactor of that screen.

---

## MVP Definition

### Launch With (v1)

These are required for a "playable core" as defined in PROJECT.md.

- [x] Welcome screen with patriotic USA silhouette and Star-Spangled Banner anthem (fade-out)
- [x] Home screen: mode selection cards with best scores/stars
- [x] Continue-saved-game dialog on home screen relaunch
- [x] USA vector map: mainland + Alaska/Hawaii insets; pan/zoom via InteractiveViewer
- [x] State token tray (outside IV) + DragTarget inside IV with `toScene()` coordinate transform
- [x] 48dp centroid proximity-snapping hit-box for micro-states (RI, DE, CT, NJ, MD, NH, VT)
- [x] Correct-drop feedback: light haptic + success SFX + fly-to-centroid animation
- [x] Wrong-drop feedback: medium haptic + error SFX + "not quite" snackbar + token bounce
- [x] Four game modes with correct label visibility matrix (Learn / States Master / Geo Master / Grand Master)
- [x] Golf-style scoring formula (+1/10s + 5/error) displayed live in HUD
- [x] Progress bar (states placed / 50) in HUD
- [x] Hint system: 2 hints/round; zoom-to-centroid + 3s glow; +5 score penalty per use
- [x] Pause/resume overlay; auto-pause on app background
- [x] Mute toggle (HUD + pause screen); preference persisted
- [x] First-launch skippable tutorial (4 steps)
- [x] Completion screen: stars (1-3), PB badge, confetti overlay on PB, play-again CTA
- [x] Best score per mode stored locally via `SharedPreferences`
- [x] Session persistence (continue game after relaunch)
- [x] COPPA/Families compliance: no Firebase, no `AD_ID`, no accounts, child-directed AdMob stub

### Add After Validation (v1.x)

- [ ] Richer state highlight on correct drop (pulse/glow on map at placed location for 500ms before advancing) — trigger: user feedback that the fly-to animation is too fast to read
- [ ] Countdown overlay (3-2-1-GO) before game starts — trigger: playtesting reveals children start dragging before the timer runs
- [ ] State abbreviation flashcard review screen (between home and game) — trigger: Learn mode retention data shows abbreviation unfamiliarity is blocking engagement

### Future Consideration (v2+)

- [ ] Mode 5: Speed Typing Challenge — text-input driven; independent of map engine; PROJECT.md explicit deferral
- [ ] Gated social sharing — parental math gate + watermarked score card screenshot + `share_plus`; PROJECT.md explicit deferral
- [ ] Full AdMob + mediation (Banner / Interstitial / Rewarded) — COPPA-compliant ad config; PROJECT.md explicit deferral
- [ ] Rewarded-ad hint refill — `refillHints()` already in notifier; just needs ad layer wiring
- [ ] State trivia / capitals quiz — separate product surface, significant data and UI work

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Drag-and-drop map placement loop | HIGH | HIGH | P1 |
| Four progressive difficulty modes | HIGH | MEDIUM | P1 |
| Correct/wrong feedback (haptic + audio + visual) | HIGH | LOW | P1 |
| 48dp micro-state proximity snap | HIGH | MEDIUM | P1 |
| Golf scoring + HUD | HIGH | LOW | P1 |
| Welcome screen + anthem | HIGH | MEDIUM | P1 |
| Completion screen with stars + PB | HIGH | LOW | P1 |
| Local best-score records | MEDIUM | LOW | P1 |
| Session persistence / continue game | MEDIUM | MEDIUM | P1 |
| First-launch tutorial | MEDIUM | MEDIUM | P1 |
| Hint system (zoom + glow + penalty) | MEDIUM | MEDIUM | P1 |
| Pause/resume + auto-pause | MEDIUM | LOW | P1 |
| Progress bar in HUD | LOW | LOW | P1 |
| Font scaling with zoom (Geo Master) | MEDIUM | MEDIUM | P1 |
| Alaska/Hawaii inset projections | HIGH | HIGH | P1 |
| Share score (parental gate) | LOW | MEDIUM | P2 (v2) |
| Speed Typing Challenge (Mode 5) | MEDIUM | MEDIUM | P2 (v2) |
| Full AdMob monetization | LOW | HIGH | P3 (v2) |

**Priority key:** P1 = Must have for v1 launch. P2 = v2 milestone. P3 = v2+ / future.

---

## Competitor Feature Analysis

| Feature | Sheppard Software (web) | Stack the States (mobile) | Our Approach |
|---------|------------------------|--------------------------|--------------|
| Difficulty levels | 7 tiers (label removal + outline removal) | Not explicit tiers; unlockable mini-games | 4 named modes with clear label-hide progression; cleaner UX |
| Touch target for small states | No snapping; click accuracy a known complaint | Physics-based; small states can be hard to target | 48dp centroid proximity snap; explicit PROJECT.md requirement |
| Hint system | None | Flash-card study before game | 2 zoom-to-centroid hints per round with score penalty |
| Scoring | Correct percentage / time | Level-unlock progression | Golf-style (lower is better); personal best per mode |
| Completion feedback | Score % shown | State collection animation | Stars (1-3) + confetti on PB + fly-to-centroid per placement |
| Session continuity | None (reload = restart) | None | `SharedPreferences` session persistence; continue dialog on launch |
| Offline | Yes (web assets cached) | Yes | Yes (fully bundled) |
| Accounts / cloud | None | 6 local profiles | None (COPPA constraint) |
| Ads | None (web) | None | Stubbed v1; COPPA-compliant AdMob v2 |
| Alaska/Hawaii | Included in map | Included | Dedicated inset frames with correct projection |
| Audio feedback | Browser-based tones | Fun SFX | `just_audio` SFX (correct/error) + anthem on launch |
| Haptics | None (web) | Not prominent | Light (correct) + medium (incorrect) via `HapticFeedback` |

---

## Feedback Pattern Catalogue

This section documents the specific multimodal feedback events the game must produce, mapped to implementation approach.

| Event | Visual | Audio | Haptic | Notes |
|-------|--------|-------|--------|-------|
| Correct drop | Fly-to-centroid overlay animation (500ms); matched state fills with "placed" color on map | `playCorrect()` via audio service | `HapticFeedback.lightImpact()` | Direct port from Flags `_handleDrop()` |
| Wrong drop | Token bounce animation; red snackbar "not quite — try again" (1200ms) | `playError()` via audio service | `HapticFeedback.mediumImpact()` | Direct port from Flags |
| Hover over target state (Learn mode only) | Target state glows gold via HighlightPainter | None | None | Only current target state glows, not arbitrary hover |
| Hint used | Animated zoom to state centroid (400ms easeInOut); 3s pulsing glow on hinted state | Snackbar "Locating [State Name]" | None | `_animateHintZoom()` + HighlightPainter `hintIso` |
| Hint depleted (v2) | Alert dialog offering rewarded ad | None | None | `refillHints()` wired to ad callback in v2 |
| Personal best on completion | Confetti overlay (2s fade-out); amber "New Personal Best!" badge | None (anthem already faded; no completion fanfare SFX in Flags) | None | Consider adding a distinct "fanfare" SFX in v1 as a differentiator |
| Game completed (any result) | Completion screen: 1-3 stars, score card, play-again CTA | None (interstitial ad on completion in v2) | None | stars computed by `computeStarCount()` |
| App backgrounded during play | Pause overlay auto-shown | Ticker stops | None | `didChangeAppLifecycleState` handler |
| Wrong drop (map hover — non-target country) | No glow on non-target countries | None | None | Prevents confusion; only target country highlighted |

---

## Accessibility Notes (Ages 8+ / COPPA Context)

- **Touch targets**: All interactive controls minimum 48×48dp per Android guidelines and PROJECT.md. Micro-state snapping effectively enlarges the logical hit area for small states to 48dp radius around centroid — this is the primary a11y mechanism for the map.
- **Semantics labels**: All interactive widgets require `Semantics(label: ..., button: true)` wrappers. HUD pause and mute buttons already use this pattern in Flags' `GameHud`.
- **Font scaling**: Abbreviations on map scale with `viewScale` (from `TransformationController`); minimum legible size must be validated against ~12sp floor.
- **Color contrast**: Patriotic palette (red/white/blue) must meet WCAG 4.5:1 for text; state fill colors need validation against label colors.
- **No reliance on color alone**: Correct/wrong states signaled multimodally (haptic + audio + visual animation), not color alone.
- **Hint text for screen readers**: The snackbar hint message ("Locating [State Name]") is text-based and accessible; the zoom animation is supplementary.

---

## Sources

- **Reference codebase (HIGH confidence):** `C:\code\Claude\FlagsRoundTheWorld\lib\features\` — `game_session.dart`, `game_session_notifier.dart`, `completion_screen.dart`, `game_hud.dart`, `flag_tray.dart`, `map_screen.dart`, `home_screen.dart`
- **PROJECT.md (HIGH confidence):** `C:\code\Claude\StateTheStates\.planning\PROJECT.md` — scope, requirements, out-of-scope decisions
- **Stack the States review:** [Common Sense Media](https://www.commonsensemedia.org/app-reviews/stack-the-states) — age 8+ target validated; feature set benchmarked
- **Sheppard Software 50 States (HIGH confidence for competitor difficulty model):** [Level 1](https://www.sheppardsoftware.com/geography/usa/50-states-game-1/) — 7-tier label-removal progression confirms our 4-mode approach is competitive
- **GeoFlight USA:** [geoflightusa.com](https://www.geoflightusa.com/) — practice/timerace modes; no map drag-drop; not a direct competitor
- **Children's UX feedback patterns (MEDIUM confidence):** [Ungrammary UX tips](https://www.ungrammary.com/post/designing-for-kids-ux-design-tips-for-children-apps), [Aufait UX](https://www.aufaitux.com/blog/ui-ux-designing-for-children/) — multimodal feedback (audio + haptic + visual) confirmed as expected for ages 8+
- **WCAG touch target guidance (HIGH confidence):** [All accessible touch target sizes](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/) — 48×48dp Android minimum validated

---

*Feature research for: U.S. Geography Educational Drag-and-Drop Map Game*
*Researched: 2026-05-30*
