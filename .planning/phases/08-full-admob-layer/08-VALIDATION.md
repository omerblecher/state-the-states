---
phase: 8
slug: full-admob-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-03
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | none (Flutter default) |
| **Quick run command** | `flutter test test/core/ads/ test/features/game/game_session_notifier_test.dart -x` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/core/ads/ test/features/game/game_session_notifier_test.dart -x`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-W0-01 | 00 | 0 | AD-01, AD-02 | — | COPPA flags before initialize() | unit | `flutter test test/core/ads/ads_initializer_test.dart` | ❌ W0 | ⬜ pending |
| 08-W0-02 | 00 | 0 | AD-03, AD-04, AD-05, HINT-05 | — | getBannerWidget/showInterstitial/showAppOpen/showRewarded no-ops correctly | unit | `flutter test test/core/ads/real_ad_service_test.dart` | ❌ W0 | ⬜ pending |
| 08-W0-03 | 00 | 0 | HINT-04 | — | refillHints() sets hintsRemaining to 2 | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ✅ | ⬜ pending |
| 08-01 | 01 | 1 | AD-01, AD-02 | T-COPPA-01 | RequestConfiguration + ironSource/Unity flags set before initialize() | unit | `flutter test test/core/ads/ads_initializer_test.dart` | ❌ W0 | ⬜ pending |
| 08-02 | 02 | 2 | AD-03, AD-04, AD-05, HINT-05 | T-COPPA-02 | RealAdService encapsulates all ad types; no SDK imports leak to notifier | unit | `flutter test test/core/ads/real_ad_service_test.dart` | ❌ W0 | ⬜ pending |
| 08-03 | 03 | 3 | HINT-03, HINT-04, HINT-05 | — | Dialog shown at hintsRemaining==0; reward in onUserEarnedReward only | widget | `flutter test test/features/map/map_screen_test.dart` | ✅ | ⬜ pending |
| 08-04 | 04 | 4 | AD-04 | — | Interstitial fires once in CompletionScreen.initState with delay | widget | `flutter test test/features/map/completion_screen_test.dart` | ✅ | ⬜ pending |
| 08-05 | 05 | 5 | AD-03 | — | Banner visible at bottom of HomeScreen when loaded | widget | `flutter test test/features/home/home_screen_test.dart` | ✅ | ⬜ pending |
| 08-06 | — | 6 | AD-06 | T-AD_ID | AD_ID absent after mediation AAR merge | manual/build | `aapt.exe dump badging app-release.apk` | Manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/core/ads/ads_initializer_test.dart` — stubs for AD-01, AD-02 (mock MobileAds, GmaMediationIronsource, GmaMediationUnity)
- [ ] `test/core/ads/real_ad_service_test.dart` — stubs for AD-03, AD-04, AD-05, HINT-05 (mock SDK calls, StubAdService as reference for no-op behavior)
- [ ] Extend `test/features/game/game_session_notifier_test.dart` — HINT-04 `refillHints()` assertion

*Existing files (`game_session_notifier_test.dart`, `map_screen_test.dart`, `completion_screen_test.dart`, `home_screen_test.dart`) are extended in-place; no new test files needed for widget tests.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AD_ID permission absent after release build with all mediation AARs | AD-06 | Requires release APK build + aapt tool | `cd build\app\outputs\flutter-apk` then `aapt.exe dump badging app-release.apk \| findstr /i "AD_ID AdServices ADVERTISING"` — expected: no output |
| App Open ad suppressed during active gameplay | AD-05 | Requires real ad SDK and device | Background and foreground the app while a game is in progress; no App Open ad should appear |
| Production AdMob IDs functional | AD-01–05 | Requires real AdMob account + real device/test device | Run app on physical or test device registered in AdMob console |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
