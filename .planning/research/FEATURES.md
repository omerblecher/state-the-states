# Feature Research — v2 New Capabilities

**Domain:** U.S. Geography Educational Mobile Game — v2 Monetization & Speed Mode
**Researched:** 2026-06-02
**Confidence:** HIGH (existing codebase read directly; ad platform policies verified via Google official docs; patterns verified from Flags reference implementation)

> This file supersedes the v1 FEATURES.md (2026-05-30) and focuses exclusively on the
> four v2 feature groups. Existing v1 features are not re-researched here.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist for each v2 capability area. Missing these = feature feels half-baked.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Speed Typing — case-insensitive input** | Every typing quiz on every platform (Sporcle, JetPunk, etc.) normalises case; forcing exact-case is a UX defect, not a challenge | LOW | Normalise to uppercase internally; display input as typed but compare `.toUpperCase()` |
| **Speed Typing — accept 2-letter postal abbreviation as valid answer** | Players who know "AL" instead of "Alabama" should not be penalised; both represent the same geographic knowledge | LOW | Maintain a `Set<String>` of both full names and postal codes; single `.contains()` check |
| **Speed Typing — deduplicate already-found states** | Typing "Alabama" again after already finding it must not count twice | LOW | Check against `matchedPostals` set before accepting |
| **Speed Typing — live found-states grid** | Players need to see accumulating progress; a bare text box with no grid feels like a black hole | MEDIUM | Scrollable grid of state chips sorted by found-order; green checkmark chip per match; updates on each valid new entry |
| **Speed Typing — success SFX on new match** | Every typing quiz genre expectation; silence on correct answer breaks the reward loop | LOW | Same `playCorrect()` audio service call used in drag modes |
| **Speed Typing — clear field on valid new match** | If the field is not cleared the player must manually delete before typing the next state | LOW | `TextEditingController.clear()` in the match handler |
| **Speed Typing — wrong-guess score penalty** | Matches the golf-scoring contract already established across all modes | LOW | `+5` per wrong entry, identical to drag-mode error penalty |
| **Speed Typing — ends when all 50 found** | The end condition must be unambiguous; no "submit" button | LOW | `matchedPostals.length == 50` triggers `completeGame()` |
| **Speed Typing — golf scoring (time-based + wrong penalty)** | Players expect the same scoring contract as Modes 1–4 | LOW | Same formula: `(elapsedSeconds ~/ 10) + (wrongGuessCount × 5)` |
| **Banner ad on home screen** | Standard mobile game expectation; bottom-of-screen is the de-facto placement | LOW | Adaptive banner below mode-card list; `getBannerWidget()` slot already in `AdService` interface |
| **Interstitial shown at natural transition (game end → completion)** | Players accept full-screen ads between rounds; mid-game interruption is a policy violation | MEDIUM | Show from `CompletionScreen.initState()` (same pattern as Flags `admob_ad_service.dart`) |
| **Rewarded ad consent UX before ad plays** | Google's rewarded interstitial policy mandates a pre-ad intro screen; missing it is a policy violation | MEDIUM | Intro dialog with reward description + "Skip" option; required for rewarded interstitial format |
| **Rewarded hint refill: clear reward messaging** | "Watch ad for X" — vague mystery rewards have lower opt-in rates | LOW | Dialog copy: "Watch a short video to get 2 more hints" — explicit, no ambiguity |
| **Rewarded hint refill: no prompt if ad not loaded** | Offering a reward that isn't available creates trust damage | LOW | Check `adService.isRewardedAdLoaded` (or equivalent) before showing prompt; silently skip if unavailable |
| **Gated sharing: screenshot of score card** | Text-only share is low-signal; screenshot of the score card (stars, score, time, mode) is the expected share artifact for mobile game results | MEDIUM | `RepaintBoundary` already wraps the score card in `CompletionScreen`; needs `GlobalKey` + `toImage()` + `XFile.fromData()` path |
| **Gated sharing: parental math gate** | COPPA / Google Play Families Policy requires a parental gate before any outbound device intent from a child-directed app | MEDIUM | Existing `_MathChallengeDialog` in `CompletionScreen` implements this; v2 upgrades from addition to 2-digit × 1-digit multiplication |
| **Gated sharing: only available on personal best** | Showing a share button on every run devalues the action; "beat PB" is the moment that creates genuine share desire | LOW | Button visible only when `_isNewPb == true` in `CompletionScreen` |
| **App Open ad on cold launch** | Standard format for apps that have a loading moment; accepted expectation for ad-supported apps | MEDIUM | Triggered via `AppStateEventNotifier` in `app.dart`; already modelled in Flags `admob_ad_service.dart`; must suppress when `GamePhase.playing` or `GamePhase.paused` |
| **All mediation SDKs call `tagForChildDirectedTreatment` independently** | Each SDK has its own COPPA flag; setting only AdMob's flag does not propagate to mediation adapters | HIGH | Unity, IronSource, InMobi each require independent calls; `ads_initializer.dart` must be extended |

---

### Differentiators (Competitive Advantage)

Features that distinguish the v2 implementation from generic "typing quiz" or "ad-supported kids game" patterns.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Speed Typing accepts both full name AND postal abbreviation** | Rewards two distinct types of state knowledge; neither Sporcle nor JetPunk's UI makes this obvious — it can be surfaced as a UI hint | LOW | One `Set` containing 50 full names + 50 postal codes = 100 entries; O(1) lookup |
| **Speed Typing UPPERCASE display** | Forced-uppercase visual reinforces the "you're taking a test" register and matches the spec; differs from Sporcle's mixed-case input | LOW | `TextCapitalization.characters` on `TextField`; compare normalised internally |
| **Speed Typing: green checkmark chip flash (1–2s) before settling into grid** | Flash animation on new match creates a micro-celebration moment before the chip joins the grid; differentiates from static list-append | MEDIUM | `AnimatedContainer` or `ScaleTransition` on chip entry; 150ms expand + 200ms settle |
| **Speed Typing: sorted found-states grid (insertion order)** | Sporcle sorts alphabetically; insertion order shows the player's journey and feels more personal | LOW | `List<String>` preserves order; grid reads top-left → bottom-right in found sequence |
| **Rewarded hint refill triggered only on hint exhaustion (contextual)** | Prompting at point of frustration (hints = 0, still needs help) drives opt-in; proactively offering rewarded ads mid-game with hints remaining is bad UX | LOW | Show prompt only when `hintsRemaining == 0` and player taps the hint button again |
| **Interstitial with 1-second delay after game complete** | Google recommends a brief pause between level-end and interstitial to prevent accidental taps; children tap quickly after seeing the completion screen | LOW | `Future.delayed(const Duration(seconds: 1), adService.showInterstitialAd)` in `CompletionScreen.initState()` |
| **Gated sharing: "New lowest score in [Level Name]!" watermark text** | Explicit achievement claim on the share image; more meaningful than generic "I played a game" | LOW | Text overlay rendered as part of the score card widget before `toImage()` capture |
| **Gated sharing: multiplication math gate** | 2-digit × 1-digit is harder than the existing addition gate (3+7 = trivial for children); better adult verification | LOW | Replace `_a + _b` with `_a * _b`; generate: `_a` ∈ [12..19], `_b` ∈ [3..9] |
| **AdMob `RequestConfiguration` set before `initialize()`** | The existing `ads_initializer.dart` already does this correctly; this is architecturally correct and a common implementation mistake in the wild | LOW | Already correct; v2 extends it to add mediation SDK calls |

---

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Speed Typing: autocomplete / typeahead suggestions** | "Make it easier for kids" | Removes the challenge entirely; the mode is a recall test, not a recognition test; autocomplete converts it to a scroll-select picker which is a different product | No autocomplete; accept abbreviations to give partial-credit to players who know codes but not full names |
| **Speed Typing: partial-name matching ("New" matching "New York", "New Jersey", "New Mexico", "New Hampshire")** | "Flexible input" | Ambiguous; creates a UX problem when "New" is valid for 4 states simultaneously; requires disambiguation UI that adds complexity | Require full name or exact 2-letter postal code; no partial matching |
| **Speed Typing: skip/pass button** | "I'm stuck" | Undermines the challenge; reduces the achievement value of completing all 50 | Hint system already provides zoom-to-centroid in map modes; Speed Typing has no hint (it is a pure recall test) |
| **Speed Typing: time limit / countdown** | "Add pressure" | The spec defines no time limit; a countdown creates a game-over condition separate from "found all 50"; complicates the end-state machine | Golf scoring already creates natural time pressure — slower = higher score |
| **Rewarded ad: auto-play without user action** | Higher ad revenue | Rewarded ads require explicit user opt-in; auto-playing them is a policy violation for child-directed apps and a bad UX pattern | Always prompt with a consent dialog; `AdService.showRewardedAd()` already models this correctly |
| **Interstitial mid-gameplay** | "Maximise impressions" | Policy violation: Google's interstitial ad guidance explicitly prohibits mid-gameplay interruption; will trigger policy enforcement on Play Store | Show only at `CompletionScreen` entry — a natural transition point |
| **Banner ad inside `InteractiveViewer` / on map canvas** | "More placements" | Covers map; degraded gameplay; accidental clicks inflate CTR metrics (detectable as policy violation) | Banner only on home screen bottom; no ads in any active-gameplay screen |
| **App Open ad on every foreground event** | Maximise impressions | Google policy: suppress App Open when `GamePhase.playing` or `GamePhase.paused`; showing during gameplay is a guideline violation; the existing Flags `admob_ad_service.dart` already suppresses this | Already modelled correctly in Flags reference; carry forward the `GamePhase` check |
| **AppLovin MAX mediation** | One of the four mediation adapters in the original plan | AppLovin SDK 13.0+ explicitly prohibits use in child-directed apps (COPPA / Google Play Families); it left the Families Self-Certified Ads SDK Program; `ad_constants.dart` already has `kAppLovinEnabled = false` | Use Unity Ads, IronSource, InMobi only (all three are on the Families Self-Certified list as of research date; verify current list before v2 submission) |
| **Screenshot sharing without parental gate** | "Simplify the flow" | COPPA + Google Play Families Policy require an adult gate before any outbound device intent (sharing) from a child-directed app; omitting the gate is a compliance violation | The existing `_MathChallengeDialog` (currently addition) must be upgraded to multiplication; it cannot be removed |
| **Share button visible on non-PB runs** | "Always let players share" | Devalues the achievement; increases spurious share attempts with low engagement on social platforms; also creates awkward copy ("I got a score of 147 with no context") | Gate on `_isNewPb == true`; the PB condition already exists in `CompletionScreen` |

---

## Feature Dependencies

```
Speed Typing Mode (Mode 5)
    └──reuses──> GameSessionNotifier
        └──requires──> new GameMode.speedTyping enum value
        └──requires──> recordTypingGuess(String input) method (new)
        └──requires──> completeGame() (existing, unchanged)
    └──reuses──> GameHud (score, elapsed, progress bar, pause, mute)
    └──requires──> SpeedTypingScreen (new Widget — no map, no InteractiveViewer)
        └──contains──> TextField (UPPERCASE, TextCapitalization.characters)
        └──contains──> FoundStatesGrid (scrollable chip grid)
    └──reuses──> HighScoreRepository (best score per mode — Mode 5 gets its own key)
    └──reuses──> just_audio playCorrect() / playError() (existing audio service)
    └──does NOT require──> usa_states_paths.json (no map rendering)
    └──does NOT require──> InteractiveViewer, HitDetection, DragTargets

Full AdMob Layer
    └──requires──> AdMobAdService (new — already modelled in Flags; replace StubAdService)
        └──preloadAll() called from ads_initializer.dart after initialize()
        └──loadBannerForWidth() called from HomeScreen.didChangeDependencies()
        └──showInterstitialAd() called from CompletionScreen.initState()
        └──showRewardedAd() called from hint-exhaustion prompt
        └──showAppOpenAd() called from AppStateEventNotifier in app.dart
    └──requires──> mediation SDK COPPA calls in ads_initializer.dart
        └──Unity: UnityAds.setCOPPAMetaData() (via gma_mediation_unity)
        └──IronSource: IronSource.setMetaData("is_child_directed", ["true"]) (via gma_mediation_ironsource)
        └──InMobi: InMobiSdk.setIsAgeRestricted(true) (via gma_mediation_inmobi)
    └──requires──> production ad unit IDs in ad_constants.dart (currently empty strings)
    └──requires──> AppStateEventNotifier subscription in app.dart (cold/warm launch App Open)

Rewarded Hint Refill
    └──requires──> Full AdMob Layer (AdMobAdService.showRewardedAd())
    └──requires──> GameSessionNotifier.refillHints() (new method — adds 2 to hintsRemaining)
    └──requires──> HintButton or hint-depleted state to surface prompt
        └──triggered when: hintsRemaining == 0 AND player taps hint button
        └──prompt: AlertDialog with reward description + "Watch Ad" + "Cancel"
        └──on reward earned: refillHints() → hintsRemaining += 2
        └──on dismissed or failed: no refill, no penalty
    └──does NOT refill if ad not loaded (silent no-op; no error state shown to user)

Gated Sharing (completion)
    └──requires──> _isNewPb == true (gate condition — already exists in CompletionScreen)
    └──requires──> RepaintBoundary GlobalKey on score card widget
        └──note: RepaintBoundary already wraps the Card in CompletionScreen (line 201)
        └──needs: promote anonymous RepaintBoundary to named GlobalKey field
    └──requires──> toImage() + ByteData + XFile.fromData() pipeline
    └──requires──> SharePlus.instance.share(ShareParams(files: [xFile])) (share_plus already imported)
    └──requires──> _MathChallengeDialog upgrade: addition → 2-digit × 1-digit multiplication
    └──requires──> score card watermark text: "New lowest score in [Level Name] level!"
        └──rendered as Text widget inside the RepaintBoundary boundary before capture
    └──share button: visible only when _isNewPb == true (currently always visible — fix)

App Open Ad (cold launch)
    └──requires──> AppStateEventNotifier export from ads/app_state_observer.dart (already exists in Flags)
    └──requires──> app.dart: WidgetsBindingObserver → didChangeAppLifecycleState
        └──on AppLifecycleState.resumed: adService.showAppOpenAd()
    └──suppressed when GamePhase.playing or GamePhase.paused (check gameSessionProvider)
    └──4-hour expiry guard already in AdMobAdService._isAppOpenAdAvailable
```

### Dependency Notes

- **Speed Typing requires a new `GameMode` enum value**: `GameMode.speedTyping` must be added; `HighScoreRepository` keys on `GameMode` so it gets a free persistence slot. The home screen needs a new mode card for Mode 5.
- **Speed Typing shares `GameSessionNotifier` but needs a new input-recording method**: `recordTypingGuess(String input)` must be added to the notifier. It normalises input to uppercase, checks against the full name + postal code set, deduplicates against `matchedPostals`, and either records a match or increments an error counter. The existing `completeGame()` is unchanged.
- **Rewarded refill requires a `refillHints()` method on the notifier**: The method is referenced in the v1 `REQUIREMENTS.md` as a v2 item; it does not yet exist in `GameSessionNotifier`. It should clamp: `hintsRemaining = min(hintsRemaining + 2, 4)` (no unbounded accumulation).
- **Gated sharing: the `RepaintBoundary` wrapping the score card already exists** in `CompletionScreen` (line 201) but has no `GlobalKey`. Promoting it to a keyed boundary requires a one-line change; no structural refactor of the screen.
- **Gated sharing: `share_plus` is already imported** in `CompletionScreen` but the share path currently sends text only. The v2 change adds an image capture step before calling `share_plus`.
- **Gated sharing: math gate upgrade**: The existing `_MathChallengeDialog` uses addition (`_a + _b`). v2 changes the arithmetic to multiplication (`_a * _b`) with `_a` ∈ [12..19] and `_b` ∈ [3..9]. This requires changing three lines in the dialog.
- **AdMob mediation: AppLovin is excluded**: `kAppLovinEnabled = false` already set in `ad_constants.dart`. AppLovin SDK ≥13.0 cannot be used in child-directed apps. Do not add `gma_mediation_applovin` to `pubspec.yaml` for v2. The three permitted adapters are Unity, IronSource, InMobi.
- **AdMob Families: App Open ads**: Google's official guidance states that apps within the Google Play Designed for Families program **cannot use App Open ads**. If the app is submitted to the Families program, App Open must be removed. If submitted to Google Play as a general audience app (with child-directed treatment flag only), App Open is permitted. This is a submission strategy decision — flag for pre-submission review.
- **Interstitial placement**: Show once per game completion, from `CompletionScreen.initState()`, with a 1-second delay. Never show during `GamePhase.playing` or `GamePhase.countdown`. Frequency cap: consider 1 per session cap in AdMob dashboard to protect retention.

---

## MVP Definition

### v2 Launch With

Minimum viable v2 — all four features must ship together since AdMob requires production ad unit IDs which require a live app ID submission.

- [ ] **Mode 5 Speed Typing** — `GameMode.speedTyping`, `SpeedTypingScreen`, `recordTypingGuess()`, found-states grid, UPPERCASE field, success SFX, golf scoring, mode card on home screen
- [ ] **AdMob Banner** — `AdMobAdService` replacing `StubAdService`; adaptive banner on home screen bottom; `loadBannerForWidth()` from `HomeScreen.didChangeDependencies()`
- [ ] **AdMob Interstitial** — preloaded at startup; shown from `CompletionScreen.initState()` with 1s delay; Modes 1–5
- [ ] **AdMob Rewarded** — preloaded; `refillHints()` wired to `showRewardedAd()` callback; hint-exhaustion prompt dialog; Modes 1–4 only (Speed Typing has no hint)
- [ ] **AdMob App Open** — cold and warm launch; suppressed during `GamePhase.playing`/`paused`; subject to Families program submission strategy (see dependency note above)
- [ ] **Mediation: Unity, IronSource, InMobi** — COPPA flags called independently in `ads_initializer.dart`
- [ ] **Gated sharing completion** — PB-gated share button; `GlobalKey` on score card `RepaintBoundary`; `toImage()` → `XFile` → `share_plus`; watermark text; multiplication math gate

### Add After v2 Validation

- [ ] **Speed Typing: abbreviation discovery hint** — a subtle UI hint that abbreviations are accepted (e.g., "tip: 2-letter codes also work"); trigger: playtesting shows players don't know abbreviations are valid
- [ ] **Interstitial frequency cap adjustment** — start at 1/session in AdMob dashboard; adjust based on retention data from Android Vitals; trigger: eCPM vs. D1 retention tradeoff data
- [ ] **Speed Typing: "states remaining" count** — display `50 - matchedPostals.length` remaining; trigger: playtesting feedback that players want a countdown
- [ ] **Completion screen: interstitial skip animation** — brief "Ads keep this game free" loading message during the 1s interstitial preload delay; trigger: if user research shows confusion about the pause

### Out of Scope for v2

- **AppLovin MAX mediation** — prohibited for child-directed apps (SDK ≥13.0); `kAppLovinEnabled = false` is a hard constraint
- **App Open ads if submitting to Families program** — policy conflict; resolve at submission strategy time
- **IAP / premium unlock** — not in PROJECT.md; Families Policy restricts IAP UX for child-directed apps
- **Speed Typing autocomplete / partial matching** — anti-feature; see Anti-Features section
- **Rewarded ad for non-hint rewards** (score reduction, time bonus) — scope creep; hint refill is the only rewarded placement

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | COPPA Risk | Priority |
|---------|------------|---------------------|-----------|---------|
| Speed Typing Mode (Mode 5) | HIGH | MEDIUM | NONE | P1 |
| AdMob Banner (home screen) | MEDIUM | LOW | LOW | P1 |
| AdMob Interstitial (game end) | MEDIUM | LOW | LOW | P1 |
| Rewarded hint refill | MEDIUM | LOW | LOW | P1 |
| Gated sharing (PB + screenshot + math gate) | LOW | MEDIUM | HIGH (math gate required) | P1 |
| Mediation (Unity, IronSource, InMobi) | HIGH (revenue) | MEDIUM | HIGH (per-SDK COPPA flags required) | P1 |
| AdMob App Open (cold launch) | LOW | LOW | MEDIUM (Families program constraint) | P2 |
| Speed Typing abbreviation hint text | LOW | LOW | NONE | P3 |
| Interstitial frequency tuning | MEDIUM | LOW | NONE | P3 |

**Priority key:** P1 = must ship in v2. P2 = ship in v2 if Families program strategy is resolved. P3 = post-v2 tuning.

---

## COPPA / Families Policy Constraint Summary

This section consolidates compliance requirements that must be verified before v2 Play Store submission.

| Requirement | Status in Codebase | v2 Action |
|------------|-------------------|-----------|
| `tagForChildDirectedTreatment(true)` on AdMob | Already set in `ads_initializer.dart` | No change |
| `maxAdContentRating: MaxAdContentRating.g` | Already set in `ads_initializer.dart` | No change |
| `AD_ID` permission removed from manifest | Already in v1 `AndroidManifest.xml` | Verify still present after adding mediation packages |
| Unity Ads COPPA flag | Not present (mediation is v2 scope) | Add to `ads_initializer.dart` |
| IronSource COPPA flag | Not present | Add to `ads_initializer.dart` |
| InMobi age restriction flag | Not present | Add to `ads_initializer.dart` |
| AppLovin: do not add | `kAppLovinEnabled = false` in `ad_constants.dart` | Do not add `gma_mediation_applovin` |
| App Open ads: Families program restriction | Not applicable in v1 | Decide Families program participation before wiring App Open |
| Parental gate before outbound sharing | Existing addition-math gate in `CompletionScreen` | Upgrade to multiplication; no removal |
| No persistent device identifiers | No Firebase anywhere; `AD_ID` blocked | Verify mediation SDKs do not add new identifier collection |
| Rewarded ad: user opt-in required | `showRewardedAd()` contract returns bool (opted-in) | Wrap with pre-ad intro dialog before `showRewardedAd()` call |

---

## Sources

- **Codebase (HIGH confidence):** `C:\code\Claude\StateTheStates\lib\` — `ad_service.dart`, `stub_ad_service.dart`, `ads_initializer.dart`, `ad_constants.dart`, `completion_screen.dart`, `game_session_notifier.dart`, `game_session.dart`, `game_hud.dart`, `home_screen.dart`, `app.dart`
- **Flags reference (HIGH confidence):** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\admob_ad_service.dart` — App Open suppression pattern, interstitial/rewarded lifecycle, preloadAll() startup
- **Google AdMob interstitial guidance (HIGH confidence):** https://support.google.com/admob/answer/6066980 — natural transition points; no mid-gameplay; delay after level end
- **Google AdMob interstitial implementation (HIGH confidence):** https://developers.google.com/admob/android/interstitial — show from `initState`; preload; 1-session frequency recommendation
- **Google rewarded interstitial overview (HIGH confidence):** https://support.google.com/admob/answer/9884467 — intro screen requirement; skip option requirement; different from rewarded ad
- **Google App Open ad guidance (HIGH confidence):** https://support.google.com/admob/answer/9341964 — Families program exclusion; suppress during active gameplay; 4-hour expiry
- **AppLovin SDK 13.0 child-directed prohibition (HIGH confidence):** https://www.kidoz.net/blog/navigating-the-applovin-decision-a-guide-for-developers-with-kids-and-mixed-audiences — AppLovin left Families Self-Certified Ads SDK Program; SDK 13.0+ bans child-directed use
- **Google Play Families Self-Certified Ads SDK Program (HIGH confidence):** https://support.google.com/googleplay/android-developer/answer/9900633 — AdMob auto-blocks non-certified adapters; verify current certified list before submission
- **IronSource child-directed docs (HIGH confidence):** https://developers.is.com/ironsource-mobile/general/ironsource-mobile-child-directed-apps/ — independent SDK flag required
- **AdMob frequency caps (MEDIUM confidence):** https://support.google.com/admob/answer/6244508 — dashboard-level cap; start low, increase carefully; retention tradeoff
- **Rewarded ad UX best practices (MEDIUM confidence):** https://appsamurai.com/blog/rewarded-ads-in-mobile-games-strategy-data-and-best-practices/ — contextual trigger at moment of frustration; opt-in rates 15–30% at right moment; explicit reward messaging
- **Flutter RepaintBoundary screenshot + XFile.fromData() (HIGH confidence):** https://www.freecodecamp.org/news/how-to-save-and-share-flutter-widgets-as-images-a-complete-production-ready-guide/ — no external storage permission needed with XFile.fromData(); pixelRatio from MediaQuery
- **Sporcle US States quiz (MEDIUM confidence, direct observation):** https://www.sporcle.com/games/g/states — accepts full name only (no abbreviations); types input in list order; 15-minute timer; no autocomplete

---

*Feature research for: v2 — Speed Typing, AdMob, Rewarded Hints, Gated Sharing*
*Researched: 2026-06-02*
