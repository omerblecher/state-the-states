---
phase: 08-full-admob-layer
fixed_at: 2026-06-03T00:00:00Z
review_path: .planning/phases/08-full-admob-layer/08-REVIEW.md
iteration: 1
findings_in_scope: 13
fixed: 13
skipped: 0
status: all_fixed
---

# Phase 08: Code Review Fix Report

**Fixed at:** 2026-06-03T00:00:00Z
**Source review:** .planning/phases/08-full-admob-layer/08-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 13 (CR-01 through CR-05, WR-01 through WR-08)
- Fixed: 13
- Skipped: 0

## Fixed Issues

### CR-01: Banner ad never displays — `adServiceProvider` emits no change notifications

**Files modified:** `lib/core/ads/ad_service_provider.dart`, `lib/core/ads/real_ad_service.dart`, `lib/features/home/home_screen.dart`
**Commit:** df6394d, 142fe58
**Applied fix:** Added `BannerReadyNotifier` (a Riverpod v3 `Notifier<int>`) and `bannerReadyProvider` (`NotifierProvider`) to `ad_service_provider.dart`. `RealAdService.loadBannerForWidth` calls `_ref.read(bannerReadyProvider.notifier).increment()` inside `onAdLoaded`. `HomeScreen.build()` calls `ref.watch(bannerReadyProvider)` at the top so the widget rebuilds when the banner loads, then `ref.read(adServiceProvider).getBannerWidget()` returns the loaded `AdWidget`. Note: Used `NotifierProvider` instead of `StateProvider` (which is in Riverpod v3's legacy API) for forward compatibility.

---

### CR-02: Hard downcast `as RealAdService` crashes under any non-production ad service

**Files modified:** `lib/core/ads/ad_service.dart`, `lib/core/ads/stub_ad_service.dart`, `lib/core/ads/real_ad_service.dart`, `lib/features/home/home_screen.dart`, `test/features/map/completion_screen_test.dart`
**Commit:** df6394d, 142fe58
**Applied fix:** Added `Future<void> loadBannerForWidth(int screenWidthDp)` to the `AdService` abstract interface with a doc comment. Added no-op `@override` implementation to `StubAdService`. Added `@override` annotation to `RealAdService.loadBannerForWidth`. Removed `import 'package:state_states/core/ads/real_ad_service.dart'` from `home_screen.dart`. Replaced `(ref.read(adServiceProvider) as RealAdService).loadBannerForWidth(widthDp)` with `ref.read(adServiceProvider).loadBannerForWidth(widthDp)`. Added `loadBannerForWidth` stub to `_SpyAdService` in `completion_screen_test.dart`.

---

### CR-03: `submitTyping` case-sensitivity — only ALL-CAPS input accepted

**Files modified:** `lib/features/game/game_session_notifier.dart`
**Commit:** 70761e4
**Applied fix:** Changed `final normalized = input.trim()` to `final normalized = input.trim().toUpperCase()` so both the name comparison (`s.name.toUpperCase() == normalized`) and the postal comparison (`s.postal == normalized`) operate on fully uppercased values.

---

### CR-04: `FutureBuilder` future re-created on every rebuild — session-restore card flickers and races against dismiss

**Files modified:** `lib/features/home/home_screen.dart`
**Commit:** df6394d
**Applied fix:** Added `Future<({GameSession session, int hintPenalty})?>? _savedSessionFuture` field to `_HomeScreenState`. In the `addPostFrameCallback` async closure, awaits `ref.read(gameStateRepositoryProvider.future)` then assigns `repo.loadSession()` to `_savedSessionFuture` via `setState`. The `FutureBuilder` now uses `future: _savedSessionFuture` — the same `Future` object across all rebuilds, eliminating flicker and the dismiss-race.

---

### CR-05: `MathChallengeDialog._onConfirm` mutates `_a`/`_b` outside `setState`

**Files modified:** `lib/features/map/completion_screen.dart`
**Commit:** 7d1a0ad
**Applied fix:** Moved `_a = 10 + rng.nextInt(90)` and `_b = 2 + rng.nextInt(8)` inside the `setState` callback alongside `_error = 'Incorrect — try again'`, so all three build-affecting mutations happen atomically within a single `setState` call.

---

### WR-01: App Open suppression race — null session treated as "not playing" even during async load

**Files modified:** `lib/app.dart`
**Commit:** bbcf6bc
**Applied fix:** Added `final sessionAsync = ref.read(gameSessionProvider)` and an `if (sessionAsync.isLoading) return;` guard before reading `sessionAsync.value?.phase`. This prevents the App Open ad from showing while session state is still resolving.

---

### WR-02: Rewarded-hint flow calls `useHint()` without triggering the zoom animation

**Files modified:** `lib/features/map/map_screen.dart`
**Commit:** cf1f0e4
**Applied fix:** Extracted `_applyHintAnimation()` helper from `_onHintPressed()` containing the zoom animation, glow state, and timer logic. `_onHintPressed()` now calls `_applyHintAnimation()` after `useHint()`. In `_showRewardedHintDialog()`, the rewarded earned branch captures the `bool` returned by `useHint()` and calls `_applyHintAnimation()` when consumed is true.

---

### WR-03: Wrong postal passed to `recordDrop` on incorrect drop

**Files modified:** `lib/features/map/map_screen.dart`
**Commit:** 3dc7170
**Applied fix:** Changed `recordDrop(hitPostal ?? _currentPostal, isCorrect: false)` to `recordDrop(_currentPostal, isCorrect: false)`. The error is always attributed to the target state the player is trying to place, not the wrong state they accidentally hit.

---

### WR-04: Synchronous file deletion on UI thread in `_captureAndShare`

**Files modified:** `lib/features/map/completion_screen.dart`
**Commit:** 7d1a0ad
**Applied fix:** Replaced `file?.deleteSync()` with `await file?.delete()` in the `finally` block. The method is already `async`, so this is a direct drop-in replacement that avoids blocking the UI thread.

---

### WR-05: Star-count logic duplicated between `initState` and `computeStarCount`

**Files modified:** `lib/features/map/completion_screen.dart`
**Commit:** 7d1a0ad
**Applied fix:** Replaced the 8-line `if/else if/else` block in `initState` with two lines: `_starCount = computeStarCount(score, prev)` and `_isNewPb = (prev != null && score < prev)`. The scoring formula is now defined in exactly one place.

---

### WR-06: Misleading comment claims `ref.watch` triggers banner rebuild

**Files modified:** `lib/features/home/home_screen.dart`
**Commit:** df6394d
**Applied fix:** Updated the comment above the banner slot to accurately describe the actual mechanism: `ref.watch(bannerReadyProvider)` at the top of `build()` triggers rebuilds via the notifier counter, after which `getBannerWidget()` returns the loaded `AdWidget`. Changed the call site from `ref.watch(adServiceProvider).getBannerWidget()` to `ref.read(adServiceProvider).getBannerWidget()` since `adServiceProvider` is a plain `Provider` that never emits notifications.

---

### WR-07: `ad.show()` exceptions leave ad objects un-disposed

**Files modified:** `lib/core/ads/real_ad_service.dart`
**Commit:** 4f17dd2
**Applied fix:** Wrapped `await ad.show()` in `try/catch` with `ad.dispose(); debugPrint(...)` in the catch block for all three ad types: interstitial, rewarded, and App Open. For rewarded, the catch also completes the `Completer` with `false` to prevent the caller from hanging.

---

### WR-08: `_buildMapStack` assigns `_states` and calls side effects from inside `build()`

**Files modified:** `lib/features/map/map_screen.dart`
**Commit:** 810e308
**Applied fix:** Moved `_states = states` from `_buildMapStack` into `_startSequence` (which is already guarded by `_sequenceInitialized`). Since `stateDataProvider` provides static map data that does not change after initial load, `_states` is correctly populated the first time `_startSequence` executes and remains valid for the lifetime of `MapScreen`. Removed the now-redundant assignment from `_buildMapStack`, replacing the comment to explain the invariant.

---

## Skipped Issues

None — all findings were fixed.

---

## Analysis Results

`dart analyze lib/ test/` was run after all fixes. Zero errors introduced by these fixes.

Pre-existing errors (11) in `test/features/map/usa_map_painter_test.dart` all reference `insetFrameRects` — a named parameter that does not exist in `UsaMapPainter`. These errors pre-date this phase's changes (confirmed by running the analyzer on the codebase before applying any fixes) and are out of scope for this fix session.

Pre-existing warnings and infos (warnings: 5, infos: 5) are also unchanged and pre-existing.

---

_Fixed: 2026-06-03T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
