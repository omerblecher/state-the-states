---
phase: 01-foundation
verified: 2026-05-31T10:30:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Launch the debug APK on a device or emulator and confirm the app reaches the HomeScreen without crashing"
    expected: "App starts, COPPA init runs, GoRouter navigates to HomeScreen, no red-screen exceptions"
    why_human: "flutter build apk --debug succeeds and flutter analyze is clean, but actual runtime startup (WidgetsFlutterBinding + ProviderScope + RealAudioService.init + anthem_placeholder.wav playback) can only be confirmed on a running device"
  - test: "Tap Play on HomeScreen, verify the MapScreen loads (blank canvas with CircularProgressIndicator then blank CustomPaint)"
    expected: "GoRouter pushes /play, stateDataProvider resolves, MapScreen renders without error, no exception thrown"
    why_human: "End-to-end compute-isolate → provider → painter wiring is proven by flutter test but interactive navigation on a real device may expose platform-level issues"
  - test: "Confirm the Alaska and Hawaii inset positions look correct visually — AK lower-left, HI lower-center, no antimeridian smear"
    expected: "AK renders as a recognizable Alaska shape bottom-left of the CONUS map; HI renders bottom-center; neither shows a horizontal stripe across the canvas"
    why_human: "test_inset_positions and test_alaska_validity prove the coordinates and shapely validity programmatically, but the optional PNG render was not produced; a human visual check is the only way to confirm the rendered appearance is correct"
---

# Phase 1: Foundation Verification Report

**Phase Goal:** The project has a valid, COPPA-compliant skeleton and a build-time pipeline that produces correct usa_states_paths.json — the single prerequisite every other phase depends on.
**Verified:** 2026-05-31T10:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running `python scripts/generate_states.py` produces `assets/map/usa_states_paths.json` with 51 records (50 placeable + DC non-placeable); Alaska passes shapely.validation.is_valid() after antimeridian split + reprojection | VERIFIED | `python -m pytest scripts/test_pipeline.py -q` → 5 passed (including test_state_count and test_alaska_validity); JSON confirmed: `51 50` via python -c query; Alaska validity gate present in generate_states.py line 369 |
| 2 | Alaska and Hawaii path coordinates are pre-transformed into final inset canvas space (AK bottom-left, HI bottom-center), not geographic latitudes | VERIFIED | AK centroid (151.85, 524.04) confirmed inside insetFrame `{x:0, y:462.38, w:250, h:134.24}`; HI centroid (381.36, 590.99) confirmed inside insetFrame `{x:255, y:533.88, w:130, h:61.24}`; test_inset_positions green; test_alaska_validity confirms shapely is_valid() |
| 3 | The Flutter app builds with google_mobile_ads declared but StubAdService wired; zero ad imports reachable from lib/features/; aapt dump badging shows AD_ID permission absent | VERIFIED | `flutter build apk --debug` produced 161 MB app-debug.apk; `aapt dump badging` output: package=`com.otis.brooke.state.the.state`, zero AD_ID / ACCESS_ADSERVICES_AD_ID / ATTRIBUTION / TOPICS permissions listed; `grep -rn "core/ads" lib/features/` → empty; `ad_service_provider.dart` wires only `const StubAdService()` |
| 4 | No firebase_* package in pubspec.yaml or pubspec.lock; LICENSES documents anthem provenance (source composition, rendering tool, soundfont) | VERIFIED | `grep -ri firebase pubspec.yaml pubspec.lock` → empty (exit 1 = no matches); LICENSES contains "Star-Spangled Banner", "Public domain", "MuseScore", "MS Basic.sf3", "MIT"; FluidR3 GM not named |
| 5 | StateDataService loads/parses usa_states_paths.json in a compute isolate; a blank CustomPaint MapScreen renders without error, confirming end-to-end wiring | VERIFIED | `flutter test` → 10 passed (8 model tests + 2 service tests); state_data_service.dart uses `compute(_decodeJson, jsonString)` with `rootBundle.loadString('assets/map/usa_states_paths.json')`; `_decodeJson` reads `data['states']`; map_screen.dart watches `stateDataProvider` and builds `CustomPaint(painter: UsaMapPainter(...))`; `flutter analyze` → No issues found |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pubspec.yaml` | Locked dependency set (no firebase), bundled asset declarations, name: state_states | VERIFIED | Contains google_mobile_ads ^8.0.0, flutter_riverpod ^3.3.1, just_audio ^0.10.5, path_drawing ^1.0.1; assets/map/ and assets/audio/ declared; name: state_states |
| `android/app/src/main/AndroidManifest.xml` | AD_ID tools:node=remove block + App ID + tools namespace | VERIFIED | xmlns:tools declared; 4x tools:node="remove" blocks: AD_ID, ACCESS_ADSERVICES_AD_ID, ATTRIBUTION, TOPICS; tools:remove="true" (wrong form) absent; app label "State the States" |
| `android/app/build.gradle.kts` | applicationId com.otis.brooke.state.the.state, minSdk | VERIFIED | applicationId = "com.otis.brooke.state.the.state" (line 31); namespace = same; minSdk pinned to 24 via val appMinSdk = 24 (deviation from plan's minSdk 21 — documented in SUMMARY, see anti-patterns section) |
| `lib/core/ads/ads_initializer.dart` | COPPA child-directed config before MobileAds.initialize() | VERIFIED | updateRequestConfiguration(tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes, maxAdContentRating: MaxAdContentRating.g) called at line 19, before await MobileAds.instance.initialize() at line 27 |
| `LICENSES` | Anthem provenance record | VERIFIED | Contains: "Star-Spangled Banner Instrumental", "Public domain (Francis Scott Key, 1814)", "MuseScore [version TBD in Phase 5]", "MS Basic.sf3 (MuseScore General / MuseScore Basic), MIT License", full MIT license text with Frank Wen / Michael Cowgill / S. Christian Collins attribution |
| `assets/audio/anthem_placeholder.wav` | Silent placeholder anthem so app builds | VERIFIED | 88,278 bytes; valid WAV (non-zero size) |
| `assets/audio/correct.wav` | Bundled SFX | VERIFIED | Exists |
| `assets/audio/error.wav` | Bundled SFX | VERIFIED | Exists |
| `scripts/generate_states.py` | Build-time Albers + antimeridian + inset-baking pipeline | VERIFIED | Contains EPSG:5070, EPSG:3338, HI_PROJ4 aea string, antimeridian.fix_shape call; pipeline produces 51-record JSON |
| `scripts/test_pipeline.py` | Pipeline validation suite | VERIFIED | Defines all 5 named tests (test_state_count, test_alaska_validity, test_inset_positions, test_no_dc_placeable, test_viewbox_derived); all 5 pass |
| `assets/map/usa_states_paths.json` | Bundled pre-transformed state path data | VERIFIED | 765 KB; top-level key "states"; 51 records / 50 placeable; viewBox {width:1000, height:628}; AK/HI insetFrames present |
| `scripts/requirements.txt` | Python deps including antimeridian | VERIFIED | antimeridian>=0.4, geopandas>=1.0, shapely>=2.0, pyproj>=3.6.0, pytest>=7.0 |
| `lib/core/models/state_data.dart` | StateData value object, BoundingBox, InsetGroup enum | VERIFIED | class StateData present; enum InsetGroup { alaska, hawaii }; postal field (not isoCode); isDegenerate absent; parseSvgPathData called in fromJson |
| `lib/core/data/state_data_service.dart` | Compute-isolate JSON loader + stateDataProvider | VERIFIED | FutureProvider<List<StateData>>; rootBundle.loadString('assets/map/usa_states_paths.json'); compute(_decodeJson); data['states'] key (not 'countries'); loadCountryNames absent |
| `lib/features/map/map_screen.dart` | Blank CustomPaint end-to-end proof widget | VERIFIED | ConsumerWidget; ref.watch(stateDataProvider); AsyncValue.when with loading/error/data; data branch builds CustomPaint(painter: UsaMapPainter(states: states)) |
| `lib/core/ads/stub_ad_service.dart` | No-op walled-garden ad implementation | VERIFIED | getBannerWidget returns const SizedBox.shrink(); showRewardedAd returns false |
| `lib/core/ads/ad_service_provider.dart` | Provider wiring StubAdService (not AdMob) | VERIFIED | Returns const StubAdService(); no google_mobile_ads import; no admob_ad_service import; no preloadAll |
| `lib/main.dart` | App entrypoint: COPPA init + ProviderScope + RealAudioService override | VERIFIED | await initializeAds() before runApp; ProviderScope with audioServiceProvider override |
| `lib/app.dart` | GoRouter (/ home, /play map) + MaterialApp.router | VERIFIED | GoRouter routes / → HomeScreen, /play → MapScreen; MaterialApp.router |
| `lib/core/audio/audio_service.dart` | AudioService interface incl playAnthem/stopAnthem | VERIFIED | playAnthem() and stopAnthem() declared (lines 8, 11) |
| `lib/core/audio/real_audio_service.dart` | just_audio three-player impl with anthem loop | VERIFIED | _anthemPlayer set from assets/audio/anthem_placeholder.wav; LoopMode.one applied |
| `test/core/data/state_data_service_test.dart` | Provider resolves 51 records / 50 placeable | VERIFIED | 2 tests pass; assertions for 51 records, 50 placeable, DC non-placeable confirmed |
| `test/core/models/state_data_test.dart` | Model parsing + Alaska centroid inset check | VERIFIED | 8 tests pass; testAlaskaCentroidInset asserts real AK centroid inside alaska insetFrame |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| AndroidManifest.xml | com.google.android.gms.permission.AD_ID | tools:node="remove" | WIRED | Confirmed at line 6-7; tools:remove="true" (wrong form) absent |
| AndroidManifest.xml | android.permission.ACCESS_ADSERVICES_AD_ID | tools:node="remove" | WIRED | Three AdServices permissions additionally stripped (plan deviation documented in SUMMARY-04) |
| ads_initializer.dart | MobileAds.instance.initialize() | updateRequestConfiguration called first | WIRED | updateRequestConfiguration line 19, initialize() line 27; correct order |
| ad_service_provider.dart | StubAdService | Provider<AdService> returns const StubAdService() | WIRED | Line 9: `Provider<AdService>((ref) => const StubAdService())` |
| main.dart | initializeAds() | awaited before runApp | WIRED | await initializeAds() before runApp(ProviderScope(...)) |
| app.dart | MapScreen / HomeScreen | GoRouter routes / and /play | WIRED | Both routes confirmed |
| state_data_service.dart | assets/map/usa_states_paths.json | rootBundle.loadString + compute(_decodeJson) | WIRED | Line 10: rootBundle.loadString('assets/map/usa_states_paths.json'); line 14: compute(_decodeJson, jsonString) |
| state_data_service.dart | data['states'] | _decodeJson reads 'states' key (not 'countries') | WIRED | Line 30: `(data['states'] as List)` |
| map_screen.dart | stateDataProvider | ref.watch + AsyncValue.when | WIRED | Line 19: ref.watch(stateDataProvider); line 26: data branch builds CustomPaint |
| generate_states.py | antimeridian.fix_shape | Alaska geometry fixed before to_crs | WIRED | Line 363: ak_gdf["geometry"].apply(fix_antimeridian) before line 364: to_crs("EPSG:3338") |
| generate_states.py | usa_states_paths.json | json.dump with 'states' key | WIRED | JSON top-level key "states" confirmed in output (51-record file) |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `lib/features/map/map_screen.dart` | mapData (AsyncValue<List<StateData>>) | stateDataProvider → StateDataService.loadMapData() → rootBundle.loadString('assets/map/usa_states_paths.json') → compute(_decodeJson) | Yes — 51 records from bundled JSON asset | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| JSON contains 51 records / 50 placeable | `python -c "import json;d=json.load(...);print(len(d['states']), sum(...))"` | `51 50` | PASS |
| All 5 Python pipeline tests pass | `python -m pytest scripts/test_pipeline.py -q` | `5 passed, 1 warning` (benign FixWindingWarning) | PASS |
| All 10 Flutter unit tests pass | `flutter test` | `10 passed` | PASS |
| Flutter static analysis clean | `flutter analyze` | `No issues found! (ran in 2.2s)` | PASS |
| No firebase in pubspec.lock | `grep -ri firebase pubspec.yaml pubspec.lock` | empty (exit 1) | PASS |
| No ad imports from lib/features/ | `grep -rn "core/ads" lib/features/` | empty (exit 1) | PASS |
| AD_ID permission absent from built APK | `aapt dump badging app-debug.apk \| grep -E "AD_ID\|uses-permission"` | package: com.otis.brooke.state.the.state; INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, FOREGROUND_SERVICE only — zero AD_ID-family permissions | PASS |
| App ID correct in built APK | `aapt dump badging app-debug.apk \| grep "package:"` | `com.otis.brooke.state.the.state` | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DATA-01 | 01-02, 01-03 | Build-time pipeline converts NE admin-1 into bundled usa_states_paths.json with path data, centroids, AK/HI inset transforms | SATISFIED | generate_states.py produces 51-record JSON; stateDataProvider resolves 51 records / 50 placeable |
| DATA-02 | 01-02, 01-03 | Alaska antimeridian split + shapely validity; no horizontal smear | SATISFIED | fix_shape() before to_crs('EPSG:3338'); is_valid() gate in pipeline; test_alaska_validity passes; AK centroid in inset frame |
| COMP-01 | 01-01, 01-04 | No Firebase and no persistent device identifiers | SATISFIED | grep firebase pubspec.lock → empty; no firebase_* in pubspec.yaml |
| COMP-02 | 01-01, 01-04 | AD_ID permission blocked from first commit | SATISFIED | tools:node="remove" on all 4 AD_ID-family permissions; aapt confirms zero AD_ID permissions in built APK |
| COMP-03 | 01-04 | Ad layer stubbed; GameSessionNotifier has zero ad imports | SATISFIED | adServiceProvider returns const StubAdService() only; grep -rn "core/ads" lib/features/ → empty |
| COMP-04 | 01-01, 01-04 | App builds under com.otis.brooke.state.the.state, G/PG content rating | SATISFIED | applicationId = "com.otis.brooke.state.the.state"; tagForChildDirectedTreatment.yes + MaxAdContentRating.g in ads_initializer.dart; aapt confirms correct package |
| SESS-05 | 01-01, 01-04 | Fully offline — all assets and data bundled | SATISFIED | All audio WAVs bundled under assets/audio/; usa_states_paths.json bundled under assets/map/; flutter build apk --debug succeeds offline; no network dependencies in core |

---

### Probe Execution

No probe-*.sh scripts declared or conventionally located. Behavioral spot-checks in section above serve as the executable verification evidence.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `LICENSES` | 10 | `MuseScore [version TBD in Phase 5]` — TBD marker present | INFO | Explicitly references Phase 5 follow-up work. The marker is intentional per D-05 (defer anthem render to Phase 5; document provenance now). Not a BLOCKER: the render-date field is an honest placeholder for a future action, the soundfont and composition provenance are fully documented now. No auditable work is missing. |
| `android/app/build.gradle.kts` | 16 | `minSdk = 24` instead of plan's 21 | INFO | Documented deviation (01-04-SUMMARY deviation #2). CLAUDE.md minSdk 21 note is stale given google_mobile_ads 8.0 + Flutter 3.44 floor. Deviation is technically correct and self-documented with inline comments. SUMMARY recommends updating CLAUDE.md. |

No TBD/FIXME/XXX markers exist in any production source file (Dart, Python, manifest). The single TBD in LICENSES references "Phase 5" — a named follow-up deliverable, not an unresolved debt item. No BLOCKER anti-patterns found.

---

### Human Verification Required

#### 1. App Runtime Startup

**Test:** Install app-debug.apk on an Android device or emulator (API 24+). Launch the app. Observe the startup sequence.
**Expected:** App starts without crashing; initializeAds() COPPA config runs; ProviderScope with RealAudioService override initializes; HomeScreen displays with a Play button; no red error screen; no console exceptions.
**Why human:** flutter build succeeds and flutter analyze is clean, but actual runtime platform plugin initialization (google_mobile_ads, just_audio native layers, ProviderScope override resolution) can only be confirmed on a running device.

#### 2. MapScreen Blank Canvas Navigation

**Test:** From HomeScreen, tap Play to navigate to /play (MapScreen). Observe the loading and data states.
**Expected:** CircularProgressIndicator appears briefly while stateDataProvider resolves; then a blank white/gray canvas renders (UsaMapPainter.paint is empty by design for Phase 1); no exception or error screen; back-navigation returns to HomeScreen.
**Why human:** flutter test confirms the provider resolves 51 records and the widget tree builds, but interactive navigation and the platform-level rootBundle asset loading can only be fully confirmed on a running device.

#### 3. Alaska/Hawaii Visual Inset Check (Optional per plan)

**Test:** Inspect the optional PNG render of the pipeline output, or build a Phase 3 preview. Confirm Alaska is bottom-left of the CONUS map and Hawaii is bottom-center.
**Expected:** Alaska renders as a recognizable Alaska-shaped polygon in the lower-left inset area; Hawaii renders as the island chain in the lower-center inset; neither state shows a horizontal stripe or antimeridian smear.
**Why human:** test_inset_positions proves the centroid coordinates are inside the declared inset frames, and test_alaska_validity proves shapely is_valid(), but the rendered visual appearance is the definitive check. The pipeline does not produce a PNG render (documented in 01-02-SUMMARY as a known stub).

---

### Gaps Summary

No automated gaps found. All 5 success criteria are VERIFIED by codebase evidence and live test execution. The 3 human verification items are runtime-behavior checks that automated grep and flutter test cannot replace — they do not indicate incomplete implementation, only that device-level confirmation is pending.

---

_Verified: 2026-05-31T10:30:00Z_
_Verifier: Claude (gsd-verifier)_
