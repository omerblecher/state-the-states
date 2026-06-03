# Phase 8: Full AdMob Layer - Research

**Researched:** 2026-06-03
**Domain:** Flutter / Google Mobile Ads SDK 8.x, mediation COPPA init, AdMob lifecycle
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Production AdMob IDs hard-coded in `lib/core/ads/ad_constants.dart`. No Dart-define or env-var mechanism.
- **D-02:** Real AdMob App ID replaces test App ID in `AndroidManifest.xml`.
- **D-03:** All three mediation adapters ship in phase 8: `gma_mediation_unity ^1.8.0`, `gma_mediation_ironsource ^2.4.1`, `gma_mediation_inmobi ^2.1.0`. AppLovin permanently disabled — do NOT add `gma_mediation_applovin` to `pubspec.yaml`; keep `kAppLovinEnabled = false`.
- **D-04:** Per-SDK COPPA flags for Unity, ironSource, and InMobi are set in `ads_initializer.dart` before `MobileAds.instance.initialize()`.
- **D-05:** COPPA / AD_ID verification via `aapt dump badging app-release.apk`. Run after all mediation AARs present in merged manifest.
- **D-06:** Banner on HomeScreen only. Positioned at the bottom, below the mode cards. One `getBannerWidget()` call site total.
- **D-07:** `refillHints()` resets `hintsRemaining` to exactly 2 (not additive).
- **D-08:** Rewarded prompt triggers only when `hintsRemaining == 0`.
- **D-09:** Ad load failure shows a Snackbar: "No ad available right now — try again later."
- **Walled-garden:** `GameSessionNotifier` has zero ad imports (inviolable).

### Claude's Discretion

- RealAdService architecture: single class implementing `AdService`; internal fields for each ad type.
- App Open suppression: `app.dart` observes `AppLifecycleState.resume` via `AppStateEventNotifier`; reads `gameSessionProvider`; suppresses when `GamePhase.playing` or `GamePhase.paused`.
- `adServiceProvider` switch: `ad_service_provider.dart` changes from `StubAdService()` to `RealAdService(...)`.
- Rewarded hint prompt: simple `showDialog` from hint button handler in `StateTray`/`MapScreen`. Actions: "Watch Ad" and "Cancel".

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AD-01 | `RequestConfiguration` with `tagForChildDirectedTreatment: yes` and `maxAdContentRating: g` set before `MobileAds.instance.initialize()` | Already in `ads_initializer.dart`; no change needed |
| AD-02 | Unity, ironSource, and InMobi per-SDK COPPA flags in `ads_initializer.dart` before initialize() | Exact method signatures verified from installed package source |
| AD-03 | Banner ad at bottom of HomeScreen | `AdSize.getLargeAnchoredAdaptiveBannerAdSize()` + `AdWidget` + `loadBannerForWidth()` pattern from Flags |
| AD-04 | Interstitial once on `CompletionScreen.initState()` (1-second delay) | `InterstitialAd.load()` + `fullScreenContentCallback` + preload-on-dismiss |
| AD-05 | App Open on cold launch; suppressed during active game | `AppStateEventNotifier` pattern from Flags `app.dart` |
| AD-06 | AD_ID still blocked after mediation AARs merge | `aapt dump badging` verification; `tools:node="remove"` in manifest |
| HINT-03 | "Watch an ad for 2 more hints?" prompt when `hintsRemaining == 0` | `showDialog` from `StateTray` / `MapScreen` hint handler |
| HINT-04 | `refillHints()` resets to 2; hint immediately consumed | New method on `GameSessionNotifier`; called from `onUserEarnedReward` only |
| HINT-05 | Reward in `onUserEarnedReward` only, never in `onAdDismissedFullScreenContent` | Verified in SDK source and Flags `AdMobAdService` pattern |
</phase_requirements>

---

## Summary

Phase 8 activates the ad monetization layer that has been stubbed since Phase 1. The work is a near-direct port of `FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart` — that file exists in the local repo at `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\admob_ad_service.dart` and implements all four ad types against the same `AdService` interface this project already uses. The primary research task was verifying the per-SDK COPPA flag method signatures from the installed package source — this is where the highest-confidence gap existed.

**Critical finding for D-04 (COPPA mediation flags):** The three adapters have fundamentally different Dart-side COPPA surfaces:

1. **Unity** (`gma_mediation_unity ^1.8.0`): Two Dart methods: `GmaMediationUnity().setGDPRConsent(false)` and `GmaMediationUnity().setCCPAConsent(false)`. Both are `Future<void>`.
2. **ironSource** (`gma_mediation_ironsource ^2.4.1`): Two Dart methods: `GmaMediationIronsource().setConsent(false)` (GDPR) and `GmaMediationIronsource().setDoNotSell(true)` (CCPA/US privacy). Both are `Future<void>`.
3. **InMobi** (`gma_mediation_inmobi ^2.1.0`): **Zero Dart-side COPPA API.** `GmaMediationInMobi` is an empty stub class. The Android plugin (`GmaMediationInMobiPlugin.kt`) is also a pure stub — it does nothing on attach/detach. InMobi COPPA is handled automatically by the native adapter forwarding `tagForChildDirectedTreatment` from GMA's `RequestConfiguration`. No Dart call is needed or possible.

This is already the exact pattern implemented in `FlagsRoundTheWorld/lib/core/ads/ads_initializer.dart` (verified direct read). The Flags project has already solved this correctly and is the canonical reference for `ads_initializer.dart` changes in Phase 8.

**Primary recommendation:** Port `AdMobAdService` from Flags as `RealAdService` with namespace adjustments; port `app.dart` App Open observer pattern; add `refillHints()` to `GameSessionNotifier`; wire `StateTray` hint-zero dialog.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Ad SDK initialization (COPPA flags) | Backend-equivalent: `main.dart` / `ads_initializer.dart` | — | Must run before `runApp`; platform-level concern |
| Ad loading and lifecycle (banner, interstitial, rewarded, App Open) | `RealAdService` (core/ads layer) | — | Encapsulated behind `AdService` interface; screens never import SDK |
| App Open ad trigger on resume | `app.dart` (`_AppState` StatefulWidget) | reads `gameSessionProvider` | Only place with access to app lifecycle AND game phase simultaneously |
| Banner display | `HomeScreen` widget | `adServiceProvider` | Layout concern; banner slot is below mode cards |
| Interstitial trigger | `CompletionScreen.initState()` | `adServiceProvider` | Post-game trigger; one call site |
| Rewarded ad dialog + trigger | `StateTray` / `MapScreen` widget layer | `adServiceProvider`, `gameSessionProvider` | D-08 condition is UI-driven; walled-garden prohibits notifier involvement |
| Hint refill logic | `GameSessionNotifier.refillHints()` | — | Pure game state; zero ad imports (walled-garden) |

---

## Standard Stack

All packages are already in `pubspec.yaml` or are additions locked by D-03.

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `google_mobile_ads` | `^8.0.0` | Banner, Interstitial, Rewarded, AppOpenAd | Already in pubspec; locked in CLAUDE.md |
| `gma_mediation_unity` | `^1.8.0` | Unity Ads mediation adapter | D-03 locked; in pub cache at 1.8.0 |
| `gma_mediation_ironsource` | `^2.4.1` | ironSource/LevelPlay mediation adapter | D-03 locked; in pub cache at 2.4.1 |
| `gma_mediation_inmobi` | `^2.1.0` | InMobi mediation adapter | D-03 locked; in pub cache at 2.1.0 |
| `flutter_riverpod` | `^3.3.1` | Provider for `adServiceProvider` | Already in pubspec |

### Supporting

No new supporting packages. The existing stack covers all needs.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `AppStateEventNotifier` (GMA SDK) | `WidgetsBindingObserver` | GMA's `AppStateEventNotifier` is the documented App Open resume pattern for Flutter; avoids duplicating lifecycle observation |
| `AdSize.getLargeAnchoredAdaptiveBannerAdSize()` | `getCurrentOrientationAnchoredAdaptiveBannerAdSize()` | The `current` variant is `@Deprecated('Use getLargeAnchoredAdaptiveBannerAdSize instead')` as of gma 8.x — confirmed in source |

**Installation (add to `pubspec.yaml` dependencies):**
```bash
# Add to pubspec.yaml dependencies section:
# gma_mediation_unity: ^1.8.0
# gma_mediation_ironsource: ^2.4.1
# gma_mediation_inmobi: ^2.1.0
```
Then: `flutter pub get`

---

## Package Legitimacy Audit

All four packages are published by `google.dev` (the Google Developers publisher on pub.dev) and are present in the local pub cache at the exact locked versions. These are official Google-published packages.

| Package | Registry | Publisher | In Pub Cache | slopcheck | Disposition |
|---------|----------|-----------|-------------|-----------|-------------|
| `gma_mediation_unity` | pub.dev | google.dev | 1.8.0 | [OK] | Approved |
| `gma_mediation_ironsource` | pub.dev | google.dev | 2.4.1 | [OK] | Approved |
| `gma_mediation_inmobi` | pub.dev | google.dev | 2.1.0 | [OK] | Approved |
| `google_mobile_ads` | pub.dev | google.dev | 8.0.0 | [OK] | Already in pubspec |

[VERIFIED: pub cache at `C:\Users\omerb\AppData\Local\Pub\Cache\hosted\pub.dev\`]

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
main()
  └─ initializeAds()  [ads_initializer.dart]
       1. MobileAds.updateRequestConfiguration(tagForChildDirectedTreatment=yes)
       2. GmaMediationIronsource().setConsent(false)  ← GDPR
       3. GmaMediationIronsource().setDoNotSell(true) ← CCPA/US
       4. GmaMediationUnity().setGDPRConsent(false)
       5. GmaMediationUnity().setCCPAConsent(false)
       6. (InMobi: NO call — auto-forwarded by native adapter)
       7. MobileAds.instance.initialize()
  └─ RealAdService.preloadAll()
       ├─ InterstitialAd.load()
       ├─ RewardedAd.load()
       └─ AppOpenAd.load()  → stores _appOpenLoadTime

runApp(ProviderScope(child: App()))
  App [ConsumerStatefulWidget] — app.dart
    initState:
      AppStateEventNotifier.startListening()
      stream.listen(AppState.foreground → _onAppResumed)
    _onAppResumed:
      if (phase == playing || phase == paused) return    ← suppression
      adService.showAppOpenAd()                          ← cold launch + resume
    build → MaterialApp.router

HomeScreen
  Column:
    [session restore card]
    [header + subtitle]
    Expanded(ListView[mode cards])
    adService.getBannerWidget()   ← banner slot (bottom, outside ListView)
    [privacy footer]

MapScreen (GamePhase.playing)
  StateTray.onHintPressed:
    if hintsRemaining == 0:
      showDialog("Watch an ad for 2 more hints?")
        "Watch Ad" → adService.showRewardedAd() → Future<bool>
          onUserEarnedReward fires → returns true
          caller: gameSession.refillHints() then gameSession.useHint()
          on false/failure: Snackbar("No ad available right now — try again later.")
        "Cancel" → dismiss

CompletionScreen.initState():
  Future.delayed(1 second, () => adService.showInterstitialAd())

RealAdService (lib/core/ads/real_ad_service.dart)
  _interstitialAd: on dismiss → dispose + _preloadInterstitial()
  _rewardedAd: Completer<bool>; onUserEarnedReward → complete(true);
               onDismissed → complete(false) if not completed
  _appOpenAd: DateTime _appOpenLoadTime; expiry check < 4 hours
  _bannerAd: loaded once via loadBannerForWidth(screenWidthDp)
```

### Recommended Project Structure

No new folders needed. One new file:

```
lib/core/ads/
├── ad_service.dart           (unchanged — interface)
├── stub_ad_service.dart      (unchanged — keep for tests)
├── real_ad_service.dart      (NEW — RealAdService implementation)
├── ads_initializer.dart      (MODIFY — add mediation COPPA calls)
├── ad_constants.dart         (MODIFY — replace empty strings with prod IDs)
├── ad_service_provider.dart  (MODIFY — return RealAdService instead of StubAdService)
├── ad_load_state.dart        (unchanged)
└── app_state_observer.dart   (NEW — thin re-export of AppStateEventNotifier, AppState)
```

`app.dart` converts from `StatelessWidget` to `ConsumerStatefulWidget` to host `AppStateEventNotifier` subscription.

`GameSessionNotifier` gets one new method: `refillHints()` — no other changes, zero ad imports.

### Pattern 1: COPPA Init Order in `ads_initializer.dart`

**What:** Set all COPPA flags BEFORE `MobileAds.instance.initialize()`. Order within flags doesn't matter; order relative to initialize() does.

**Verified from:** `FlagsRoundTheWorld/lib/core/ads/ads_initializer.dart` (direct read) and installed package source

```dart
// Source: FlagsRoundTheWorld/lib/core/ads/ads_initializer.dart (direct read)
// Exact method signatures verified from installed pub cache source.
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';
// NOTE: no import for gma_mediation_inmobi — it has NO Dart-side COPPA API

Future<void> initializeAds() async {
  // Step 1: GMA global child-directed flag
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      maxAdContentRating: MaxAdContentRating.g,
    ),
  );

  // Step 2: ironSource — setDoNotSell for US state privacy (belt-and-suspenders)
  // GDPR consent: false = no consent for children
  // setConsent maps to IronSource GDPR; setDoNotSell maps to CCPA/CPRA
  GmaMediationIronsource().setConsent(false);
  GmaMediationIronsource().setDoNotSell(true);

  // Step 3: Unity — no GDPR consent + no CCPA consent (child-directed, no data sold)
  await GmaMediationUnity().setGDPRConsent(false);
  await GmaMediationUnity().setCCPAConsent(false);

  // Step 4: InMobi — NO DART CALL. GmaMediationInMobi is an empty class.
  // The native InMobi adapter automatically forwards tagForChildDirectedTreatment
  // from MobileAds RequestConfiguration set in Step 1.

  // Step 5: AppLovin permanently disabled
  if (kAppLovinEnabled) { /* activate when account approved */ }

  // LAST: initialize after all flags
  await MobileAds.instance.initialize();
}
```

[VERIFIED: installed package source `gma_mediation_unity-1.8.0/lib/gma_mediation_unity.dart`, `gma_mediation_ironsource-2.4.1/lib/gma_mediation_ironsource.dart`, `gma_mediation_inmobi-2.1.0/lib/gma_mediation_inmobi.dart`]

### Pattern 2: App Open Ad — `AppStateEventNotifier` (not `WidgetsBindingObserver`)

**What:** GMA SDK provides `AppStateEventNotifier` that fires `AppState.foreground` on resume. This is the documented Flutter App Open pattern. The Flags project uses it correctly.

**Why not `WidgetsBindingObserver`:** CONTEXT.md mentions `WidgetsBindingObserver` in the Claude's Discretion section; however the Flags baseline uses `AppStateEventNotifier` which is the GMA-idiomatic pattern. Both work; `AppStateEventNotifier` avoids manual lifecycle observation and is the GMA Flutter documentation recommendation.

```dart
// Source: FlagsRoundTheWorld/lib/app.dart (direct read)
// app_state_observer.dart re-exports AppStateEventNotifier and AppState
// so app.dart does not import google_mobile_ads directly.
class App extends ConsumerStatefulWidget { ... }
class _AppState extends ConsumerState<App> {
  StreamSubscription<AppState>? _appStateSubscription;

  @override
  void initState() {
    super.initState();
    AppStateEventNotifier.startListening();
    _appStateSubscription = AppStateEventNotifier.appStateStream.listen(
      (appState) {
        if (appState == AppState.foreground) _onAppResumed();
      },
    );
  }

  void _onAppResumed() {
    final phase = ref.read(gameSessionProvider).value?.phase;
    if (phase == GamePhase.playing || phase == GamePhase.paused) return;
    ref.read(adServiceProvider).showAppOpenAd();
  }

  @override
  void dispose() {
    _appStateSubscription?.cancel();
    super.dispose();
  }
}
```

[VERIFIED: `FlagsRoundTheWorld/lib/app.dart` and `FlagsRoundTheWorld/lib/core/ads/app_state_observer.dart` (direct read)]

### Pattern 3: App Open — 4-Hour Expiry Check

**What:** App Open ads expire after 4 hours. Store `DateTime` when ad loads; check `difference < Duration(hours: 4)` before showing.

```dart
// Source: FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart (direct read)
AppOpenAd? _appOpenAd;
DateTime? _appOpenLoadTime;
static const Duration _kAppOpenExpiry = Duration(hours: 4);

bool get _isAppOpenAdAvailable {
  if (_appOpenAd == null) return false;
  final loadTime = _appOpenLoadTime;
  if (loadTime == null) return false;
  return DateTime.now().difference(loadTime) < _kAppOpenExpiry;
}

// In AppOpenAdLoadCallback.onAdLoaded:
_appOpenAd = ad;
_appOpenLoadTime = DateTime.now();
```

[VERIFIED: `FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart` (direct read)]

### Pattern 4: Rewarded Ad — `onUserEarnedReward` via `Completer<bool>`

**What:** `RewardedAd.show()` takes a required `onUserEarnedReward` callback. The reward fires BEFORE `onAdDismissedFullScreenContent`. Use a `Completer<bool>` so `showRewardedAd()` can return `Future<bool>` — `true` only if reward earned.

**Why `onUserEarnedReward` and not `onAdDismissedFullScreenContent`:**
- `onUserEarnedReward` fires when the user has completed the rewarded content — the grant condition.
- `onAdDismissedFullScreenContent` fires when the ad closes — fires REGARDLESS of whether the user earned the reward (they may have skipped).
- HINT-05 explicitly requires the reward in `onUserEarnedReward` only.

```dart
// Source: FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart (direct read)
@override
Future<bool> showRewardedAd() async {
  final ad = _rewardedAd;
  if (ad == null) return false;
  final completer = Completer<bool>();
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _rewardedAd = null;
      _preloadRewarded();
      if (!completer.isCompleted) completer.complete(false);
    },
    onAdFailedToShowFullScreenContent: (ad, _) {
      ad.dispose();
      _rewardedAd = null;
      if (!completer.isCompleted) completer.complete(false);
    },
  );
  _rewardedAd = null; // prevent double-show
  await ad.show(
    onUserEarnedReward: (_, __) {
      if (!completer.isCompleted) completer.complete(true);
    },
  );
  return completer.future;
}
```

[VERIFIED: `FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart` (direct read); `google_mobile_ads-8.0.0/lib/src/ad_containers.dart` line 1317 confirms `show({required OnUserEarnedRewardCallback onUserEarnedReward})`]

### Pattern 5: Interstitial — Preload-on-Dismiss

**What:** After showing an interstitial, preload the next one inside `onAdDismissedFullScreenContent`. Set `_interstitialAd = null` BEFORE calling `show()` to prevent double-show if show() somehow calls back synchronously.

```dart
// Source: FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart (direct read)
@override
Future<void> showInterstitialAd() async {
  final ad = _interstitialAd;
  if (ad == null) return;
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _interstitialAd = null;
      _preloadInterstitial();  // ← preload next before dismiss completes
    },
    onAdFailedToShowFullScreenContent: (ad, _) {
      ad.dispose();
      _interstitialAd = null;
    },
  );
  _interstitialAd = null; // ← null BEFORE show to prevent double-show
  await ad.show();
}
```

[VERIFIED: `FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart` (direct read)]

### Pattern 6: Banner — `getLargeAnchoredAdaptiveBannerAdSize` (NOT deprecated variant)

**What:** `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize()` is `@Deprecated('Use getLargeAnchoredAdaptiveBannerAdSize instead')` in `google_mobile_ads` 8.x. Use `getLargeAnchoredAdaptiveBannerAdSize(screenWidthDp)` instead.

The banner must be loaded AFTER the widget has a valid screen width (call from `didChangeDependencies` or `initState` with `MediaQuery.of(context).size.width`). Wrap in `SizedBox` sized to `ad.size.width/height` to prevent layout jumping.

```dart
// Source: FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart (direct read)
Future<void> loadBannerForWidth(int screenWidthDp) async {
  if (_bannerState is AdLoaded) return;
  final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(screenWidthDp);
  if (adSize == null) return;
  BannerAd(
    adUnitId: kBannerAdUnitId,
    request: const AdRequest(),
    size: adSize,
    listener: BannerAdListener(
      onAdLoaded: (ad) { _bannerAd = ad as BannerAd; _bannerState = const AdLoaded(); },
      onAdFailedToLoad: (ad, error) { ad.dispose(); _bannerAd = null; _bannerState = const AdFailed(); },
    ),
  ).load();
}

@override
Widget getBannerWidget() {
  final ad = _bannerAd;
  if (ad == null) return const SizedBox.shrink();
  return SizedBox(
    width: ad.size.width.toDouble(),
    height: ad.size.height.toDouble(),
    child: AdWidget(ad: ad),
  );
}
```

[VERIFIED: `FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart` (direct read); deprecation confirmed in `google_mobile_ads-8.0.0/lib/src/ad_containers.dart` line 490]

### Pattern 7: `refillHints()` in `GameSessionNotifier`

**What:** New method alongside `useHint()` (lines 293–310). Resets `hintsRemaining` to exactly 2. Zero ad imports — walled-garden rule.

```dart
// Sibling to useHint() in game_session_notifier.dart
// WALLED-GARDEN RULE: Zero ad imports.
void refillHints() {
  final current = state.value;
  if (current == null || current.phase != GamePhase.playing) return;
  state = AsyncData(current.copyWith(hintsRemaining: 2));
  _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
}
```

The widget layer (MapScreen / StateTray) calls `refillHints()` then immediately calls `useHint()` — both calls in `onUserEarnedReward`. `refillHints()` must not apply a score penalty (that's `useHint()`'s responsibility).

[VERIFIED: `game_session_notifier.dart` lines 293-314 read directly; pattern derived from `useHint()`]

### Pattern 8: Rewarded Hint Dialog

**What:** Standard `showDialog` from `MapScreen._onHintPressed()` when `hintsRemaining == 0`. No custom widget needed.

```dart
// In MapScreen or StateTray's onHintPressed callback
if (session.hintsRemaining == 0) {
  final watch = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Watch an ad for 2 more hints?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Watch Ad')),
      ],
    ),
  );
  if (watch != true) return;
  final earned = await ref.read(adServiceProvider).showRewardedAd();
  if (!mounted) return;
  if (earned) {
    ref.read(gameSessionProvider.notifier).refillHints();
    ref.read(gameSessionProvider.notifier).useHint();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No ad available right now — try again later.')),
    );
  }
}
```

[ASSUMED — exact dialog call site (MapScreen vs StateTray) and mounted guards are implementation detail]

### Anti-Patterns to Avoid

- **Calling ad methods from `GameSessionNotifier`:** Violates the walled-garden rule. All ad calls originate from the widget layer.
- **Granting hint refill in `onAdDismissedFullScreenContent`:** Fires on skip/close, not on reward earned. HINT-05 is explicit.
- **Using `getCurrentOrientationAnchoredAdaptiveBannerAdSize`:** Deprecated in gma 8.x. Use `getLargeAnchoredAdaptiveBannerAdSize`.
- **Calling `AdWidget` before `BannerAd.load()` completes:** Throws `PlatformException`. Always gate behind `_bannerAd != null` check.
- **Double-dispose of ads:** Set `_interstitialAd = null` / `_appOpenAd = null` BEFORE calling `show()` and also in the dismiss callback — the Flags pattern nulls the field before show to prevent double-show, then nulls again in dismiss to allow GC.
- **Adding `gma_mediation_applovin` to pubspec:** D-03 explicitly prohibits this. `kAppLovinEnabled = false` remains as documentation of the activation path.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| App Open resume detection | Custom `WidgetsBindingObserver` | `AppStateEventNotifier` (GMA SDK) | GMA's notifier handles the foreground/background transition correctly for App Open timing |
| Banner sizing | Fixed pixel heights | `AdSize.getLargeAnchoredAdaptiveBannerAdSize()` | Device-appropriate height from Google's algorithm; hand-rolled heights risk policy violation |
| Ad expiry tracking | Complex TTL cache | `DateTime _appOpenLoadTime` + `Duration(hours: 4)` diff | Simple DateTime arithmetic; the 4-hour window is a GMA policy requirement |
| Rewarded completion detection | Polling / timer | `Completer<bool>` + `onUserEarnedReward` | SDK fires the callback synchronously before dismiss; Completer bridges async cleanly |

---

## Common Pitfalls

### Pitfall 1: InMobi Has No Dart-Side COPPA Method

**What goes wrong:** Developer calls a non-existent method on `GmaMediationInMobi` or attempts to set child-directed treatment via Dart.

**Why it happens:** The CONTEXT.md D-04 says "per-SDK COPPA flags for Unity, ironSource, and InMobi" — implying all three have Dart APIs. In fact InMobi's Flutter adapter is a pure stub.

**How to avoid:** Do NOT import `gma_mediation_inmobi` in `ads_initializer.dart`. No Dart call needed. The native Android adapter (`InMobiFlutterMediationExtras.kt` is empty; `GmaMediationInMobiPlugin.kt` only attaches) automatically forwards `tagForChildDirectedTreatment` from GMA's `RequestConfiguration`.

**Warning signs:** Compiler error "The method 'setChildDirectedTreatment' isn't defined for the class 'GmaMediationInMobi'".

[VERIFIED: `gma_mediation_inmobi-2.1.0/lib/gma_mediation_inmobi.dart` — `GmaMediationInMobi` is an empty class]

### Pitfall 2: `AD_ID` Erasure by Mediation AAR Manifests

**What goes wrong:** Unity or ironSource AARs declare `AD_ID` permission in their own `AndroidManifest.xml`; after manifest merge, the `tools:node="remove"` in the app manifest may be overridden.

**Why it happens:** `tools:node="remove"` operates at the manifest merger node level. If a library AAR declares the permission with a different node type, the removal may not propagate.

**How to avoid:**
1. Keep `tools:node="remove"` on all four permission entries (already done).
2. After `flutter build apk --release` with mediation AARs present, run: `C:\Users\omerb\AppData\Local\Android\Sdk\build-tools\37.0.0\aapt.exe dump badging app-release.apk | grep -i "AD_ID\|AdServices\|ADVERTISING"` — if nothing returns, the permissions are gone. This is the AD-06 verification step.
3. If AD_ID reappears, add an explicit `tools:merge` attribute or use the `<remove-node>` manifest merger tool.

**Warning signs:** `aapt dump badging` output contains `com.google.android.gms.permission.AD_ID`.

[VERIFIED: `AndroidManifest.xml` read directly; aapt at `C:\Users\omerb\AppData\Local\Android\Sdk\build-tools\37.0.0\aapt.exe` confirmed]

### Pitfall 3: App Open Fires During Gameplay

**What goes wrong:** Player is in the middle of placing a state and an App Open ad appears, interrupting the game.

**Why it happens:** `AppStateEventNotifier` fires on every foreground transition, including when the player returns from a momentary distraction.

**How to avoid:** In `_onAppResumed()`, read `gameSessionProvider` and return early if `GamePhase.playing` or `GamePhase.paused`. This is exactly the Flags pattern. The `RealAdService.showAppOpenAd()` also reads session state as a belt-and-suspenders check.

**Warning signs:** Players reporting ads appearing mid-drag.

[VERIFIED: `FlagsRoundTheWorld/lib/app.dart` (direct read)]

### Pitfall 4: Double-Loading the Banner

**What goes wrong:** `loadBannerForWidth()` called multiple times (e.g., on widget rebuild), causing multiple `BannerAd` instances and memory leaks.

**Why it happens:** `HomeScreen` rebuilds frequently (provider updates). If `loadBannerForWidth` is called in `build()`, it fires repeatedly.

**How to avoid:** Guard with `if (_bannerState is AdLoaded) return;` at the top of `loadBannerForWidth`. Call it only from `initState` or `didChangeDependencies` — never from `build()`.

**Warning signs:** Multiple banner ads stacking, `MobileAds` limit warnings in logcat.

[VERIFIED: `FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart` line 23 (direct read)]

### Pitfall 5: `adServiceProvider` Needs `Ref` for App Open Suppression Check

**What goes wrong:** `RealAdService` needs to read `gameSessionProvider` inside `showAppOpenAd()` — but the service is not a Riverpod provider itself.

**Why it happens:** Services don't naturally have access to `Ref`.

**How to avoid:** Inject `Ref` via constructor: `RealAdService(this._ref)`. The `adServiceProvider` becomes `Provider<AdService>((ref) => RealAdService(ref))`. This is the Flags pattern.

**Warning signs:** `showAppOpenAd()` cannot check game phase.

[VERIFIED: `FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart` line 11-14 (direct read)]

### Pitfall 6: `App` Must Become `ConsumerStatefulWidget`

**What goes wrong:** `app.dart` currently has `App extends StatelessWidget`. The App Open observer requires `initState`/`dispose` and `ref` access.

**Why it happens:** Phase 1 deliberately made `App` stateless.

**How to avoid:** Change `App` to `ConsumerStatefulWidget` with `_AppState extends ConsumerState<App>`. No other app.dart changes needed.

**Warning signs:** Compiler error "StatelessWidget has no method initState".

[VERIFIED: `lib/app.dart` read directly — currently `StatelessWidget`]

---

## Code Examples

### Complete RealAdService Skeleton

```dart
// lib/core/ads/real_ad_service.dart
// Source: direct port of FlagsRoundTheWorld/lib/core/ads/admob_ad_service.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:state_states/features/game/game_session_notifier.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'ad_service.dart';
import 'ad_load_state.dart';
import 'ad_constants.dart';

class RealAdService implements AdService {
  RealAdService(this._ref);
  final Ref _ref;

  // Banner
  BannerAd? _bannerAd;
  AdLoadState _bannerState = const AdFailed();

  Future<void> loadBannerForWidth(int screenWidthDp) async { ... }

  @override
  Widget getBannerWidget() { ... }

  // Interstitial
  InterstitialAd? _interstitialAd;
  void _preloadInterstitial() { ... }
  @override Future<void> showInterstitialAd() async { ... }

  // Rewarded
  RewardedAd? _rewardedAd;
  void _preloadRewarded() { ... }
  @override Future<bool> showRewardedAd() async { ... }

  // App Open
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadTime;
  static const Duration _kAppOpenExpiry = Duration(hours: 4);
  void _preloadAppOpen() { ... }
  bool get _isAppOpenAdAvailable { ... }
  @override Future<void> showAppOpenAd() async { ... }

  // Startup preload
  void preloadAll() {
    _preloadInterstitial();
    _preloadRewarded();
    _preloadAppOpen();
  }
}
```

### `adServiceProvider` Switch

```dart
// lib/core/ads/ad_service_provider.dart  — AFTER change
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_service.dart';
import 'real_ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) => RealAdService(ref));
```

### `HomeScreen` Banner Slot

```dart
// In _HomeScreenState — banner placed at bottom of Column, outside ListView
// loadBannerForWidth called once from initState/didChangeDependencies
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final widthDp = MediaQuery.of(context).size.width.toInt();
    (ref.read(adServiceProvider) as RealAdService).loadBannerForWidth(widthDp);
  });
}

// In _buildBody():
// After Expanded(ListView(...)) and before privacy footer:
ref.read(adServiceProvider).getBannerWidget(),
```

### `CompletionScreen` Interstitial Trigger

```dart
// In _CompletionScreenState.initState() — replace current NOTE comment
@override
void initState() {
  super.initState();
  // ... existing star/PB logic ...
  // AD-04: fire interstitial once, 1-second delay
  Future.delayed(const Duration(seconds: 1), () {
    if (mounted) ref.read(adServiceProvider).showInterstitialAd();
  });
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `getCurrentOrientationAnchoredAdaptiveBannerAdSize()` | `getLargeAnchoredAdaptiveBannerAdSize()` | gma 8.x | `@Deprecated` — use new name |
| `WidgetsBindingObserver` for App Open | `AppStateEventNotifier` (GMA SDK) | gma 5+ | GMA-idiomatic; both work |
| `AdSize.getAnchoredAdaptiveBannerAdSize` (old) | `getLargeAnchoredAdaptiveBannerAdSize` | gma 8.x | Same underlying platform call, new name |

**Deprecated/outdated:**
- `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize()`: deprecated in gma 8.x; use `getLargeAnchoredAdaptiveBannerAdSize()` instead.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Banner `loadBannerForWidth` should be called from `HomeScreen.initState` via `addPostFrameCallback` | Code Examples: HomeScreen Banner Slot | If called too early (before context has size), `MediaQuery` returns zero width — banner never loads |
| A2 | `CompletionScreen` can access `adServiceProvider` via `ref` after upgrade to `ConsumerStatefulWidget` (it already is `ConsumerStatefulWidget`) | CompletionScreen interstitial | Low risk — `CompletionScreen` is already `ConsumerStatefulWidget` confirmed in source |
| A3 | The dialog for rewarded hint originates from `MapScreen._onHintPressed()` rather than inside `StateTray` directly | Architecture diagram, Pattern 8 | `StateTray` has `onHintPressed: VoidCallback?` — dialog must be in the caller (MapScreen); minor implementation detail |

**If this table is empty:** Not applicable — three low-risk assumptions identified above.

---

## Open Questions

1. **Production AdMob IDs**
   - What we know: D-01 says production IDs will be hard-coded. The `ad_constants.dart` currently has empty strings.
   - What's unclear: The actual production unit IDs are not in any planning file — they must be provided by the developer before implementation.
   - Recommendation: Planner creates a task stub "insert production IDs" as Wave 0 (human provides values). All other tasks can proceed with test IDs during development; the final ID swap is the last task before release verification.

2. **`HomeScreen` access to `RealAdService` for `loadBannerForWidth`**
   - What we know: The `AdService` interface only exposes `getBannerWidget()`. `loadBannerForWidth(int)` is a `RealAdService`-specific method.
   - What's unclear: Whether to expose `loadBannerForWidth` on the interface, or cast in `HomeScreen`, or make `RealAdService` load automatically.
   - Recommendation: Keep the interface clean. In `HomeScreen`, either (a) access via `ref.read(adServiceProvider) as RealAdService` (works but casts), or (b) add `loadBannerForWidth` to the `AdService` interface with a no-op in `StubAdService`. The Flags project uses approach (a). Either is fine.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gma_mediation_unity` 1.8.0 | AD-02 | Already in pub cache | 1.8.0 | — |
| `gma_mediation_ironsource` 2.4.1 | AD-02 | Already in pub cache | 2.4.1 | — |
| `gma_mediation_inmobi` 2.1.0 | AD-02 | Already in pub cache | 2.1.0 | — |
| `google_mobile_ads` 8.0.0 | All ad types | Already in pubspec | 8.0.0 | — |
| `aapt.exe` (Android build-tools) | AD-06 verification | Available | 37.0.0 | aapt2 (same dir) |
| Real AdMob production unit IDs | D-01, D-02 | Not in codebase — must be provided | N/A | Test IDs during dev |

`aapt.exe` path: `C:\Users\omerb\AppData\Local\Android\Sdk\build-tools\37.0.0\aapt.exe`

Verification command:
```
C:\Users\omerb\AppData\Local\Android\Sdk\build-tools\37.0.0\aapt.exe dump badging build\app\outputs\flutter-apk\app-release.apk | findstr /i "AD_ID AdServices ADVERTISING"
```
Expected: no output (AD_ID absent). Any match = COPPA violation, fix manifest.

**Missing dependencies with no fallback:**
- Production AdMob App ID and unit IDs (four) — planner must create a human-checkpoint task for the developer to supply these.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none (Flutter default) |
| Quick run command | `flutter test test/core/ads/ -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AD-01 | RequestConfiguration child-directed flags | unit | `flutter test test/core/ads/ads_initializer_test.dart` | Wave 0 |
| AD-02 | Per-SDK COPPA flags called before initialize() | unit (mock) | `flutter test test/core/ads/ads_initializer_test.dart` | Wave 0 |
| AD-03 | Banner `getBannerWidget()` returns SizedBox.shrink when no ad loaded | unit | `flutter test test/core/ads/real_ad_service_test.dart` | Wave 0 |
| AD-04 | Interstitial: `showInterstitialAd()` no-ops when `_interstitialAd == null` | unit | `flutter test test/core/ads/real_ad_service_test.dart` | Wave 0 |
| AD-05 | App Open: suppressed when `GamePhase.playing` | unit | `flutter test test/core/ads/real_ad_service_test.dart` | Wave 0 |
| AD-06 | AD_ID absent after build | manual/build | `aapt.exe dump badging ...` | Manual |
| HINT-03 | Dialog shown when hintsRemaining == 0 | widget | `flutter test test/features/map/map_screen_test.dart` | Exists (extend) |
| HINT-04 | `refillHints()` sets hintsRemaining to 2 | unit | `flutter test test/features/game/game_session_notifier_test.dart` | Exists (extend) |
| HINT-05 | `showRewardedAd()` returns false on dismiss-without-reward | unit | `flutter test test/core/ads/real_ad_service_test.dart` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/core/ads/ test/features/game/game_session_notifier_test.dart -x`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/core/ads/ads_initializer_test.dart` — covers AD-01, AD-02 (mock `MobileAds`, `GmaMediationIronsource`, `GmaMediationUnity`)
- [ ] `test/core/ads/real_ad_service_test.dart` — covers AD-03 through AD-05, HINT-05 (mock SDK, `StubAdService` as reference)

*(Existing tests `game_session_notifier_test.dart`, `map_screen_test.dart`, `completion_screen_test.dart` are extended in-place — no new files needed for HINT-03, HINT-04)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Hint dialog input is user intent (yes/no), not a data field — no injection risk |
| V6 Cryptography | no | — |
| COPPA / Privacy | yes | `tagForChildDirectedTreatment=yes`; `AD_ID` blocked; no persistent identifiers |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| AD_ID permission resurfaces after AAR merge | Information Disclosure | `tools:node="remove"` + post-build `aapt dump badging` verification |
| App Open fires during active gameplay | Denial of Experience | `gameSessionProvider` phase check before `showAppOpenAd()` |
| Rewarded hint granted on ad skip/dismiss | Tampering (HINT-05) | Grant only in `onUserEarnedReward`; `Completer<bool>` completes `false` on dismiss |
| `gma_mediation_applovin` accidentally added | Supply Chain | D-03 locked; `kAppLovinEnabled = false`; AppLovin SDK 13.0+ self-disables in child-directed apps but gating at pubspec level is preferred |

---

## Sources

### Primary (HIGH confidence)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\admob_ad_service.dart` — complete RealAdService implementation; direct read; authoritative baseline
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ads_initializer.dart` — confirmed mediation COPPA init order with exact method signatures; direct read
- `C:\code\Claude\FlagsRoundTheWorld\lib\app.dart` — App Open AppStateEventNotifier pattern; direct read
- `C:\Users\omerb\AppData\Local\Pub\Cache\hosted\pub.dev\gma_mediation_unity-1.8.0\lib\gma_mediation_unity.dart` — exact Dart API: `setGDPRConsent(bool)`, `setCCPAConsent(bool)` on `GmaMediationUnity`; direct read
- `C:\Users\omerb\AppData\Local\Pub\Cache\hosted\pub.dev\gma_mediation_ironsource-2.4.1\lib\gma_mediation_ironsource.dart` — exact Dart API: `setConsent(bool)`, `setDoNotSell(bool)` on `GmaMediationIronsource`; direct read
- `C:\Users\omerb\AppData\Local\Pub\Cache\hosted\pub.dev\gma_mediation_inmobi-2.1.0\lib\gma_mediation_inmobi.dart` — **`GmaMediationInMobi` is an empty class — no Dart COPPA API**; direct read
- `C:\Users\omerb\AppData\Local\Pub\Cache\hosted\pub.dev\gma_mediation_inmobi-2.1.0\android\src\main\kotlin\...GmaMediationInMobiPlugin.kt` — Android stub (empty attach/detach); direct read
- `C:\Users\omerb\AppData\Local\Pub\Cache\hosted\pub.dev\google_mobile_ads-8.0.0\lib\src\ad_containers.dart` — `AppOpenAd.load()`, `RewardedAd.show({required onUserEarnedReward})`, `InterstitialAd.load()`, `BannerAd`, `AdWidget`, `getLargeAnchoredAdaptiveBannerAdSize` (current), deprecation of `getCurrentOrientationAnchoredAdaptiveBannerAdSize`; direct read
- `C:\Users\omerb\AppData\Local\Pub\Cache\hosted\pub.dev\google_mobile_ads-8.0.0\lib\src\ad_listeners.dart` — `OnUserEarnedRewardCallback`, `FullScreenContentCallback`, load callback types; direct read
- `C:\code\Claude\StateTheStates\lib\core\ads\*.dart` — existing ad infrastructure (interface, stub, initializer, constants, provider, load state); direct read
- `C:\code\Claude\StateTheStates\lib\features\game\game_session_notifier.dart` — `useHint()` pattern for `refillHints()` sibling; direct read
- `C:\code\Claude\StateTheStates\android\app\src\main\AndroidManifest.xml` — existing `tools:node="remove"` on AD_ID + AdServices permissions; direct read

### Secondary (MEDIUM confidence)
- [pub.dev/packages/gma_mediation_inmobi](https://pub.dev/packages/gma_mediation_inmobi) — CHANGELOG confirms 2.1.0 supports gma 8.0.0; web search corroborates auto-forwarding of tagForChildDirectedTreatment

### Tertiary (LOW confidence)
- [InMobi COPPA support center](https://support.inmobi.com/monetize/privacy/coppa) — general COPPA guidance; not specific to Flutter adapter behavior

---

## Metadata

**Confidence breakdown:**
- COPPA mediation flag method signatures: HIGH — read directly from installed package source
- RealAdService implementation patterns: HIGH — direct port from Flags authoritative baseline
- App Open expiry (4 hours): HIGH — documented in Flags source + `Duration(hours: 4)` constant
- AD_ID manifest tool: HIGH — `aapt.exe` verified at `build-tools/37.0.0/`
- Rewarded/Interstitial callback logic: HIGH — verified in gma 8.x SDK source

**Research date:** 2026-06-03
**Valid until:** 2026-09-03 (90 days — gma 8.x is stable; mediation adapters are google.dev published and change slowly)
