---
phase: 01-foundation
plan: "01"
subsystem: project-scaffold
tags: [coppa, android, pubspec, audio, licenses, flutter-scaffold]
dependency_graph:
  requires: []
  provides:
    - Flutter project scaffold (pubspec.yaml, lockfile, Android/iOS/lib structure)
    - COPPA-compliant AndroidManifest.xml (AD_ID blocked, App ID set)
    - ads_initializer.dart (child-directed config before MobileAds.initialize)
    - Bundled audio assets (anthem_placeholder.wav, correct.wav, error.wav)
    - LICENSES file with anthem provenance record
  affects:
    - All subsequent plans (build on this scaffold)
    - plan 01-04 (replaces lib/main.dart placeholder with full entry point)
    - Phase 5 (renders real anthem WAV, fills in LICENSES render details)
tech_stack:
  added:
    - flutter_riverpod ^3.3.1
    - riverpod_annotation ^4.0.2
    - go_router ^17.2.3
    - flutter_svg ^2.3.0
    - path_drawing ^1.0.1
    - shared_preferences ^2.5.5
    - just_audio ^0.10.5
    - google_mobile_ads ^8.0.0 (stub-only v1)
    - intl ^0.20.2
    - url_launcher ^6.3.2
    - share_plus ^13.1.0 (v2 scope, declared now)
    - build_runner ^2.15.0
    - riverpod_generator ^4.0.3
    - mocktail ^1.0.5
    - flutter_lints ^6.0.0
    - flutter_launcher_icons ^0.14.4
  patterns:
    - Flags Around the World pubspec.yaml as baseline + CLAUDE.md deltas applied
    - COPPA AndroidManifest: tools:node=remove on AD_ID (verbatim Flags pattern)
    - COPPA init sequence: updateRequestConfiguration before MobileAds.initialize
key_files:
  created:
    - pubspec.yaml
    - pubspec.lock
    - .gitignore
    - analysis_options.yaml
    - lib/main.dart (placeholder — replaced in 01-04)
    - android/app/src/main/AndroidManifest.xml
    - android/app/build.gradle.kts
    - lib/core/ads/ads_initializer.dart
    - assets/audio/anthem_placeholder.wav
    - assets/audio/correct.wav
    - assets/audio/error.wav
    - LICENSES
  modified: []
decisions:
  - "D-06 confirmed: MS Basic.sf3 (MIT) chosen as anthem soundfont; documented in LICENSES; FluidR3 GM excluded (openness restriction)"
  - "ads_initializer.dart is v1 stub: updateRequestConfiguration + initialize only; no mediation SDK calls (gma_mediation_* is v2 scope)"
  - "build.gradle.kts uses Kotlin DSL (not Groovy); applicationId set to com.otis.brooke.state.the.state as required by COMP-04"
metrics:
  duration_minutes: 4
  completed_date: "2026-05-31T05:33:30Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 130+
  files_modified: 3
requirements_satisfied: [COMP-01, COMP-02, COMP-04, SESS-05]
---

# Phase 1 Plan 1: COPPA Flutter Scaffold Summary

**One-liner:** Firebase-free Flutter project scaffold (pubspec locked to Flags+deltas) with AD_ID permission blocked via `tools:node="remove"`, App ID `com.otis.brooke.state.the.state`, COPPA-correct ads initializer, bundled audio assets, and MS Basic.sf3 MIT-licensed anthem provenance record.

## What Was Built

A fully-compliant project skeleton that every subsequent Phase 1 plan builds on:

1. **Flutter project scaffold** — `flutter create` with `org=com.otis.brooke`, `name=state_states`. All 130 scaffold files committed, including Android, iOS, Linux, macOS, Windows, and Web platforms.

2. **Locked pubspec.yaml** — Flags Around the World lockfile as baseline with all CLAUDE.md deltas applied: Dart `>=3.10.0`, Flutter `>=3.44.0`, upgraded `share_plus ^13.1.0`, `url_launcher ^6.3.2`, `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.4`. Zero Firebase packages. Zero `gma_mediation_*` packages (v2 scope). `google_mobile_ads ^8.0.0` declared stub-only. Assets dirs `assets/map/` and `assets/audio/` declared under `flutter:`.

3. **COPPA AndroidManifest.xml** — Added `xmlns:tools` namespace. AD_ID permission blocked with `tools:node="remove"` (the verified-correct form, not `tools:remove="true"`). App label `"State the States"`. AdMob test App ID meta-data. Added `https` URL intent for url_launcher compatibility.

4. **build.gradle.kts** — `applicationId = "com.otis.brooke.state.the.state"` (COMP-04). `minSdk = 21` (just_audio + Flags baseline). Kotlin DSL (the scaffolded form).

5. **ads_initializer.dart** — COPPA stub: calls `updateRequestConfiguration(tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes, maxAdContentRating: MaxAdContentRating.g)` FIRST, then `await MobileAds.instance.initialize()` LAST. No mediation SDK calls (v2 scope).

6. **Bundled audio assets** — `anthem_placeholder.wav`: 1-second silent mono WAV at 44100Hz (ffmpeg-generated valid playable asset; replaced in Phase 5). `correct.wav` and `error.wav`: ported from Flags Around the World sibling project.

7. **LICENSES file** — Documents anthem provenance per D-05/D-06: composition (public domain), rendering tool (MuseScore, TBD Phase 5), soundfont (MS Basic.sf3, MIT license with full Frank Wen / Michael Cowgill / S. Christian Collins attribution and full MIT license text). No `FluidR3 GM` named (openness restriction).

## Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Scaffold Flutter project + locked pubspec.yaml | `3a50212` | pubspec.yaml, pubspec.lock, .gitignore, lib/main.dart, android/ios/... |
| 2 | COPPA AndroidManifest, App ID, ads_initializer | `31aaaff` | AndroidManifest.xml, build.gradle.kts, lib/core/ads/ads_initializer.dart |
| 3 | Bundle audio assets + LICENSES provenance | `303b551` | LICENSES, assets/audio/anthem_placeholder.wav, correct.wav, error.wav |

## Deviations from Plan

### Auto-applied adjustments

**1. [Rule 1 - Adaptation] build.gradle.kts uses Kotlin DSL (not Groovy .gradle)**
- **Found during:** Task 2
- **Issue:** Plan references `android/app/build.gradle` (Groovy), but `flutter create` in Flutter 3.44 scaffolds `android/app/build.gradle.kts` (Kotlin DSL). The plan's acceptance criterion `grep -c "com.otis.brooke.state.the.state" android/app/build.gradle` targets the wrong filename.
- **Fix:** Modified `android/app/build.gradle.kts` with the correct Kotlin DSL syntax (`applicationId = "..."` not `applicationId "..."`). All functionality is equivalent.
- **Files modified:** `android/app/build.gradle.kts`

**2. [Rule 2 - Critical] AndroidManifest.xml did not have a `package=` attribute**
- **Found during:** Task 2
- **Issue:** Flutter 3.44 scaffolds the manifest without a `package=` attribute (the App ID is now solely in `build.gradle.kts`). The PATTERNS.md template shows `package="com.otis.brooke.state.the.state"` on the `<manifest>` element. This is correct — the modern Android Gradle Plugin approach puts `namespace` + `applicationId` in `build.gradle.kts` and removes `package=` from the manifest.
- **Fix:** Left manifest without `package=` attribute (correct modern approach). App ID authority is `build.gradle.kts` via `namespace` and `applicationId`.
- **Files modified:** none (adaptation to modern approach, no fix needed)

None — plan executed per spec with the above Kotlin DSL and modern manifest adaptations (cosmetic only; no behavioral deviation).

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| Placeholder `lib/main.dart` | `lib/main.dart` | A compilable placeholder with no app logic; plan 01-04 replaces it with the full entry point (ProviderScope, initializeAds, RealAudioService wiring). This is intentional per the plan spec. |
| Silent `anthem_placeholder.wav` | `assets/audio/anthem_placeholder.wav` | 1-second silent WAV. The real anthem is rendered in Phase 5 using MuseScore + MS Basic.sf3. Intentional per D-05. |
| AdMob test App ID | `AndroidManifest.xml` | `ca-app-pub-3940256099942544~3347511713` (Google's public test ID). Replaced with production App ID before Play Store submission. |

## Threat Flags

No new threat surface beyond what is documented in the plan's threat model. All T-01-01 through T-01-04 mitigations are applied:
- T-01-01 (AD_ID): `tools:node="remove"` in manifest — MITIGATED
- T-01-02 (Firebase): No firebase_* in pubspec — MITIGATED
- T-01-03 (MobileAds order): `updateRequestConfiguration` before `initialize()` — MITIGATED
- T-01-04 (Anthem DMCA): LICENSES file with PD composition + MIT soundfont — MITIGATED (placeholder)

## Self-Check: PASSED

Files verified:
- `pubspec.yaml`: FOUND
- `pubspec.lock`: FOUND
- `android/app/src/main/AndroidManifest.xml`: FOUND
- `android/app/build.gradle.kts`: FOUND
- `lib/core/ads/ads_initializer.dart`: FOUND
- `assets/audio/anthem_placeholder.wav`: FOUND (88278 bytes)
- `assets/audio/correct.wav`: FOUND
- `assets/audio/error.wav`: FOUND
- `LICENSES`: FOUND

Commits verified:
- `3a50212`: scaffold commit — FOUND
- `31aaaff`: COPPA commit — FOUND
- `303b551`: audio/LICENSES commit — FOUND
