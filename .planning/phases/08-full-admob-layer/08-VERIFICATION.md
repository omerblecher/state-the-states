---
phase: 08-full-admob-layer
verified: 2026-06-03T00:00:00Z
status: human_needed
score: 9/9 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Live banner ad renders on HomeScreen bottom"
    expected: "A real AdMob banner appears below the mode cards on a physical or emulator device with network access"
    why_human: "getBannerWidget() returns SizedBox.shrink() when the banner has not loaded from AdMob servers; cannot verify real ad delivery in a static code scan"
  - test: "App Open ad fires on cold launch and is suppressed during gameplay"
    expected: "First time the app reaches foreground after a cold launch, an App Open ad appears. When a game session is in GamePhase.playing or GamePhase.paused, the same foreground event triggers no ad"
    why_human: "AppStateEventNotifier fires on real device lifecycle events; suppression logic reads live gameSessionProvider state at runtime"
  - test: "Rewarded hint dialog — Watch Ad earns 2 hints"
    expected: "With hintsRemaining==0, tapping the hint button shows 'Watch an ad for 2 more hints?'; completing the ad refills to 2 and immediately uses 1 (leaving 1 remaining); dismissing shows the 'No ad available right now' Snackbar"
    why_human: "Full Completer<bool> flow requires a real AdMob rewarded ad to fire onUserEarnedReward; mock tests confirm the code path but not ad delivery"
  - test: "Interstitial fires once on CompletionScreen after 1-second delay"
    expected: "Navigating to CompletionScreen after finishing any game mode triggers one interstitial ad approximately 1 second after screen appears"
    why_human: "Future.delayed(1s) interstitial requires real ad inventory and device time passage; unit tests stub the AdService"
  - test: "AD-06: aapt confirms no AD_ID after full mediation AAR merge (developer confirmation)"
    expected: "aapt dump badging on app-release.apk returns zero lines matching AD_ID, AdServices, or ADVERTISING"
    why_human: "Automated probe was run and returned no output (PASS), but REQUIREMENTS.md traceability table still shows AD-06 as Pending — developer must confirm the tracker should be updated to Complete"
---

# Phase 08: Full AdMob Layer — Verification Report

**Phase Goal:** Full AdMob layer — COPPA-compliant ad integration with banner, interstitial, rewarded, and App Open ads; mediation (Unity/ironSource/InMobi); AD_ID blocked in merged manifest.
**Verified:** 2026-06-03T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | COPPA RequestConfiguration set before initialize(); Unity/ironSource/InMobi per-SDK flags set before that; AppLovin permanently disabled | VERIFIED | `ads_initializer.dart`: `updateRequestConfiguration` at Step 1; `GmaMediationIronsource().setConsent(false)`, `setDoNotSell(true)` at Steps 2–3; `GmaMediationUnity().setGDPRConsent(false)`, `setCCPAConsent(false)` at Steps 3–4; `kAppLovinEnabled = false` guard; `MobileAds.instance.initialize()` last at Step 6 |
| SC-2 | Banner at bottom of HomeScreen; interstitial on CompletionScreen.initState() 1-second delay; App Open on cold launch suppressed during playing/paused | VERIFIED | `home_screen.dart` line 179: `ref.watch(adServiceProvider).getBannerWidget()`; `completion_screen.dart` lines 87–89: `Future.delayed(1s, () { if (mounted) ref.read(adServiceProvider).showInterstitialAd(); })`; `app.dart` lines 82–87: AppStateEventNotifier subscription; `_onAppResumed()` suppression check at lines 91–94 |
| SC-3 | hintsRemaining==0 hint tap shows rewarded prompt; reward only in onUserEarnedReward; hint consumed immediately after refill | VERIFIED | `map_screen.dart`: `_onHintPressed()` forks at hintsRemaining==0 to `_showRewardedHintDialog()`; `_showRewardedHintDialog()` line 249: `refillHints()` then `useHint()` called on `earned==true` only; `real_ad_service.dart` lines 114–115, 125–128: `completer.complete(false)` only in `onAdDismissedFullScreenContent`, `completer.complete(true)` only in `onUserEarnedReward` |
| SC-4 | GameSessionNotifier has zero ad imports; all ad calls from widget layer | VERIFIED | `grep "^import.*ads\|^import.*google_mobile_ads\|^import.*gma_mediation" game_session_notifier.dart` returns no output; `refillHints()` is called from `_showRewardedHintDialog()` in widget layer; `showInterstitialAd()` called from `completion_screen.dart` widget; `showAppOpenAd()` called from `app.dart` widget |
| SC-5 | aapt dump badging confirms AD_ID absent after all mediation AARs merged | VERIFIED | `app-release.apk` (73.3 MB) exists; `aapt dump badging app-release.apk | Select-String "AD_ID\|AdServices\|ADVERTISING"` returns no output; 5 `tools:node="remove"` blocks present in AndroidManifest.xml (4 permissions + 1 uses-library for android.ext.adservices) |

**Score:** 5/5 success criteria verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pubspec.yaml` | gma_mediation_unity ^1.8.0, gma_mediation_ironsource ^2.4.1, gma_mediation_inmobi ^2.1.0 | VERIFIED | All three entries present at exact versions; gma_mediation_applovin absent |
| `lib/core/ads/ads_initializer.dart` | COPPA mediation flags before initialize() | VERIFIED | ironSource: setConsent(false)/setDoNotSell(true); Unity: setGDPRConsent(false)/setCCPAConsent(false); both before `MobileAds.instance.initialize()`; no gma_mediation_inmobi import |
| `lib/core/ads/ad_constants.dart` | Production ad unit IDs | VERIFIED | kAdMobAppId, kBannerAdUnitId, kInterstitialAdUnitId, kRewardedAdUnitId, kAppOpenAdUnitId all hold ca-app-pub-4227443066128564/* production values; no empty strings |
| `android/app/src/main/AndroidManifest.xml` | Production App ID + 4 permission removes + 1 library remove | VERIFIED | APPLICATION_ID = ca-app-pub-4227443066128564~7081667253; 5 tools:node="remove" blocks present |
| `lib/features/game/game_session_notifier.dart` | refillHints() method, zero ad imports | VERIFIED | `void refillHints()` at line 322: guards on null/phase!=playing; copyWith(hintsRemaining: 2); saveSession; zero ad imports confirmed by grep |
| `lib/core/ads/real_ad_service.dart` | Full RealAdService implements AdService | VERIFIED | All four ad types: banner (loadBannerForWidth + getBannerWidget), interstitial, rewarded (Completer<bool>), App Open (4-hour expiry + suppression); preloadAll(); getLargeAnchoredAdaptiveBannerAdSize |
| `lib/core/ads/app_state_observer.dart` | Re-export of AppStateEventNotifier and AppState | VERIFIED | 5-line re-export: `export 'package:google_mobile_ads/google_mobile_ads.dart' show AppStateEventNotifier, AppState;` |
| `lib/core/ads/ad_service_provider.dart` | Provider returning RealAdService(ref) + preloadAll() | VERIFIED | `Provider<AdService>((ref) { final service = RealAdService(ref); service.preloadAll(); return service; })` |
| `lib/app.dart` | ConsumerStatefulWidget with App Open lifecycle | VERIFIED | `class App extends ConsumerStatefulWidget`; `class _AppState extends ConsumerState<App>`; `AppStateEventNotifier.startListening()` in initState; `_appStateSubscription?.cancel()` in dispose; playing/paused suppression in `_onAppResumed()` |
| `lib/features/game/state_tray.dart` | Hint button enabled when onHintPressed != null | VERIFIED | `_buildHintButton` line 136: `final enabled = widget.onHintPressed != null;` — no hintsRemaining > 0 condition |
| `lib/features/map/map_screen.dart` | _onHintPressed fork + _showRewardedHintDialog | VERIFIED | `_onHintPressed()` forks at `session?.hintsRemaining == 0`; `_showRewardedHintDialog()` shows AlertDialog; adServiceProvider.showRewardedAd(); refillHints() + useHint() on earned; Snackbar "No ad available right now — try again later." on failure |
| `lib/features/home/home_screen.dart` | Banner slot + loadBannerForWidth in initState | VERIFIED | initState: `addPostFrameCallback` calls `(ref.read(adServiceProvider) as RealAdService).loadBannerForWidth(widthDp)`; Column: `ref.watch(adServiceProvider).getBannerWidget()` at line 179 between ListView and privacy footer |
| `lib/features/map/completion_screen.dart` | Interstitial in initState with 1-second delay | VERIFIED | `Future.delayed(const Duration(seconds: 1), () { if (mounted) ref.read(adServiceProvider).showInterstitialAd(); })` at line 87–89 |
| `build/app/outputs/flutter-apk/app-release.apk` | Release APK with mediation AARs | VERIFIED | File exists; aapt probe returned zero AD_ID/AdServices/ADVERTISING matches |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ads_initializer.dart` | `MobileAds.instance.initialize()` | COPPA flags before call | WIRED | ironSource/Unity flags at Steps 2–4; initialize() at Step 6 |
| `ad_service_provider.dart` | `real_ad_service.dart` | `RealAdService(ref)` | WIRED | `final service = RealAdService(ref); service.preloadAll(); return service;` |
| `real_ad_service.dart` | `game_session_notifier.dart` | `_ref.read(gameSessionProvider)` | WIRED | showAppOpenAd() reads session phase via `_ref.read(gameSessionProvider).value` |
| `real_ad_service.dart` | `ad_constants.dart` | `kBannerAdUnitId`, `kInterstitialAdUnitId`, `kRewardedAdUnitId`, `kAppOpenAdUnitId` | WIRED | All four unit ID constants imported and used in respective ad load calls |
| `app.dart` | `app_state_observer.dart` | import app_state_observer.dart | WIRED | Import present; `AppStateEventNotifier.startListening()` + stream subscription in initState |
| `app.dart` | `game_session_notifier.dart` | `ref.read(gameSessionProvider)` | WIRED | `_onAppResumed()` reads phase via `ref.read(gameSessionProvider).value?.phase` |
| `app.dart` | `ad_service_provider.dart` | `ref.read(adServiceProvider)` | WIRED | `ref.read(adServiceProvider).showAppOpenAd()` in `_onAppResumed()` |
| `map_screen.dart` | `ad_service_provider.dart` | `ref.read(adServiceProvider).showRewardedAd()` | WIRED | `_showRewardedHintDialog()` line 246 |
| `home_screen.dart` | `ad_service_provider.dart` | `ref.watch(adServiceProvider).getBannerWidget()` | WIRED | Line 179 |
| `completion_screen.dart` | `ad_service_provider.dart` | `ref.read(adServiceProvider).showInterstitialAd()` | WIRED | Line 88 |
| `AndroidManifest.xml` | `app-release.apk` | `tools:node="remove"` surviving AAR merge | WIRED | 5 removal blocks; aapt probe confirms zero AD_ID/AdServices/ADVERTISING in merged output |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `home_screen.dart` | `getBannerWidget()` return | `_bannerAd` field in `RealAdService`, populated by `AdMob SDK` on `onAdLoaded` | Only if AdMob returns a live ad | WIRED — static fallback `SizedBox.shrink()` is correct behavior when no ad loaded; not a stub |
| `real_ad_service.dart` | App Open suppression | `_ref.read(gameSessionProvider).value?.phase` | Real Riverpod state | FLOWING — reads live provider state |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| gma_mediation_inmobi absent from ads_initializer.dart source | `grep "gma_mediation_inmobi" lib/core/ads/ads_initializer.dart` | no output | PASS |
| ad imports absent from game_session_notifier.dart | `grep "^import.*ads\|^import.*google_mobile_ads\|^import.*gma_mediation" lib/features/game/game_session_notifier.dart` | no output | PASS |
| 5 tools:node="remove" blocks in AndroidManifest.xml | count of `tools:node="remove"` in manifest | 5 matches | PASS |
| aapt dump badging returns no AD_ID/AdServices/ADVERTISING | `aapt.exe dump badging app-release.apk \| Select-String "AD_ID\|AdServices\|ADVERTISING"` | no output | PASS |
| RealAdService.showRewardedAd() uses Completer<bool> | grep "Completer<bool>" real_ad_service.dart | match found | PASS |
| getLargeAnchoredAdaptiveBannerAdSize used (not deprecated variant) | grep "getLargeAnchoredAdaptiveBannerAdSize" real_ad_service.dart | match found | PASS |
| getCurrentOrientationAnchoredAdaptiveBannerAdSize absent | grep "getCurrentOrientation" real_ad_service.dart | no output | PASS |

---

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| AD-06 aapt | `aapt.exe dump badging app-release.apk \| Select-String "AD_ID\|AdServices\|ADVERTISING"` | exit 0, no output | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| AD-01 | 08-01 | RequestConfiguration COPPA flags before initialize() | SATISFIED | ads_initializer.dart: updateRequestConfiguration(tagForChildDirectedTreatment:yes, maxAdContentRating:g) at Step 1 before initialize() at Step 6 |
| AD-02 | 08-01 | Unity/ironSource/InMobi per-SDK COPPA flags; AppLovin disabled | SATISFIED | ads_initializer.dart: GmaMediationIronsource().setConsent(false)/setDoNotSell(true); GmaMediationUnity().setGDPRConsent(false)/setCCPAConsent(false); kAppLovinEnabled=false guard; no gma_mediation_inmobi import |
| AD-03 | 08-02, 08-04 | Banner ad at bottom of HomeScreen | SATISFIED | home_screen.dart lines 29–33 (loadBannerForWidth in addPostFrameCallback) + line 179 (getBannerWidget() in Column) |
| AD-04 | 08-02, 08-04 | Interstitial once on CompletionScreen.initState() | SATISFIED | completion_screen.dart lines 86–89: Future.delayed(1s) showInterstitialAd() |
| AD-05 | 08-02, 08-03 | App Open on cold launch; suppressed when GamePhase.playing/paused | SATISFIED | real_ad_service.dart showAppOpenAd() reads gameSessionProvider phase; app.dart _onAppResumed() second-layer suppression |
| AD-06 | 08-05 | AD_ID absent in merged manifest after mediation AARs | SATISFIED (tracker pending) | aapt dump badging probe returned no output; 5 tools:node="remove" blocks present; REQUIREMENTS.md traceability still shows Pending — needs tracker update |
| HINT-03 | 08-04 | hintsRemaining==0 hint tap shows rewarded prompt | SATISFIED | map_screen.dart _onHintPressed() forks to _showRewardedHintDialog(); state_tray.dart enabled=widget.onHintPressed!=null |
| HINT-04 | 08-01 | refillHints() resets hintsRemaining to 2 | SATISFIED | game_session_notifier.dart: void refillHints() at line 322; called from _showRewardedHintDialog() after earned==true; useHint() immediately after |
| HINT-05 | 08-02 | Reward only in onUserEarnedReward, never in onAdDismissedFullScreenContent | SATISFIED | real_ad_service.dart: completer.complete(true) only in `onUserEarnedReward` lambda (line 127); completer.complete(false) in dismiss callback (line 115) |

---

### Anti-Patterns Found

No blockers or warnings found.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | — |

No TBD/FIXME/XXX/HACK/PLACEHOLDER markers found in any file modified by this phase.

---

### Human Verification Required

#### 1. Live Banner Ad on HomeScreen

**Test:** On a physical Android device or emulator with network access, launch the app and navigate to the HomeScreen.
**Expected:** A real AdMob banner ad renders below the mode cards at the bottom of the screen. `SizedBox.shrink()` (zero height) is shown while the ad loads or if the load fails.
**Why human:** `getBannerWidget()` returns `SizedBox.shrink()` when `_bannerAd` is null; real ad delivery requires a live AdMob network request that cannot be verified via static code analysis.

#### 2. App Open Ad Lifecycle (Cold Launch + Gameplay Suppression)

**Test:** Cold-launch the app (kill and relaunch). Navigate into a game session (GamePhase.playing). Background and re-foreground the app.
**Expected:** First foreground after cold launch triggers an App Open ad. While in GamePhase.playing or GamePhase.paused, foregrounding does NOT show an App Open ad.
**Why human:** AppStateEventNotifier fires on real device lifecycle; gameSessionProvider phase is live Riverpod state; cannot simulate in static analysis.

#### 3. Rewarded Hint Refill Flow (End-to-End)

**Test:** Start a game, use both hints, then tap the hint button with hintsRemaining==0. Choose "Watch Ad". Watch the full rewarded ad to completion.
**Expected:** "Watch an ad for 2 more hints?" dialog appears; after completing the ad, hintsRemaining resets (briefly 2) then immediately drops to 1 as one hint is consumed; the hint glow animation fires. Dismiss the ad without completing — the Snackbar "No ad available right now — try again later." appears.
**Why human:** Full Completer<bool> flow requires a live AdMob rewarded ad delivering onUserEarnedReward; unit tests confirm the code paths but not actual ad delivery.

#### 4. Interstitial on CompletionScreen

**Test:** Complete any game mode (drag-and-drop or speed typing). On the CompletionScreen, wait approximately 1 second.
**Expected:** An interstitial ad fires approximately 1 second after the CompletionScreen appears.
**Why human:** Future.delayed(1s) interstitial requires real ad inventory and device time passage; unit tests use StubAdService.

#### 5. AD-06 Tracker Inconsistency — Confirm REQUIREMENTS.md Update

**Test:** The automated aapt probe confirmed: `aapt dump badging app-release.apk | Select-String "AD_ID|AdServices|ADVERTISING"` returns no output. However, REQUIREMENTS.md traceability table still shows `AD-06 | Phase 8 (v2) | Pending`.
**Expected:** REQUIREMENTS.md should show `AD-06 | Phase 8 (v2) | Complete`.
**Why human:** The verifier ran the aapt probe and confirmed PASS. The developer must decide whether to update the REQUIREMENTS.md tracker to reflect this, or re-run the probe independently to confirm before closing the requirement.

---

### Gaps Summary

No technical gaps found. All 9 requirement IDs (AD-01 through AD-06, HINT-03, HINT-04, HINT-05) are satisfied in the codebase. All 5 roadmap success criteria are verified.

One administrative item requires human attention: REQUIREMENTS.md traceability shows `AD-06` as `Pending` despite the build artifact and aapt probe confirming the feature is implemented. This is a documentation update, not a code gap.

---

_Verified: 2026-06-03T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
