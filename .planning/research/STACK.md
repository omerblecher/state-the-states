# Stack Research

**Domain:** Cross-platform Flutter educational map game (USA states, ages 8+, offline, COPPA/Families-compliant)
**Researched:** 2026-05-30
**Confidence:** HIGH — all versions verified against pub.dev; pipeline design verified against live Flags codebase

---

## Baseline: Flags Around the World lockfile

The `pubspec.yaml` at `C:\code\Claude\FlagsRoundTheWorld` is the authoritative lockfile.
Every recommendation below is either a direct carry-over or an explicit, reasoned delta.

```
Flags pubspec.yaml (environment):
  sdk: '>=3.7.0 <4.0.0'
  flutter: '>=3.32.0'
```

Flutter 3.44.0 (Dart 3.10) is current stable as of 2026-05-30.
The `>=3.32.0` lower-bound from Flags is compatible; raise the constraint to `>=3.44.0` for
State States to track the latest stable and pick up performance improvements to
`CustomPainter` and `InteractiveViewer`.

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

### Ads Layer (deferred to v2 — stub in v1)

Per PROJECT.md, the full AdMob + mediation layer is a v2 concern. In v1 the `AdService` interface stubs as `AdLoadState.failed` (identical to Flags Phases 1–5 pattern). The packages are listed here for completeness and to confirm versions for v2 planning.

| Library | Flags Version | Current Stable | Purpose | COPPA Note |
|---------|--------------|---------------|---------|-----------|
| `google_mobile_ads` | `^8.0.0` | `8.0.0` | AdMob banner / interstitial / rewarded | Must call `tagForChildDirectedTreatment(true)` before `MobileAds.initialize()`. |
| `gma_mediation_unity` | `^1.8.0` | `1.8.0` | Unity Ads mediation | Must set child-directed flag on its own SDK independently. |
| `gma_mediation_ironsource` | `^2.4.1` | `2.4.1` | IronSource mediation | Same independent child-directed requirement. |
| `gma_mediation_inmobi` | `^2.1.0` | `2.1.0` | InMobi mediation | Same. |
| `gma_mediation_applovin` | `^2.6.1` | `2.6.1` | AppLovin MAX mediation | Same. |

All four mediation packages are at the same version as Flags. No delta required.

### Supporting Libraries

| Library | Flags Version | State States Version | Purpose | When to Use |
|---------|--------------|---------------------|---------|-------------|
| `share_plus` | `^10.0.0` | `^13.1.0` | Native share sheet | Deferred to v2 (gated social sharing behind math parental challenge). **Delta:** latest stable is 13.1.0; upgrade from ^10.0.0. API is stable — `SharePlus.instance.share(params)` unchanged between 10→13. Breaking change in 13.0.0 was Dart/Flutter minimum version bump only. |
| `url_launcher` | `^6.3.0` | `^6.3.2` | Open URLs (privacy policy, store links) | Used in Flags for external links. Minor version bump to 6.3.2 (flutter.dev publisher). |
| `flutter_localizations` | SDK | SDK | Localization support | Required for `flutter gen-l10n` / ARB pipeline. |

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
# pubspec.yaml — State States

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
  # Ads — declare now for v2 wiring; stub in v1
  google_mobile_ads: ^8.0.0
  gma_mediation_unity: ^1.8.0
  gma_mediation_ironsource: ^2.4.1
  gma_mediation_inmobi: ^2.1.0
  gma_mediation_applovin: ^2.6.1
  # v2 features — declare now to match Flags baseline
  url_launcher: ^6.3.2
  share_plus: ^13.1.0

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

---

## Deltas from Flags Lockfile

| Package | Flags | State States | Delta Type | Notes |
|---------|-------|-------------|-----------|-------|
| Flutter SDK constraint | `>=3.32.0` | `>=3.44.0` | Bump lower-bound | Track current stable; no breaking changes. |
| Dart SDK constraint | `>=3.7.0` | `>=3.10.0` | Bump lower-bound | Matches Flutter 3.44 / Dart 3.10. |
| `share_plus` | `^10.0.0` | `^13.1.0` | Minor version bump | 13.1.0 is current stable; API unchanged (no breaking API changes between 10→13, only platform minimum bumps in 13.0.0). Deferred to v2 anyway. |
| `url_launcher` | `^6.3.0` | `^6.3.2` | Patch bump | No behavior change. |
| `flutter_lints` | `^5.0.0` | `^6.0.0` | Minor version bump | 6.0.0 is current stable; new lint rules added but none removed. |
| `flutter_launcher_icons` | `^0.14.3` | `^0.14.4` | Patch bump | No API change. |
| `riverpod_generator` | `^4.0.3` (dev) | same | Unchanged | Current stable is 4.0.3. |

All other packages are at identical versions to Flags.

---

## Version Compatibility

| Concern | Status | Notes |
|---------|--------|-------|
| `flutter_riverpod` 3.3.1 + `riverpod_annotation` 4.0.2 + `riverpod_generator` 4.0.3 | Compatible | These three packages share the Riverpod 3.x generation and are designed to move in lock-step. Verified via pub.dev dependency constraints. |
| `path_drawing` 1.0.1 + `flutter_svg` 2.3.0 | Compatible | `path_drawing` is a standalone SVG path parser; it does not depend on `flutter_svg` at runtime. Both are used in Flags without conflict. |
| `google_mobile_ads` 8.0.0 + four `gma_mediation_*` packages | Compatible | All four mediation adapters are google.dev published and designed for the gma 8.x API. Identical to Flags lockfile. |
| `just_audio` 0.10.5 + Android minSdk 21 | Compatible | `just_audio` supports Android API 21+. Flags sets `min_sdk_android: 21` in `pubspec.yaml` / `flutter_launcher_icons` config. Carry this forward. |
| `share_plus` 13.1.0 minimum Flutter | Compatible | 13.1.0 lowered the requirement to Flutter 3.38.1 / Dart 3.10. Our `>=3.44.0` constraint satisfies this. |

---

## Sources

- `C:\code\Claude\FlagsRoundTheWorld\pubspec.yaml` — Flags lockfile (direct read, authoritative baseline)
- `C:\code\Claude\FlagsRoundTheWorld\pubspec.lock` — Resolved dependency graph (confirmed versions)
- `C:\code\Claude\FlagsRoundTheWorld\CLAUDE.md` — Locked architecture decisions (CustomPainter, no Firebase, no flutter_map, no Syncfusion)
- `C:\code\Claude\FlagsRoundTheWorld\scripts\generate_map.py` — Python pipeline design (direct read, authoritative)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\models\country_data.dart` — JSON schema design (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart` — Background-isolate load pattern (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\real_audio_service.dart` — `just_audio` service pattern (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\hit_detection.dart` — Proximity-snap and centroid hit-test algorithm (direct read)
- https://pub.dev/packages/flutter_riverpod — Version 3.3.1 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/go_router — Version 17.2.3 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/flutter_svg — Version 2.3.0 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/just_audio — Version 0.10.5 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/google_mobile_ads — Version 8.0.0 confirmed current stable (HIGH confidence)
- https://pub.dev/packages/share_plus — Version 13.1.0 confirmed current stable; changelog confirms no API breaking changes vs 10.x (HIGH confidence)
- https://pub.dev/packages/shared_preferences — Version 2.5.5 confirmed (HIGH confidence)
- https://pub.dev/packages/intl — Version 0.20.2 confirmed (HIGH confidence)
- https://pub.dev/packages/riverpod_annotation — Version 4.0.2 confirmed stable (HIGH confidence)
- https://pub.dev/packages/riverpod_generator — Version 4.0.3 confirmed stable (HIGH confidence)
- https://pub.dev/packages/path_drawing — Version 1.0.1 confirmed (HIGH confidence)
- https://pub.dev/packages/build_runner — Version 2.15.0 confirmed (HIGH confidence)
- https://pub.dev/packages/flutter_lints — Version 6.0.0 confirmed current stable (HIGH confidence)
- https://docs.flutter.dev/release/release-notes/release-notes-3.44.0 — Flutter 3.44.0 bundles Dart 3.10 (HIGH confidence)
- https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/ — NE admin-1 10m v5.1.1, public domain license confirmed (HIGH confidence)
- Community usage patterns confirming `adm0_a3`, `postal`, `name`, `iso_3166_2` field names (MEDIUM confidence — field names confirmed via community examples; definitive names should be verified when downloading the shapefile for the first time)

---
*Stack research for: State States — Flutter educational USA geography game*
*Researched: 2026-05-30*
