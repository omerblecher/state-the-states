# Phase 1: Foundation - Pattern Map

**Mapped:** 2026-05-31
**Files analyzed:** 18 new/modified files
**Analogs found:** 16 / 18 (2 have no close analog — see "No Analog Found")

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/generate_states.py` | utility (build-time) | transform/batch | `C:\code\Claude\FlagsRoundTheWorld\scripts\generate_map.py` | role-match (projection step replaced) |
| `scripts/requirements.txt` | config | — | `C:\code\Claude\FlagsRoundTheWorld\scripts\requirements.txt` | exact (add `antimeridian`) |
| `pubspec.yaml` | config | — | `C:\code\Claude\FlagsRoundTheWorld\pubspec.yaml` | exact (apply CLAUDE.md deltas) |
| `android/app/src/main/AndroidManifest.xml` | config | — | `C:\code\Claude\FlagsRoundTheWorld\android\app\src\main\AndroidManifest.xml` | exact (change package + App ID) |
| `lib/main.dart` | entrypoint | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\main.dart` | exact (swap to StubAdService) |
| `lib/app.dart` | provider/router | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\app.dart` | role-match (simpler route set) |
| `lib/core/models/state_data.dart` | model | transform | `C:\code\Claude\FlagsRoundTheWorld\lib\core\models\country_data.dart` | role-match (renames + new fields) |
| `lib/core/data/state_data_service.dart` | service | batch/async | `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart` | exact (key rename only) |
| `lib/core/ads/ad_service.dart` | middleware/interface | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service.dart` | exact copy |
| `lib/core/ads/stub_ad_service.dart` | service | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\stub_ad_service.dart` | exact copy |
| `lib/core/ads/ad_service_provider.dart` | provider | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service_provider.dart` | role-match (wire Stub, not AdMob) |
| `lib/core/ads/ad_load_state.dart` | model | — | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_load_state.dart` | exact copy |
| `lib/core/ads/ad_constants.dart` | config | — | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_constants.dart` | role-match (clear unit IDs) |
| `lib/core/audio/audio_service.dart` | middleware/interface | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\audio_service.dart` | role-match (add anthem methods) |
| `lib/core/audio/stub_audio_service.dart` | service | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\stub_audio_service.dart` | role-match (add anthem stubs) |
| `lib/core/audio/real_audio_service.dart` | service | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\real_audio_service.dart` | role-match (add anthem loop) |
| `lib/features/home/home_screen.dart` | component | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\home_screen.dart` | role-match (placeholder scaffold) |
| `lib/features/map/map_screen.dart` | component | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` | role-match (blank canvas proof) |

---

## Pattern Assignments

### `scripts/generate_states.py` (build-time pipeline, transform/batch)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\scripts\generate_map.py`

**File structure pattern** (lines 1-10, 132-235 of analog):
```python
import geopandas as gpd
import json
from shapely.geometry import MultiPolygon, Polygon

# Constants at top of file: target set, projection strings, output path
VIEWBOX_WIDTH = 2000.0   # ← replace with derived canvas_width = 1000
# ...
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', default=None)
    # ...
    gdf = gpd.read_file(url)
    gdf = gdf.to_crs('EPSG:4326')
    # ...
    output = {"version": 1, "viewBox": {...}, "countries": countries}
    with open(out_path, 'w') as f:
        json.dump(output, f, separators=(',', ':'))

if __name__ == '__main__':
    main()
```

**Core path-string extraction pattern** (analog lines 91-99):
```python
def polygon_to_path(polygon):
    coords = list(polygon.exterior.coords)[:-1]
    if len(coords) < 3:
        return None
    parts = [f"M{lon_to_x(coords[0][0])},{lat_to_y(coords[0][1])}"]
    for lon, lat in coords[1:]:
        parts.append(f"L{lon_to_x(lon)},{lat_to_y(lat)}")
    parts.append("Z")
    return " ".join(parts)
```

**MultiPolygon iteration pattern** (analog lines 164-173):
```python
polys = list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]
for poly in polys:
    if not isinstance(poly, Polygon):
        continue
    path = polygon_to_path(poly)
    if path:
        all_paths.append(path)
```

**Representative centroid pattern** (analog lines 178-193):
```python
merged = unary_union(geometries)
if isinstance(merged, MultiPolygon):
    largest = max(merged.geoms, key=lambda p: p.area)
else:
    largest = merged
rep = largest.representative_point()
cx = to_canvas(rep.x, rep.y)   # canvas version of lon_to_x/lat_to_y
```

**Output record pattern** (analog lines 195-207):
```python
entry = {
    "iso": iso,           # ← rename to "postal" for states
    "paths": all_paths,
    "boundingBox": {"x": min_x, "y": min_y, "w": ..., "h": ...},
    "centroid": {"x": cx, "y": cy},
}
```

**Key deltas from analog (MUST apply):**

| Analog | State States replacement |
|--------|--------------------------|
| `lon_to_x()` / `lat_to_y()` equirectangular | `to_crs('EPSG:5070')` for CONUS + `normalize_bounds()` (D-01) |
| Single global projection | Three-CRS pipeline: CONUS=EPSG:5070, AK=EPSG:3338, HI=proj4 (D-02) |
| No antimeridian handling | `antimeridian.fix_shape(ak_geometry)` before `to_crs()` (D-02/DATA-02) |
| `"countries"` JSON key | `"states"` JSON key (D-04/Pitfall 7) |
| `"iso"` field | `"postal"` field |
| No `isPlaceable` field | Add `"isPlaceable": bool` (D-03/D-04) |
| No `insetGroup` field | Add `"insetGroup": "alaska"\|"hawaii"\|null` (D-08) |
| Hardcoded `viewBox: {width:2000, height:1000}` | Derived from CONUS Albers projected bounds, normalize to width=1000 (D-07) |
| No inset transforms | Bake AK/HI inset scale(~0.45×)+translate into path coordinates (D-08) |
| No validity gate | `assert shapely.validation.is_valid(geom)` after AK fix (DATA-02) |
| Filter by ISO code | Filter `adm0_a3=='USA'` then `postal in ALL_RECORDS` (50 states + 'DC') |
| `"countries"` output list | `"states"` output list with 51 records |
| No `insetFrames` top-level key | Add `"insetFrames": {"alaska":{...}, "hawaii":{...}}` |

**Three-CRS pipeline (from RESEARCH.md Pattern 1 — VERIFIED):**
```python
# CONUS — EPSG:5070 (NAD83/Conus Albers)
conus_gdf = gdf_usa[~gdf_usa['postal'].isin(['AK','HI'])].to_crs('EPSG:5070')

# Alaska — EPSG:3338 (NAD83/Alaska Albers); antimeridian FIRST
ak_rows = gdf_usa[gdf_usa['postal'] == 'AK'].copy()
ak_rows['geometry'] = ak_rows['geometry'].apply(fix_antimeridian)
ak_projected = ak_rows.to_crs('EPSG:3338')

# Hawaii — proj4 (Hawaii Albers, ESRI:102007 equivalent)
HI_PROJ4 = '+proj=aea +lat_0=13 +lon_0=-157 +lat_1=8 +lat_2=18 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs'
hi_projected = gdf_usa[gdf_usa['postal'] == 'HI'].to_crs(HI_PROJ4)
```

**Normalization pattern (from RESEARCH.md Pattern 1 — ASSUMED, correct in principle):**
```python
def normalize_bounds(gdf_projected, canvas_width=1000):
    minx, miny, maxx, maxy = gdf_projected.total_bounds
    proj_w = maxx - minx
    proj_h = maxy - miny
    canvas_height = round(canvas_width * proj_h / proj_w)
    def to_canvas(x, y):
        cx = round((x - minx) / proj_w * canvas_width, 2)
        cy = round((maxy - y) / proj_h * canvas_height, 2)  # y flipped
        return cx, cy
    return canvas_height, to_canvas
```

**Antimeridian fix pattern (from RESEARCH.md Pattern 2 — VERIFIED v0.4.7):**
```python
import antimeridian
from shapely.geometry import shape
from shapely.validation import is_valid, explain_validity

def fix_antimeridian(geom):
    fixed = antimeridian.fix_shape(geom)
    return shape(fixed)

# Gate after fix + reproject:
for geom in ak_projected.geometry:
    assert is_valid(geom), f"AK invalid: {explain_validity(geom)}"
```

**First-run field verification (MUST be in pipeline — field names MEDIUM confidence):**
```python
gdf = gpd.read_file(NE_URL)
print("Columns:", gdf.columns.tolist())   # verify adm0_a3, postal, name
gdf_usa = gdf[gdf['adm0_a3'] == 'USA']
print(f"USA rows: {len(gdf_usa)}")
print("Postal sample:", gdf_usa['postal'].head(10).tolist())
```

---

### `scripts/requirements.txt` (config)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\scripts\requirements.txt` (lines 1-3):
```
geopandas>=0.14.0
shapely>=2.0.0
pyproj>=3.6.0
```

**Delta:** add `antimeridian>=0.4` (required for AK Aleutian split, D-02):
```
geopandas>=1.0
shapely>=2.0
pyproj>=3.6.0
antimeridian>=0.4
```

---

### `pubspec.yaml` (config)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\pubspec.yaml` (all lines — read directly)

**Copy verbatim then apply CLAUDE.md deltas:**

| Field | Flags value | State States value |
|-------|-------------|-------------------|
| `name` | `flags_around_the_world` | `state_states` |
| `description` | `Educational flag-placement game` | `Educational US states geography game` |
| `sdk` lower bound | `>=3.7.0 <4.0.0` | `>=3.10.0 <4.0.0` |
| `flutter` lower bound | `>=3.32.0` | `>=3.44.0` |
| `share_plus` | `^10.0.0` | `^13.1.0` |
| `url_launcher` | `^6.3.0` | `^6.3.2` |
| `flutter_lints` | `^5.0.0` | `^6.0.0` |
| `flutter_launcher_icons` | `^0.14.3` | `^0.14.4` |
| assets | `assets/flags/` etc. | remove `assets/flags/`; add `assets/map/`, `assets/audio/` |

**Assets section pattern** (analog lines 51-57):
```yaml
flutter:
  generate: true
  uses-material-design: true
  assets:
    - assets/map/
    - assets/audio/
    - assets/icon/
```

---

### `android/app/src/main/AndroidManifest.xml` (config, COPPA)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\android\app\src\main\AndroidManifest.xml` (all lines — read directly)

**Copy verbatim then apply these changes:**

| Field | Flags value | State States value |
|-------|-------------|-------------------|
| `package=` | `com.otis.brooke.flags.around.the.world` | `com.otis.brooke.state.the.state` |
| `android:label=` | `"Flags Around the World"` | `"State the States"` |
| AdMob App ID meta-data value | `ca-app-pub-4227443066128564~1432248157` | TBD (use test ID initially) |

**AD_ID block — copy exactly as-is** (analog lines 5-8):
```xml
<!-- COMP-02: Block AD_ID permission — prevents GAID leakage from transitive AdMob deps -->
<uses-permission
    android:name="com.google.android.gms.permission.AD_ID"
    tools:node="remove"/>
```

**Manifest root with tools namespace** (analog line 1-3):
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="com.otis.brooke.state.the.state">
```

**Critical:** `tools:node="remove"` is the correct form (NOT `tools:remove="true"`). Verified in Flags production manifest.

---

### `lib/main.dart` (entrypoint)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\main.dart` (all lines — read directly)

**Analog pattern** (lines 1-25):
```dart
import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/ads/ads_initializer.dart';
import 'core/audio/audio_service_provider.dart';
import 'core/audio/real_audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAds();
  runApp(
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWith((_) {
          final svc = RealAudioService();
          unawaited(svc.init());
          return svc;
        }),
      ],
      child: const App(),
    ),
  );
}
```

**Phase 1 delta:** `initializeAds()` still called for COPPA configuration correctness (ads_initializer.dart stub version calls `updateRequestConfiguration` only, no real SDK init). Audio override carries over. No other changes.

---

### `lib/app.dart` (router/provider)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\app.dart` (all lines — read directly)

**Router pattern** (analog lines 20-61):
```dart
final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/play', builder: (context, state) => const MapScreen()),
  ],
);
```

**App widget pattern** (analog lines 63-107):
```dart
class App extends ConsumerStatefulWidget {
  const App({super.key});
  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'State the States',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
```

**Phase 1 delta:** Remove `AppStateObserver` (app-open ad logic); Phase 1 routes are `/` (HomeScreen) and `/play` (MapScreen blank canvas). Remove `gameSessionProvider` reference — that is Phase 2+.

---

### `lib/core/models/state_data.dart` (model, transform)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\models\country_data.dart` (all lines — read directly)

**BoundingBox class — copy verbatim** (analog lines 1-14):
```dart
import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';

class BoundingBox {
  final double x, y, w, h;
  const BoundingBox({required this.x, required this.y, required this.w, required this.h});
  Rect get rect => Rect.fromLTWH(x, y, w, h);
  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    h: (json['h'] as num).toDouble(),
  );
}
```

**fromJson pattern — copy then adapt** (analog lines 36-49):
```dart
factory CountryData.fromJson(Map<String, dynamic> json) {
  final pathStrings = List<String>.from(json['paths'] as List);
  final paths = pathStrings.map((s) => parseSvgPathData(s)).toList();
  final bb = BoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>);
  final c = json['centroid'] as Map<String, dynamic>;
  return CountryData(
    isoCode: json['iso'] as String,        // ← rename to postal: json['postal']
    pathStrings: pathStrings,
    paths: paths,
    boundingBox: bb,
    centroid: Offset((c['x'] as num).toDouble(), (c['y'] as num).toDouble()),
    isDegenerate: _checkDegenerate(pathStrings),  // ← REMOVE; replace with:
    // isPlaceable: (json['isPlaceable'] as bool?) ?? true,
    // insetGroup: _parseInsetGroup(json['insetGroup'] as String?),
  );
}
```

**State States class declaration (adds fields, drops `isDegenerate`):**
```dart
enum InsetGroup { alaska, hawaii }

class StateData {
  final String postal;          // replaces isoCode
  final String name;            // full state name (new — not in CountryData)
  final List<String> pathStrings;
  final List<Path> paths;
  final BoundingBox boundingBox;
  final Offset centroid;
  final bool isPlaceable;       // false for DC (D-03)
  final InsetGroup? insetGroup; // null = mainland (D-08)

  const StateData({...});

  factory StateData.fromJson(Map<String, dynamic> json) { ... }

  static InsetGroup? _parseInsetGroup(String? value) {
    if (value == null) return null;
    return InsetGroup.values.firstWhere((e) => e.name == value);
  }
}
```

**Key deltas from analog:**

| Analog field | StateData replacement | Reason |
|---|---|---|
| `isoCode` (String) | `postal` (String) | USPS 2-letter; JSON key `'postal'` not `'iso'` |
| — | `name` (String) | full state name from JSON |
| `isDegenerate` (bool) | removed | no degenerate geometry in NE 10m US states |
| — | `isPlaceable` (bool) | D-03: DC = false |
| — | `insetGroup` (InsetGroup?) | D-08: alaska/hawaii/null |

---

### `lib/core/data/state_data_service.dart` (service, batch/async)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart` (all lines — read directly)

**Copy verbatim, apply renames only** (analog lines 1-53):
```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/state_data.dart';

class StateDataService {
  Future<List<StateData>> loadMapData() async {
    final jsonString =
        await rootBundle.loadString('assets/map/usa_states_paths.json');
    // Decode JSON off main thread — SVG path data is large
    final rawEntries = await compute(_decodeJson, jsonString);
    // dart:ui Path objects must be created on the main thread.
    // Yield every 30 states so the loading indicator can animate.
    final result = <StateData>[];
    for (int i = 0; i < rawEntries.length; i++) {
      result.add(StateData.fromJson(rawEntries[i]));
      if (i % 30 == 29) await Future.delayed(Duration.zero);
    }
    return result;
  }

  static List<Map<String, dynamic>> _decodeJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    return (data['states'] as List).cast<Map<String, dynamic>>();
    //          ↑ 'states' not 'countries' — CRITICAL (Pitfall 7)
  }
}

final stateDataProvider = FutureProvider<List<StateData>>(
  (ref) => StateDataService().loadMapData(),
);
```

**Remove** `loadCountryNames()` and `countryNamesProvider` — no analog needed in Phase 1 (state names are bundled in JSON, not a separate locale file).

---

### `lib/core/ads/ad_service.dart` (interface, request-response)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service.dart`

**Copy verbatim** (all 21 lines — verified):
```dart
import 'package:flutter/widgets.dart';

abstract interface class AdService {
  Widget getBannerWidget();
  Future<void> showInterstitialAd();
  Future<bool> showRewardedAd();
  Future<void> showAppOpenAd();
}
```

No delta. Interface is identical across both apps.

---

### `lib/core/ads/stub_ad_service.dart` (service, request-response)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\stub_ad_service.dart`

**Copy verbatim** (all 21 lines — verified):
```dart
import 'package:flutter/widgets.dart';
import 'ad_service.dart';

class StubAdService implements AdService {
  const StubAdService();

  @override
  Widget getBannerWidget() => const SizedBox.shrink();

  @override
  Future<void> showInterstitialAd() async {}

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  Future<void> showAppOpenAd() async {}
}
```

No delta. Walled garden: returns `SizedBox.shrink()` and `false`; zero ad SDK imports.

---

### `lib/core/ads/ad_service_provider.dart` (provider, request-response)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service_provider.dart` (all lines — read directly)

**Analog (DO NOT COPY VERBATIM — wires real AdMobAdService):**
```dart
// Flags production — not for Phase 1:
import 'admob_ad_service.dart';
final adServiceProvider = Provider<AdService>((ref) {
  final service = AdMobAdService(ref);
  service.preloadAll();
  return service;
});
```

**Phase 1 replacement — wire StubAdService:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_service.dart';
import 'stub_ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return const StubAdService();  // Phase 1-5: never calls preloadAll()
});
```

---

### `lib/core/ads/ad_load_state.dart` (model)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_load_state.dart`

**Copy verbatim** (all 11 lines — verified):
```dart
sealed class AdLoadState {
  const AdLoadState();
}

class AdLoaded extends AdLoadState {
  const AdLoaded();
}

class AdFailed extends AdLoadState {
  const AdFailed();
}
```

---

### `lib/core/ads/ad_constants.dart` (config)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_constants.dart` (all lines — read directly)

**Copy structure, clear all ID strings:**
```dart
// Phase 1 — all unit IDs are empty; replace with real IDs before Play Store submission.
const String kAdMobTestAppId       = '';
const String kBannerAdUnitId       = '';
const String kInterstitialAdUnitId = '';
const String kRewardedAdUnitId     = '';
const String kAppOpenAdUnitId      = '';
const bool   kAppLovinEnabled      = false;
const String kAppLovinSdkKey       = '';
```

---

### `lib/core/audio/audio_service.dart` (interface, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\audio_service.dart` (all lines — read directly)

**Analog base (copy then extend):**
```dart
abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();
  Future<void> setMuted(bool muted);
  Future<void> dispose();
}
```

**Phase 1 addition** — add anthem methods for the placeholder asset and Phase 5 wiring:
```dart
abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();
  Future<void> playAnthem();    // loops anthem_placeholder.wav (Phase 5: real anthem)
  Future<void> stopAnthem();   // stop/fade-out anthem loop
  Future<void> setMuted(bool muted);
  Future<void> dispose();
}
```

---

### `lib/core/audio/stub_audio_service.dart` (service, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\stub_audio_service.dart` (all lines — read directly)

**Copy verbatim then add anthem stubs:**
```dart
import 'audio_service.dart';

class StubAudioService implements AudioService {
  const StubAudioService();

  @override Future<void> init() async {}
  @override Future<void> playCorrect() async {}
  @override Future<void> playError() async {}
  @override Future<void> playAnthem() async {}   // new
  @override Future<void> stopAnthem() async {}   // new
  @override Future<void> setMuted(bool muted) async {}
  @override Future<void> dispose() async {}
}
```

---

### `lib/core/audio/real_audio_service.dart` (service, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\real_audio_service.dart` (all lines — read directly)

**just_audio init pattern** (analog lines 1-27):
```dart
import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_service.dart';

class RealAudioService implements AudioService {
  late AudioPlayer _correctPlayer;
  late AudioPlayer _errorPlayer;
  bool _initialized = false;

  @override
  Future<void> init() async {
    _correctPlayer = AudioPlayer();
    _errorPlayer   = AudioPlayer();
    try {
      await _correctPlayer.setAsset('assets/audio/correct.wav');
      await _errorPlayer.setAsset('assets/audio/error.wav');
      _initialized = true;
    } on PlayerException catch (e) {
      debugPrint('AudioService init failed: $e');
      _initialized = false;
    } catch (e) {
      debugPrint('AudioService init error: $e');
      _initialized = false;
    }
  }
```

**playCorrect pattern — stop/seek/play** (analog lines 30-37):
```dart
  @override
  Future<void> playCorrect() async {
    if (!_initialized) return;
    try {
      await _correctPlayer.stop();
      await _correctPlayer.seek(Duration.zero);
      unawaited(_correctPlayer.play());
    } catch (_) {}
  }
```

**setMuted/dispose pattern** (analog lines 50-64):
```dart
  @override
  Future<void> setMuted(bool muted) async {
    if (!_initialized) return;
    final volume = muted ? 0.0 : 1.0;
    try {
      await _correctPlayer.setVolume(volume);
      await _errorPlayer.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _correctPlayer.dispose();
    await _errorPlayer.dispose();
  }
```

**Phase 1 addition** — add `_anthemPlayer` initialized with `anthem_placeholder.wav`:
```dart
late AudioPlayer _anthemPlayer;

// In init():
await _anthemPlayer.setAsset('assets/audio/anthem_placeholder.wav');
await _anthemPlayer.setLoopMode(LoopMode.one);  // looping for welcome screen

// playAnthem():
Future<void> playAnthem() async {
  if (!_initialized) return;
  try { unawaited(_anthemPlayer.play()); } catch (_) {}
}

// stopAnthem():
Future<void> stopAnthem() async {
  if (!_initialized) return;
  try { await _anthemPlayer.stop(); } catch (_) {}
}
```

---

### `lib/features/home/home_screen.dart` (component, request-response)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\home_screen.dart` (full file — read directly)

**ConsumerStatefulWidget scaffold pattern** (analog lines 17-29):
```dart
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Phase 1: placeholder — no session restore logic yet
  }
  ...
}
```

**FutureProvider.when() loading-state pattern** (analog lines 191-201):
```dart
return Scaffold(
  body: SafeArea(
    child: asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) => _buildBody(context, data),
    ),
  ),
);
```

**Phase 1 scope:** Placeholder scaffold only — a `Scaffold` with a title and a button navigating to `/play`. The full mode card list and high-score loading are Phase 2+.

---

### `lib/features/map/map_screen.dart` (component, request-response)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` (lines 1-60 — read directly)

**ConsumerStatefulWidget + stateDataProvider pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/state_data_service.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statesAsync = ref.watch(stateDataProvider);
    return Scaffold(
      body: statesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading map: $e')),
        data: (states) => CustomPaint(
          painter: UsaMapPainter(states: states),  // Phase 1: blank painter
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
```

**Phase 1 scope:** `UsaMapPainter` is a `CustomPainter` that receives `List<StateData>` and does nothing (blank canvas). This is the end-to-end proof of Success Criterion #5. The full map rendering is Phase 3.

---

## Shared Patterns

### COPPA Init Sequence (from `ads_initializer.dart`)
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ads_initializer.dart` (all lines — read directly)
**Apply to:** `lib/core/ads/ads_initializer.dart` (Phase 1 stub version)

The COPPA init sequence order is mandatory even in stub mode (prevents mis-init if real service is activated later):
```dart
// Correct order — verified in Flags production:
// 1. updateRequestConfiguration  ← BEFORE initialize()
// 2. Mediation SDK COPPA flags   ← BEFORE initialize()
// 3. MobileAds.instance.initialize()  ← LAST
MobileAds.instance.updateRequestConfiguration(
  RequestConfiguration(
    tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
    maxAdContentRating: MaxAdContentRating.g,
  ),
);
// (mediation flags omitted in stub; no real SDK calls)
await MobileAds.instance.initialize();
```

Phase 1 `ads_initializer.dart` keeps the `updateRequestConfiguration` call; the mediation SDK calls are guarded/omitted since stubs have no real SDK dependency.

### Riverpod FutureProvider Pattern
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart` (lines 44-53)
**Apply to:** `lib/core/data/state_data_service.dart`

Top-level (not codegen) `FutureProvider` declared in the service file:
```dart
final stateDataProvider = FutureProvider<List<StateData>>(
  (ref) => StateDataService().loadMapData(),
);
```

### compute() Isolate Pattern
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart` (lines 15-25)
**Apply to:** `lib/core/data/state_data_service.dart`

JSON decode in background, `dart:ui Path` construction on main thread, yield every 30 items:
```dart
final rawEntries = await compute(_decodeJson, jsonString);
for (int i = 0; i < rawEntries.length; i++) {
  result.add(StateData.fromJson(rawEntries[i]));
  if (i % 30 == 29) await Future.delayed(Duration.zero);
}
```

### Abstract Interface + Provider Swap (Walled Garden)
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\` and `lib\core\audio\`
**Apply to:** Both `core/ads/` and `core/audio/` in State States

Pattern: abstract `interface class` + stub impl + `Provider<Interface>` → stub. Screens only import the interface and the provider, never the concrete ad/audio SDK classes. This is the compile-time walled garden: `GameSessionNotifier` must have zero imports from `core/ads/`.

### ProviderScope Override for Audio
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\main.dart` (lines 11-24)
**Apply to:** `lib/main.dart`

```dart
runApp(
  ProviderScope(
    overrides: [
      audioServiceProvider.overrideWith((_) {
        final svc = RealAudioService();
        unawaited(svc.init());
        return svc;
      }),
    ],
    child: const App(),
  ),
);
```

---

## No Analog Found

Files with no close match in either codebase — use RESEARCH.md patterns and external specs:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `LICENSES` (text file) | documentation | — | No analog in Flags (it has no anthem; no LICENSES file exists); structure from RESEARCH.md §Anthem Provenance |
| `assets/audio/anthem_placeholder.wav` | asset | — | Silent 1-second WAV generated via tooling (e.g., `ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 anthem_placeholder.wav`); no Flags analog for a placeholder anthem |

---

## Metadata

**Analog search scope:** `C:\code\Claude\FlagsRoundTheWorld\` (scripts/, lib/, android/)
**Files read:** 18 source files across the reference codebase
**Pattern extraction date:** 2026-05-31

**Confidence summary:**
- Python pipeline structure: HIGH (generate_map.py read directly)
- Albers projection parameters: HIGH (EPSG codes verified, RESEARCH.md)
- Antimeridian fix API: HIGH (antimeridian 0.4.7 installed; RESEARCH.md verified)
- NE shapefile field names: MEDIUM (community-confirmed; verify on first run)
- Inset scale/translate constants: LOW (D-08 ~0.45×; calibrated at pipeline run time)
- All Dart/Flutter patterns: HIGH (all analog files read directly)
- COPPA manifest pattern: HIGH (Flags AndroidManifest.xml read directly)
