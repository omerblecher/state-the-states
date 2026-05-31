---
phase: 01-foundation
plan: "04"
subsystem: app-shell-coppa
tags: [coppa, ads-stub, audio, go-router, riverpod, app-shell, build-verification]
dependency_graph:
  requires:
    - plan 01-01 (ads_initializer, AndroidManifest, pubspec, audio assets)
    - plan 01-03 (MapScreen — the /play route target)
  provides:
    - AdService interface + StubAdService + adServiceProvider (walled garden)
    - AudioService interface (+playAnthem/stopAnthem) + StubAudioService + RealAudioService + provider
    - Runnable app — main.dart (COPPA init + ProviderScope), app.dart (GoRouter), HomeScreen
    - COPPA-verified debug APK (no AD_ID, no Firebase, App ID correct)
  affects:
    - Phase 2+ (game session, modes build on this app shell)
    - Phase 4 (HomeScreen placeholder replaced with mode-card grid)
    - v2 (real AdMob service replaces StubAdService)
tech_stack:
  added: []
  patterns:
    - Flags ad walled garden (StubAdService-only provider; no AdMob path)
    - Flags audio stub/real split + ProviderScope override in main.dart
    - just_audio three-player RealAudioService (correct/error/anthem, LoopMode.one)
    - GoRouter file-scope router + MaterialApp.router
    - COPPA build verification via aapt dump badging
key_files:
  created:
    - lib/core/ads/ad_service.dart
    - lib/core/ads/stub_ad_service.dart
    - lib/core/ads/ad_service_provider.dart
    - lib/core/ads/ad_load_state.dart
    - lib/core/ads/ad_constants.dart
    - lib/core/audio/audio_service.dart
    - lib/core/audio/stub_audio_service.dart
    - lib/core/audio/real_audio_service.dart
    - lib/core/audio/audio_service_provider.dart
    - lib/app.dart
    - lib/features/home/home_screen.dart
  modified:
    - lib/main.dart (placeholder → full COPPA entry point)
    - android/app/src/main/AndroidManifest.xml (strip Privacy-Sandbox AdServices perms)
    - android/app/build.gradle.kts (pin minSdk = 24)
decisions:
  - "COMP-03 walled garden: adServiceProvider returns ONLY const StubAdService(); no AdMob import, no preloadAll"
  - "COMP-02 extended: beyond legacy com.google...AD_ID, also strip ACCESS_ADSERVICES_AD_ID/ATTRIBUTION/TOPICS that google_mobile_ads 8.x transitively merges"
  - "minSdk: locked value 21 is unachievable — google_mobile_ads 8.0 requires 24, Flutter 3.44 floors at 23; pinned to 24 via a val so the gradle migration cannot silently rewrite it"
  - "l10n delegates omitted (no ARB files generated yet); app.dart kept minimal (no AppStateObserver/gameSessionProvider — Phase 2+)"
  - "audioServiceProvider defaults to StubAudioService; RealAudioService injected via ProviderScope override in main.dart"
metrics:
  duration_minutes: 30
  completed_date: "2026-05-31T06:45:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 11
  files_modified: 3
requirements_satisfied: [COMP-01, COMP-02, COMP-03, COMP-04, SESS-05]
execution_note: "Executed inline by the orchestrator (consistent with 01-03 after the subagent dispatch denial). Atomic per-task commits, blocking COPPA build verification run live."
---

# Phase 1 Plan 4: App Shell + COPPA Walled Garden Summary

**One-liner:** The runnable, COPPA-verified app shell — a stub-only ad walled garden (`adServiceProvider` → `StubAdService`, no AdMob path), the full audio service split (interface + stub + `just_audio` `RealAudioService` with anthem loop), and `main.dart`/`app.dart`/`HomeScreen` wiring COPPA init + GoRouter — proven by a debug APK build with no AD_ID permission, no Firebase, and App ID `com.otis.brooke.state.the.state`.

## What Was Built

1. **Ads walled garden (`lib/core/ads/`)** — `AdService` interface, `StubAdService` (no-op, `SizedBox.shrink()`/`false`), `AdLoadState` sealed class (verbatim from Flags); `ad_constants.dart` with empty unit IDs + `kAppLovinEnabled=false`; `ad_service_provider.dart` returning ONLY `const StubAdService()` — no `google_mobile_ads`/AdMob import, no `preloadAll`. This is the compile-time COMP-03 walled garden.

2. **Audio service layer (`lib/core/audio/`)** — `AudioService` interface (Flags methods + new `playAnthem`/`stopAnthem`), `StubAudioService` (7 no-ops), `RealAudioService` (three `just_audio` players: correct/error + a looped `_anthemPlayer` from `assets/audio/anthem_placeholder.wav`; `dispose()` disposes all three), and a provider defaulting to `StubAudioService`.

3. **App shell** — `main.dart` (`WidgetsFlutterBinding.ensureInitialized()` → `await initializeAds()` → `runApp(ProviderScope(overrides: [audioServiceProvider → RealAudioService], child: App()))`); `app.dart` (file-scope `GoRouter`: `/`→HomeScreen, `/play`→MapScreen; `MaterialApp.router`); `HomeScreen` (placeholder menu, Play button → `/play`, zero ad-layer import).

4. **Blocking COPPA build verification** — `flutter build apk --debug` succeeds; `aapt dump badging` confirms package `com.otis.brooke.state.the.state` and **no AD_ID-family permission**; `grep core/ads lib/features/` empty; `grep firebase pubspec.lock` empty.

## Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Ads walled garden | `3e4c061` | lib/core/ads/* |
| 2 | Audio service layer | `47d44f1` | lib/core/audio/* |
| 3 | App shell + COPPA build verification | `8581908` | main.dart, app.dart, home_screen.dart, AndroidManifest.xml, build.gradle.kts |

## Deviations from Plan

**1. [Rule 2 — Critical] COMP-02 extended to strip Privacy-Sandbox AdServices permissions**
- **Found during:** Task 3 blocking build verification.
- **Issue:** 01-01 blocked the legacy `com.google.android.gms.permission.AD_ID` (correctly absent). But `google_mobile_ads` 8.x transitively manifest-merges three Android Privacy-Sandbox permissions — `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_TOPICS`. The first grants advertising-ID access via the new AdServices API — the same COPPA concern in modern form — so the `grep AD_ID` gate (correctly) failed on the first build.
- **Fix:** Added `tools:node="remove"` for all three AdServices permissions in AndroidManifest.xml. Rebuilt; the merged APK now has zero AD_ID-family permissions. Appropriate for a fully-offline, no-real-ads, child-directed app.
- **Files modified:** `android/app/src/main/AndroidManifest.xml`

**2. [Rule 2 — Critical] minSdk 21 (locked) is unachievable; pinned to 24**
- **Found during:** Task 3 build.
- **Issue:** CLAUDE.md locked `minSdk 21` (just_audio 21+). But (a) Flutter 3.44 (also locked) enforces a hard floor of 23 via `DebugMinSdkCheck`, and (b) `google_mobile_ads` 8.0.0 declares `minSdkVersion 24`, so the manifest merge requires ≥24. minSdk 21 and 23 both fail. The two locked constraints are mutually inconsistent with the minSdk-21 note. Additionally, Flutter's `flutter build` gradle migration silently rewrites a literal `minSdk = 21` to `flutter.minSdkVersion` (24), masking the conflict.
- **Fix:** Pinned `minSdk = 24` (the lowest achievable for the locked dependency set) via a `val appMinSdk = 24` indirection so the gradle migration cannot silently rewrite it, with an inline comment documenting the cause. Device-reach impact: drops API 21–23 (Android 5.0–6.0), which were never actually shippable with google_mobile_ads 8.0 anyway.
- **Files modified:** `android/app/build.gradle.kts`
- **FLAG FOR USER:** The CLAUDE.md "minSdk 21" / "just_audio + minSdk 21 Compatible" notes are stale given the google_mobile_ads 8.0 + Flutter 3.44 floor of 24. Consider updating CLAUDE.md to record minSdk 24.

**3. [Rule 1 — Adaptation] Inline orchestrator execution; l10n omitted; app.dart simplified**
- The plan was executed inline (see execution_note). l10n delegates were omitted because no ARB files are generated yet (the plan permits "omit if not generated"). app.dart drops the Flags `AppStateObserver`/`gameSessionProvider` (Phase 2+), as the plan directs.

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `StubAdService` is the only wired ad service | `lib/core/ads/ad_service_provider.dart` | COMP-03 walled garden; real AdMob is v2. |
| Silent `anthem_placeholder.wav` loop | `lib/core/audio/real_audio_service.dart` | Real rights-clean anthem render is Phase 5 (D-05). |
| Placeholder `HomeScreen` | `lib/features/home/home_screen.dart` | Full mode-card grid is Phase 4. |
| AdMob test App ID in manifest | `AndroidManifest.xml` (from 01-01) | Replaced with production App ID before Play Store submission. |

## Threat Flags

- T-04-01 (COPPA-bypass via feature→ad import): `grep core/ads lib/features/` empty; provider returns only StubAdService — MITIGATED
- T-04-02 (AD_ID surviving manifest merge): legacy AD_ID + all three AdServices permissions stripped; verified absent on built APK — MITIGATED (strengthened beyond plan)
- T-04-03 (player leak): `dispose()` disposes all three players; init guarded — MITIGATED
- T-04-04 (Firebase reintroduced): `grep firebase pubspec.lock` empty at build — MITIGATED
- T-04-SC (google_mobile_ads compiled in): only the stub is wired; no real ad requests — ACCEPTED

## Self-Check: PASSED

- `flutter analyze`: No issues found
- `flutter test`: 10 passed (model + service)
- `flutter build apk --debug`: Built app-debug.apk
- `aapt dump badging | grep AD_ID`: empty (package `com.otis.brooke.state.the.state`)
- `grep -r core/ads lib/features/`: empty
- `grep firebase pubspec.lock`: empty
- `grep -c "const StubAdService()" lib/core/ads/ad_service_provider.dart`: 1
- `grep playAnthem lib/core/audio/audio_service.dart` and `anthem_placeholder.wav` in real_audio_service.dart: present
