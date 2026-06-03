---
phase: 08-full-admob-layer
plan: "01"
status: complete
completed: "2026-06-03"
subsystem: ads
tags: [admob, mediation, coppa, game-session]
requires: [08-00]
provides: [mediation-packages, production-ad-ids, refill-hints]
affects: [pubspec.yaml, ads_initializer.dart, ad_constants.dart, AndroidManifest.xml, game_session_notifier.dart]
tech_stack:
  added: [gma_mediation_unity@1.8.0, gma_mediation_ironsource@2.4.1, gma_mediation_inmobi@2.1.0]
  patterns: [coppa-mediation-flags, walled-garden-notifier]
key_files:
  modified:
    - pubspec.yaml
    - lib/core/ads/ads_initializer.dart
    - lib/core/ads/ad_constants.dart
    - android/app/src/main/AndroidManifest.xml
    - lib/features/game/game_session_notifier.dart
decisions:
  - "InMobi comment must not contain the string 'gma_mediation_inmobi' — source-assertion test scans raw file text"
  - "refillHints() uses no-op guard on phase != playing; score/penalty unchanged (useHint's responsibility)"
  - "ads_initializer.dart comment text adjusted to avoid triggering the no-InMobi-import assertion test"
metrics:
  duration: 15min
  completed: "2026-06-03"
  tasks: 3
  files: 5
---

# Phase 08 Plan 01: Mediation Packages, Production IDs, and refillHints Summary

## What Was Built

Three mediation packages wired into pubspec, per-SDK COPPA flags added to ads_initializer.dart in the correct order before MobileAds.initialize(), all five production AdMob IDs installed in ad_constants.dart and AndroidManifest.xml, and refillHints() added to GameSessionNotifier — turning the three HINT-04 RED tests GREEN.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add mediation packages to pubspec.yaml (D-03) | ff1c2d8 | pubspec.yaml, pubspec.lock |
| 2 | COPPA flags in ads_initializer.dart + production IDs (D-02, D-04) | b83db97 | ads_initializer.dart, ad_constants.dart, AndroidManifest.xml |
| 3 | Add refillHints() to GameSessionNotifier (HINT-04) | f03e878 | game_session_notifier.dart |

## Verification Results

```
flutter test test/core/ads/ads_initializer_test.dart — 3 passed, 1 skipped (AD-01 structural)
flutter test test/features/game/game_session_notifier_test.dart --name HINT-04 — 3 passed (all GREEN)
flutter analyze lib/core/ads/ lib/features/game/game_session_notifier.dart — No issues found
grep ^import.*ads in game_session_notifier.dart — no output (walled-garden preserved)
```

## Key Decisions

1. **InMobi comment text stripped of package name string** — the AD-02 source-assertion test uses `contains('gma_mediation_inmobi')` as a raw text scan. Comments in ads_initializer.dart were rephrased to say "InMobi mediation adapter" rather than the package name to avoid triggering the negative assertion.

2. **refillHints() guard: null or phase != playing** — per Pattern 7 in RESEARCH.md. The method is a no-op for any non-playing phase; score and _hintPenalty are untouched (those are useHint()'s domain).

3. **kAdMobTestAppId renamed to kAdMobAppId** — removed "Test" from the constant name to match the production context.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Comment in ads_initializer.dart triggered the no-InMobi-import test**
- **Found during:** Task 2 verification
- **Issue:** The AD-02 test uses a raw string search for `gma_mediation_inmobi` in the source file. The plan's spec'd comment "// InMobi: NO Dart call. GmaMediationInMobi is an empty stub class." contained the package name verbatim, causing the negative assertion to fail.
- **Fix:** Rewrote comments to say "InMobi mediation adapter" and "the InMobi adapter" without spelling out the package identifier.
- **Files modified:** lib/core/ads/ads_initializer.dart
- **Commit:** b83db97 (included in Task 2 commit)

## Known Stubs

None — all production values wired. No placeholder strings remain in the files modified by this plan.

## Threat Flags

No new security surface introduced. All changes are pure configuration (package declarations, constant values, comment updates) and a single pure-Dart method with no network or ad-SDK imports.

## Self-Check: PASSED

- pubspec.yaml contains all three gma_mediation_* entries: confirmed
- pubspec.lock resolves gma_mediation_unity 1.8.0, ironsource 2.4.1, inmobi 2.1.0: confirmed
- gma_mediation_applovin absent from pubspec.yaml and pubspec.lock: confirmed
- ads_initializer.dart contains setConsent(false), setDoNotSell(true), setGDPRConsent(false), setCCPAConsent(false): confirmed
- ads_initializer.dart does NOT contain string "gma_mediation_inmobi": confirmed
- ad_constants.dart holds production App ID and all four unit IDs (no empty strings): confirmed
- AndroidManifest.xml APPLICATION_ID = ca-app-pub-4227443066128564~7081667253: confirmed
- game_session_notifier.dart contains refillHints() method: confirmed
- game_session_notifier.dart has zero ad imports: confirmed
- All 3 HINT-04 tests GREEN: confirmed
- Task commits exist: ff1c2d8, b83db97, f03e878: confirmed
