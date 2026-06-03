---
phase: 08-full-admob-layer
plan: "00"
status: complete
completed: "2026-06-03"
---

# Plan 08-00: Pre-flight — AdMob IDs + RED Test Stubs

## What Was Built

Wave 0 pre-flight for Phase 8: collected all five production AdMob values from the
developer and created RED test stubs establishing the TDD baseline for Waves 1–3.

## Production AdMob Values (D-01, D-02)

**App ID:** `ca-app-pub-4227443066128564~7081667253`
**Package:** `com.otis.brooke.state.the.state`

| Ad Unit | ID |
|---------|-----|
| Banner | `ca-app-pub-4227443066128564/1019125702` |
| Interstitial | `ca-app-pub-4227443066128564/9220059672` |
| Rewarded | `ca-app-pub-4227443066128564/7906978004` |
| App Open | `ca-app-pub-4227443066128564/5312604258` |

These five values are consumed by Wave 1 tasks:
- `ad_constants.dart` — all four ad unit IDs + kAdMobAppId
- `AndroidManifest.xml` — App ID in APPLICATION_ID meta-data

## Test Stubs Created

### test/core/ads/ads_initializer_test.dart
- **AD-01** `updateRequestConfiguration` test — SKIPPED (requires SDK interaction mock)
- **AD-02** ironSource `setConsent(false)` + `setDoNotSell(true)` — RED (source assertion fails, calls absent until Wave 1)
- **AD-02** Unity `setGDPRConsent(false)` + `setCCPAConsent(false)` — RED (source assertion fails, calls absent until Wave 1)
- **AD-02** no `gma_mediation_inmobi` import — GREEN immediately (InMobi has no Dart COPPA API)

### test/core/ads/real_ad_service_test.dart
- **StubAdService interface parity** (AD-03, HINT-05 reference) — GREEN (2 tests passing)
- **RealAdService unit tests** (AD-03, AD-04, AD-05, HINT-05) — SKIPPED with `'real_ad_service.dart created in Wave 2'`

### test/features/game/game_session_notifier_test.dart
- **HINT-04** `refillHints() — HINT-04` group added — 3 tests RED (`NoSuchMethodError` confirmed)
  - `refillHints() resets hintsRemaining to 2 when in playing phase`
  - `refillHints() is a no-op when game is not in playing phase`
  - `refillHints() does not modify the score or hintPenalty`

## Key Decisions

- AD-02 tests written as source assertions (not SDK mocks) so they compile without mediation packages in pubspec — packages added in Wave 1
- HINT-04 tests use `(notifier as dynamic).refillHints()` for dynamic dispatch so the file compiles cleanly while yielding the expected `NoSuchMethodError` RED state

## Verification Results

```
flutter test test/core/ads/ — 3 passed (StubAdService + no-InMobi), 1 skipped (AD-01), 4 skipped (RealAdService), 2 failed RED (AD-02 ironSource + Unity)
flutter test test/features/game/game_session_notifier_test.dart — 3 HINT-04 tests RED with NoSuchMethodError; all pre-existing tests outside submitTyping group pass
```

## Self-Check: PASSED

- Five production values collected and recorded above
- Two new test files in test/core/ads/ — both compile
- Three HINT-04 RED tests added to game_session_notifier_test.dart
- All pre-existing tests (outside submitTyping group) still pass
- Wave 1 can proceed with known production IDs
