# Project Research Summary

**Project:** State the States v2
**Domain:** Flutter educational mobile game - USA geography, ages 8+, COPPA/Families-compliant, offline, ad-monetized
**Researched:** 2026-06-02
**Confidence:** HIGH

## Executive Summary

State the States v2 adds four feature groups onto a solid v1 foundation: Mode 5 Speed Typing Challenge, full AdMob monetization (banner + interstitial + rewarded + App Open), mediation layer activation (Unity + ironSource + InMobi), and gated screenshot sharing on personal bests. The v1 codebase already contains the correct abstraction layer for all of these: StubAdService behind an abstract interface, a RepaintBoundary wrapping the score card, share_plus imported but text-only, and mediation packages declared but not initialized. v2 is principally a matter of filling in those stubs correctly, not rebuilding from scratch. The highest-leverage change is a single-line provider swap (StubAdService to AdMobAdService) that unlocks all four ad formats simultaneously.

The dominant risk in v2 is COPPA/Families compliance. Every new code path touches either ad SDK initialization, outbound device intents (sharing), or child-directed consent propagation to three mediation adapters. The failure modes are invisible in development and catastrophic in production: Play Store rejection, policy violation flag on the developer account, or DMCA-equivalent takedown. The key decisions already made eliminate the highest-risk items: App Open ads are permitted (general audience app, not Designed for Families program), AppLovin is excluded (SDK 13+ prohibits child-directed use), and Mode 5 wrong-submission penalty is resolved at +5 to match the golf scoring contract across all modes.

The recommended build order is Mode 5 first (pure Dart, zero SDK risk), screenshot sharing second (surgical changes to CompletionScreen, one new package), and AdMob last (highest complexity, external SDK, requires production ad unit IDs). This order means the app is shippable after each phase, and the most compliance-sensitive work is done last when the full checklist can be run against the final binary.

## Key Findings

### Recommended Stack

The v1 pubspec is correct. One new package is needed for v2: path_provider ^2.1.5 for writing the screenshot PNG to a temp file before passing it to share_plus as an XFile. The temp-file approach is more reliable than XFile.fromData() on Android because some share targets (e.g., Gmail) require an actual file path. The three mediation packages already declared in pubspec move from declared-but-unused to actively initialized in ads_initializer.dart. AppLovin remains permanently disabled via kAppLovinEnabled = false -- AppLovin SDK 13.0+ refuses to initialize in child-directed apps.

**Core technologies (unchanged from v1):**
- flutter_riverpod ^3.3.1 + riverpod_annotation ^4.0.2: state management via AsyncNotifier; GameSessionNotifier drives all session state including the new speedTyping mode
- just_audio ^0.10.5: correct/error SFX and anthem -- single audio stack, no audioplayers
- shared_preferences ^2.5.5: all persistence; no cloud, no Firebase, COPPA-required
- go_router ^17.2.3: navigation with onExit back-button guard; new /typing route added for Mode 5
- share_plus ^13.1.0: already imported; v2 upgrades from text-only to screenshot + text sharing

**v2 stack additions:**
- path_provider ^2.1.5 (NEW): temp file write for screenshot-to-XFile pipeline
- google_mobile_ads ^8.0.0: already present; StubAdService to AdMobAdService swap activates it
- gma_mediation_unity ^1.8.0, gma_mediation_ironsource ^2.4.1, gma_mediation_inmobi ^2.1.0: already declared; COPPA init calls added to ads_initializer.dart

### Expected Features

**Must have (table stakes):**
- Speed Typing: case-insensitive input normalised to uppercase; accepts both full state name and 2-letter postal code
- Speed Typing: live found-states chip grid (insertion order); success SFX on new match; field clears on correct guess
- Speed Typing: wrong-guess penalty +5 per wrong submission (matches golf scoring contract; RESOLVED decision)
- Speed Typing: ends when all 50 states found; golf scoring formula elapsed_secs / 10 + wrongCount * 5
- AdMob banner on home screen bottom; adaptive sizing via loadBannerForWidth()
- AdMob interstitial at game end (CompletionScreen.initState, 1-second delay, all modes)
- Rewarded ad for hint refill: prompt only when hintsRemaining == 0; grant only if onUserEarnedReward fires (not onAdDismissed)
- App Open on cold/warm launch; suppressed when GamePhase.playing or GamePhase.paused
- Mediation COPPA flags for Unity, ironSource, InMobi called independently before MobileAds.instance.initialize()
- Gated sharing: PB-only share button; screenshot via RepaintBoundary.toImage(); multiplication math gate (2-digit x 1-digit replaces addition)

**Should have (differentiators):**
- Speed Typing: TextCapitalization.characters for visual UPPERCASE display
- Speed Typing: chip flash animation (150ms expand + 200ms settle) on new match before settling into grid
- Gated sharing: watermark text inside score card widget boundary before capture
- Rewarded hint: immediately consume one hint after refillHints() so the player gets the hint without a second tap
- Interstitial: 1-second delay after game complete prevents accidental taps

**Defer (post-v2):**
- Speed Typing abbreviation discovery hint (UI text tip that 2-letter codes are accepted)
- Interstitial frequency cap tuning based on D1 retention data from Android Vitals
- Speed Typing states-remaining countdown display
- AppLovin MAX re-enablement (only if AppLovin re-enters Families Self-Certified Ads SDK Program)

### Architecture Approach

v2 makes minimal structural changes. The walled-garden rule is preserved: GameSessionNotifier has zero imports from the ads layer. The AdService abstract interface is unchanged (four methods). All ad calls originate from the widget layer: CompletionScreen.initState() for interstitial, MapScreen or SpeedTypingScreen _onHintPressed() for rewarded, app.dart didChangeAppLifecycleState for App Open. A new feature directory lib/features/typing/ houses SpeedTypingScreen -- structurally closer to HomeScreen than MapScreen (no map, no InteractiveViewer, no DragTarget).

**Major components and v2 changes:**

1. lib/features/typing/speed_typing_screen.dart -- NEW: Mode 5 screen; reuses GameHud, gameSessionProvider, audioServiceProvider; adds TextField + FoundStatesGrid; no map rendering
2. lib/core/ads/admob_ad_service.dart -- PROMOTED: scaffold to real implementation; port from Flags admob_ad_service.dart; replaces StubAdService via single provider-line change
3. lib/core/ads/ads_initializer.dart -- PROMOTED: partial to complete; adds Unity setGDPRConsent(false) + setCCPAConsent(false), ironSource setDoNotSell(true), InMobi (auto-forwarded); all before MobileAds.instance.initialize()
4. lib/features/game/game_session_notifier.dart -- ADDITIVE: new recordTypingGuess(String postal) and refillHints() methods; no existing methods change; no ads imports added
5. lib/features/map/completion_screen.dart -- ADDITIVE: GlobalKey _scoreCardKey on existing RepaintBoundary; _captureScoreCard() method; updated _onSharePressed(); math gate upgraded to multiplication
6. lib/features/game/game_mode.dart -- ONE-WORD ADDITION: append speedTyping to enum; downstream impact limited to CompletionScreen._modeColor() and HomeScreen mode-card builder

**Key architectural invariants preserved:**
- GameSessionNotifier imports from ads: zero
- AdService interface: unchanged (four methods)
- GameSession value object: unchanged (no new fields)
- All map-rendering code (MapScreen, UsaMapPainter, HighlightPainter, hitTest()): unchanged

### Critical Pitfalls

**v2-specific pitfalls (ordered by severity):**

1. **App Open lifecycle safety** -- App Open must be suppressed when GamePhase.playing or GamePhase.paused. Port the Flags admob_ad_service.dart AppStateEventNotifier + gameplay-check pattern verbatim. Verify: start a game, background then foreground -- no App Open should appear.

2. **Rewarded callback timing** -- refillHints() must be called inside onUserEarnedReward, never inside onAdDismissedFullScreenContent. The dismiss callback fires on every close including early exits. Use a _rewardGranted bool guard against adapters that fire onUserEarnedReward multiple times.

3. **AD_ID manifest merge after mediation packages** -- The v1 manifest has four tools:node=remove entries. When three mediation AARs are added, each may re-declare these permissions. Inspect build/intermediates/merged_manifests/debug/AndroidManifest.xml after adding each adapter. Run aapt dump badging app-release.apk before every Play Store submission.

4. **toImage() is UI-thread-only** -- RenderRepaintBoundary.toImage() cannot be called from a compute() isolate. Use WidgetsBinding.instance.addPostFrameCallback. Delete the temp PNG file in a finally block after share_plus returns.

5. **Mode 5 scoring gap (RESOLVED)** -- Decision: +5 per wrong submission, matching map-mode wrong-drop penalty. Backspace corrections before submission carry no penalty. Document in PROJECT.md Key Decisions before any Mode 5 code is written.

**Inherited v1 pitfalls that remain active:**

6. **Mediation native init COPPA timing** -- Adding a mediation package to pubspec causes its native Android layer to register at engine startup before any Dart code runs. Set all COPPA flags at the earliest point in main() before runApp(). Add one mediation package at a time and verify COPPA timing after each.

## Implications for Roadmap

Based on combined research, the recommended v2 phase structure is:

### Phase 1: Mode 5 Speed Typing Challenge

**Rationale:** Pure Dart, zero external SDK risk, no COPPA surface area. Delivers a shippable new game mode testable end-to-end without AdMob credentials. Validates recordTypingGuess(), GameMode.speedTyping, and SpeedTypingScreen before the ad layer adds complexity.

**Delivers:** SpeedTypingScreen, GameMode.speedTyping enum value, recordTypingGuess() + refillHints() on GameSessionNotifier, Mode 5 card on HomeScreen, /typing route in app.dart, golf scoring with +5 wrong-submission penalty, UPPERCASE TextField + found-states chip grid, success SFX integration.

**Addresses features:** Speed Typing full table-stakes list (case-insensitive input, postal abbreviation acceptance, deduplication, live grid, SFX, field-clear, golf scoring, ends at 50 found).

**Avoids pitfalls:** Mode 5 scoring gap resolved before first line of code. Zero ad SDK surface area in this phase.

**Research flag:** Standard patterns -- GameSessionNotifier extension is internal and well-documented. No external research needed during phase planning.

---

### Phase 2: Gated Screenshot Sharing Completion

**Rationale:** Surgical changes to CompletionScreen with one new package. No AdMob dependency; StubAdService continues to work. Fully testable on device without production ad unit IDs. Completes a v1 stub with minimal blast radius.

**Delivers:** GlobalKey _scoreCardKey on existing RepaintBoundary; _captureScoreCard() using toImage(pixelRatio: 2.0); updated _onSharePressed() with XFile path + share_plus; score card watermark text; math gate upgraded to 2-digit x 1-digit multiplication; path_provider ^2.1.5 added to pubspec; temp file cleanup in finally block; share button hidden unless _isNewPb == true.

**Addresses features:** Gated sharing table stakes (screenshot artifact, PB-only gate, multiplication math gate, watermark text).

**Avoids pitfalls:** toImage() main-thread constraint (UI isolate via postFrameCallback, never in compute()); temp file accumulation (delete in finally); parental gate preserved (multiplication replaces addition).

**Research flag:** Standard patterns -- RenderRepaintBoundary.toImage() and share_plus ShareParams are stable APIs. Pattern fully specified in ARCHITECTURE.md section 5.

---

### Phase 3: Full AdMob Layer Activation

**Rationale:** Highest complexity and compliance risk; comes last when the app is feature-complete. Requires production ad unit IDs from AdMob console. The StubAdService wall means zero risk of regressing Phases 1 and 2.

**Delivers:** AdMobAdService full implementation (port from Flags admob_ad_service.dart); ads_initializer.dart complete with Unity/ironSource/InMobi COPPA calls before MobileAds.instance.initialize(); ad_service_provider.dart single-line swap; adaptive banner on HomeScreen; interstitial with 1-second delay; rewarded hint refill via onUserEarnedReward; App Open with GamePhase suppression check; production ad unit IDs in ad_constants.dart; merged manifest AD_ID verification after each mediation adapter.

**Addresses features:** Banner (home screen), interstitial (game end), rewarded hint refill, App Open (cold/warm launch), mediation COPPA initialization (Unity + ironSource + InMobi).

**Avoids pitfalls:** App Open lifecycle safety (port Flags suppression pattern verbatim); rewarded callback timing (_rewardGranted guard); AD_ID manifest merge (inspect merged manifest + aapt check before submission); mediation COPPA timing (all flags before MobileAds.instance.initialize()).

**Research flag:** Needs implementation review -- Flags admob_ad_service.dart is the authoritative port target. Confirm mediation SDK COPPA method signatures against installed package source after flutter pub get before writing ads_initializer.dart.

---

### Phase Ordering Rationale

- Mode 5 first: pure Dart, unit-testable, zero external SDK dependencies.
- Sharing second: minimal blast radius, one new package, fully testable without AdMob.
- AdMob last: requires production ad unit IDs, highest compliance risk, benefits from complete app.
- All three phases are independent at the code level. Sequential delivery is recommended to avoid git-worktree corruption risk (documented in MEMORY.md).

### Research Flags

Phases needing deeper research during planning:
- **Phase 3 (AdMob):** App Open suppression timing and per-SDK COPPA call ordering need review against current Google Developers documentation. Mediation API methods verified at MEDIUM confidence -- confirm method signatures against installed package source before writing ads_initializer.dart.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Mode 5):** All patterns internal -- GameSessionNotifier extension, enum addition, new screen. Zero external API surface.
- **Phase 2 (Sharing):** RenderRepaintBoundary.toImage() and share_plus ShareParams are stable, well-documented APIs.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All package versions verified against pub.dev; v1 pubspec confirmed correct; path_provider is the only new package and is stable |
| Features | HIGH | v2 scope derived from existing codebase read directly; all feature groups have clear implementation paths |
| Architecture | HIGH | Based on direct read of Flags reference codebase; v2 changes are additive with documented invariants; patterns proven in production |
| Pitfalls | HIGH (v1) / MEDIUM (v2) | v1 pitfalls proven from Flags codebase; v2-specific pitfalls verified against Google official docs at MEDIUM confidence |

**Overall confidence:** HIGH

### Gaps to Address

- **Mediation SDK method signatures (MEDIUM confidence):** GmaMediationUnity.setGDPRConsent(false), GmaMediationUnity.setCCPAConsent(false), GmaMediationIronsource().setDoNotSell(true) confirmed via Google Developers pages but rated MEDIUM. Confirm exact signatures from installed package source after flutter pub get.

- **App Open Families program decision:** Research confirmed general audience apps may use App Open ads. Key decision made to include App Open. Must be re-validated at Play Store submission time -- if submission strategy changes to Families enrollment, App Open must be removed.

- **Production ad unit IDs:** ad_constants.dart currently has empty strings. Real IDs from AdMob console are a hard dependency for Phase 3 validation. Production IDs require the app registered in AdMob console with app ID com.otis.brooke.state.the.state.

- **Mediation certified SDK list verification:** Unity, ironSource, and InMobi were on the Families Self-Certified Ads SDK Program as of research date. Verify current status before v2 Play Store submission.

## Sources

### Primary (HIGH confidence)

- Flags admob_ad_service.dart -- full AdMobAdService implementation; authoritative port target for v2
- Flags ads_initializer.dart -- Unity + ironSource COPPA init sequence; port target
- StateTheStates lib/ -- v1 codebase read directly: ad_service.dart, stub_ad_service.dart, ads_initializer.dart, ad_constants.dart, completion_screen.dart, game_session_notifier.dart, game_session.dart, game_hud.dart, home_screen.dart, app.dart
- StateTheStates AndroidManifest.xml -- AD_ID + AdServices permissions confirmed stripped
- StateTheStates build.gradle.kts -- minSdk 24 confirmed
- https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html -- toImage() UI-isolate-only constraint
- https://developers.google.com/admob/flutter/rewarded -- onUserEarnedReward vs onAdDismissedFullScreenContent callback semantics
- https://support.google.com/admob/answer/9341964 -- App Open: Families program exclusion; gameplay suppression required
- https://pub.dev/packages/gma_mediation_inmobi -- InMobi empty Dart class; COPPA auto-forwarded from RequestConfiguration
- https://pub.dev/packages/path_provider -- getTemporaryDirectory() confirmed; version 2.1.5
- https://support.google.com/admob/answer/6066980 -- interstitial natural transitions; no mid-gameplay

### Secondary (MEDIUM confidence)

- https://developers.google.com/admob/flutter/mediation/unity -- GmaMediationUnity.setGDPRConsent / setCCPAConsent static methods
- https://developers.google.com/admob/flutter/mediation/ironsource -- GmaMediationIronsource().setDoNotSell(true) instance method
- https://developers.is.com/ironsource-mobile/general/ironsource-mobile-child-directed-apps/ -- ironSource COPPA must be set before SDK init
- https://support.axon.ai/en/max/flutter/overview/privacy/ -- AppLovin SDK 13.0+ child-directed prohibition
- https://support.google.com/googleplay/android-developer/answer/9900633 -- Families Self-Certified Ads SDK Program current list

---
*Research completed: 2026-06-02*
*Ready for roadmap: yes*
