---
phase: 08-full-admob-layer
plan: "02"
status: complete
completed: "2026-06-03"
subsystem: ads
tags: [admob, real-ad-service, rewarded, app-open, banner, interstitial, coppa]
requires: [08-01]
provides: [real-ad-service, app-state-observer, real-ad-service-provider]
affects:
  - lib/core/ads/real_ad_service.dart
  - lib/core/ads/app_state_observer.dart
  - lib/core/ads/ad_service_provider.dart
  - test/core/ads/real_ad_service_test.dart
tech_stack:
  added: []
  patterns: [completer-rewarded-ad, app-open-suppression, preload-on-dismiss, double-load-guard]
key_files:
  created:
    - lib/core/ads/real_ad_service.dart
    - lib/core/ads/app_state_observer.dart
  modified:
    - lib/core/ads/ad_service_provider.dart
    - test/core/ads/real_ad_service_test.dart
decisions:
  - "Ref is sealed in Riverpod 3.x — cannot be mocked with mocktail; use ProviderContainer + overrideWith pattern instead"
  - "unnecessary_underscores lint: onUserEarnedReward (_, __) replaced with (_, reward) to name the second param"
  - "_PlayingPhaseNotifier subclasses GameSessionNotifier with FakeTicker; overrides build() to return playing-phase session for AD-05 test"
metrics:
  duration: 9min
  completed: "2026-06-03"
  tasks: 2
  files: 4
---

# Phase 08 Plan 02: RealAdService, app_state_observer, and GREEN Tests Summary

## What Was Built

Full `RealAdService` implementation ported from Flags' `AdMobAdService` — all four ad types (banner, interstitial, rewarded, App Open) behind the `AdService` interface. `app_state_observer.dart` thin re-export created. `adServiceProvider` switched from `StubAdService` to `RealAdService(ref)` with `preloadAll()`. All four skipped `RealAdService` tests are now GREEN.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create real_ad_service.dart and app_state_observer.dart | ccaa3af | real_ad_service.dart, app_state_observer.dart |
| 2 | Switch adServiceProvider to RealAdService; enable tests | 35c707b | ad_service_provider.dart, real_ad_service_test.dart |

## Verification Results

```
flutter test test/core/ads/ — 9 passed, 1 skipped (AD-01 structural, expected Wave 0 skip)
flutter analyze lib/core/ads/ — No issues found
real_ad_service.dart contains "class RealAdService implements AdService": confirmed
real_ad_service.dart contains "Completer<bool>": confirmed
real_ad_service.dart contains "getLargeAnchoredAdaptiveBannerAdSize": confirmed
real_ad_service.dart does NOT contain "getCurrentOrientationAnchoredAdaptiveBannerAdSize": confirmed
ad_service_provider.dart contains "RealAdService(ref)" and "preloadAll()": confirmed
stub_ad_service.dart still exists (not deleted): confirmed
```

## Key Decisions

1. **Ref is sealed in Riverpod 3.x** — `sealed class Ref` has a private constructor and cannot be extended or mocked with mocktail. The test pattern uses `ProviderContainer` with `gameSessionProvider.overrideWith()` and a `_PlayingPhaseNotifier` subclass to inject a real `Ref` into `RealAdService`.

2. **`unnecessary_underscores` lint on `(_, __)` pattern** — The Flags analog uses `(_, __)` in `onUserEarnedReward`, which triggers the `unnecessary_underscores` lint rule in `flutter_lints ^6.0.0`. Fixed by naming the second param `reward`: `(_, reward)`.

3. **`_PlayingPhaseNotifier` extends `GameSessionNotifier`** — For AD-05 test (App Open suppression), a subclass overrides `build()` to return `GamePhase.playing` immediately, avoiding the need to tick through the 5-step countdown. Constructor passes `FakeTicker()` to satisfy the required `ticker` param.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `unnecessary_underscores` lint on `(_, __)` in `onUserEarnedReward`**
- **Found during:** Task 1 verification (`flutter analyze`)
- **Issue:** `flutter_lints ^6.0.0` flags `(_, __)` — the second parameter must be named, not a second wildcard
- **Fix:** Changed `(_, __)` to `(_, reward)` in the `onUserEarnedReward` callback
- **Files modified:** lib/core/ads/real_ad_service.dart
- **Commit:** ccaa3af (included in Task 1)

**2. [Rule 1 - Bug] `Ref` cannot be mocked in Riverpod 3.x**
- **Found during:** Task 2 first test run
- **Issue:** `Ref` is a `sealed class` with a private constructor — `class MockRef extends Mock implements Ref` fails to compile
- **Fix:** Replaced mock-based approach with `ProviderContainer` + `overrideWith` pattern; created `_PlayingPhaseNotifier` subclass for phase-specific session injection
- **Files modified:** test/core/ads/real_ad_service_test.dart
- **Commit:** 35c707b (included in Task 2)

## Known Stubs

None — all four ad types are fully implemented. `adServiceProvider` returns real `RealAdService(ref)` with `preloadAll()`. No placeholder values in any modified files.

## Threat Flags

No new security surface introduced beyond what was planned.

| Flag | File | Description |
|------|------|-------------|
| None | — | All ad calls remain behind AdService interface; no new network endpoints; GameSessionNotifier walled-garden preserved (zero ad imports) |

## Self-Check: PASSED

- lib/core/ads/real_ad_service.dart exists: confirmed
- lib/core/ads/app_state_observer.dart exists: confirmed
- `class RealAdService implements AdService` in real_ad_service.dart: confirmed
- `Completer<bool>` in real_ad_service.dart: confirmed
- `getLargeAnchoredAdaptiveBannerAdSize` in real_ad_service.dart: confirmed
- `getCurrentOrientationAnchoredAdaptiveBannerAdSize` ABSENT from real_ad_service.dart: confirmed
- `RealAdService(ref)` and `preloadAll()` in ad_service_provider.dart: confirmed
- stub_ad_service.dart still exists: confirmed
- All 4 RealAdService tests GREEN (AD-03, AD-04, AD-05, HINT-05): confirmed
- Task commits ccaa3af and 35c707b exist: confirmed
