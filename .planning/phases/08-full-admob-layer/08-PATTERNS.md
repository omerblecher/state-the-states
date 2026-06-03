# Phase 8: Full AdMob Layer - Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 13 new/modified files
**Analogs found:** 13 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/core/ads/real_ad_service.dart` | service | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\admob_ad_service.dart` | exact |
| `lib/core/ads/ads_initializer.dart` | utility | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ads_initializer.dart` | exact |
| `lib/core/ads/ad_constants.dart` | config | — | `lib/core/ads/ad_constants.dart` (self — modify) | exact |
| `lib/core/ads/ad_service_provider.dart` | provider | — | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service_provider.dart` | exact |
| `lib/core/ads/app_state_observer.dart` | utility | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\app_state_observer.dart` | exact |
| `lib/app.dart` | component | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\app.dart` | exact |
| `lib/features/home/home_screen.dart` | component | request-response | `lib/features/home/home_screen.dart` (self — modify) | exact |
| `lib/features/map/completion_screen.dart` | component | request-response | `lib/features/map/completion_screen.dart` (self — modify) | exact |
| `lib/features/game/game_session_notifier.dart` | service | CRUD | `lib/features/game/game_session_notifier.dart` `useHint()` (self — modify) | exact |
| `lib/features/game/state_tray.dart` | component | request-response | `lib/features/game/state_tray.dart` `_buildHintButton` (self — modify) | exact |
| `pubspec.yaml` | config | — | `pubspec.yaml` (self — modify) | exact |
| `android/app/src/main/AndroidManifest.xml` | config | — | `AndroidManifest.xml` (self — modify) | exact |
| `test/core/ads/ads_initializer_test.dart` | test | — | `test/core/audio/audio_service_test.dart` | role-match |
| `test/core/ads/real_ad_service_test.dart` | test | — | `test/core/audio/audio_service_test.dart` + `test/features/game/game_session_notifier_test.dart` | role-match |

---

## Pattern Assignments

### `lib/core/ads/real_ad_service.dart` (service, event-driven) — NEW

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\admob_ad_service.dart` (direct port — rename class, change package prefix)

**Imports pattern** (lines 1–9):
```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flags_around_the_world/features/game/game_session_notifier.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'ad_service.dart';
import 'ad_load_state.dart';
import 'ad_constants.dart';
```
Replace `flags_around_the_world` with `state_states` and rename class `AdMobAdService` → `RealAdService`.

**Constructor + Ref injection** (lines 11–14):
```dart
class RealAdService implements AdService {
  RealAdService(this._ref);
  final Ref _ref;
```

**Banner section** (lines 17–55):
```dart
BannerAd? _bannerAd;
AdLoadState _bannerState = const AdFailed();

Future<void> loadBannerForWidth(int screenWidthDp) async {
  if (_bannerState is AdLoaded) return;                    // ← guard against double-load
  final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(screenWidthDp);
  if (adSize == null) return;
  BannerAd(
    adUnitId: kBannerAdUnitId,
    request: const AdRequest(),
    size: adSize,
    listener: BannerAdListener(
      onAdLoaded: (ad) {
        _bannerAd = ad as BannerAd;
        _bannerState = const AdLoaded();
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        _bannerAd = null;
        _bannerState = const AdFailed();
      },
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

**Interstitial section — preload-on-dismiss pattern** (lines 58–88):
```dart
InterstitialAd? _interstitialAd;

void _preloadInterstitial() {
  InterstitialAd.load(
    adUnitId: kInterstitialAdUnitId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) => _interstitialAd = ad,
      onAdFailedToLoad: (_) => _interstitialAd = null,
    ),
  );
}

@override
Future<void> showInterstitialAd() async {
  final ad = _interstitialAd;
  if (ad == null) return;
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _interstitialAd = null;
      _preloadInterstitial();           // ← preload next immediately on dismiss
    },
    onAdFailedToShowFullScreenContent: (ad, _) {
      ad.dispose();
      _interstitialAd = null;
    },
  );
  _interstitialAd = null;               // ← null BEFORE show to prevent double-show
  await ad.show();
}
```

**Rewarded section — Completer<bool> pattern** (lines 91–129):
```dart
RewardedAd? _rewardedAd;

void _preloadRewarded() {
  RewardedAd.load(
    adUnitId: kRewardedAdUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) => _rewardedAd = ad,
      onAdFailedToLoad: (_) => _rewardedAd = null,
    ),
  );
}

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
      if (!completer.isCompleted) completer.complete(false);  // ← false on dismiss/skip
    },
    onAdFailedToShowFullScreenContent: (ad, _) {
      ad.dispose();
      _rewardedAd = null;
      if (!completer.isCompleted) completer.complete(false);
    },
  );
  _rewardedAd = null;
  await ad.show(
    onUserEarnedReward: (_, __) {
      if (!completer.isCompleted) completer.complete(true);   // ← true ONLY here
    },
  );
  return completer.future;
}
```

**App Open section — 4-hour expiry + game-phase suppression** (lines 131–185):
```dart
AppOpenAd? _appOpenAd;
DateTime? _appOpenLoadTime;
static const Duration _kAppOpenExpiry = Duration(hours: 4);

void _preloadAppOpen() {
  AppOpenAd.load(
    adUnitId: kAppOpenAdUnitId,
    request: const AdRequest(),
    adLoadCallback: AppOpenAdLoadCallback(
      onAdLoaded: (ad) {
        _appOpenAd = ad;
        _appOpenLoadTime = DateTime.now();
      },
      onAdFailedToLoad: (_) => _appOpenAd = null,
    ),
  );
}

bool get _isAppOpenAdAvailable {
  if (_appOpenAd == null) return false;
  final loadTime = _appOpenLoadTime;
  if (loadTime == null) return false;
  return DateTime.now().difference(loadTime) < _kAppOpenExpiry;
}

@override
Future<void> showAppOpenAd() async {
  // Suppress during active gameplay or pause (D-O02 / AD-05)
  final session = _ref.read(gameSessionProvider).value;
  if (session != null &&
      (session.phase == GamePhase.playing ||
          session.phase == GamePhase.paused)) {
    return;
  }

  if (!_isAppOpenAdAvailable) {
    _preloadAppOpen();
    return;
  }
  final ad = _appOpenAd!;
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _appOpenAd = null;
      _preloadAppOpen();
    },
    onAdFailedToShowFullScreenContent: (ad, _) {
      ad.dispose();
      _appOpenAd = null;
    },
  );
  _appOpenAd = null;
  await ad.show();
}
```

**Startup preload** (lines 188–195):
```dart
void preloadAll() {
  _preloadInterstitial();
  _preloadRewarded();
  _preloadAppOpen();
}
```

---

### `lib/core/ads/ads_initializer.dart` (utility, request-response) — MODIFY

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ads_initializer.dart` (direct port of mediation section)

**Current file** (`lib/core/ads/ads_initializer.dart` lines 1–28): already has Step 1 (RequestConfiguration) and Step 5 (initialize). Add Steps 2–3 from Flags analog between them.

**Imports to add** (after `google_mobile_ads`):
```dart
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';
// NOTE: NO import for gma_mediation_inmobi — GmaMediationInMobi is an empty stub.
// InMobi forwards tagForChildDirectedTreatment automatically from RequestConfiguration.
import 'ad_constants.dart';
```

**Mediation COPPA calls to insert** (from Flags analog lines 29–43, between existing Step 1 and existing `MobileAds.instance.initialize()`):
```dart
// Step 2: ironSource — GDPR no-consent + CCPA do-not-sell for children.
// Flags analog: FlagsRoundTheWorld/lib/core/ads/ads_initializer.dart lines 29-30
GmaMediationIronsource().setConsent(false);
GmaMediationIronsource().setDoNotSell(true);

// Step 3: Unity — no GDPR consent + no CCPA consent (child-directed).
// Flags analog: FlagsRoundTheWorld/lib/core/ads/ads_initializer.dart lines 33-34
await GmaMediationUnity().setGDPRConsent(false);
await GmaMediationUnity().setCCPAConsent(false);

// Step 4: AppLovin — permanently disabled.
if (kAppLovinEnabled) {
  // Activate only when: (1) AppLovin account approved,
  // (2) AppLovin back on Google Play Families Self-Certified Ads SDK list.
}
```
Remove the v1 comment "Mediation SDK COPPA flag calls are omitted in v1" from line 11 of existing file.

---

### `lib/core/ads/ad_constants.dart` (config) — MODIFY

**Current file** (`lib/core/ads/ad_constants.dart` lines 1–17): replace empty strings and test App ID.

**Target state** (developer supplies actual production IDs — see Open Questions in RESEARCH.md):
```dart
// AdMob production App ID (matches AndroidManifest meta-data).
const String kAdMobAppId = '<PRODUCTION_APP_ID>';

// Production ad unit IDs — populated for Phase 8 real ad activation.
const String kBannerAdUnitId       = '<PRODUCTION_BANNER_ID>';
const String kInterstitialAdUnitId = '<PRODUCTION_INTERSTITIAL_ID>';
const String kRewardedAdUnitId     = '<PRODUCTION_REWARDED_ID>';
const String kAppOpenAdUnitId      = '<PRODUCTION_APP_OPEN_ID>';

// AppLovin remains permanently disabled.
const bool   kAppLovinEnabled = false;
const String kAppLovinSdkKey  = '';
```

---

### `lib/core/ads/ad_service_provider.dart` (provider) — MODIFY

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service_provider.dart` (lines 1–9 — exact pattern)

**Current:** returns `const StubAdService()` (no preload, no Ref).
**Target** (copy directly from Flags analog with class rename):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_service.dart';
import 'real_ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  final service = RealAdService(ref);
  service.preloadAll();
  return service;
});
```
Remove the `stub_ad_service.dart` import. Keep `StubAdService` available for tests (do not delete `stub_ad_service.dart`).

---

### `lib/core/ads/app_state_observer.dart` (utility, event-driven) — NEW

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\app_state_observer.dart` (exact copy — 5 lines)

**Full file content** (copy verbatim from Flags):
```dart
// Thin re-export so app.dart can subscribe to AppStateEventNotifier
// without importing google_mobile_ads directly.
// The google_mobile_ads import stays inside the lib/core/ads/ walled garden.
export 'package:google_mobile_ads/google_mobile_ads.dart'
    show AppStateEventNotifier, AppState;
```

---

### `lib/app.dart` (component, event-driven) — MODIFY

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\app.dart` (lines 63–107)

**Current:** `App extends StatelessWidget` (lines 62–73 in `lib/app.dart`).
**Target:** Replace `App` class and add `_AppState`. Keep the `_router` definition and all imports unchanged; add new imports:

**New imports to add** (from Flags analog lines 15–18):
```dart
import 'dart:async';
import 'features/game/game_phase.dart';
import 'features/game/game_session_notifier.dart';
import 'core/ads/ad_service_provider.dart';
import 'core/ads/app_state_observer.dart';
```

**Replace `App` class** (from Flags analog lines 63–107 — rename title only):
```dart
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

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
    // AD-05: suppress App Open during active gameplay or pause.
    final phase = ref.read(gameSessionProvider).value?.phase;
    if (phase == GamePhase.playing || phase == GamePhase.paused) return;
    ref.read(adServiceProvider).showAppOpenAd();
  }

  @override
  void dispose() {
    _appStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'State the States',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
```

---

### `lib/features/home/home_screen.dart` (component, request-response) — MODIFY

**Analog:** `lib/features/home/home_screen.dart` (self — add banner slot at bottom of `_buildBody`)

**New import to add**:
```dart
import 'package:state_states/core/ads/ad_service_provider.dart';
import 'package:state_states/core/ads/real_ad_service.dart';
```

**Banner load in `_HomeScreenState`** (from RESEARCH.md Pattern 6 + Pitfall 4 — never call from `build()`):
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final widthDp = MediaQuery.of(context).size.width.toInt();
    (ref.read(adServiceProvider) as RealAdService).loadBannerForWidth(widthDp);
  });
}
```

**Banner slot in `_buildBody`** — insert between the `Expanded(ListView(...))` (line 99) and the `// Privacy footer` block (line 163). Pattern: place `getBannerWidget()` call outside the ListView, directly in the Column:
```dart
// AD-03: Banner ad slot — below mode cards, above privacy footer.
ref.watch(adServiceProvider).getBannerWidget(),
```
Use `ref.watch` (not `ref.read`) so the widget rebuilds when the banner loads.

---

### `lib/features/map/completion_screen.dart` (component, request-response) — MODIFY

**Analog:** `lib/features/map/completion_screen.dart` `_CompletionScreenState.initState()` (lines 57–84)

**New import to add**:
```dart
import 'package:state_states/core/ads/ad_service_provider.dart';
```

**Interstitial trigger in `initState()`** — add after existing star/PB logic (after line 84, before closing brace):
```dart
// AD-04: Interstitial once per completion, 1-second delay (all modes).
Future.delayed(const Duration(seconds: 1), () {
  if (mounted) ref.read(adServiceProvider).showInterstitialAd();
});
```
`CompletionScreen` is already a `ConsumerStatefulWidget` (line 33) — `ref` is available directly.

---

### `lib/features/game/game_session_notifier.dart` (service, CRUD) — MODIFY

**Analog:** `lib/features/game/game_session_notifier.dart` `useHint()` method (lines 293–314)

**`refillHints()` method** — insert as sibling to `useHint()` (after line 314, before `completeGame()`):
```dart
/// Resets hintsRemaining to exactly 2 (not additive).
///
/// Called from the widget layer inside [onUserEarnedReward] only.
/// Zero ad imports — walled-garden rule (COMP-03) is inviolable.
void refillHints() {
  final current = state.value;
  if (current == null || current.phase != GamePhase.playing) return;
  state = AsyncData(current.copyWith(hintsRemaining: 2));
  _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
}
```
Pattern is a direct mirror of `useHint()` structure: guard on phase, `copyWith`, `saveSession`. No score/penalty recalculation — that is `useHint()`'s responsibility. No ad imports.

---

### `lib/features/game/state_tray.dart` (component, request-response) — MODIFY

**Current state:** `_buildHintButton` (line 135–151) disables button when `hintsRemaining <= 0` (`enabled` is false when `onHintPressed == null || hintsRemaining <= 0`).

**Required change (D-08):** When `hintsRemaining == 0` AND a callback is wired, the button should be enabled so the rewarded-ad prompt can trigger. The zero-hint path forks at the caller (`MapScreen._onHintPressed`), not here.

**Change to `_buildHintButton`** (line 136):
```dart
// Before:
final enabled = widget.onHintPressed != null && widget.hintsRemaining > 0;

// After (D-08: zero-hint path enables button for rewarded ad prompt):
final enabled = widget.onHintPressed != null;
```
The label text stays as `'Hint ×${widget.hintsRemaining}'` — shows `×0` when empty, which is the user-facing cue to watch an ad.

**`MapScreen._onHintPressed()` fork** (line 191 in `map_screen.dart`) — the rewarded hint dialog originates here, not in `StateTray`:
```dart
void _onHintPressed() {
  if (session?.hintsRemaining == 0) {
    _showRewardedHintDialog();    // ← new path for zero-hint case
    return;
  }
  final consumed = ref.read(gameSessionProvider.notifier).useHint();
  // ... existing hint glow logic unchanged ...
}

Future<void> _showRewardedHintDialog() async {
  final watch = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Watch an ad for 2 more hints?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Watch Ad'),
        ),
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
Snackbar pattern matches existing incorrect-drop Snackbar in `MapScreen` (same `ScaffoldMessenger.of(context).showSnackBar` form).

---

### `pubspec.yaml` (config) — MODIFY

**Current:** `google_mobile_ads: ^8.0.0` present; three mediation packages absent.

**Add to `dependencies` section** (after `google_mobile_ads: ^8.0.0`):
```yaml
  gma_mediation_unity: ^1.8.0
  gma_mediation_ironsource: ^2.4.1
  gma_mediation_inmobi: ^2.1.0
```
No other changes. `share_plus`, `url_launcher`, and all existing deps unchanged.

---

### `android/app/src/main/AndroidManifest.xml` (config) — MODIFY

**Current** (line 55–57): test App ID `ca-app-pub-3940256099942544~3347511713`.

**Change:** Replace `android:value` of `com.google.android.gms.ads.APPLICATION_ID` with the production App ID (developer-supplied). Pattern:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXX~XXXXXXXXXX"/>
```
All four `tools:node="remove"` blocks (lines 5–20) remain unchanged — they must survive the mediation AAR merge.

---

### `test/core/ads/ads_initializer_test.dart` (test) — NEW

**Analog:** `test/core/audio/audio_service_test.dart` (mock-channel pattern for platform SDKs) + `test/features/game/game_session_notifier_test.dart` (ProviderContainer + mock injection pattern)

**Imports pattern** (from `audio_service_test.dart` lines 1–6 + `game_session_notifier_test.dart` lines 1–14):
```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';
import 'package:state_states/core/ads/ads_initializer.dart';
```

**Mock class pattern** (from `game_session_notifier_test.dart` lines 15–16):
```dart
class MockMobileAds extends Mock implements MobileAds {}
class MockGmaMediationUnity extends Mock implements GmaMediationUnity {}
class MockGmaMediationIronsource extends Mock implements GmaMediationIronsource {}
```

**Test structure** — covers AD-01 and AD-02:
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initializeAds — COPPA init order (AD-01, AD-02)', () {
    test('AD-01: updateRequestConfiguration called with child-directed flags', ...);
    test('AD-02: ironSource and Unity COPPA flags called before initialize()', ...);
    test('AD-02: InMobi has no Dart call — no import of gma_mediation_inmobi', ...);
  });
}
```

---

### `test/core/ads/real_ad_service_test.dart` (test) — NEW

**Analog:** `test/core/audio/audio_service_test.dart` (mock-channel pattern + stub fallback for interface parity)

**Imports pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/ads/ad_service.dart';
import 'package:state_states/core/ads/stub_ad_service.dart';
import 'package:state_states/core/ads/real_ad_service.dart';
```

**Test structure** — covers AD-03 through AD-05 and HINT-05:
```dart
void main() {
  group('StubAdService — interface parity (reference)', () {
    test('getBannerWidget returns SizedBox.shrink', ...);
    test('showRewardedAd returns false', ...);
  });

  group('RealAdService unit tests', () {
    test('AD-03: getBannerWidget returns SizedBox.shrink when no ad loaded', ...);
    test('AD-04: showInterstitialAd no-ops when _interstitialAd is null', ...);
    test('AD-05: showAppOpenAd suppressed when GamePhase.playing', ...);
    test('HINT-05: showRewardedAd returns false when _rewardedAd is null', ...);
  });
}
```
Use `StubAdService` (already available, no SDK calls) as the reference for interface parity tests. For `RealAdService` tests, construct with a mock `Ref` that returns a mock `gameSessionProvider` value.

---

## Shared Patterns

### Provider switch (adServiceProvider)
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service_provider.dart` lines 1–9
**Apply to:** `lib/core/ads/ad_service_provider.dart`
```dart
final adServiceProvider = Provider<AdService>((ref) {
  final service = RealAdService(ref);
  service.preloadAll();
  return service;
});
```

### Snackbar user feedback
**Source:** `lib/features/map/map_screen.dart` (existing incorrect-drop Snackbar)
**Apply to:** `lib/features/map/map_screen.dart` rewarded-ad failure path (D-09)
```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('No ad available right now — try again later.')),
);
```

### ConsumerStatefulWidget + ref + initState pattern
**Source:** `lib/features/map/completion_screen.dart` lines 33–84 (already `ConsumerStatefulWidget`)
**Apply to:** `lib/app.dart` (convert from `StatelessWidget`)
Pattern: `ConsumerStatefulWidget` → `ConsumerState<T>` → `ref` available in all lifecycle methods.

### Mock class + ProviderContainer test pattern
**Source:** `test/features/game/game_session_notifier_test.dart` lines 15–16 + ProviderContainer usage
**Apply to:** `test/core/ads/ads_initializer_test.dart`, `test/core/ads/real_ad_service_test.dart`
```dart
class MockFoo extends Mock implements Foo {}
// In test:
final container = ProviderContainer(
  overrides: [someProvider.overrideWith((ref) => MockFoo())],
);
addTearDown(container.dispose);
```

### platform-channel mock (for SDK tests)
**Source:** `test/core/audio/audio_service_test.dart` lines 21–55
**Apply to:** `test/core/ads/ads_initializer_test.dart`, `test/core/ads/real_ad_service_test.dart`
Register mock `MethodChannel` handlers in `setUp`; clear in `tearDown`. The `google_mobile_ads` SDK uses method channels; mock them to avoid `MissingPluginException` in unit tests.

---

## No Analog Found

All 13 files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `C:\code\Claude\StateTheStates\lib\`, `C:\code\Claude\StateTheStates\test\`, `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\`, `C:\code\Claude\FlagsRoundTheWorld\lib\`
**Files scanned:** 16 source files read directly
**Pattern extraction date:** 2026-06-03

**Critical implementation notes for planner:**
1. `RealAdService` is a near-verbatim port of `AdMobAdService` — only the class name and package prefix change.
2. `app_state_observer.dart` is a 5-line re-export file — copy exactly.
3. Production AdMob IDs are the only human-provided values; planner must create a Wave 0 human-checkpoint task.
4. The `StateTray` `_buildHintButton` `enabled` condition changes (hintsRemaining > 0 → remove that guard); the zero-hint dialog lives in `MapScreen._onHintPressed`.
5. `gma_mediation_inmobi` requires NO Dart-side COPPA call — do not import in `ads_initializer.dart`.
6. `adServiceProvider` in Flags calls `service.preloadAll()` — State States must do the same (currently missing from the stub provider).
