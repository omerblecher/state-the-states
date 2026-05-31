---
phase: 01-foundation
reviewed: 2026-05-31T06:21:34Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - lib/main.dart
  - lib/app.dart
  - lib/core/ads/ad_service.dart
  - lib/core/ads/stub_ad_service.dart
  - lib/core/ads/ad_service_provider.dart
  - lib/core/ads/ad_load_state.dart
  - lib/core/ads/ad_constants.dart
  - lib/core/ads/ads_initializer.dart
  - lib/core/audio/audio_service.dart
  - lib/core/audio/stub_audio_service.dart
  - lib/core/audio/real_audio_service.dart
  - lib/core/audio/audio_service_provider.dart
  - lib/core/data/state_data_service.dart
  - lib/core/models/state_data.dart
  - lib/features/home/home_screen.dart
  - lib/features/map/map_screen.dart
  - lib/features/map/usa_map_painter.dart
  - test/core/data/state_data_service_test.dart
  - test/core/models/state_data_test.dart
  - scripts/generate_states.py
  - scripts/test_pipeline.py
  - android/app/src/main/AndroidManifest.xml
  - android/app/build.gradle.kts
findings:
  critical: 1
  warning: 7
  info: 5
  total: 13
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-05-31T06:21:34Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

Phase 1 foundation is largely well-structured: the ad layer wires only `StubAdService`, the AndroidManifest strips the full AD_ID permission family, `tagForChildDirectedTreatment.yes` is set before `MobileAds.initialize()`, and the Python pipeline uses the correct three-CRS Albers strategy with antimeridian-fix-before-reproject ordering and a validity gate. Tests cover the key invariants (51/50/DC, inset containment, derived viewBox).

However, the review surfaces one Critical defect and several warnings centered on the three flagged risk areas:

- **Audio lifecycle:** `RealAudioService` is constructed in `main.dart` but its `dispose()` is never wired to anything — three `just_audio` `AudioPlayer` instances leak for the lifetime of the process (Critical).
- **COPPA walled garden:** the *service* layer is a clean stub, but `main.dart` still calls `MobileAds.instance.initialize()` at startup in a "fully-offline, no real ads in v1" app. The documented walled-garden intent ("no real ads are requested") and the offline constraint are in tension with eagerly initializing the AdMob SDK (Warning).
- **Pipeline robustness:** several unguarded `min()`/`max()` and division operations, plus dead code, would fail noisily or silently on edge inputs (Warnings/Info).

## Critical Issues

### CR-01: `RealAudioService` players are never disposed — resource leak

**File:** `lib/main.dart:21-25`, `lib/core/audio/real_audio_service.dart:83-88`
**Issue:** `main.dart` overrides `audioServiceProvider` by constructing a `RealAudioService` and calling `init()` (which allocates three `AudioPlayer` instances and three native player resources), but nothing ever calls `dispose()`. `audioServiceProvider` is a plain `Provider` (not `autoDispose`), and the `overrideWith` closure registers no `ref.onDispose(...)` callback. The well-formed `dispose()` method at `real_audio_service.dart:83` is therefore dead — unreachable in the running app. Three native audio players and their platform channels leak for the process lifetime. On a child's device that may background/foreground the app repeatedly, orphaned `just_audio` players are a known source of stuck audio sessions and audio-focus contention.
**Fix:** Register disposal in the override so Riverpod tears the service down with the scope:
```dart
audioServiceProvider.overrideWith((ref) {
  final svc = RealAudioService();
  unawaited(svc.init());
  ref.onDispose(() => unawaited(svc.dispose()));
  return svc;
}),
```
Additionally consider stopping the anthem and releasing players on app lifecycle `detached`/`paused` (Phase 4+ when an `AppLifecycleListener` is introduced).

## Warnings

### WR-01: AdMob SDK is initialized at startup despite "fully-offline / no real ads" v1 design

**File:** `lib/main.dart:15`, `lib/core/ads/ads_initializer.dart:12-28`
**Issue:** Every doc comment in the ad layer asserts the v1 posture is a walled garden where "No real ads are requested" (`ad_constants.dart:5`) and there is "no compile-time path to a real AdMob service" (`ad_service_provider.dart`). Yet `main.dart` unconditionally `await`s `initializeAds()`, which calls `MobileAds.instance.initialize()`. Initializing the AdMob SDK performs SDK setup and can trigger outbound network activity, which contradicts both the "fully offline — no network dependency for core gameplay" constraint and the stated "no real ads in v1" intent. The child-directed flag *is* correctly set before initialize, so this is not a COPPA-flag bug — but eagerly bringing up an ad SDK that will never serve an ad in v1 is unnecessary attack surface for a child-directed offline app, and an `await` on it also blocks first frame on whatever the SDK does at init.
**Fix:** In v1, do not initialize the SDK at all — the stub serves no ads. Either guard the call behind a `kAdsEnabled` compile-time flag (default `false` in v1) or remove the `initializeAds()` call from `main.dart` until the real ad service lands in v2. If the SDK must stay linked (to satisfy the manifest `APPLICATION_ID` meta-data), prefer not calling `initialize()` until an ad is actually requested. At minimum, do not block `runApp` on it:
```dart
// v1: stub-only. Do not initialize the ad SDK.
// (Re-enable in v2 behind a flag, before runApp, with child-directed config.)
```

### WR-02: `initializeAds()` has no error handling — a failed init aborts app launch

**File:** `lib/core/ads/ads_initializer.dart:27`, `lib/main.dart:15`
**Issue:** `await MobileAds.instance.initialize()` is unguarded, and `main.dart` `await`s it before `runApp`. If the AdMob SDK throws or hangs during initialization (e.g. Play Services missing/old on a low-end Android device, which is squarely in the 8+ children audience on cheap hardware), the entire app fails to start with no UI. For an app that shows zero ads in v1, an ad-SDK failure must never be able to prevent gameplay.
**Fix:** Wrap in try/catch and never let it block launch:
```dart
try {
  await MobileAds.instance.initialize();
} catch (e, st) {
  debugPrint('Ad SDK init failed (non-fatal): $e\n$st');
}
```
(Or remove the call entirely per WR-01.)

### WR-03: `_parseInsetGroup` throws on any unknown inset value

**File:** `lib/core/models/state_data.dart:64-67`
**Issue:** `InsetGroup.values.firstWhere((e) => e.name == value)` has no `orElse`. If the bundled JSON ever contains an `insetGroup` string other than `"alaska"`/`"hawaii"` (schema drift, a future inset, or a typo from a pipeline change), `firstWhere` throws `StateError`, which propagates out of `StateData.fromJson` and fails the entire `FutureProvider` — the map screen renders the generic error branch and the game is unplayable. Parsing of bundled data should degrade gracefully, not hard-fail on one bad field.
**Fix:**
```dart
static InsetGroup? _parseInsetGroup(String? value) {
  if (value == null) return null;
  return InsetGroup.values.where((e) => e.name == value).firstOrNull;
}
```

### WR-04: Pipeline `min()`/`max()` over empty coordinate lists raise opaque `ValueError`

**File:** `scripts/generate_states.py:173-174` (`build_record`), `:389`, `:434-437`, `:463`, `:505-509`
**Issue:** `build_record` calls `min(all_xs), max(all_xs)` etc. with no guard. `geometry_to_paths` only appends coordinates for `Polygon`/`MultiPolygon` parts; a `GeometryCollection`, empty geometry, or all-degenerate polygons (every part `< 3` vertices) yields empty `all_xs`/`all_ys`, and `min([])` raises a bare `ValueError: min() arg is an empty sequence` with no indication of which state failed. The same unguarded `min/max` pattern repeats for the AK/HI natural-bounds and inset-frame computations. Given the field names are explicitly MEDIUM-confidence and the input shapefile is external, this should fail with a state-identifying message.
**Fix:** Guard and contextualize:
```python
if not all_xs or not all_ys:
    raise RuntimeError(f"State {postal} produced no drawable polygons")
```
and similarly assert non-empty before the AK/HI bounds `min/max`.

### WR-05: `compute_inset_transform` divides by natural width/height with no zero guard

**File:** `scripts/generate_states.py:214`
**Issue:** `s = min(tgt_w / nat_w, tgt_h / nat_h)`. If `nat_w` or `nat_h` is `0` (single-point or vertical/horizontal degenerate landmass after projection), this raises `ZeroDivisionError`. Unlikely for real AK/HI but the function is generic and silently assumes non-degenerate bounds.
**Fix:** Add `assert nat_w > 0 and nat_h > 0, "degenerate inset bounds for ..."` before the division, or clamp with a small epsilon.

### WR-06: CONUS multi-row merge re-runs the CONUS transform but appends without re-centroiding

**File:** `scripts/generate_states.py:349-353` (and AK `:414-417`, HI `:487-489`)
**Issue:** The "defensive" merge path `records[postal]["paths"].extend(record["paths"])` only merges path strings. The first row's `boundingBox` and `centroid` are kept and the second row's are discarded — so if a state ever does span multiple rows, its bounding box would be wrong (covering only the first fragment) and the centroid could land outside the combined geometry. The code comments it "shouldn't happen in NE 10m" but the branch exists and is silently incorrect if taken. Because Natural Earth admin-1 *can* split territories across rows, this is a latent correctness bug, not purely theoretical.
**Fix:** Either drop the merge branch and assert one row per postal (`assert postal not in records`), or do a true geometry-level `unary_union` of all rows for a postal *before* `build_record` so bounding box and centroid are recomputed over the union.

### WR-07: `playAnthem()` does not stop before replaying — repeated calls can stack/seek-fight

**File:** `lib/core/audio/real_audio_service.dart:56-62`
**Issue:** Unlike `playCorrect`/`playError` (which `stop()` then `seek(0)` then `play()`), `playAnthem` only `seek(0)` + `play()`. If `playAnthem()` is called twice without an intervening `stopAnthem()` (e.g. the welcome screen rebuilds, or navigates away and back quickly), the second `seek(0)` mid-playback restarts the loop abruptly and the play futures race. With `LoopMode.one` already set, a re-entrant `playAnthem` is at best a hard restart and at worst overlapping `play()` calls.
**Fix:** Make it idempotent — check `playing` state or stop first:
```dart
if (_anthemPlayer.playing) return;        // already looping
await _anthemPlayer.seek(Duration.zero);
unawaited(_anthemPlayer.play());
```

## Info

### IN-01: `bake_inset_transform` is dead code

**File:** `scripts/generate_states.py:233-244`
**Issue:** The function body is a docstring plus `pass`; its own docstring says "this function isn't used directly." It is never called. Dead code that documents a non-implementation invites confusion.
**Fix:** Delete `bake_inset_transform` entirely; `make_inset_to_canvas` already covers the need.

### IN-02: Duplicate inset-frame / centroid computations in `test_inset_positions`

**File:** `scripts/test_pipeline.py:146-157`
**Issue:** `ak_frame`/`hi_frame` are assigned at lines 146-147 then re-fetched into `ak_frame_val`/`hi_frame_val` at lines 156-157; the first pair is unused. Minor clutter that suggests an incomplete edit.
**Fix:** Remove the unused `ak_frame`/`hi_frame` locals and use one set of names.

### IN-03: `AK_SCALE_FACTOR` constant is declared but never used

**File:** `scripts/generate_states.py:62-63`
**Issue:** `AK_SCALE_FACTOR = 0.45` is defined with an authoritative-sounding comment, but the actual AK scale is computed by `compute_inset_transform` (`min(tgt_w/nat_w, tgt_h/nat_h)`), so the constant is never read. A reader could mistakenly assume changing it affects output.
**Fix:** Remove the constant, or wire it into the target-rect sizing if a fixed scale was actually intended (it appears it was not — the fit-to-rect approach supersedes it).

### IN-04: `AdLoadState` sealed class is unused in Phase 1

**File:** `lib/core/ads/ad_load_state.dart:1-11`
**Issue:** `AdLoadState`/`AdLoaded`/`AdFailed` are defined but referenced nowhere in the reviewed v1 surface (the only wired service is the stub, which tracks no load state). Not harmful, but it is speculative scaffolding for v2 shipping in the v1 walled-garden module.
**Fix:** Acceptable to keep as a v2 placeholder; consider a `// v2` marker comment or move it under a v2-scoped folder so the v1 ad surface stays minimal.

### IN-05: `app.dart` MaterialApp title and home screen title strings are hardcoded, bypassing the planned ARB/i18n pipeline

**File:** `lib/app.dart:28`, `lib/features/home/home_screen.dart:25`
**Issue:** CLAUDE.md commits to `intl` + `flutter gen-l10n` ARB-based UI strings. `'State the States'` and `'Play'` are inline string literals. For Phase 1 placeholders this is fine, but flagging so the i18n debt is tracked before user-facing strings proliferate.
**Fix:** Route user-facing strings through the generated localizations once the ARB pipeline lands (Phase 4 UI work); leave a `// TODO(i18n)` if deferring.

---

_Reviewed: 2026-05-31T06:21:34Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
