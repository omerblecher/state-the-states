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
  critical: 5
  warning: 8
  info: 4
  total: 17
status: issues_found
---

# Phase 08: Code Review Report

**Reviewed:** 2026-06-03T00:00:00Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

This phase wires the full AdMob ad layer — banner, interstitial, rewarded, and App Open — into the
production app. COPPA compliance in the manifest is solid: AD_ID and AdServices permissions are
correctly stripped with `tools:node="remove"`, and `tagForChildDirectedTreatment(true)` is set
before `MobileAds.instance.initialize()`. The mediation SDK child-directed calls (IronSource,
Unity) are correctly ordered. `AndroidManifest.xml` is clean.

Five blockers are present. The banner ad will never render because `adServiceProvider` is a plain
`Provider` that emits no change notifications when the async load callback fires. A hard downcast
`as RealAdService` in `HomeScreen` will crash under any test override. The typing mode silently
rejects mixed-case input — only ALL-CAPS is accepted. The `FutureBuilder` for session restore
recreates its `Future` on every rebuild, causing flicker and a race against dismiss. And
`MathChallengeDialog` mutates `_a`/`_b` outside `setState`, violating Flutter state rules.

Eight warnings cover: the App Open suppression race, a missing hint animation in the rewarded
flow, the wrong postal passed on incorrect drops, synchronous file deletion on the UI thread,
duplicated star-count logic, a misleading comment, `ad.show()` exceptions leaving ad objects
leaked, and the `_buildMapStack` side-effect pattern inside `build()`. Four info items cover
code quality concerns.

---

## Critical Issues

### CR-01: Banner ad never displays — `adServiceProvider` emits no change notifications

**File:** `lib/features/home/home_screen.dart:179` and `lib/core/ads/ad_service_provider.dart:10`

**Issue:** `adServiceProvider` is declared as `Provider<AdService>`. A plain `Provider` returns
the same object instance for the lifetime of the `ProviderScope` and never notifies listeners.
The comment on line 178 of `home_screen.dart` states "ref.watch rebuilds this widget when the
banner loads" — this is factually incorrect. `_bannerAd` is populated inside `RealAdService`
asynchronously via `onAdLoaded`, but no Riverpod invalidation is triggered. The
`ref.watch(adServiceProvider).getBannerWidget()` call on line 179 will always return
`SizedBox.shrink()` unless an unrelated rebuild coincidentally fires after the ad loads.
On typical devices, the banner slot remains permanently blank.

**Fix:** `RealAdService` must extend `ChangeNotifier` and call `notifyListeners()` inside
`onAdLoaded`, and `adServiceProvider` must become a `ChangeNotifierProvider`. Or, at minimum,
add a separate `bannerReadyProvider` that `RealAdService` invalidates when the banner is ready:

```dart
// In RealAdService — inject Ref, call inside onAdLoaded:
_bannerAd = ad as BannerAd;
_bannerState = const AdLoaded();
_ref.invalidate(bannerReadyProvider); // triggers HomeScreen rebuild

// In home_screen.dart — subscribe:
ref.watch(bannerReadyProvider); // causes rebuild when banner loads
ref.read(adServiceProvider).getBannerWidget(),
```

---

### CR-02: Hard downcast `as RealAdService` crashes under any non-production ad service

**File:** `lib/features/home/home_screen.dart:32`

**Issue:**
```dart
(ref.read(adServiceProvider) as RealAdService).loadBannerForWidth(widthDp);
```
`adServiceProvider` is typed `Provider<AdService>`. Every test that overrides `adServiceProvider`
with `StubAdService` (or any other implementation) will trigger a `_CastError: type 'StubAdService'
is not a subtype of 'RealAdService'` at runtime — specifically in `initState` (via the
`addPostFrameCallback`). The `completion_screen_test.dart` already overrides `adServiceProvider`
with `StubAdService`. If any test pumps `HomeScreen`, it crashes.

This also breaks interface segregation: `loadBannerForWidth` is a `RealAdService`-specific
method absent from the `AdService` interface, forcing the hard cast.

**Fix:** Add `loadBannerForWidth` to the `AdService` interface with a no-op in `StubAdService`:

```dart
// AdService interface:
Future<void> loadBannerForWidth(int screenWidthDp);

// StubAdService:
@override
Future<void> loadBannerForWidth(int screenWidthDp) async {}

// HomeScreen — remove cast:
ref.read(adServiceProvider).loadBannerForWidth(widthDp);
```

---

### CR-03: `submitTyping` case-sensitivity — only ALL-CAPS input accepted

**File:** `lib/features/game/game_session_notifier.dart:207-214`

**Issue:**
```dart
final normalized = input.trim();
// ...
if (s.name.toUpperCase() == normalized || s.postal == normalized) {
```
`normalized` is `input.trim()` with no case normalization. The left side is uppercased
(`s.name.toUpperCase()`), but the right side is the raw input. A player typing "California"
will produce `normalized = "California"` compared against `"CALIFORNIA"` — no match, error
incremented. Only typing "CALIFORNIA" (all caps) succeeds. Similarly, `s.postal == normalized`
requires uppercase "CA"; typing "ca" is a miss. The docstring on lines 188-189 documents this
broken contract without flagging it as wrong.

**Fix:**
```dart
final normalized = input.trim().toUpperCase();
// s.name.toUpperCase() == normalized  (both uppercase — correct)
// s.postal == normalized              (postal codes are already uppercase — correct)
```

---

### CR-04: `FutureBuilder` future re-created on every rebuild — session-restore card flickers and races against dismiss

**File:** `lib/features/home/home_screen.dart:56-59`

**Issue:**
```dart
FutureBuilder<({GameSession session, int hintPenalty})?>(
  future: ref
      .read(gameStateRepositoryProvider.future)
      .then((r) => r.loadSession()),
```
`_buildBody` is called from `build()`. A new `Future` object is constructed inline on every
rebuild. `FutureBuilder` detects future changes by object identity — receiving a new `Future`
resets to `ConnectionState.waiting`, causing `SizedBox.shrink()` to be returned momentarily.
Every rebuild (high-score provider resolving, session state change, etc.) causes the restore
card to briefly vanish and reappear (flicker). More critically, when `onDismiss` calls
`setState(() {})` (line 79) to trigger a rebuild after `endGame()`, the new `Future` is
issued before `clearSession()` has flushed to disk, so `loadSession()` may return the
just-dismissed session again, re-showing the card.

**Fix:** Cache the future exactly once in `initState`:

```dart
Future<({GameSession session, int hintPenalty})?>? _savedSessionFuture;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final repo = await ref.read(gameStateRepositoryProvider.future);
    if (mounted) setState(() => _savedSessionFuture = repo.loadSession());
  });
  // ...existing banner load...
}
// In build: FutureBuilder(future: _savedSessionFuture, ...)
```

---

### CR-05: `MathChallengeDialog._onConfirm` mutates `_a`/`_b` outside `setState`

**File:** `lib/features/map/completion_screen.dart:417-426`

**Issue:**
```dart
void _onConfirm() {
  final entered = int.tryParse(_controller.text.trim());
  if (entered == _a * _b) {
    Navigator.of(context).pop(true);
  } else {
    _controller.clear();
    final rng = math.Random();
    _a = 10 + rng.nextInt(90);   // mutated OUTSIDE setState
    _b = 2 + rng.nextInt(8);     // mutated OUTSIDE setState
    setState(() => _error = 'Incorrect — try again');
  }
}
```
`_a` and `_b` are widget state fields displayed in `build()` via `'What is $_a × $_b?'`. They
are mutated synchronously before `setState`, which in practice works in Dart's single-threaded
model because `setState` follows immediately. However, this violates Flutter's rule that all
mutations to fields affecting `build()` must occur inside `setState()`. A future refactor that
moves any of these fields to a separate mechanism (e.g., making them late-init or nullable) will
introduce a subtle bug where the displayed question diverges from the stored operands.

**Fix:**
```dart
void _onConfirm() {
  final entered = int.tryParse(_controller.text.trim());
  if (entered == _a * _b) {
    Navigator.of(context).pop(true);
  } else {
    _controller.clear();
    setState(() {
      final rng = math.Random();
      _a = 10 + rng.nextInt(90);
      _b = 2 + rng.nextInt(8);
      _error = 'Incorrect — try again';
    });
  }
}
```

---

## Warnings

### WR-01: App Open suppression race — null session treated as "not playing" even during async load

**File:** `lib/app.dart:90-95` and `lib/core/ads/real_ad_service.dart:162-167`

**Issue:** Both `_onAppResumed()` in `app.dart` and `showAppOpenAd()` in `real_ad_service.dart`
suppress the App Open ad by reading `gameSessionProvider` and checking the phase. Both use
`ref.read(gameSessionProvider).value?.phase` — on first foreground, if the provider is still
`AsyncLoading`, `.value` returns `null`, the null-safe phase comparison (`phase == GamePhase.playing`)
evaluates to false (null equals neither), and the suppression does not fire. The App Open ad
proceeds immediately even though the session state is unknown. This creates a brief window on cold
start where an App Open ad could be shown while the game is nominally launching.

**Fix:** Add an `isLoading` guard in both suppression checks:
```dart
void _onAppResumed() {
  final sessionAsync = ref.read(gameSessionProvider);
  if (sessionAsync.isLoading) return; // unknown state — skip
  final phase = sessionAsync.value?.phase;
  if (phase == GamePhase.playing || phase == GamePhase.paused) return;
  ref.read(adServiceProvider).showAppOpenAd();
}
```

---

### WR-02: Rewarded-hint flow calls `useHint()` without triggering the zoom animation

**File:** `lib/features/map/map_screen.dart:248-250`

**Issue:**
```dart
if (earned) {
  ref.read(gameSessionProvider.notifier).refillHints();
  ref.read(gameSessionProvider.notifier).useHint();
}
```
When the user earns hints from the rewarded ad and `useHint()` is called here, the visual hint
behaviour — zoom-to-target animation (`_hintZoomController.forward()`), 3-second glow
(`_hintPostal`), and `_hintGlowTimer` — is never triggered. This is because those effects live
inside `_onHintPressed()`, which is not called in the rewarded path. A player watching an ad
to earn hints gets the hint count decremented but no map zoom assistance — defeating the
point of the hint.

**Fix:** Extract the animation logic from `_onHintPressed` into a shared helper, then call it
from both code paths after a successful `useHint()`:

```dart
void _applyHintAnimation() {
  final target = _stateIndex[_currentPostal];
  if (target == null) return;
  setState(() => _hintPostal = _currentPostal);
  final endMatrix = _computeHintMatrix(target.centroid, target);
  _hintZoomAnimation = Matrix4Tween(
    begin: _controller.value.clone(), end: endMatrix,
  ).animate(CurvedAnimation(parent: _hintZoomController, curve: Curves.easeInOut));
  _hintZoomController..reset()..forward();
  _hintGlowTimer?.cancel();
  _hintGlowTimer = Timer(const Duration(seconds: 3), () {
    if (mounted) setState(() => _hintPostal = null);
  });
}
// In rewarded earned path: if (consumed) _applyHintAnimation();
```

---

### WR-03: Wrong postal passed to `recordDrop` on incorrect drop

**File:** `lib/features/map/map_screen.dart:454-456`

**Issue:**
```dart
ref.read(gameSessionProvider.notifier).recordDrop(
    hitPostal ?? _currentPostal, isCorrect: false);
```
When the player drops onto a valid but wrong state polygon, `hitPostal` is that wrong state's
postal code. Passing `hitPostal` to `recordDrop` records the error against the wrong state.
The target the player is attempting to place is `_currentPostal`. Any future per-state error
tracking, analytics, or diagnostics will attribute the miss to the wrong state.

**Fix:**
```dart
ref.read(gameSessionProvider.notifier).recordDrop(_currentPostal, isCorrect: false);
```

---

### WR-04: Synchronous file deletion on UI thread in `_captureAndShare`

**File:** `lib/features/map/completion_screen.dart:139`

**Issue:**
```dart
} finally {
  file?.deleteSync(); // synchronous I/O on UI thread
  if (mounted) setState(() => _isSharing = false);
}
```
`deleteSync()` blocks the calling isolate. On a slow device, an encrypted partition, or an
overloaded storage stack, this can freeze the UI thread long enough to trigger a jank frame or
an ANR. The method is already `async` — `await file?.delete()` is a direct replacement.

**Fix:**
```dart
} finally {
  await file?.delete();
  if (mounted) setState(() => _isSharing = false);
}
```

---

### WR-05: Star-count logic duplicated between `initState` and `computeStarCount`

**File:** `lib/features/map/completion_screen.dart:60-74`

**Issue:** `_CompletionScreenState.initState` manually replicates the exact same conditional
logic already present in the top-level `computeStarCount` function, then adds a separate
`_isNewPb` flag computed inline. If the scoring formula changes (e.g., the 20% threshold moves
to 15%), one branch will diverge silently:

```dart
// initState (duplicated):
if (prev == null) { _isNewPb = false; _starCount = 3; }
else if (score < prev) { _isNewPb = true; _starCount = 3; }
else if (score <= (prev * 1.20).ceil()) { _isNewPb = false; _starCount = 2; }
```

**Fix:**
```dart
_starCount = computeStarCount(score, prev);
_isNewPb = (prev != null && score < prev);
```

---

### WR-06: Misleading comment claims `ref.watch` triggers banner rebuild

**File:** `lib/features/home/home_screen.dart:177-179`

**Issue:**
```dart
// AD-03: Banner ad slot — below mode cards, above privacy footer.
// ref.watch rebuilds this widget when the banner loads.
ref.watch(adServiceProvider).getBannerWidget(),
```
`adServiceProvider` is `Provider<AdService>` — a static provider that never emits change
notifications. `ref.watch` on it will not rebuild `HomeScreen` when `_bannerAd` is
asynchronously populated. The comment will mislead future maintainers into believing the
mechanism is working correctly when it is not (see CR-01).

**Fix:** Correct the comment after implementing CR-01's fix to reflect the actual notification
mechanism used.

---

### WR-07: `ad.show()` exceptions leave ad objects un-disposed

**File:** `lib/core/ads/real_ad_service.dart:87`, `lib/core/ads/real_ad_service.dart:124-129`, `lib/core/ads/real_ad_service.dart:186`

**Issue:** In `showInterstitialAd`, `showRewardedAd`, and `showAppOpenAd`, the pattern is:
```dart
final ad = _interstitialAd;
_interstitialAd = null; // null before show
await ad.show();        // if this throws synchronously…
```
If `ad.show()` throws a Dart exception (not an ad SDK failure callback), the
`FullScreenContentCallback` callbacks never fire, so `ad.dispose()` is never called. The
exception propagates out of the method as an unhandled Future error, and `ad` leaks. This can
happen on Android if the Activity is finishing at the moment `show()` is called.

**Fix:** Wrap each `ad.show()` call in a try/catch with explicit disposal on error:
```dart
try {
  await ad.show();
} catch (e) {
  ad.dispose();
  debugPrint('interstitial show threw: $e');
}
```

---

### WR-08: `_buildMapStack` assigns `_states` and calls `_startSequence`/`_maybeStartGame` from inside `build()`

**File:** `lib/features/map/map_screen.dart:689-691`

**Issue:**
```dart
Widget _buildMapStack(List<StateData> states, GameSession? session) {
  _states = states;           // mutable field assignment inside build
  _startSequence(states);     // side effect inside build (guarded, but still)
  _maybeStartGame(session);   // side effect inside build
```
Flutter may call `build()` more than once in a frame (e.g., during `setState` within a frame).
Assigning to `_states` (a field used by `_handleDrop` via the closure) inside `build()` is
an anti-pattern — it creates a window where `_handleDrop` could be called with a stale
`_states` while `build()` has not yet run after a data update. `_startSequence` is safely
guarded by `_sequenceInitialized`, but the pattern is fragile and will confuse any reviewer
looking at this code.

**Fix:** Move `_states` assignment and `_startSequence` call into `didChangeDependencies` or
a `ref.listen` on `stateDataProvider`. `_maybeStartGame` should become a
`ref.listen(gameSessionProvider, ...)` side effect, not a build-time call.

---

## Info

### IN-01: Dead code — `kAppLovinEnabled` `if` block with empty body

**File:** `lib/core/ads/ads_initializer.dart:45-47`

**Issue:**
```dart
if (kAppLovinEnabled) {
  // No-op: AppLovin SDK 13.0+ refuses child-directed init.
}
```
`kAppLovinEnabled` is `const false`. This `if` block is permanently dead code — the body is a
comment with zero statements. The intent (blocking AppLovin until v2 preconditions are met) is
not enforced by anything executable.

**Fix:** Remove the block and replace with a commented work item, or add an assertion that
will fire if the flag is accidentally enabled before the preconditions are met:
```dart
assert(!kAppLovinEnabled,
    'AppLovin activation requires: (1) account approval, '
    '(2) re-listing on Google Play Families Self-Certified Ads SDK list.');
```

---

### IN-02: Production ad unit IDs committed to source control

**File:** `lib/core/ads/ad_constants.dart:5-8`

**Issue:** All four production ad unit IDs (`ca-app-pub-4227443066128564/...`) are hardcoded
constants committed to the git repository. While client-side ad IDs are not secrets in the
same category as API keys, they expose the AdMob publisher account structure in git history.
For a currently private repo this is acceptable but should be noted for any future open-source
transition.

**Fix:** For private repo: acceptable as-is. If the repo ever goes public, move IDs to
`--dart-define` build arguments or a non-committed configuration file.

---

### IN-03: `state_tray_test.dart` tests find text via SVG placeholder path, not production card face

**File:** `test/features/map/state_tray_test.dart:26-29`

**Issue:** The "Learn mode shows abbreviation on face" test asserts `find.text('CA')`. The
production card face is `SvgPicture.asset('assets/flags/ca.svg')` — not a `Text` widget. The
test finds "CA" only because `stateData` is not passed, causing the fallback `Text(widget.postal)`
in `placeholderBuilder` to render. The test passes for the wrong reason and would not catch a
regression in the SVG-primary rendering path. The "States Master mode shows state name on face"
test description is also incorrect — no mode puts the full state name on the card face; the
card always shows the flag SVG (or postal abbreviation as fallback).

**Fix:** Add a comment documenting the SVG-fallback dependency. For a more robust test, mock
the asset bundle to provide a trivial SVG and assert the SVG widget exists.

---

### IN-04: `_captureAndShare` uses a fixed temp filename — concurrent share attempts collide

**File:** `lib/features/map/completion_screen.dart:126`

**Issue:**
```dart
file = File('${Directory.systemTemp.path}/score_card.png');
```
The filename is static. If the user double-taps the share button quickly (the `_isSharing`
guard is set after the file is created, not before), two concurrent `_captureAndShare`
invocations could write to and delete the same file path simultaneously, corrupting the share
payload. The `_isSharing` boolean is set to `true` only at line 132, after `file.writeAsBytes`
has already been called — there is a window between the method entry and line 132 where a
second invocation is not blocked.

**Fix:** Use a unique filename suffix and set `_isSharing = true` as the very first action:
```dart
if (_isSharing) return; // guard at entry
setState(() => _isSharing = true);
// ...
final tmpName = 'score_card_${DateTime.now().millisecondsSinceEpoch}.png';
file = File('${Directory.systemTemp.path}/$tmpName');
```

---

_Reviewed: 2026-06-03T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
