# Stack Research

**Domain:** Cross-platform Flutter educational map game (USA states, ages 8+, offline, COPPA/Families-compliant)
**Researched:** 2026-05-30 (v1) · updated 2026-06-02 (v2 — AdMob activation, screenshot sharing, Mode 5)
**Confidence:** HIGH — all versions verified against pub.dev; API patterns verified against Flags codebase and official Google Developers documentation

---

## Baseline: Flags Around the World lockfile

The `pubspec.yaml` at `C:\code\Claude\FlagsRoundTheWorld` is the authoritative lockfile.
Every recommendation below is either a direct carry-over or an explicit, reasoned delta.

```
Flags pubspec.yaml (environment):
  sdk: '>=3.7.0 <4.0.0'
  flutter: '>=3.32.0'
```

Flutter 3.44.0 (Dart 3.10) is current stable as of 2026-06-02.
The `>=3.32.0` lower-bound from Flags is compatible; raise the constraint to `>=3.44.0` for
State States to track the latest stable and pick up performance improvements to
`CustomPainter` and `InteractiveViewer`.

---

## v2 Stack Changes

The v1 `pubspec.yaml` is already correct. **One new package is needed for v2:**

| Package | v1 | v2 | Reason |
|---------|----|----|--------|
| `path_provider` | not present | `^2.1.5` | Required for screenshot-to-temp-file before `share_plus` sharing. `XFile.fromData()` works without it on most platforms, but writing to a temp file with a proper filename is the reliable Android path. |
| `gma_mediation_unity` | declared, not initialized | declared + initialized | See init sequence below. |
| `gma_mediation_ironsource` | declared, not initialized | declared + initialized | See init sequence below. |
| `gma_mediation_inmobi` | declared, not initialized | declared + initialized | No Dart-side COPPA call needed — adapter auto-forwards `tagForChildDirectedTreatment` from `RequestConfiguration`. |
| `gma_mediation_applovin` | declared, disabled | remains disabled | AppLovin SDK 13.0+ cannot be initialized in COPPA/child-directed apps. `kAppLovinEnabled = false` gate stays. Remove the package from pubspec only when AppLovin re-enters the Families Self-Certified Ads SDK Program. |

Add to `pubspec.yaml` dependencies:
```yaml
  path_provider: ^2.1.5
```

---

## Recommended Stack

### Core Technologies

| Technology | Flags Version | State States Version | Purpose | Why |
|------------|--------------|---------------------|---------|-----|
| Flutter SDK | `>=3.32.0` | `>=3.44.0` | Framework | Raises lower-bound to current stable (3.44.0 / Dart 3.10). No breaking changes for this stack; gains CustomPainter + InteractiveViewer improvements. |
| Dart SDK | `>=3.7.0 <4.0.0` | `>=3.10.0 <4.0.0` | Language | Matches Dart bundled with Flutter 3.44. |
| `flutter_riverpod` | `^3.3.1` | `^3.3.1` | State management | Riverpod 3.x with codegen is the Flags pattern. `AsyncNotifier` drives `GameSessionNotifier`; `FutureProvider` loads map data. No delta needed — 3.3.1 is current stable. |
| `riverpod_annotation` | `^4.0.2` | `^4.0.2` | Codegen annotations | Pairs with `riverpod_generator`. 4.0.2 is current stable (4.0.3-dev exists but is pre-release). |
| `go_router` | `^17.2.3` | `^17.2.3` | Navigation | Flags uses go_router with `onExit` back-button guard. 17.2.3 is current stable (flutter.dev publisher). No delta. |
| `flutter_svg` | `^2.3.0` | `^2.3.0` | SVG asset rendering | Used in Flags for flag assets. State States does NOT need runtime SVG parsing for the map (see pipeline below), but `flutter_svg` is still needed for any incidental SVG UI assets (welcome screen silhouette, icons). 2.3.0 is current stable (flutter.dev publisher). |
| `path_drawing` | `^1.0.1` | `^1.0.1` | SVG path string → dart:ui Path | The `parseSvgPathData()` function is called in `CountryData.fromJson` / `StateData.fromJson` at startup to convert the bundled JSON path strings into `dart:ui Path` objects. Unchanged; 1.0.1 is still the only stable release. |
| `shared_preferences` | `^2.5.5` | `^2.5.5` | Local persistence | Stores high scores, mode times, mute preference. No accounts, no cloud — COPPA requirement. 2.5.5 is current stable (flutter.dev publisher). |
| `just_audio` | `^0.10.5` | `^0.10.5` | Audio playback | Flags' `RealAudioService` uses `just_audio` with `setAsset()` / `stop()` / `seek()` / `play()` / `setVolume()` pattern. State States needs: (1) correct/error SFX (same pattern), (2) anthem loop on welcome screen with fade-out on transition. 0.10.5 is current stable. **Do not use `audioplayers`** — PROJECT.md explicitly supersedes that mention. |
| `intl` | `^0.20.2` | `^0.20.2` | i18n runtime + `flutter gen-l10n` | ARB-based UI strings. 0.20.2 is current stable (dart.dev publisher). |

### Ads Layer — v2 Activation

All four packages were declared in v1 `pubspec.yaml` but only `google_mobile_ads` had its
`initializeAds()` call completed. In v2 the mediation adapters are also initialized. The
packages remain at the same versions as Flags — no delta required.

| Library | Version | Purpose | COPPA Status |
|---------|---------|---------|-------------|
| `google_mobile_ads` | `^8.0.0` | AdMob banner / interstitial / rewarded / App Open | `tagForChildDirectedTreatment(yes)` + `maxAdContentRating(g)` set via `RequestConfiguration` BEFORE `initialize()`. Already done in `ads_initializer.dart`. |
| `gma_mediation_unity` | `^1.8.0` | Unity Ads mediation | Call `GmaMediationUnity.setGDPRConsent(false)` and `GmaMediationUnity.setCCPAConsent(false)` before `MobileAds.instance.initialize()`. COPPA forwarding (tagForChildDirectedTreatment) is automatic via `RequestConfiguration`. |
| `gma_mediation_ironsource` | `^2.4.1` | ironSource/LevelPlay mediation | Call `GmaMediationIronsource().setDoNotSell(true)` before `MobileAds.instance.initialize()`. COPPA value is auto-forwarded via `RequestConfiguration`. |
| `gma_mediation_inmobi` | `^2.1.0` | InMobi mediation | `GmaMediationInMobi` is an empty Dart class (no Dart-side COPPA call needed). The adapter reads `tagForChildDirectedTreatment` from `RequestConfiguration` and forwards it to the InMobi SDK natively. |
| `gma_mediation_applovin` | `^2.6.1` | AppLovin MAX mediation | **Disabled** (`kAppLovinEnabled = false`). AppLovin SDK 13.0+ refuses to initialize in apps classified as children's content under COPPA/Families Policy. Keep package declared but do not initialize until AppLovin re-enters Families Self-Certified Ads SDK Program. |

#### AdMob + Mediation COPPA Init Sequence

The correct order (already implemented in `lib/core/ads/ads_initializer.dart` in the Flags
codebase and partially in State States' stub initializer) is:

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gma_mediation_ironsource/gma_mediation_ironsource.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';

Future<void> initializeAds() async {
  // Step 1: AdMob child-directed flags — MUST precede initialize().
  // Do NOT set both tagForChildDirectedTreatment AND tagForUnderAgeOfConsent
  // to yes simultaneously — child-directed covers UCPA; dual-flag not recommended.
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      maxAdContentRating: MaxAdContentRating.g,
    ),
  );

  // Step 2: ironSource — setDoNotSell for CCPA/CPRA belt-and-suspenders.
  // COPPA tagForChildDirectedTreatment is auto-forwarded by the adapter.
  GmaMediationIronsource().setDoNotSell(true);

  // Step 3: Unity — withhold consent (child-directed: no consent, no selling).
  // These are STATIC calls on GmaMediationUnity.
  GmaMediationUnity.setGDPRConsent(false);
  GmaMediationUnity.setCCPAConsent(false);
  // COPPA tagForChildDirectedTreatment is auto-forwarded by the adapter.

  // Step 4: InMobi — no Dart call needed.
  // GmaMediationInMobi is an empty class; the native adapter reads COPPA from
  // RequestConfiguration directly.

  // Step 5: AppLovin — disabled. SDK 13.0+ cannot init in child-directed apps.
  if (kAppLovinEnabled) {
    // Activation path documented here; do not remove.
    // Requires: AppLovin account approval + Families Program re-entry confirmed.
  }

  // Step 6: Initialize GMA SDK — LAST, after all child-directed flags are set.
  await MobileAds.instance.initialize();
}
```

**Critical:** Steps 1–5 must complete before Step 6. Google's documentation is explicit that
`updateRequestConfiguration` and mediation SDK privacy calls must precede `initialize()`.

**Call site:** `initializeAds()` is called in `main()` before `runApp()`, as shown in the
Flags `main.dart` pattern.

**AndroidManifest.xml (already correct in v1):**
- `APPLICATION_ID` meta-data entry is present (required to prevent RuntimeException)
- `AD_ID` permission is stripped via `tools:node="remove"`
- Android Privacy Sandbox permissions (`ACCESS_ADSERVICES_*`) are stripped

**Android minSdk (already correct):** `minSdk = 24` in `android/app/build.gradle.kts`.
`google_mobile_ads` 8.0.0 declares `minSdkVersion 24` in its manifest; this is already
accounted for and documented in the build file comments.

#### AdMob Ad Unit ID Activation

`lib/core/ads/ad_constants.dart` in v1 has empty string ad unit IDs — these must be
replaced with production IDs from AdMob console before v2 goes live. Test IDs for
development are the standard Google test ad unit IDs:

```dart
// Development/test IDs (replace before Play Store submission):
const String kBannerAdUnitId       = 'ca-app-pub-3940256099942544/6300978111';
const String kInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const String kRewardedAdUnitId     = 'ca-app-pub-3940256099942544/5224354917';
const String kAppOpenAdUnitId      = 'ca-app-pub-3940256099942544/9257395921';
```

The `AdMobAdService` implementation exists in full in
`C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\admob_ad_service.dart` and is a direct
port target for v2 — it implements Banner (anchored adaptive), Interstitial (preload +
show with reload), Rewarded (Completer<bool> pattern), and App Open (4-hour expiry +
gameplay suppression). The `adServiceProvider` in `ad_service_provider.dart` must be
switched from `StubAdService()` to `AdMobAdService(ref)` as part of v2 activation.

### Supporting Libraries (v2 additions)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `share_plus` | `^13.1.0` | Native share sheet | Already declared. v2 upgrades the `_onSharePressed` in `CompletionScreen` from text-only to screenshot + text. API: `SharePlus.instance.share(ShareParams(files: [xfile], text: '...'))`. |
| `path_provider` | `^2.1.5` | Filesystem paths | NEW in v2. Needed to write the PNG screenshot to a temp file before passing to `share_plus` as an `XFile`. `getTemporaryDirectory()` is the right call — temp storage is app-scoped, auto-cleaned, no permissions needed on Android 10+. |
| `url_launcher` | `^6.3.2` | Open URLs | Already declared. No change for v2. |
| `flutter_localizations` | SDK | Localization support | No change. |

#### Screenshot Capture → Share Pattern

The score card in `CompletionScreen` already has a `RepaintBoundary` widget wrapping it.
The v2 upgrade assigns a `GlobalKey` to that boundary and captures it as a PNG:

```dart
final _scoreCardKey = GlobalKey();

// In build():
RepaintBoundary(
  key: _scoreCardKey,
  child: Card(...),
)

// In _onSharePressed() — after math gate passes:
Future<XFile> _captureScoreCard() async {
  final boundary = _scoreCardKey.currentContext!
      .findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  // Write to temp file with a meaningful filename for the share sheet.
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/state_the_states_result.png');
  await file.writeAsBytes(pngBytes);
  return XFile(file.path, mimeType: 'image/png');
}

// Share:
final xfile = await _captureScoreCard();
await SharePlus.instance.share(ShareParams(
  files: [xfile],
  text: 'New personal best in $_modeName! Score: $_score — State the States',
));
```

**pixelRatio: 2.0** — doubles resolution for crisp social-media sharing without
significant memory impact (the score card widget is small).

**XFile.fromData() alternative:** `XFile.fromData(pngBytes, mimeType: 'image/png')` works
on Android without writing a temp file, but some share targets (e.g. Gmail) require an
actual file path. The temp-file approach is the reliable Android-first path.

**PB-gating:** The share button should only be offered / enabled when `_isNewPb == true`
(or always offered but the share text changes to reflect no-PB). The math gate already
exists; v2 adds PB-aware messaging.

### Development Tools

| Tool | Flags Version | Current Stable | Purpose |
|------|--------------|---------------|---------|
| `riverpod_generator` | `^4.0.3` | `4.0.3` | Code generation for `@riverpod` annotations | Run via `build_runner`. |
| `build_runner` | `^2.15.0` | `2.15.0` | Build-time codegen orchestrator | `dart run build_runner build --delete-conflicting-outputs` |
| `mocktail` | `^1.0.5` | `1.0.5` | Mock objects in tests | Used to mock `AudioService`, `AdService`, `HighScoreRepository`. |
| `flutter_lints` | `^5.0.0` | `6.0.0` | Lint rules | **Delta:** upgrade to ^6.0.0 (flutter.dev publisher, latest stable). No lints were removed; new rules are additions only. |
| `flutter_launcher_icons` | `^0.14.3` | `0.14.4` | Generate adaptive launcher icons | Minor patch bump; no API change. |
| `integration_test` | SDK | SDK | Widget and integration tests | |
| `flutter_test` | SDK | SDK | Unit + widget tests | |

---

## Map Data Pipeline

This is NOT a runtime dependency — it is a build-time Python script that runs once per data update and produces a bundled JSON asset. The pipeline is locked from Flags and adapted for US states.

### Source Data

**Dataset:** Natural Earth Admin-1 States and Provinces, 10m scale
**URL:** `https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_1_states_provinces.zip`
**Version:** 5.1.1
**License:** Public domain — no attribution required. Explicitly safe for a Google Play Families / COPPA app.
**Why 10m, not 110m:** Flags uses 110m admin-0 (country outlines); for US states at the level of detail needed (Rhode Island, Delaware, Hawaii islands), 10m is the right resolution. 110m admin-1 loses small state geometry entirely.

### Key Shapefile Fields (verified via community usage)

- `adm0_a3` — country code; filter `== 'USA'` to isolate the 50 states + DC
- `postal` — two-letter US postal abbreviation (AL, AK, … WY); use as the canonical entity key
- `name` — full state name (e.g. "Alabama")
- `iso_3166_2` — ISO 3166-2 subdivision code (e.g. "US-AL")

Filter: `gdf[gdf['adm0_a3'] == 'USA']` yields 50 states + DC + territories. Further filter by `postal` membership in the canonical 50-state set.

### Pipeline Design (direct port of `generate_map.py`)

```
ne_10m_admin_1_states_provinces.zip
        │
        ▼
  generate_usa_map.py  (geopandas + shapely)
        │  – filter adm0_a3 == 'USA', postal in STATES_50
        │  – project Alaskan geometry to inset space (scale + translate)
        │  – project Hawaiian geometry to inset space (scale + translate)
        │  – polygon_to_path(): exterior coords → SVG path string in viewBox coords
        │  – compute representative_point() centroid (inside polygon, not area centroid)
        │  – compute boundingBox from all exterior coord extremes
        │
        ▼
  assets/map/usa_states_paths.json
        │  {
        │    "version": 1,
        │    "viewBox": {"width": 1000, "height": 620},
        │    "states": [
        │      {
        │        "postal": "AL",
        │        "name": "Alabama",
        │        "paths": ["M... L... Z"],
        │        "boundingBox": {"x":..., "y":..., "w":..., "h":...},
        │        "centroid": {"x":..., "y":...},
        │        "inset": null          ← null for mainland
        │      },
        │      {
        │        "postal": "AK",
        │        "name": "Alaska",
        │        "paths": ["M... L... Z", "M... L... Z"],  ← multiple polygons
        │        "boundingBox": {...},
        │        "centroid": {...},
        │        "inset": "alaska"      ← flag for inset rendering
        │      },
        │      ...
        │    ]
        │  }
        │
        ▼
  StateData.fromJson()  (Dart, startup)
        │  – path_drawing.parseSvgPathData(s) → dart:ui Path
        │  – BoundingBox.fromJson() → Rect
        │  – centroid → Offset
        │
        ▼
  USAMapPainter (CustomPainter)
        └  draws Path objects via canvas.drawPath()
           InteractiveViewer wraps the Canvas; tray is outside
```

### Alaska / Hawaii Inset Strategy

The generator script must apply affine transforms to bring Alaska and Hawaii polygons into an inset region within the main viewBox (bottom-left corner convention, matching standard US atlas layout). The transforms are:

- **Alaska:** scale ~0.35×, translate to bottom-left inset frame (~x: 0–250, y: 430–620 in a 1000×620 viewBox)
- **Hawaii:** scale ~0.8×, translate to inset frame (~x: 250–380, y: 500–620)

These transforms are applied in the Python script at path-generation time — the JSON stores already-transformed coordinates. The Dart side has no special-case logic for insets; it draws all paths identically. The `inset` field is metadata only (for future labelling rules).

### Python Dependencies

```
geopandas>=0.14
shapely>=2.0
```

Install: `pip install geopandas shapely`

---

## Installation

```yaml
# pubspec.yaml — State States v2

environment:
  sdk: '>=3.10.0 <4.0.0'
  flutter: '>=3.44.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^3.3.1
  riverpod_annotation: ^4.0.2
  flutter_svg: ^2.3.0
  go_router: ^17.2.3
  path_drawing: ^1.0.1
  shared_preferences: ^2.5.5
  intl: ^0.20.2
  just_audio: ^0.10.5
  # Ads — active in v2
  google_mobile_ads: ^8.0.0
  gma_mediation_unity: ^1.8.0
  gma_mediation_ironsource: ^2.4.1
  gma_mediation_inmobi: ^2.1.0
  gma_mediation_applovin: ^2.6.1   # declared but disabled; kAppLovinEnabled=false
  # Sharing — v2 screenshot path
  url_launcher: ^6.3.2
  share_plus: ^13.1.0
  path_provider: ^2.1.5            # NEW in v2 — temp file for screenshot sharing

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  riverpod_generator: ^4.0.3
  build_runner: ^2.15.0
  mocktail: ^1.0.5
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.4
```

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Map rendering | `CustomPainter` + `InteractiveViewer` | `flutter_map` (Leaflet) | flutter_map is a tile-based mapping SDK; tiles require network, wrong rendering model for drag-drop entity matching, incompatible with offline first-class constraint. Locked decision in Flags CLAUDE.md. |
| Map rendering | `CustomPainter` + `InteractiveViewer` | Syncfusion Maps | Commercial license (free tier has attribution); violates Families Policy visual cleanliness requirements; vendor lock-in. Locked decision in Flags CLAUDE.md. |
| State data | Natural Earth admin-1 10m | US Census Bureau TIGER/Line | TIGER/Line is high-fidelity (detailed coastlines, 50 MB+); far too large for a mobile bundle. Natural Earth 10m is purpose-built for small-scale display and gives clean, compact polygons. License is equivalent (public domain). |
| State data | Natural Earth admin-1 10m | OpenStreetMap | OSM data is ODbL-licensed — share-alike clause complicates a closed-source commercial app even though it is nominally free. Natural Earth's public domain is unambiguous. |
| State management | Riverpod 3.x + codegen | Bloc | Bloc is valid but incompatible with Flags patterns; rewriting to Bloc would eliminate the baseline advantage entirely. |
| State management | Riverpod 3.x + codegen | Provider (v1 Riverpod) | Provider is deprecated for new projects; Riverpod 3.x supersedes it. |
| Audio | `just_audio` | `audioplayers` | PROJECT.md explicitly supersedes the `audioplayers` mention: "Standardize audio on `just_audio`." `just_audio` is already in the Flags lockfile and its service pattern is directly portable. |
| Analytics | Android Vitals (no package) | Firebase Analytics | Firebase Analytics captures a persistent App Instance ID — a persistent identifier prohibited by COPPA for child-directed apps. Locked decision in both Flags CLAUDE.md and PROJECT.md. |
| Crash reporting | Android Vitals (no package) | Firebase Crashlytics | Crashlytics assigns a persistent UUID per install — same COPPA prohibition. |
| Screenshot sharing | `RepaintBoundary` + temp file | `screenshot` package | The `screenshot` package is a thin wrapper around the same Flutter rendering API. No benefit over direct `RenderRepaintBoundary.toImage()` — adds a dependency for code that is 10 lines. |
| AppLovin mediation | disabled | enabled | AppLovin SDK 13.0+ explicitly prohibits initialization in child-directed / COPPA apps. Enabling it would violate Families Policy. Re-enable only if AppLovin provides a COPPA-safe SDK variant and re-enters the Families Self-Certified Ads SDK Program. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `firebase_core` (and any Firebase package) | Firebase assigns persistent device/install identifiers (App Instance ID, Crashlytics UUID). COPPA prohibits persistent identifiers for child-directed apps. This is a hard constraint, not a preference. | Android Vitals for crash/ANR reporting (zero code required). |
| `flutter_map` | Tile-based map SDK; requires network; wrong rendering model for offline drag-drop gameplay. | `CustomPainter` + `InteractiveViewer` (the Flags pattern). |
| Syncfusion Maps | Commercial license; attribution requirement; vendor lock-in. | `CustomPainter` + `InteractiveViewer`. |
| `audioplayers` | Superseded by `just_audio` for this project. Two audio stacks would diverge from the Flags baseline. | `just_audio`. |
| Runtime SVG parsing for the map | Parsing SVG at runtime is slow (blocks frame budget), prevents pre-computing centroids and bounding boxes, and loses the structured JSON schema needed for hit-testing. | Build-time Python pipeline → bundled `usa_states_paths.json`. |
| Any online/cloud storage SDK | App is fully offline by design. Accounts and cloud sync are explicitly out of scope. | `shared_preferences` for all local persistence. |
| Initializing AppLovin MAX in v2 | AppLovin SDK 13.0+ refuses to initialize in apps classified as children's content under COPPA/Google Play Families Ads Policy. | Keep `kAppLovinEnabled = false`. Revenue loss is acceptable; policy violation is not. |
| `tagForChildDirectedTreatment` + `tagForUnderAgeOfConsent` both set to `yes` | Google documentation explicitly advises against setting both simultaneously — child-directed treatment already covers UCPA/under-age scenarios. Dual-flag is undefined behavior. | Set only `tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes`. |

---

## Deltas from Flags Lockfile

| Package | Flags | State States | Delta Type | Notes |
|---------|-------|-------------|-----------|-------|
| Flutter SDK constraint | `>=3.32.0` | `>=3.44.0` | Bump lower-bound | Track current stable; no breaking changes. |
| Dart SDK constraint | `>=3.7.0` | `>=3.10.0` | Bump lower-bound | Matches Flutter 3.44 / Dart 3.10. |
| `share_plus` | `^10.0.0` | `^13.1.0` | Minor version bump | 13.1.0 is current stable; API unchanged (no breaking API changes between 10→13, only platform minimum bumps in 13.0.0). |
| `url_launcher` | `^6.3.0` | `^6.3.2` | Patch bump | No behavior change. |
| `flutter_lints` | `^5.0.0` | `^6.0.0` | Minor version bump | 6.0.0 is current stable; new lint rules added but none removed. |
| `flutter_launcher_icons` | `^0.14.3` | `^0.14.4` | Patch bump | No API change. |
| `riverpod_generator` | `^4.0.3` (dev) | same | Unchanged | Current stable is 4.0.3. |
| `path_provider` | not present | `^2.1.5` | New addition (v2) | Required for screenshot temp-file → share_plus path. |

All other packages are at identical versions to Flags.

---

## Version Compatibility

| Concern | Status | Notes |
|---------|--------|-------|
| `flutter_riverpod` 3.3.1 + `riverpod_annotation` 4.0.2 + `riverpod_generator` 4.0.3 | Compatible | These three packages share the Riverpod 3.x generation and are designed to move in lock-step. Verified via pub.dev dependency constraints. |
| `path_drawing` 1.0.1 + `flutter_svg` 2.3.0 | Compatible | `path_drawing` is a standalone SVG path parser; it does not depend on `flutter_svg` at runtime. Both are used in Flags without conflict. |
| `google_mobile_ads` 8.0.0 + four `gma_mediation_*` packages | Compatible | All four mediation adapters are google.dev published and designed for the gma 8.x API. Identical to Flags lockfile. Note: `gma_mediation_applovin` is compatible but its underlying SDK cannot be used in child-directed apps. |
| `just_audio` 0.10.5 + Android minSdk 24 | Compatible | `just_audio` supports Android API 21+; our minSdk 24 is a superset of that requirement. |
| `share_plus` 13.1.0 minimum Flutter | Compatible | 13.1.0 requires Flutter 3.38.1 / Dart 3.10. Our `>=3.44.0` constraint satisfies this. |
| `path_provider` 2.1.5 + Android minSdk 24 | Compatible | `path_provider` supports Android API 16+; our minSdk 24 satisfies this. |
| `google_mobile_ads` 8.0.0 + Android minSdk | Required: minSdk 24 | GMA 8.0.0 wraps the native Android GMA SDK which requires minSdkVersion 24. This is already enforced in `android/app/build.gradle.kts` (`val appMinSdk = 24`). |

---

## Sources

- `C:\code\Claude\FlagsRoundTheWorld\pubspec.yaml` — Flags lockfile (direct read, authoritative baseline)
- `C:\code\Claude\FlagsRoundTheWorld\pubspec.lock` — Resolved dependency graph (confirmed versions)
- `C:\code\Claude\FlagsRoundTheWorld\CLAUDE.md` — Locked architecture decisions (CustomPainter, no Firebase, no flutter_map, no Syncfusion)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\admob_ad_service.dart` — Full AdMobAdService implementation (direct read; port target for v2)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ads_initializer.dart` — Flags init sequence with ironSource + Unity mediation calls (direct read, authoritative)
- `C:\code\Claude\StateTheStates\lib\core\ads\ads_initializer.dart` — v1 partial init (no mediation); v2 completes it
- `C:\code\Claude\StateTheStates\android\app\build.gradle.kts` — minSdk 24 confirmed, with inline comment explaining why (direct read)
- `C:\code\Claude\StateTheStates\android\app\src\main\AndroidManifest.xml` — AD_ID + AdServices permissions stripped (direct read)
- https://developers.google.com/admob/flutter/mediation/unity — GmaMediationUnity.setGDPRConsent / setCCPAConsent (static methods, call before initialize) (MEDIUM confidence — Google Developers page, WebSearch verified)
- https://developers.google.com/admob/flutter/mediation/ironsource — GmaMediationIronsource().setDoNotSell(true) (instance method) (MEDIUM confidence — Google Developers page, WebSearch verified)
- https://developers.is.com/ironsource-mobile/flutter/regulation-advanced-settings/ — ironSource regulation settings guide (MEDIUM confidence)
- https://developers.is.com/ironsource-mobile/general/ironsource-mobile-child-directed-apps/ — ironSource COPPA child-directed API (MEDIUM confidence)
- https://pub.dev/packages/gma_mediation_inmobi — "GmaMediationInMobi is an empty class needed to allow correct compatibility analysis" — no Dart-side COPPA call required (HIGH confidence — pub.dev official)
- https://developers.google.com/admob/android/mediation/inmobi — InMobi adapter auto-forwards COPPA from RequestConfiguration (MEDIUM confidence)
- https://support.axon.ai/en/max/flutter/overview/privacy/ — AppLovin SDK 13.0+ cannot be initialized in child-directed apps (HIGH confidence — AppLovin official docs)
- https://www.kidoz.net/blog/navigating-the-applovin-decision-a-guide-for-developers-with-kids-and-mixed-audiences — AppLovin 13.0 child-directed prohibition (MEDIUM confidence, corroborating source)
- https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html — `toImage(pixelRatio: double)` method signature (HIGH confidence — Flutter official API docs)
- https://pub.dev/documentation/cross_file/latest/cross_file/XFile-class.html — `XFile.fromData()` and `XFile(path)` constructors (HIGH confidence — official Dart API docs)
- https://pub.dev/packages/path_provider — `getTemporaryDirectory()` confirmed; version ~2.1.x (HIGH confidence — pub.dev official)
- https://pub.dev/packages/flutter_riverpod — Version 3.3.1 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/go_router — Version 17.2.3 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/flutter_svg — Version 2.3.0 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/just_audio — Version 0.10.5 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/google_mobile_ads — Version 8.0.0 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/share_plus — Version 13.1.0 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/shared_preferences — Version 2.5.5 confirmed (HIGH confidence)
- https://pub.dev/packages/intl — Version 0.20.2 confirmed (HIGH confidence)
- https://docs.flutter.dev/release/release-notes/release-notes-3.44.0 — Flutter 3.44.0 bundles Dart 3.10 (HIGH confidence)
- https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/ — NE admin-1 10m v5.1.1, public domain license confirmed (HIGH confidence)
- Community usage patterns confirming `adm0_a3`, `postal`, `name`, `iso_3166_2` field names (MEDIUM confidence — field names confirmed via community examples; definitive names should be verified when downloading the shapefile for the first time)

---
*Stack research for: State States — Flutter educational USA geography game*
*v1 researched: 2026-05-30 | v2 updated: 2026-06-02*
