# Phase 8: Full AdMob Layer - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 8 activates the full ad monetization layer that was stubbed in v1:

1. **RealAdService** — Replace `StubAdService` with a `RealAdService` implementing the existing `AdService` interface. Manages internal lifecycle for all 4 ad types: `BannerAd`, `InterstitialAd`, `RewardedAd`, `AppOpenAd`.
2. **COPPA init order** — Before `MobileAds.instance.initialize()`: set `RequestConfiguration` (already done), then set per-SDK COPPA flags on Unity, ironSource, and InMobi adapters. AppLovin is permanently disabled (`kAppLovinEnabled = false`).
3. **Mediation adapters** — Add `gma_mediation_unity`, `gma_mediation_ironsource`, `gma_mediation_inmobi` to `pubspec.yaml`.
4. **Banner** — Load adaptive banner; display at the bottom of `HomeScreen` via `adService.getBannerWidget()`.
5. **Interstitial** — Preload and fire once on `CompletionScreen.initState()` with a 1-second delay, for all modes.
6. **Rewarded** — When `hintsRemaining == 0` and the player taps the hint button: prompt "Watch an ad for 2 more hints?"; on completion trigger `refillHints()` inside `onUserEarnedReward` only.
7. **App Open** — Show on cold app launch; suppress when `GamePhase.playing` or `GamePhase.paused`.
8. **Production IDs** — Replace all empty-string constants and the test App ID in `AndroidManifest.xml` with real production values.
9. **COPPA verification** — After all mediation AARs merge: `aapt dump badging app-release.apk` confirms `AD_ID` is still absent.

**What is NOT in Phase 8:** Any new game mode, UI changes beyond the HomeScreen banner slot, Firebase (ever), AppLovin (ever), any change to `GameSessionNotifier`'s import graph (walled-garden rule preserved).

</domain>

<decisions>
## Implementation Decisions

### Ad Unit IDs

- **D-01: Production AdMob IDs are available and will be hard-coded in `lib/core/ads/ad_constants.dart`.** All four unit IDs (banner, interstitial, rewarded, App Open) replace the current empty strings. No Dart-define or env-var mechanism needed — IDs are not secret (they appear in APK resources regardless).
- **D-02: Real AdMob App ID replaces the test App ID in `AndroidManifest.xml`.** The `com.google.android.gms.ads.APPLICATION_ID` meta-data value is updated to the production App ID. Do this in the same plan as activating `RealAdService`.

### Mediation Scope

- **D-03: All three mediation adapters ship in phase 8.** Add `gma_mediation_unity`, `gma_mediation_ironsource`, `gma_mediation_inmobi` to `pubspec.yaml` (versions from CLAUDE.md: `^1.8.0`, `^2.4.1`, `^2.1.0`). AppLovin remains permanently disabled — do not add `gma_mediation_applovin` to `pubspec.yaml` and keep `kAppLovinEnabled = false`.
- **D-04: Per-SDK COPPA flags for Unity, ironSource, and InMobi are set in `ads_initializer.dart` before `MobileAds.instance.initialize()`.** Current `initializeAds()` has a comment noting mediation flags are omitted in v1; remove that comment and add the three flag calls in the correct pre-init position.
- **D-05: COPPA / AD_ID verification via `aapt dump badging app-release.apk`.** Same verification pattern used in Phase 1. Run after all mediation AARs are present in the merged manifest to confirm `tools:remove` on `AD_ID` survived.

### Banner Placement

- **D-06: Banner appears on HomeScreen only.** Positioned at the bottom of the screen, below the mode cards. No banner on `MapScreen`, `SpeedTypingScreen`, or `CompletionScreen`. One `getBannerWidget()` call site total.

### Rewarded Hint Refill

- **D-07: `refillHints()` in `GameSessionNotifier` resets `hintsRemaining` to exactly 2** (not additive). This is a new method alongside the existing `useHint()`. Called from the widget layer inside `onUserEarnedReward` only — never inside `onAdDismissedFullScreenContent`.
- **D-08: Rewarded prompt triggers only when `hintsRemaining == 0`.** When the player taps the hint button with 0 hints, show a dialog: "Watch an ad for 2 more hints?" rather than silently doing nothing or showing the prompt at any hint count.
- **D-09: Ad load failure shows a Snackbar.** Message: "No ad available right now — try again later." Consistent with the existing incorrect-drop Snackbar pattern in `MapScreen`. No hint granted on failure.

### Claude's Discretion

- **RealAdService architecture:** Single class implementing `AdService`; internal fields for each ad type. Standard preload-on-load-completion pattern (preload a new interstitial after showing the current one). Banner is loaded once and reused; App Open ad checks its 4-hour expiry before showing.
- **App Open suppression:** `app.dart` observes `AppLifecycleState.resume` via `WidgetsBindingObserver`. Before calling `showAppOpenAd()`, reads `gameSessionProvider` state — if `GamePhase.playing` or `GamePhase.paused`, suppresses the show. Cold launch path also calls `showAppOpenAd()` after `initializeAds()`.
- **`adServiceProvider` switch:** `ad_service_provider.dart` changes from returning `StubAdService()` to returning `RealAdService(...)`. No other file changes for the provider.
- **Rewarded hint prompt:** A simple `showDialog` from the hint button handler in `StateTray` (or the caller in `MapScreen`). Two actions: "Watch Ad" (triggers `adService.showRewardedAd()`) and "Cancel".

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 8 Requirements & Goal
- `.planning/ROADMAP.md` §"Phase 8: Full AdMob Layer" — goal, 5 success criteria (verification targets), dependency note (requires Phase 5; 6 and 7 recommended).
- `.planning/REQUIREMENTS.md` §v2 Requirements — AD-01 through AD-06, HINT-03 through HINT-05.
- `.planning/PROJECT.md` — COPPA constraints, walled-garden ad rule, offline requirement, AppLovin disabled rationale.
- `CLAUDE.md` — locked stack versions for all `gma_mediation_*` packages, "What NOT to Use" (no Firebase, no AppLovin unless account approved + back on Families list).

### Existing Ad Infrastructure (extend, do not rewrite)
- `lib/core/ads/ad_service.dart` — `AdService` abstract interface (4 methods). `RealAdService` must satisfy this contract.
- `lib/core/ads/stub_ad_service.dart` — Current v1 walled garden; will be replaced by `RealAdService` in `ad_service_provider.dart`. Keep `StubAdService` for tests.
- `lib/core/ads/ad_constants.dart` — All unit IDs and App ID live here. Replace empty strings + test App ID with production values.
- `lib/core/ads/ads_initializer.dart` — COPPA init order already correct. Add mediation SDK COPPA flag calls before `MobileAds.instance.initialize()`.
- `lib/core/ads/ad_service_provider.dart` — Switch from `StubAdService()` to `RealAdService(...)`.
- `lib/core/ads/ad_load_state.dart` — `AdLoaded` / `AdFailed` sealed class; may be used internally by `RealAdService`.

### Hint System (extend)
- `lib/features/game/game_session_notifier.dart` — `useHint()` exists (lines 293–310). Add `refillHints()` alongside it. Zero ad imports — walled-garden rule is inviolable.
- `lib/features/game/state_tray.dart` — Hint button with `hintsRemaining` display. The rewarded-ad prompt originates from this widget's `onHintPressed` callback (or its caller in `MapScreen`).

### Ad Call Sites (to add)
- `lib/features/home/home_screen.dart` — Banner slot at bottom via `adService.getBannerWidget()`.
- `lib/features/map/completion_screen.dart` — Interstitial via `adService.showInterstitialAd()` in `initState()` with 1-second delay.
- `lib/app.dart` — App Open ad on cold launch + `AppLifecycleState.resume` handler.

### Prior Phase Context
- `.planning/phases/07-gated-sharing-completion/07-CONTEXT.md` — Phase 7 decisions (sharing completion). No direct overlap with ads; confirms walled-garden rule still intact.
- `.planning/phases/05-polish-welcome-accessibility/05-CONTEXT.md` — Phase 5 decisions; COPPA audit baseline.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AdService` interface: fully defined with the 4 methods `RealAdService` must implement. No changes to the interface.
- `StubAdService`: Keep as test double; tests can inject it to avoid real SDK calls.
- `ads_initializer.dart`: COPPA init sequence is correct — only needs mediation SDK flag calls added before the `initialize()` call.
- `AdLoadState` sealed class: Available for internal `RealAdService` state tracking if useful.
- `GameSessionNotifier.useHint()`: Clear pattern for adding the sibling `refillHints()` method (lines 293–310).

### Established Patterns
- **Walled-garden ad rule:** `GameSessionNotifier` has zero ad imports. All ad calls originate from the widget layer. This is a hard constraint carried from Phase 1.
- **StubAdService wiring:** `adServiceProvider` returns `StubAdService()` — this is the single switch point. Change only this file to activate real ads.
- **COPPA init order:** `updateRequestConfiguration` → (add: mediation flags) → `MobileAds.instance.initialize()`. Already documented in `ads_initializer.dart`'s comment block.
- **Snackbar for user feedback:** Existing pattern in `MapScreen` for incorrect drops — reuse for "No ad available" message.
- **`aapt dump badging` verification:** Phase 1 COMP-02 verification pattern — reuse for Phase 8 AD_ID confirmation after mediation AAR merge.

### Integration Points
- `lib/app.dart` — App Open ad wired here via `WidgetsBindingObserver`; reads `gameSessionProvider` to check `GamePhase` before showing.
- `lib/features/home/home_screen.dart` — Banner widget embedded at the bottom of the `Scaffold` body (outside the `ListView`/`Column` of mode cards).
- `lib/features/map/completion_screen.dart` — `initState()` fires `showInterstitialAd()` after a 1-second `Future.delayed`.
- `lib/features/game/state_tray.dart` — Hint button `onPressed` handler triggers the rewarded prompt when `hintsRemaining == 0`.

</code_context>

<specifics>
## Specific Ideas

- The rewarded hint prompt is a standard `showDialog` with "Watch Ad" and "Cancel" — no custom widget needed.
- The hint refill dialog copy: "Watch an ad for 2 more hints?" (from ROADMAP SC #3).
- "No ad available right now — try again later." is the Snackbar copy for failed ad load.
- AppLovin: `kAppLovinEnabled = false` stays as-is. Do NOT add `gma_mediation_applovin` to `pubspec.yaml` in this phase.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 8-Full AdMob Layer*
*Context gathered: 2026-06-03*
