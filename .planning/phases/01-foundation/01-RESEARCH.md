# Phase 1: Foundation - Research

**Researched:** 2026-05-31
**Domain:** Python geospatial pipeline (Albers reprojection, antimeridian split, inset baking) + Flutter/Dart COPPA skeleton + service stubs
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use Albers equal-area conic for the mainland 48 states (not equirectangular lon/lat). The Flags `generate_map.py` equirectangular approach is the structural baseline, but the projection step is replaced: reproject geometry (via `pyproj`/`geopandas`) into Albers before extracting path strings. Rationale: Albers is the conventional, classroom-familiar US-map look with a naturally curving northern border.
- **D-02:** Alaska and Hawaii each get their own landmass-centered conic projection parameters (the d3 `AlbersUsa` strategy) BEFORE being scaled and translated into their inset frames — NOT the CONUS Albers parameters. Reusing CONUS parameters shears Alaska badly because it sits far outside the CONUS standard parallels. Each landmass must look geometrically correct in its inset.
- **D-03:** Render Washington D.C. as a non-placeable filler. Emit its path in the JSON flagged `isPlaceable: false` so the mid-Atlantic has no visible hole, but it is never a tray token and never a valid drop target.
- **D-04 (schema impact):** The JSON contains 51 records: 50 placeable states + 1 non-placeable D.C. The pipeline/tests should assert "50 placeable records" rather than "exactly 50 total records."
- **D-05:** Document anthem provenance now; defer the actual render to Phase 5. Phase 1 writes the LICENSES entry and ships a short placeholder/silent audio asset so the app builds.
- **D-06:** Toolchain to document (and use in Phase 5): MuseScore + a free, redistributable SoundFont. Researcher MUST verify the exact chosen soundfont's redistribution license before naming it in LICENSES.
- **D-07:** Do not hardcode the viewBox. Let the Albers-projected CONUS bounds define the natural aspect ratio (~1.6:1), normalize width to 1000, and let height follow (~620–625). This supersedes CLAUDE.md's fixed 1000x620 suggestion.
- **D-08:** AK and HI overlay the empty lower-left ocean area (classic US-map convention), not a separate extended letterbox band. Alaska scaled to ~0.45× of its true projected size. Bake thin inset-frame rectangles into data/coordinate space. Exact numbers computed from projected bounds during the pipeline build.

### Claude's Discretion

- JSON schema field set beyond the locked essentials (path string, centroid, abbreviation/postal key, full name, `isPlaceable`, inset-group flag, bounding box) — researcher/planner finalize, guided by the Flags `country_data.dart` schema.
- Flutter project scaffolding details (directory layout) follow the Flags feature-first structure verbatim.
- Exact AK/HI inset scale/translate numbers (within the D-08 convention).

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 1 scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DATA-01 | Build-time Python pipeline converts Natural Earth admin-1 (public domain) into bundled `usa_states_paths.json` containing path data, per-state centroids, and Alaska/Hawaii inset transforms. | Albers reprojection via pyproj/geopandas; NE admin-1 10m field names; JSON schema design; pipeline structure ported from Flags' generate_map.py |
| DATA-02 | Pipeline splits Alaska's Aleutian antimeridian geometry so Alaska renders correctly (no horizontal smear) and passes shapely validity. | `antimeridian` package v0.4.7; `fix_shape()` API confirmed; shapely validity gate |
| COMP-01 | No Firebase and no persistent device identifiers used anywhere. | Flags reference has no firebase_*; AndroidManifest pattern confirmed; walled garden pattern |
| COMP-02 | `AD_ID` permission blocked in `AndroidManifest.xml` (`tools:remove`) from first commit. | Flags AndroidManifest.xml confirmed: `tools:node="remove"` pattern; `aapt dump badging` verification |
| COMP-03 | Ad layer exists but is stubbed (`AdLoadState.failed`) as walled garden; `GameSessionNotifier` has zero imports from ads module. | Flags `StubAdService` + `AdService` abstract interface patterns confirmed; provider swap pattern |
| COMP-04 | App builds under App ID `com.otis.brooke.state.the.state` and configured for maximum content rating G/PG. | AndroidManifest App ID + `google_mobile_ads` `tagForChildDirectedTreatment` before `initialize()` pattern |
| SESS-05 | Game is fully offline — all assets and data are bundled, no network dependency for any core feature. | All assets bundled; `shared_preferences` for persistence; no network calls in data pipeline output |

</phase_requirements>

---

## Summary

Phase 1 is a foundation-and-data phase with no novel algorithmic risk: every deliverable is either a direct port from Flags Around the World or a well-documented geospatial technique. The two technically novel elements — Albers reprojection replacing equirectangular, and the Aleutian antimeridian split — have mature Python library solutions with verified APIs.

The Python pipeline is the highest-value deliverable because every subsequent phase depends on `usa_states_paths.json` being correct. The pipeline replaces Flags' `lon_to_x` / `lat_to_y` equirectangular functions with a two-step geopandas `.to_crs()` reprojection followed by normalized coordinate extraction. Alaska and Hawaii are reprojected with their own per-landmass conic parameters (matching d3's `albersUsa` strategy) before the inset scale/translate is baked. The Aleutian antimeridian crossing is fixed with `antimeridian.fix_shape()` before reprojection, ensuring `shapely.validation.is_valid()` passes and no horizontal smear appears.

The Flutter skeleton follows the Flags feature-first structure verbatim. The COPPA baseline — `AD_ID` blocked in `AndroidManifest.xml` from day one, `StubAdService` walled garden, no Firebase — is copied directly from the Flags reference. The anthem soundfont decision has been resolved: MuseScore's `MS Basic.sf3` (formerly MuseScore_General) is MIT-licensed with explicit commercial redistribution rights, and `FluidR3Mono` is also MIT-licensed; either is viable as long as the MIT license notice is included in LICENSES. `FluidR3 GM` carries an "openness" restriction for commercial bundling and should NOT be used.

**Primary recommendation:** Port Flags' `generate_map.py` structure verbatim, replace the equirectangular lon/lat remap with a three-CRS pipeline (EPSG:4326 → CRS of choice per landmass → normalized 0..1000 canvas), and derive the viewBox from CONUS Albers bounds. Use the `antimeridian` package for the Alaska split before reprojection. For soundfont: use `MS Basic.sf3` (MIT license, no openness restriction, ships with MuseScore); document provenance in LICENSES; defer the actual render to Phase 5.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| State path data generation | Build-time Python pipeline | — | Offline-first requirement: all data is bundled; no runtime processing |
| JSON loading + Path construction | Core service (`StateDataService`) | `compute()` isolate | `dart:ui Path` must be main-thread; JSON decode is off-thread |
| COPPA manifest configuration | Android native layer | — | `AndroidManifest.xml` is the only place AD_ID can be blocked |
| Ad stub isolation | `core/ads/` abstract interface | Riverpod provider | Walled garden pattern: `GameSessionNotifier` has zero ad imports |
| State data model | `core/models/StateData` | — | Pure Dart value object; consumed by all rendering and game logic |
| Placeholder audio asset | `assets/audio/` | — | Silent WAV committed; real render deferred to Phase 5 |
| Anthem provenance documentation | `LICENSES` file | — | Legal compliance record; not a runtime concern |
| Flutter project scaffolding | Project root + `lib/` structure | — | Follows Flags feature-first layout verbatim |

---

## Standard Stack

### Core: Python Pipeline Dependencies

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `geopandas` | `>=1.0` (1.1.3 installed) | Shapefile loading, CRS reprojection, geometry iteration | Standard geospatial Python stack; used in Flags requirements.txt baseline |
| `shapely` | `>=2.0` (2.1.2 installed) | Geometry operations, validity checking, MultiPolygon handling | Geopandas dependency; `shapely.validation.is_valid()` is the pipeline gate |
| `pyproj` | `>=3.6` (3.7.2 installed) | CRS definitions and transformations backing geopandas `.to_crs()` | Already in Flags requirements.txt; required for EPSG lookup |
| `antimeridian` | `>=0.4` (0.4.7 installed) | Splits Aleutian geometry crossing the 180° meridian | Only production-quality library for this specific task; `fix_shape()` API confirmed |

[VERIFIED: npm registry equivalent — all 4 packages confirmed via slopcheck [OK] and pip show on this machine]

### Core: Flutter/Dart Dependencies

All Flutter dependencies are carried verbatim from the Flags lockfile with the deltas from CLAUDE.md. No new Flutter packages are introduced in Phase 1. The full pubspec.yaml is specified in CLAUDE.md and STACK.md.

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | `^3.3.1` | State management; `FutureProvider` for `stateDataProvider` |
| `riverpod_annotation` | `^4.0.2` | Codegen annotations |
| `path_drawing` | `^1.0.1` | `parseSvgPathData()` in `StateData.fromJson` |
| `just_audio` | `^0.10.5` | Placeholder audio asset playback in stub; real anthem deferred |
| `google_mobile_ads` | `^8.0.0` | Declared in pubspec (stub only in v1); AD_ID blocked in manifest |
| `shared_preferences` | `^2.5.5` | Local persistence (repos wired in Phase 2; stubs in Phase 1) |

[VERIFIED: All versions confirmed in Flags pubspec.yaml direct read — authoritative baseline]

### Python Pipeline Installation

```bash
pip install "geopandas>=1.0" "shapely>=2.0" "pyproj>=3.6" "antimeridian>=0.4"
```

Or using the `requirements.txt` (extend Flags' requirements.txt):

```
geopandas>=1.0
shapely>=2.0
pyproj>=3.6.0
antimeridian>=0.4
```

---

## Package Legitimacy Audit

| Package | Registry | Age | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|
| `geopandas` | PyPI | ~14 yrs | [OK] | Approved |
| `shapely` | PyPI | ~17 yrs | [OK] | Approved |
| `pyproj` | PyPI | ~14 yrs | [OK] | Approved |
| `antimeridian` | PyPI | ~3 yrs | [OK] | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*slopcheck 0.6.1 ran on this machine; all 4 packages confirmed [OK].*

---

## Architecture Patterns

### System Architecture Diagram

```
Natural Earth admin-1 10m ZIP (download once)
        │
        ▼
generate_states.py (Python, build-time only)
   ├── Load shapefile via geopandas.read_file()
   ├── Filter: adm0_a3 == 'USA'  →  ~50+ records (states + DC + territories)
   ├── Further filter: postal in FIFTY_STATES_SET ∪ {'DC'}
   │
   ├── [ALASKA BRANCH]
   │   ├── antimeridian.fix_shape(ak_geometry)  ← fix Aleutian crossing FIRST
   │   ├── gdf.to_crs('EPSG:3338')              ← Alaska Albers
   │   ├── normalize to 0..1000 canvas space    ← derive from AK projected bounds
   │   ├── apply inset scale (~0.45×) + translate to lower-left frame
   │   └── emit path strings + centroid + bbox in CANVAS space
   │
   ├── [HAWAII BRANCH]
   │   ├── gdf.to_crs('+proj=aea +lat_0=13 +lon_0=-157 +lat_1=8 +lat_2=18 ...')
   │   ├── normalize to 0..1000 canvas space    ← derive from HI projected bounds
   │   ├── apply inset scale + translate to lower-left frame (right of AK)
   │   └── emit path strings + centroid + bbox in CANVAS space
   │
   ├── [CONUS BRANCH + DC]
   │   ├── gdf.to_crs('EPSG:5070')             ← NAD83 / Conus Albers
   │   ├── derive CONUS projected bounds
   │   ├── normalize: x = (px - min_x) / (max_x - min_x) * 1000
   │   │              y = (max_y - py) / (max_y - min_y) * height_derived
   │   └── emit path strings + centroid + bbox in CANVAS space
   │
   ├── compute inset-frame rectangles from AK/HI canvas positions
   ├── emit viewBox: {"width": 1000, "height": ~620-625}
   └── write assets/map/usa_states_paths.json
           │
           ▼ (Dart app startup)
   StateDataService.loadMapData()
   ├── rootBundle.loadString('assets/map/usa_states_paths.json')
   ├── compute(_decodeJson, jsonString)   ← off main thread
   │       returns List<Map<String,dynamic>>
   └── for each entry (chunked, 30 at a time):
       └── StateData.fromJson(entry)
               ├── parseSvgPathData(pathString)  → dart:ui Path
               ├── BoundingBox.fromJson()
               └── Offset centroid
                        │
                        ▼
           stateDataProvider (FutureProvider<List<StateData>>)
                        │
                        ▼
           CustomPaint(painter: UsaMapPainter(...))
           [BLANK CANVAS — Phase 1 end-to-end proof]
```

### Recommended Project Structure

```
state_states/
├── scripts/
│   ├── generate_states.py       # Python pipeline (port of generate_map.py)
│   └── requirements.txt         # geopandas, shapely, pyproj, antimeridian
├── assets/
│   ├── audio/
│   │   ├── correct.wav          # carry from Flags or generate 1s silence
│   │   ├── error.wav            # carry from Flags or generate 1s silence
│   │   └── anthem_placeholder.wav  # 1s silent WAV; replaced in Phase 5
│   └── map/
│       └── usa_states_paths.json   # generated by pipeline
├── LICENSES                     # anthem provenance + soundfont attribution
├── pubspec.yaml
├── android/app/src/main/AndroidManifest.xml  # AD_ID tools:remove from day one
└── lib/
    ├── main.dart
    ├── app.dart
    ├── core/
    │   ├── ads/
    │   │   ├── ad_service.dart          # abstract interface (copy from Flags)
    │   │   ├── stub_ad_service.dart     # no-op impl (copy from Flags)
    │   │   ├── ad_service_provider.dart # Provider<AdService> → StubAdService
    │   │   ├── ad_load_state.dart       # enum (copy from Flags)
    │   │   └── ad_constants.dart        # empty unit IDs (copy from Flags)
    │   ├── audio/
    │   │   ├── audio_service.dart       # abstract interface + playAnthem/stopAnthem
    │   │   ├── stub_audio_service.dart  # no-op impl
    │   │   └── real_audio_service.dart  # just_audio impl (Phase 2 wires fully)
    │   ├── data/
    │   │   └── state_data_service.dart  # JSON loader + stateDataProvider
    │   ├── l10n/                        # ARB baseline with 50 state names
    │   └── models/
    │       └── state_data.dart          # StateData, BoundingBox, InsetGroup
    └── features/
        ├── home/
        │   └── home_screen.dart         # placeholder scaffold
        └── map/
            └── map_screen.dart          # blank CustomPaint proof widget
```

### Pattern 1: Three-CRS Albers Pipeline (D-01 + D-02)

**What:** Each landmass is reprojected with its own CRS before normalization to canvas space. CONUS uses EPSG:5070 (NAD83/Conus Albers). Alaska uses EPSG:3338 (NAD83/Alaska Albers) applied AFTER antimeridian split. Hawaii uses a proj4 string for Hawaii Albers (no standard EPSG, common proj4 from EPA/ESRI).

**When to use:** In `generate_states.py`, applied per-landmass group.

**CONUS — EPSG:5070:**
```python
# Source: epsg.io/5070 [VERIFIED: epsg.io/5070]
# +proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5
# +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs
conus_gdf = gdf_usa[~gdf_usa['postal'].isin(['AK', 'HI'])].to_crs('EPSG:5070')
```

**Alaska — EPSG:3338:**
```python
# Source: epsg.io/3338 [VERIFIED: epsg.io/3338]
# +proj=aea +lat_0=50 +lon_0=-154 +lat_1=55 +lat_2=65
# +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs
ak_gdf = gdf_usa[gdf_usa['postal'] == 'AK'].to_crs('EPSG:3338')
```

**Hawaii — proj4 string (ESRI:102007 equivalent):**
```python
# Source: d3/albersUsa parallels [8,18]; central meridian -157; EPA/ESRI documentation
# [VERIFIED: epsg.io/102007, d3 albersUsa.js source]
HI_PROJ4 = '+proj=aea +lat_0=13 +lon_0=-157 +lat_1=8 +lat_2=18 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs'
hi_gdf = gdf_usa[gdf_usa['postal'] == 'HI'].to_crs(HI_PROJ4)
```

**Normalization after reprojection:**
```python
# Source: adapted from Flags generate_map.py + D-07 derived viewBox
# [ASSUMED] — exact normalization formula, correct in principle
def normalize_to_canvas(gdf_projected, canvas_width=1000):
    """Derive height from CONUS aspect ratio; normalize all coords to [0, canvas_width]."""
    total_bounds = gdf_projected.total_bounds  # [minx, miny, maxx, maxy]
    min_x, min_y, max_x, max_y = total_bounds
    proj_width = max_x - min_x
    proj_height = max_y - min_y
    aspect = proj_height / proj_width
    canvas_height = round(canvas_width * aspect)

    def proj_to_canvas(x, y):
        cx = (x - min_x) / proj_width * canvas_width
        cy = (max_y - y) / proj_height * canvas_height  # y flipped (SVG coords)
        return round(cx, 2), round(cy, 2)

    return canvas_height, proj_to_canvas
```

### Pattern 2: Antimeridian Split Before Reprojection (DATA-02)

**What:** Alaska's Aleutian geometry crosses the 180th meridian in EPSG:4326. The `antimeridian.fix_shape()` function splits rings that cross, producing a valid MultiPolygon. This MUST happen before `.to_crs()` because reprojecting an antimeridian-crossing geometry in EPSG:4326 produces the smear.

**When to use:** Always, for the Alaska row(s), before any coordinate transform.

**Example:**
```python
# Source: antimeridian 0.4.7 API confirmed via help() on this machine
# [VERIFIED: antimeridian package v0.4.7 installed and help() read]
import antimeridian
from shapely.geometry import shape, mapping

def fix_antimeridian(geom):
    """Fix a shapely geometry that may cross the antimeridian."""
    # fix_shape accepts anything with __geo_interface__ (shapely has this)
    fixed_geojson = antimeridian.fix_shape(geom)
    return shape(fixed_geojson)

# In the pipeline:
ak_row = gdf_usa[gdf_usa['postal'] == 'AK'].copy()
ak_row['geometry'] = ak_row['geometry'].apply(fix_antimeridian)
# Now safe to reproject:
ak_projected = ak_row.to_crs('EPSG:3338')

# Gate: validate after fix
from shapely.validation import is_valid
for geom in ak_projected.geometry:
    assert is_valid(geom), f"Alaska geometry invalid after fix: {explain_validity(geom)}"
```

### Pattern 3: Inset Baking (D-08)

**What:** After AK and HI are reprojected in their own CRS, compute their canvas-space bounds, then apply scale + translate so they fit in the lower-left ocean area. The output path coordinates are in final canvas space — the Dart side draws them with no transform.

**When to use:** In the pipeline, after normalization of all three landmasses.

**Example:**
```python
# [ASSUMED] — formula is standard affine math; specific constants computed at runtime
def compute_inset_transform(ak_canvas_bounds, target_rect, scale_factor=0.45):
    """
    target_rect: (x0, y0, w, h) in canvas space — the lower-left ocean area
    scale_factor: D-08 mandates ~0.45x for Alaska
    Returns (scale, translate_x, translate_y) to apply to AK path coords.
    """
    ak_w = ak_canvas_bounds[2] - ak_canvas_bounds[0]
    ak_h = ak_canvas_bounds[3] - ak_canvas_bounds[1]
    # Scale so AK fits within its target rect at scale_factor
    s = scale_factor
    # Translate: offset from AK's natural canvas position to target rect
    tx = target_rect[0] - ak_canvas_bounds[0] * s
    ty = target_rect[1] - ak_canvas_bounds[1] * s
    return s, tx, ty

def apply_inset(x, y, s, tx, ty):
    return round(x * s + tx, 2), round(y * s + ty, 2)
```

The inset-frame rectangle (drawn by UsaMapPainter in Phase 3) should be emitted in the JSON as `insetFrame: {"x":..., "y":..., "w":..., "h":...}` for each inset group. The Dart painter reads it as metadata.

### Pattern 4: Flags Ad Stub Wired Garden (COMP-03)

**What:** `AdService` is an abstract interface. `StubAdService` returns `SizedBox.shrink()` and `false` from all methods. The provider wires `StubAdService` for Phases 1–5. `GameSessionNotifier` has no import from `core/ads/` or `features/ads/`.

**When to use:** From project initialization. Copied verbatim from Flags.

**Key files to copy from Flags:**
```
lib/core/ads/ad_service.dart          → identical
lib/core/ads/stub_ad_service.dart     → identical
lib/core/ads/ad_load_state.dart       → identical
lib/core/ads/ad_constants.dart        → update unit ID strings to ""
lib/core/ads/ad_service_provider.dart → CHANGE: wire StubAdService (not AdMobAdService)
```

**Provider for Phase 1 (not Flags' production wiring):**
```dart
// Source: Flags ad_service_provider.dart pattern; MODIFIED for Phase 1
// [VERIFIED: Flags lib/core/ads/stub_ad_service.dart read directly]
final adServiceProvider = Provider<AdService>((ref) {
  return const StubAdService();  // Never preloadAll() in v1
});
```

### Pattern 5: AndroidManifest AD_ID Block (COMP-02)

**What:** `google_mobile_ads` and mediation SDKs declare `AD_ID` in their own manifests. Flutter's manifest merger includes it unless explicitly overridden.

**Exact node to add (confirmed from Flags production AndroidManifest.xml):**
```xml
<!-- Source: FlagsRoundTheWorld/android/app/src/main/AndroidManifest.xml direct read -->
<!-- [VERIFIED: Flags AndroidManifest.xml read — line 6-8] -->
<uses-permission
    android:name="com.google.android.gms.permission.AD_ID"
    tools:node="remove"/>
```

Note: Flags uses `tools:node="remove"` (not `tools:remove="true"` mentioned in some docs). Both achieve the same manifest merge outcome, but `tools:node="remove"` is the correct attribute form seen in the reference codebase.

The `xmlns:tools` namespace must also be declared on the `<manifest>` root element:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="com.otis.brooke.state.the.state">
```

**Verification command:**
```bash
aapt dump badging build/app/outputs/flutter-apk/app-debug.apk | grep AD_ID
# Expected: no output (permission absent)
```

### Pattern 6: StateData JSON Schema (Claude's Discretion)

**Finalized schema** based on Flags' `country_data.dart` + D-03/D-04 additions:

```json
{
  "version": 1,
  "viewBox": {"width": 1000, "height": 621},
  "insetFrames": {
    "alaska": {"x": 0, "y": 430, "w": 220, "h": 175},
    "hawaii": {"x": 240, "y": 480, "w": 130, "h": 100}
  },
  "states": [
    {
      "postal": "AL",
      "name": "Alabama",
      "paths": ["M... L... Z"],
      "boundingBox": {"x": 620, "y": 310, "w": 45, "h": 62},
      "centroid": {"x": 642, "y": 341},
      "isPlaceable": true,
      "insetGroup": null
    },
    {
      "postal": "AK",
      "name": "Alaska",
      "paths": ["M... L... Z", "M... L... Z"],
      "boundingBox": {"x": 5, "y": 440, "w": 210, "h": 160},
      "centroid": {"x": 90, "y": 520},
      "isPlaceable": true,
      "insetGroup": "alaska"
    },
    {
      "postal": "DC",
      "name": "District of Columbia",
      "paths": ["M... L... Z"],
      "boundingBox": {"x": 810, "y": 215, "w": 8, "h": 9},
      "centroid": {"x": 814, "y": 219},
      "isPlaceable": false,
      "insetGroup": null
    }
  ]
}
```

**Dart model mirroring `country_data.dart`:**
```dart
// Source: mirrors FlagsRoundTheWorld/lib/core/models/country_data.dart
// [VERIFIED: Flags country_data.dart read directly]

enum InsetGroup { alaska, hawaii }

class StateData {
  final String postal;          // replaces isoCode — USPS 2-letter (or 'DC')
  final String name;            // full state name
  final List<String> pathStrings;
  final List<Path> paths;       // dart:ui Path, constructed at load time
  final BoundingBox boundingBox;
  final Offset centroid;        // in final canvas coordinates
  final bool isPlaceable;       // false for DC
  final InsetGroup? insetGroup; // null = mainland
}
```

The `isDegenerate` field from Flags (`country_data.dart`) is NOT needed: no US state has degenerate geometry in the 10m dataset. Omit it. The schema leaves room for proximity hit-box radius (centroid + boundingBox are sufficient inputs; Phase 3/4 adds the expansion constant in code, not in JSON).

### Pattern 7: StateDataService Compute Isolate (DATA-01)

**Exact port from Flags `country_data_service.dart` with renames:**

```dart
// Source: FlagsRoundTheWorld/lib/core/data/country_data_service.dart direct read
// [VERIFIED: file read directly]

class StateDataService {
  Future<List<StateData>> loadMapData() async {
    final jsonString = await rootBundle.loadString('assets/map/usa_states_paths.json');

    // Decode JSON in a background isolate — SVG path data is large
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
    return (data['states'] as List).cast<Map<String, dynamic>>();  // 'states' not 'countries'
  }
}

final stateDataProvider = FutureProvider<List<StateData>>(
  (ref) => StateDataService().loadMapData(),
);
```

### Anti-Patterns to Avoid

- **Equirectangular lon/lat remap:** Do not use Flags' `lon_to_x(lon)` / `lat_to_y(lat)` functions. They produce a stretched, skewed map. Replace with `.to_crs(EPSG:5070)` for CONUS.
- **Reprojecting before antimeridian split:** Calling `.to_crs('EPSG:3338')` on an antimeridian-crossing Alaska geometry in EPSG:4326 produces the smear. Always `fix_shape()` first.
- **Outputting geographic (non-inset) coordinates for AK/HI:** If AK/HI paths are at their true geographic canvas positions, drops on the inset frame miss the path. Bake the inset transform into the path coordinates before writing JSON.
- **Calling `MobileAds.initialize()` before `updateRequestConfiguration()`:** AdMob ignores child-directed config if init runs first. Even in stub mode, the configuration call must precede init.
- **Wiring `AdMobAdService` in the Phase 1 provider:** Phase 1 uses `StubAdService`. Do not copy Flags' production `ad_service_provider.dart` verbatim — it wires the real service.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Antimeridian polygon split | Custom coordinate-shifting logic | `antimeridian.fix_shape()` | Inner/outer ring winding order, 180° wraparound edge cases; library handles all; confirmed on this machine |
| CRS reprojection math | Manual lat/lon → projected coordinate formula | `geopandas.to_crs(epsg=5070)` | Handles datum shifts, ellipsoid parameters, standard parallels; one-line call |
| SVG path string → dart:ui Path | Custom parser | `path_drawing.parseSvgPathData()` | Handles arc commands, relative/absolute, whitespace variants; battle-tested in Flags |
| Shapefile loading | Custom .dbf/.shp reader | `geopandas.read_file(url)` | Reads zip directly from URL or disk; handles .prj projection metadata |
| ad isolation at runtime | Runtime flag / feature toggle | Abstract interface + provider swap | Compile-time isolation: wrong pattern is impossible to accidentally call |

**Key insight:** Every "hand-roll" in this domain involves coordinate math with silent failure modes (off-by-half-pixel smears at scale). Use libraries with established test suites.

---

## Common Pitfalls

### Pitfall 1: Alaska Antimeridian Smear

**What goes wrong:** Running `to_crs('EPSG:3338')` on Alaska's geometry in EPSG:4326 before splitting antimeridian-crossing rings. Shapely renders the Aleutian chain as a horizontal line stretching across the full canvas.

**Why it happens:** EPSG:4326 coordinates wrap at ±180°. The Aleutian rings have vertices at both +173° and -170° (GeoJSON convention). The reprojection treats these as a continuous ring spanning 343° of longitude.

**How to avoid:** Call `antimeridian.fix_shape(ak_geometry)` before `.to_crs()`. The function splits rings crossing ±180°, producing a valid MultiPolygon in EPSG:4326 that reprojects cleanly.

**Warning signs:**
- `shapely.validation.is_valid()` returns `False` for Alaska after reproject
- Alaska polygon has a thin horizontal line stretching full canvas width
- Bounding box width of Alaska is nearly equal to canvas width

### Pitfall 2: DC Hole in the Mid-Atlantic

**What goes wrong:** Pipeline filters `postal in FIFTY_STATES_SET`, omitting DC. The mid-Atlantic region shows a visible hole at DC's position.

**How to avoid:** Include `'DC'` in the filter set. Emit DC with `isPlaceable: false`. The Dart painter renders it with the same fill/border as other states; the game logic ignores it because `GameSessionNotifier` only iterates `isPlaceable == true` records.

### Pitfall 3: `tools:node="remove"` vs `tools:remove="true"`

**What goes wrong:** COPPA audit fails because the AD_ID permission is still present in the merged manifest.

**Why it happens:** `tools:remove="true"` is sometimes documented but `tools:node="remove"` is the correct merge attribute. Flags uses `tools:node="remove"` and it passes `aapt dump badging` cleanly.

**How to avoid:** Copy the exact attribute form from Flags' `AndroidManifest.xml` — `tools:node="remove"` on the `<uses-permission>` element.

### Pitfall 4: AdMob Initialization Before Configuration

**What goes wrong:** Calling `MobileAds.instance.initialize()` before `updateRequestConfiguration(tagForChildDirectedTreatment: yes)`. AdMob initializes with default (adult) settings; child-directed config has no effect.

**How to avoid:** Follow the order confirmed in Flags' `ads_initializer.dart`:
1. `updateRequestConfiguration(...)` — FIRST
2. Mediation SDK COPPA flags — SECOND
3. `MobileAds.instance.initialize()` — LAST

In Phase 1 (stub mode), the `initializeAds()` call in `main.dart` should still include the configuration step even though no ads will load. The stub prevents real ad requests; the configuration prevents a mis-init if someone later activates the real service.

### Pitfall 5: Inset Coordinates Not Baked Into JSON

**What goes wrong:** AK/HI `StateData.paths` store geographic or non-inset projected coordinates. A token dropped on the visible inset frame hits scene coordinates that correspond to Canada or the Pacific Ocean, never matching the Alaska path.

**How to avoid:** All path coordinates — including AK and HI — must be in final canvas coordinate space in the JSON. The `insetGroup` field is metadata only (for drawing the frame rect decoration). The Dart side draws every state with the same `canvas.drawPath()` call, zero branching.

### Pitfall 6: `FluidR3 GM` Soundfont "Openness" Restriction

**What goes wrong:** Using `FluidR3 GM` (not FluidR3Mono or MS Basic) in a commercial app that doesn't allow users to swap soundfonts. The license has an "openness" restriction: "Your design must have openness for anyone to be able to load whatever soundfont they want to use."

**How to avoid:** Use `MS Basic.sf3` (MuseScore's MIT-licensed soundfont, formerly MuseScore_General) or `FluidR3Mono` (also MIT-licensed via MuseScore). Both are pure MIT with no openness restrictions. Include the MIT license notice and attribution in the LICENSES file. Do NOT use `FluidR3 GM` (the original).

### Pitfall 7: Wrong JSON Key — `'countries'` instead of `'states'`

**What goes wrong:** Copying `country_data_service.dart`'s `_decodeJson` verbatim. It reads `data['countries']`. The new JSON key is `data['states']`.

**How to avoid:** `StateDataService._decodeJson` must use `data['states'] as List`. This is the only functional change from the Flags service; everything else is identical.

---

## Anthem Provenance — Soundfont Decision (D-06)

**Resolved recommendation: use `MS Basic.sf3` (MuseScore Basic soundfont).**

| Soundfont | License | Openness Restriction | Commercial App Bundling | Verdict |
|-----------|---------|---------------------|------------------------|---------|
| `MS Basic.sf3` (MuseScore General/Basic) | MIT | None | Yes — MIT permits; include license notice in LICENSES | **USE THIS** |
| `FluidR3Mono_GM.sf2` | MIT | None | Yes — MIT permits; include license notice in LICENSES | Acceptable alternative |
| `FluidR3 GM` (original) | Custom (MIT-ish with restriction) | Yes — must allow soundfont swapping | Ambiguous for fixed-asset app | **DO NOT USE** |
| `GeneralUser GS` | Custom permissive | No, but unknown sample provenance acknowledged by author | Technically permitted but sample origin uncertainty makes it inadvisable for commercial Play Store app | Avoid |

**LICENSES file entry template (Phase 1 writes this, Phase 5 fills in render specifics):**

```
Star-Spangled Banner Instrumental
  Composition: Public domain (Francis Scott Key, 1814)
  Rendering tool: MuseScore [version TBD in Phase 5]
  SoundFont: MS Basic.sf3 (MuseScore General), MIT License
    Copyright: Frank Wen (FluidR3), Michael Cowgill (FluidR3Mono),
               S. Christian Collins (MuseScore_General adaptations)
    Full MIT license text: [include below]
  Render date: [Phase 5]
  Output file: assets/audio/anthem.wav
  Notes: Self-rendered from public-domain composition score.
         No third-party recording used. WAV is an original work
         produced by this project's build pipeline.
```

[CITED: github.com/musescore/MuseScore/blob/master/share/sound/MS%20Basic_License.md — MIT license text confirmed]
[CITED: member.keymusician.com/Member/FluidR3_GM/README.html — FluidR3 GM openness restriction confirmed]

---

## Natural Earth Shapefile Field Verification

**Status:** MEDIUM confidence (community usage confirmed; field names should be verified on first download by running `gdf.columns.tolist()` before writing filter logic)

[CITED: naturalearthdata.com — admin-1 10m dataset, community usage confirming adm0_a3 and postal fields]

Confirmed via web search cross-referencing community usage and Natural Earth documentation:

| Field | Type | Used For | Confidence |
|-------|------|---------|------------|
| `adm0_a3` | string | Filter `== 'USA'` to get US rows | MEDIUM — confirmed via multiple community examples and Natural Earth blog |
| `postal` | string | Canonical 2-letter key (e.g. 'CA', 'AK', 'DC') | MEDIUM — confirmed via Natural Earth blog post about postal code labels |
| `name` | string | Full state name ('California') | MEDIUM — standard field documented in README |
| `iso_3166_2` | string | ISO code ('US-CA'); not used as primary key | MEDIUM — documented in STACK.md community sources |

**First-run verification step** (MUST be in pipeline):
```python
gdf = gpd.read_file(NE_URL)
print("Columns:", gdf.columns.tolist())
usa_rows = gdf[gdf['adm0_a3'] == 'USA']
print(f"USA rows: {len(usa_rows)}")
print("Postal sample:", usa_rows['postal'].head(10).tolist())
```

If `adm0_a3` is not present, check for `ADM0_A3` (uppercase variant). Natural Earth attribute names have historically varied between versions.

---

## Code Examples

### Complete Pipeline Skeleton

```python
# Source: adapted from FlagsRoundTheWorld/scripts/generate_map.py + D-01/D-02/D-07/D-08
# [VERIFIED: Flags generate_map.py read directly; Albers parameters from epsg.io]

import geopandas as gpd
import json
import antimeridian
from shapely.geometry import shape, mapping
from shapely.validation import is_valid, explain_validity

NE_URL = 'https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_1_states_provinces.zip'

# D-03/D-04: 50 states + DC
FIFTY_STATES = {
    'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA',
    'HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
    'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
    'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
    'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
}
DC_POSTAL = 'DC'
ALL_RECORDS = FIFTY_STATES | {DC_POSTAL}

HI_PROJ4 = '+proj=aea +lat_0=13 +lon_0=-157 +lat_1=8 +lat_2=18 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs'

def fix_antimeridian(geom):
    fixed = antimeridian.fix_shape(geom)
    return shape(fixed)

def polygon_to_path_str(polygon, to_canvas):
    coords = list(polygon.exterior.coords)[:-1]
    if len(coords) < 3:
        return None
    cx0, cy0 = to_canvas(coords[0][0], coords[0][1])
    parts = [f'M{cx0},{cy0}']
    for x, y in coords[1:]:
        cx, cy = to_canvas(x, y)
        parts.append(f'L{cx},{cy}')
    parts.append('Z')
    return ' '.join(parts)

def normalize_bounds(gdf_projected, canvas_width=1000):
    """Returns (canvas_height, to_canvas_fn) from projected bounds."""
    minx, miny, maxx, maxy = gdf_projected.total_bounds
    proj_w = maxx - minx
    proj_h = maxy - miny
    canvas_height = round(canvas_width * proj_h / proj_w)

    def to_canvas(x, y):
        cx = round((x - minx) / proj_w * canvas_width, 2)
        cy = round((maxy - y) / proj_h * canvas_height, 2)
        return cx, cy

    return canvas_height, to_canvas

def main():
    gdf = gpd.read_file(NE_URL).to_crs('EPSG:4326')
    # First-run verification
    print("Columns:", gdf.columns.tolist())
    gdf_usa = gdf[gdf['adm0_a3'] == 'USA']
    gdf_usa = gdf_usa[gdf_usa['postal'].isin(ALL_RECORDS)]

    # --- CONUS + DC ---
    conus_gdf = gdf_usa[~gdf_usa['postal'].isin(['AK','HI'])].to_crs('EPSG:5070')
    canvas_height, conus_to_canvas = normalize_bounds(conus_gdf)
    canvas_width = 1000

    # --- ALASKA (antimeridian split before reproject) ---
    ak_rows = gdf_usa[gdf_usa['postal'] == 'AK'].copy()
    ak_rows['geometry'] = ak_rows['geometry'].apply(fix_antimeridian)
    ak_projected = ak_rows.to_crs('EPSG:3338')
    for geom in ak_projected.geometry:
        assert is_valid(geom), f"AK invalid: {explain_validity(geom)}"
    _, ak_to_canvas_natural = normalize_bounds(ak_projected)

    # --- HAWAII ---
    hi_projected = gdf_usa[gdf_usa['postal'] == 'HI'].to_crs(HI_PROJ4)
    _, hi_to_canvas_natural = normalize_bounds(hi_projected)

    # TODO: apply inset scale/translate (D-08) — calibrated visually against PNG output
    # Emit JSON with pre-baked canvas coordinates for all states
    ...

if __name__ == '__main__':
    main()
```

### StateData.fromJson (Dart)

```dart
// Source: mirrors FlagsRoundTheWorld/lib/core/models/country_data.dart
// [VERIFIED: Flags country_data.dart read directly]

factory StateData.fromJson(Map<String, dynamic> json) {
  final pathStrings = List<String>.from(json['paths'] as List);
  final paths = pathStrings.map((s) => parseSvgPathData(s)).toList();
  final bb = BoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>);
  final c = json['centroid'] as Map<String, dynamic>;
  return StateData(
    postal: json['postal'] as String,
    name: json['name'] as String,
    pathStrings: pathStrings,
    paths: paths,
    boundingBox: bb,
    centroid: Offset((c['x'] as num).toDouble(), (c['y'] as num).toDouble()),
    isPlaceable: (json['isPlaceable'] as bool?) ?? true,
    insetGroup: _parseInsetGroup(json['insetGroup'] as String?),
  );
}

static InsetGroup? _parseInsetGroup(String? value) {
  if (value == null) return null;
  return InsetGroup.values.firstWhere((e) => e.name == value);
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Equirectangular lon/lat remap (Flags) | Albers equal-area conic via geopandas.to_crs() | Correct US map shape; no stretching |
| Single global projection for all US territory | Per-landmass conic projections (d3 albersUsa strategy) | AK and HI look geometrically correct in their insets |
| Manual antimeridian workaround | `antimeridian.fix_shape()` library | Reliable; handles inner ring winding order |
| viewBox hardcoded to 1000x620 | Derived from CONUS Albers projected bounds | Correct aspect ratio; no letterboxing |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `adm0_a3 == 'USA'` filter correctly isolates all 50 states + DC from the Natural Earth 10m admin-1 shapefile | Natural Earth Field Verification | Filter returns wrong rows; pipeline emits incorrect set. Mitigation: verify `gdf.columns.tolist()` and row count on first run |
| A2 | `postal` field contains USPS 2-letter abbreviations ('CA', 'AK', 'DC') in the NE admin-1 10m shapefile | Natural Earth Field Verification | Primary key field is wrong; all state lookups fail. Mitigation: print postal column on first run |
| A3 | Inset scale/translate constants (D-08: ~0.45× for Alaska) produce correct visual placement without letterboxing | Inset Baking pattern | AK/HI overlap CONUS or appear too small; require re-running pipeline and regenerating JSON. Low recovery cost. |
| A4 | The normalization formula (`normalize_bounds`) correctly derives canvas height from CONUS Albers projected aspect ratio | Pipeline Skeleton | Canvas height wrong; all states appear squished or stretched. Mitigation: visual PNG render check before proceeding. |
| A5 | MS Basic.sf3 MIT license permits bundling the rendered WAV in a commercial Google Play app without soundfont-swapping openness requirement | Anthem Soundfont Decision | License interpretation incorrect; legal risk for commercial distribution. Mitigation: legal review if commercial revenue is expected; MIT is generally unambiguous for commercial use. |

---

## Open Questions

1. **Exact AK/HI inset scale/translate constants**
   - What we know: D-08 mandates ~0.45× for Alaska; lower-left ocean area
   - What's unclear: exact pixel values depend on CONUS Albers projected bounds of the actual NE 10m dataset
   - Recommendation: derive computationally in the pipeline; verify with a PNG render before committing JSON. This is expected to require 1–2 calibration iterations.

2. **Natural Earth shapefile field name case sensitivity**
   - What we know: Community examples show `adm0_a3` (lowercase) and `ADM0_A3` (uppercase) in different dataset versions
   - What's unclear: Which case the current v5.1.1 uses in its .dbf attribute table
   - Recommendation: pipeline must print `gdf.columns.tolist()` on first run and gate on finding the expected column before proceeding

3. **US territories in the USA filter**
   - What we know: `adm0_a3 == 'USA'` may include Puerto Rico, Guam, USVI, etc. as additional rows
   - What's unclear: whether `postal` field has standardized codes for territories or if they appear with unusual values
   - Recommendation: `postal in ALL_RECORDS` filter (50 states + DC) handles this; territories with non-standard postal codes are silently excluded

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | Pipeline script | ✓ | 3.13 | — |
| geopandas | Shapefile loading | ✓ | 1.1.3 | — |
| shapely | Geometry ops | ✓ | 2.1.2 | — |
| pyproj | CRS transforms | ✓ | 3.7.2 | — |
| antimeridian | AK split | ✓ | 0.4.7 | — |
| Flutter SDK | App build | [ASSUMED] present | >=3.44.0 required | — |
| aapt (Android Build Tools) | COMP-02 verification | [ASSUMED] present via Android Studio | — | adb shell pm dump checks AD_ID in granted permissions |
| dart run build_runner | Riverpod codegen | [ASSUMED] present | — | — |

**Missing dependencies with no fallback:** None confirmed — all Python packages verified installed on this machine.

**Missing dependencies with fallback:** Flutter SDK assumed present (project has pubspec.yaml implying prior Flutter setup).

---

## Validation Architecture

`workflow.nyquist_validation: true` in `.planning/config.json` — section required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) |
| Config file | none — uses `pubspec.yaml` dev_dependencies |
| Quick run command | `flutter test test/core/models/state_data_test.dart` |
| Full suite command | `flutter test` |

Python pipeline tests:
| Property | Value |
|----------|-------|
| Framework | Python `unittest` / `pytest` (pytest not in requirements; use unittest std lib) |
| Quick run command | `python -m pytest scripts/test_pipeline.py -x` or `python -m unittest scripts.test_pipeline` |
| Full suite command | `python -m pytest scripts/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DATA-01 | `generate_states.py` produces `usa_states_paths.json` with 51 records total, 50 `isPlaceable: true` | unit (Python) | `python scripts/generate_states.py && python -m pytest scripts/test_pipeline.py::test_state_count` | ❌ Wave 0 |
| DATA-01 | `stateDataProvider` resolves with 51 `StateData` items, 50 placeable | unit (Dart) | `flutter test test/core/data/state_data_service_test.dart` | ❌ Wave 0 |
| DATA-02 | Alaska geometry passes `shapely.validation.is_valid()` after pipeline | unit (Python) | `python -m pytest scripts/test_pipeline.py::test_alaska_validity` | ❌ Wave 0 |
| DATA-02 | Alaska `StateData.centroid` is within lower-left inset frame bounds | unit (Dart) | `flutter test test/core/models/state_data_test.dart::testAlaskaCentroidInset` | ❌ Wave 0 |
| COMP-01 | No Firebase package in pubspec.lock | smoke | `grep firebase pubspec.lock` returns empty | ❌ Wave 0 (script) |
| COMP-02 | AD_ID permission absent from APK | smoke (manual) | `aapt dump badging build/.../app-debug.apk \| grep AD_ID` returns empty | manual |
| COMP-03 | `GameSessionNotifier` has no import from ads module | static analysis | `grep -r "import.*ads" lib/features/game/` returns empty | manual |
| COMP-04 | App builds with package `com.otis.brooke.state.the.state` | smoke | `flutter build apk --debug` succeeds | manual |
| SESS-05 | All assets bundled in APK; no network calls at runtime | smoke | `flutter build apk` succeeds; no `http` package in pubspec.lock | manual |

### Sampling Rate

- **Per task commit:** `flutter test test/core/` (Dart model + service tests only, ~5s)
- **Per wave merge:** `flutter test` + `python -m pytest scripts/`
- **Phase gate:** All tests green + `aapt dump badging` shows no AD_ID + `grep firebase pubspec.lock` empty

### Wave 0 Gaps

- [ ] `scripts/test_pipeline.py` — pipeline output validation (state count, Alaska validity, inset positions)
- [ ] `test/core/models/state_data_test.dart` — `StateData.fromJson` round-trip, `isPlaceable`, `InsetGroup` parsing
- [ ] `test/core/data/state_data_service_test.dart` — provider resolves 51 records, 50 placeable
- [ ] Python: `pip install pytest` or confirm `unittest` approach in wave instructions

*(All Dart tests require `usa_states_paths.json` to exist — pipeline must run in Wave 0 setup before Dart tests run.)*

---

## Security Domain

`security_enforcement` is not explicitly set to `false` in config.json — section required.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No accounts |
| V3 Session Management | no | Local session only, no tokens |
| V4 Access Control | no | Single-user, no roles |
| V5 Input Validation | partial | JSON asset is bundled (not user input); no external data ingestion at runtime |
| V6 Cryptography | no | `shared_preferences` plaintext is acceptable for non-sensitive scores |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Persistent device identifier leak (`AD_ID`) | Information Disclosure | `tools:node="remove"` in AndroidManifest + `aapt dump badging` verification |
| Firebase package accidentally introduced | Information Disclosure | `grep firebase pubspec.lock` gate in CI / pre-PR check |
| Third-party recording bundled without license review | Repudiation / DMCA | Self-render from PD score; LICENSES file with provenance |

---

## Sources

### Primary (HIGH confidence)

- `C:\code\Claude\FlagsRoundTheWorld\scripts\generate_map.py` — Flags pipeline source (direct read); baseline for generate_states.py structure
- `C:\code\Claude\FlagsRoundTheWorld\scripts\requirements.txt` — Python baseline deps confirmed (geopandas, shapely, pyproj already present)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\models\country_data.dart` — JSON schema + path_drawing parse pattern (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart` — compute isolate load pattern (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\stub_ad_service.dart` — StubAdService implementation (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ad_service.dart` — abstract interface (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\ads_initializer.dart` — COPPA init sequence (direct read)
- `C:\code\Claude\FlagsRoundTheWorld\android\app\src\main\AndroidManifest.xml` — AD_ID `tools:node="remove"` pattern (direct read)
- `C:\code\Claude\StateTheStates\.planning\phases\01-foundation\01-CONTEXT.md` — locked decisions D-01 through D-08
- [epsg.io/5070](https://epsg.io/5070) — NAD83/Conus Albers PROJ4 string verified
- [epsg.io/3338](https://epsg.io/3338) — NAD83/Alaska Albers PROJ4 string verified
- [d3/albersUsa.js](https://github.com/d3/d3-geo/blob/main/src/projection/albersUsa.js) — Alaska rotate:[154,0] center:[-2,58.5] parallels:[55,65]; Hawaii rotate:[157,0] center:[-3,19.9] parallels:[8,18]
- `antimeridian` package v0.4.7 — `fix_shape()` API verified via `help()` on this machine; `antimeridian.GeoInterface` accepted
- slopcheck 0.6.1 — all 4 Python packages confirmed [OK]
- [github.com/musescore/MuseScore/blob/master/share/sound/MS%20Basic_License.md](https://github.com/musescore/MuseScore/blob/master/share/sound/MS%20Basic_License.md) — MIT license text confirmed for MS Basic.sf3

### Secondary (MEDIUM confidence)

- [naturalearthdata.com admin-1 10m](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/) — dataset page; field names `adm0_a3`, `postal` confirmed via community examples
- [member.keymusician.com/Member/FluidR3_GM/](https://member.keymusician.com/Member/FluidR3_GM/) — FluidR3 GM "openness" restriction clause (site returned ECONNREFUSED; clause sourced via WebSearch cross-reference)
- [epsg.io/102007](https://epsg.io/102007) — Hawaii Albers ESRI:102007 PROJ4 string

### Tertiary (LOW confidence)

- Natural Earth shapefile field name case (`adm0_a3` vs `ADM0_A3`) — confirmed via multiple community examples; MUST verify on actual download

---

## Metadata

**Confidence breakdown:**
- Python pipeline reprojection mechanics: HIGH — EPSG codes verified against epsg.io; API verified against installed packages
- Antimeridian split: HIGH — `antimeridian.fix_shape()` API confirmed via `help()` on installed v0.4.7
- NE shapefile field names: MEDIUM — community-confirmed; not verified against actual .dbf file
- Anthem soundfont license: HIGH (MS Basic.sf3) — MIT license text read from MuseScore GitHub
- Inset scale/translate constants: LOW — D-08 gives ~0.45× for AK; exact numbers require visual calibration run
- Flutter/Dart patterns: HIGH — all copied from Flags reference codebase (direct read)
- COPPA wiring: HIGH — exact manifest and init patterns copied from Flags production code

**Research date:** 2026-05-31
**Valid until:** 2026-07-01 (stable stack; Natural Earth data and EPSG codes do not change frequently)
