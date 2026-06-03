---
phase: 08-full-admob-layer
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - android/app/src/main/AndroidManifest.xml
  - lib/app.dart
  - lib/core/ads/ad_constants.dart
  - lib/core/ads/ad_service_provider.dart
  - lib/core/ads/ads_initializer.dart
  - lib/core/ads/app_state_observer.dart
  - lib/core/ads/real_ad_service.dart
  - lib/features/game/game_session_notifier.dart
  - lib/features/game/state_tray.dart
  - lib/features/home/home_screen.dart
  - lib/features/map/completion_screen.dart
  - lib/features/map/map_screen.dart
  - test/core/ads/real_ad_service_test.dart
  - test/features/map/completion_screen_test.dart
  - test/features/map/state_tray_test.dart
findings:
  critical: 4
  warning: 5
  info: 2
  total: 11
status: issues_found
---

# Phase 08: Code Review Report

**Reviewed:** 2026-06-03
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

Phase 8 introduces the full AdMob layer: `RealAdService` (banner, interstitial,
rewarded, App Open), `ads_initializer.dart` (COPPA-safe init sequence), and
wiring in `HomeScreen`, `CompletionScreen`, `MapScreen`, and `app.dart`. The
COPPA/Families compliance setup in `ads_initializer.dart` and the `AndroidManifest`
AD_ID stripping are structurally correct.

Four blockers are present: the banner ad will never be displayed because
`adServiceProvider` is a plain `Provider` that never emits change notifications;
a hard downcast in `HomeScreen` will crash at runtime under any test or future
override that uses a non-`RealAdService`; the session-restore `FutureBuilder`
recreates its future on every rebuild causing flickering; and `submitTyping`
in the typing mode is case-sensitive in the wrong direction — only ALL-CAPS input
is accepted.

Five warnings cover: the rewarded-hint flow not triggering the visual zoom
animation, incorrect postal passed to `recordDrop` on wrong drops, synchronous
file deletion on the UI thread during sharing, duplicated star-count logic that
will diverge, and a misleading code comment about `ref.watch` triggering banner
reloads.

---

## Critical Issues

### CR-01: Banner ad never displays — `adServiceProvider` emits no change notifications

**File:** `lib/features/home/home_screen.dart:179` and `lib/core/ads/ad_service_provider.dart:10`

**Issue:** `adServiceProvider` is declared as `Provider<AdService>`. A plain
`Provider` returns the same value for the lifetime of the `ProviderScope` and
never notifies listeners. The comment on line 178 of `home_screen.dart` says
"ref.watch rebuilds this widget when the banner loads" — this is incorrect.
`_bannerAd` is set inside `RealAdService.loadBannerForWidth` as a side-effect
after an async callback, but no Riverpod state invalidation is triggered. The
`ref.watch(adServiceProvider).getBannerWidget()` call will therefore always
return `SizedBox.shrink()` unless an unrelated rebuild happens to occur after
the ad loads. In practice the banner slot is always blank.

**Fix:** Either convert `adServiceProvider` to a `StateProvider` or
`NotifierProvider` and emit a state change when `_bannerAd` is set, or expose
a `ValueNotifier<Widget>` from `RealAdService` and use `ValueListenableBuilder`
in `HomeScreen`. The simplest surgical fix is to add a `StateProvider<int>` as
a banner-ready signal:

```dart
// In RealAdService, inject a Ref and invalidate a generation counter.
onAdLoaded: (ad) {
  _bannerAd = ad as BannerAd;
  _bannerState = const AdLoaded();
  _ref.invalidate(bannerReadyProvider); // triggers HomeScreen rebuild
},

// Provider:
final bannerReadyProvider = StateProvider<int>((_) => 0);
```

Then in `HomeScreen.build`:
```dart
ref.watch(bannerReadyProvider); // subscribe to banner-ready signal
ref.read(adServiceProvider).getBannerWidget(), // safe to call now
```

---

### CR-02: Hard downcast `as RealAdService` crashes under test overrides

**File:** `lib/features/home/home_screen.dart:32`

**Issue:**
```dart
(ref.read(adServiceProvider) as RealAdService).loadBannerForWidth(widthDp);
```
`adServiceProvider` is typed `Provider<AdService>`. In tests (including
`completion_screen_test.dart`) `adServiceProvider` is overridden with
`StubAdService`. Any test that navigates to `HomeScreen` or any future code
that overrides the provider will throw `_CastError: type 'StubAdService'
is not a subtype of 'RealAdService'` at runtime.

`loadBannerForWidth` is not on the `AdService` interface, so the cast is
forced by design — but this breaks interface segregation and the
test/production substitution contract.

**Fix:** Add `loadBannerForWidth` to the `AdService` interface with a no-op
default in `StubAdService`, then remove the cast:

```dart
// In AdService interface:
Future<void> loadBannerForWidth(int screenWidthDp);

// In StubAdService:
@override
Future<void> loadBannerForWidth(int screenWidthDp) async {} // no-op

// In HomeScreen:
ref.read(adServiceProvider).loadBannerForWidth(widthDp); // no cast
```

---

### CR-03: `submitTyping` case-sensitivity — only ALL-CAPS input accepted

**File:** `lib/features/game/game_session_notifier.dart:214`

**Issue:**
```dart
if (s.name.toUpperCase() == normalized || s.postal == normalized) {
```
`normalized` is `input.trim()` — it is NOT uppercased. The comparison
`s.name.toUpperCase() == normalized` will only match if the player types the
state name in ALL CAPITALS (e.g., "CALIFORNIA"). Typing "California" or
"california" produces a miss and increments `errorCount`. Similarly,
`s.postal == normalized` requires uppercase postal code (e.g., "CA"), so
typing "ca" is a miss.

The docstring on line 188–189 says:
```
///  - Full name match: `s.name.toUpperCase() == normalized`
///  - Postal code match: `s.postal == normalized`
```
This documents the broken contract — both sides of the comparison should be
normalised to the same case.

**Fix:**
```dart
final normalized = input.trim().toUpperCase();
// s.name.toUpperCase() == normalized  ← both uppercase, always works
// s.postal == normalized              ← postal codes are already uppercase
```

---

### CR-04: `FutureBuilder` future recreated on every rebuild — session-restore card flickers

**File:** `lib/features/home/home_screen.dart:56–59`

**Issue:**
```dart
FutureBuilder<({GameSession session, int hintPenalty})?>(
  future: ref
      .read(gameStateRepositoryProvider.future)
      .then((r) => r.loadSession()),
  ...
)
```
`_buildBody` is called from `build()` inside `repoAsync.when(data: ...)`. A new
`Future` object is created on every call to `_buildBody`. `FutureBuilder`
detects future changes by reference equality — a new `Future` object causes
`FutureBuilder` to reset to `ConnectionState.waiting`, returning
`SizedBox.shrink()` (empty). This means every rebuild (provider watch, scroll,
orientation change) briefly removes the session-restore card, causing a visible
flicker. If the rebuild happens between the user reading the card and tapping
"Continue", the card may also disappear before the tap registers.

**Fix:** Cache the future in a field initialised once in `initState`:

```dart
Future<({GameSession session, int hintPenalty})?>? _savedSessionFuture;

@override
void initState() {
  super.initState();
  // ...existing banner load...
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final repo = await ref.read(gameStateRepositoryProvider.future);
    if (mounted) {
      setState(() {
        _savedSessionFuture = repo.loadSession();
      });
    }
  });
}

// In build:
FutureBuilder(future: _savedSessionFuture, ...)
```

---

## Warnings

### WR-01: Rewarded-hint flow skips visual zoom animation

**File:** `lib/features/map/map_screen.dart:248–250`

**Issue:**
```dart
if (earned) {
  ref.read(gameSessionProvider.notifier).refillHints();
  ref.read(gameSessionProvider.notifier).useHint(); // decrements counter
}
```
When a user watches an ad and earns hints, `refillHints()` is called followed
by `useHint()`. This decrements `hintsRemaining` from 2 to 1, which is
correct. However, the visual hint behaviour — the zoom-to-state animation
(`_hintZoomController.forward()`), the 3-second glow (`_hintPostal`), and
the hint glow timer — is only triggered inside `_onHintPressed()`. The
rewarded-hint code path calls `useHint()` directly without any animation. The
player watches an ad, gets hints refilled, consumes one, but the map does not
zoom to the target state. This defeats the purpose of the hint.

**Fix:** Extract the animation logic from `_onHintPressed` into a shared
helper `_applyHintAnimation()` and call it from both paths:

```dart
void _applyHintAnimation() {
  final target = _stateIndex[_currentPostal];
  if (target == null) return;
  setState(() => _hintPostal = _currentPostal);
  final startMatrix = _controller.value.clone();
  final endMatrix = _computeHintMatrix(target.centroid, target);
  _hintZoomAnimation = Matrix4Tween(begin: startMatrix, end: endMatrix)
      .animate(CurvedAnimation(parent: _hintZoomController, curve: Curves.easeInOut));
  _hintZoomController..reset()..forward();
  _hintGlowTimer?.cancel();
  _hintGlowTimer = Timer(const Duration(seconds: 3), () {
    if (mounted) setState(() => _hintPostal = null);
  });
}

// In rewarded path after useHint() succeeds:
if (earned) {
  ref.read(gameSessionProvider.notifier).refillHints();
  final consumed = ref.read(gameSessionProvider.notifier).useHint();
  if (consumed) _applyHintAnimation();
}
```

---

### WR-02: Wrong postal passed to `recordDrop` on incorrect drop

**File:** `lib/features/map/map_screen.dart:454–455`

**Issue:**
```dart
ref.read(gameSessionProvider.notifier).recordDrop(
    hitPostal ?? _currentPostal, isCorrect: false);
```
When the player drops on the wrong state, `hitPostal` is the postal code of
the state the player actually dropped on (not the target). Passing `hitPostal`
to `recordDrop` with `isCorrect: false` records the error against the wrong
state. This matters if `recordDrop` ever uses the postal argument for incorrect
drops (e.g., logging, analytics, or future per-state error counts). The target
being placed is `_currentPostal`; the error should be attributed there.

**Fix:**
```dart
ref.read(gameSessionProvider.notifier).recordDrop(
    _currentPostal, isCorrect: false);
```

---

### WR-03: Synchronous file deletion on UI thread in `_captureAndShare`

**File:** `lib/features/map/completion_screen.dart:139`

**Issue:**
```dart
} finally {
  file?.deleteSync();  // ← synchronous I/O on UI thread
  if (mounted) setState(() => _isSharing = false);
}
```
`deleteSync()` blocks the UI thread. On a slow device or when the temp
directory is on an encrypted partition under load, this can cause a visible
jank or ANR. All file I/O should be async.

**Fix:**
```dart
} finally {
  await file?.delete(); // async — does not block UI thread
  if (mounted) setState(() => _isSharing = false);
}
```
Note: because this is in a `finally` block inside `_captureAndShare` (an
`async` method), `await file?.delete()` is safe to use here.

---

### WR-04: Star-count logic duplicated between `initState` and `computeStarCount`

**File:** `lib/features/map/completion_screen.dart:62–74`

**Issue:** The `_CompletionScreenState.initState` block manually replicates the
`computeStarCount` + PB logic instead of calling `computeStarCount`. If the
formula changes in one place it will silently diverge from the other:

```dart
// initState computes _starCount manually:
if (prev == null) { _isNewPb = false; _starCount = 3; }
else if (score < prev) { _isNewPb = true; _starCount = 3; }
...

// computeStarCount is a free function that does the same thing:
int computeStarCount(int score, int? previousBest) { ... }
```

**Fix:** Use `computeStarCount` in `initState`:

```dart
_starCount = computeStarCount(score, prev);
_isNewPb = (prev != null && score < prev);
```

---

### WR-05: Misleading comment claims `ref.watch` triggers banner rebuild

**File:** `lib/features/home/home_screen.dart:177–179`

**Issue:**
```dart
// AD-03: Banner ad slot — below mode cards, above privacy footer.
// ref.watch rebuilds this widget when the banner loads.
ref.watch(adServiceProvider).getBannerWidget(),
```
This comment is factually wrong. `adServiceProvider` is a `Provider<AdService>`
— it holds a static value and never emits change notifications. The banner
state is mutated inside `RealAdService` via an async callback without
invalidating any provider, so `ref.watch` will not rebuild `HomeScreen` when
the banner loads. This comment will mislead future maintainers into thinking
the banner display mechanism is working when it is not (see CR-01).

**Fix:** Correct the comment after implementing CR-01's fix, then update the
comment to accurately describe the mechanism used.

---

## Info

### IN-01: Dead code in `ads_initializer.dart` — `kAppLovinEnabled` block

**File:** `lib/core/ads/ads_initializer.dart:45–47`

**Issue:**
```dart
if (kAppLovinEnabled) {
  // No-op: AppLovin SDK 13.0+ refuses child-directed init.
}
```
`kAppLovinEnabled` is a compile-time constant `false` in `ad_constants.dart`.
The `if` block is dead code — the body is a comment with no statements. The
block contributes no value and will not be reached even if a future developer
sets `kAppLovinEnabled = true` (since the body is empty). The intent (blocking
AppLovin until preconditions are met) would be better served by either a
`throw` inside the block or removing the block entirely with a clear comment
explaining the v2 work item.

**Fix:** Remove the block or replace it with an assertion:
```dart
assert(!kAppLovinEnabled,
    'AppLovin activation requires: (1) account approval, '
    '(2) re-listing on Google Play Families Self-Certified Ads SDK list.');
```

---

### IN-02: `state_tray_test.dart` tests assert on SVG placeholder text, not actual card face

**File:** `test/features/map/state_tray_test.dart:26–29`

**Issue:**
```dart
testWidgets('Learn mode shows abbreviation on face and state name below', ...
  expect(find.text('CA'), findsAtLeastNWidgets(1));
```
`_buildFlagCard()` renders `SvgPicture.asset('assets/flags/ca.svg', ...)` as
the card face, with the postal abbreviation only shown as a `placeholderBuilder`
fallback when `stateData == null`. In the test, `stateData` is not passed
(defaults to `null`), so the test finds "CA" in the fallback `Text` widget, not
the production flag SVG. The test passes for the wrong reason — it does not
exercise the real card face, and would continue passing even if the SVG path
were broken or the mode-driven logic were completely removed.

This does not block shipping but creates false confidence in the Learn mode card
face rendering path.

**Fix:** Either inject a real `StateData` instance in the test (so the SVG
codepath is exercised) and assert on the SVG asset being present, or add a
comment acknowledging this limitation explicitly.

---

_Reviewed: 2026-06-03_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
