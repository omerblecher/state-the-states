<!-- GSD:project-start source:PROJECT.md -->
## Project

**State States**

A cross-platform (Flutter), fully-offline, COPPA / Google Play Families-compliant educational mobile game for a general audience including children aged 8+. Players learn U.S. geography by dragging state tokens onto an interactive vector map of the United States (mainland plus Alaska and Hawaii inset projections). It is the spiritual successor to *Flags Around the World* and deliberately baselines that project's directory architecture, Riverpod state-management patterns, CustomPainter map engine, and UI polish.

**Core Value:** A child can drag a state onto its correct place on the U.S. map and immediately feel they got it right — the interactive map placement loop must be smooth, forgiving, and rewarding above everything else.

### Constraints

- **Compliance**: COPPA + Google Play Families Policy — no persistent identifiers, no Firebase, child-directed ad config (`tagForChildDirectedTreatment(true)` on AdMob **and** every mediation SDK), `AD_ID` permission blocked, max content rating G/PG. Outbound device intents (sharing) gated behind an adult-verification math challenge.
- **Tech stack**: Flutter/Dart; baseline directly from *Flags Around the World* (Riverpod + codegen, go_router, CustomPainter + InteractiveViewer map, `just_audio`, `shared_preferences`). Standardize audio on `just_audio` (the spec's `audioplayers` mention is superseded for one-stack consistency).
- **Platforms**: Android first (Google Play Store launch), iOS App Store as a first-class future build target.
- **Offline**: fully offline — no network dependency for core gameplay; all data and assets bundled.
- **Audio rights**: anthem must be a genuinely rights-clean asset (self-rendered from the public-domain composition); a public-domain *composition* does not make an arbitrary *recording* free to ship.
- **App ID**: `com.otis.brooke.state.the.state`.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Baseline: Flags Around the World lockfile
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
| Library | Flags Version | Current Stable | Purpose | COPPA Note |
|---------|--------------|---------------|---------|-----------|
| `google_mobile_ads` | `^8.0.0` | `8.0.0` | AdMob banner / interstitial / rewarded | Must call `tagForChildDirectedTreatment(true)` before `MobileAds.initialize()`. |
| `gma_mediation_unity` | `^1.8.0` | `1.8.0` | Unity Ads mediation | Must set child-directed flag on its own SDK independently. |
| `gma_mediation_ironsource` | `^2.4.1` | `2.4.1` | IronSource mediation | Same independent child-directed requirement. |
| `gma_mediation_inmobi` | `^2.1.0` | `2.1.0` | InMobi mediation | Same. |
| `gma_mediation_applovin` | `^2.6.1` | `2.6.1` | AppLovin MAX mediation | Same. |
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
## Map Data Pipeline
### Source Data
### Key Shapefile Fields (verified via community usage)
- `adm0_a3` — country code; filter `== 'USA'` to isolate the 50 states + DC
- `postal` — two-letter US postal abbreviation (AL, AK, … WY); use as the canonical entity key
- `name` — full state name (e.g. "Alabama")
- `iso_3166_2` — ISO 3166-2 subdivision code (e.g. "US-AL")
### Pipeline Design (direct port of `generate_map.py`)
### Alaska / Hawaii Inset Strategy
- **Alaska:** scale ~0.35×, translate to bottom-left inset frame (~x: 0–250, y: 430–620 in a 1000×620 viewBox)
- **Hawaii:** scale ~0.8×, translate to inset frame (~x: 250–380, y: 500–620)
### Python Dependencies
## Installation
# pubspec.yaml — State States
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
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `firebase_core` (and any Firebase package) | Firebase assigns persistent device/install identifiers (App Instance ID, Crashlytics UUID). COPPA prohibits persistent identifiers for child-directed apps. This is a hard constraint, not a preference. | Android Vitals for crash/ANR reporting (zero code required). |
| `flutter_map` | Tile-based map SDK; requires network; wrong rendering model for offline drag-drop gameplay. | `CustomPainter` + `InteractiveViewer` (the Flags pattern). |
| Syncfusion Maps | Commercial license; attribution requirement; vendor lock-in. | `CustomPainter` + `InteractiveViewer`. |
| `audioplayers` | Superseded by `just_audio` for this project. Two audio stacks would diverge from the Flags baseline. | `just_audio`. |
| Runtime SVG parsing for the map | Parsing SVG at runtime is slow (blocks frame budget), prevents pre-computing centroids and bounding boxes, and loses the structured JSON schema needed for hit-testing. | Build-time Python pipeline → bundled `usa_states_paths.json`. |
| Any online/cloud storage SDK | App is fully offline by design. Accounts and cloud sync are explicitly out of scope. | `shared_preferences` for all local persistence. |
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
## Version Compatibility
| Concern | Status | Notes |
|---------|--------|-------|
| `flutter_riverpod` 3.3.1 + `riverpod_annotation` 4.0.2 + `riverpod_generator` 4.0.3 | Compatible | These three packages share the Riverpod 3.x generation and are designed to move in lock-step. Verified via pub.dev dependency constraints. |
| `path_drawing` 1.0.1 + `flutter_svg` 2.3.0 | Compatible | `path_drawing` is a standalone SVG path parser; it does not depend on `flutter_svg` at runtime. Both are used in Flags without conflict. |
| `google_mobile_ads` 8.0.0 + four `gma_mediation_*` packages | Compatible | All four mediation adapters are google.dev published and designed for the gma 8.x API. Identical to Flags lockfile. |
| `just_audio` 0.10.5 + Android minSdk 21 | Compatible | `just_audio` supports Android API 21+. Flags sets `min_sdk_android: 21` in `pubspec.yaml` / `flutter_launcher_icons` config. Carry this forward. |
| `share_plus` 13.1.0 minimum Flutter | Compatible | 13.1.0 lowered the requirement to Flutter 3.38.1 / Dart 3.10. Our `>=3.44.0` constraint satisfies this. |
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
