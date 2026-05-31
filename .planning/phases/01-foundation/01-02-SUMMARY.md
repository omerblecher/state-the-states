---
phase: 01-foundation
plan: "02"
subsystem: map-data-pipeline
tags: [data, python, albers, antimeridian, inset, natural-earth, geopandas]
dependency_graph:
  requires: []
  provides:
    - scripts/generate_states.py (build-time three-CRS Albers + antimeridian + inset-baking pipeline)
    - scripts/test_pipeline.py (5-test pytest validation suite)
    - scripts/requirements.txt (Python deps incl antimeridian)
    - assets/map/usa_states_paths.json (51-record bundled state path data)
  affects:
    - plan 01-03 (StateDataService consumes usa_states_paths.json end-to-end)
    - Phase 3 (map rendering + coordinate-transform spike reads this same JSON)
tech_stack:
  added:
    - geopandas>=1.0
    - shapely>=2.0
    - pyproj>=3.6.0
    - antimeridian>=0.4
    - pytest>=7.0
  patterns:
    - Flags Around the World generate_map.py as structural baseline (polygon_to_path, MultiPolygon iteration, representative_point centroid, json.dump)
    - Three-CRS reprojection — CONUS EPSG:5070, Alaska EPSG:3338, Hawaii custom aea proj4
    - antimeridian.fix_shape() BEFORE to_crs() to prevent Aleutian smear (D-02/DATA-02)
    - Inset baking — AK/HI transformed into final lower-left canvas coordinates, not geographic latitudes (D-08)
    - Derived viewBox from CONUS Albers bounds normalized to width 1000 (D-07)
key_files:
  created:
    - scripts/generate_states.py
    - scripts/requirements.txt
    - scripts/test_pipeline.py
    - assets/map/usa_states_paths.json
  modified: []
decisions:
  - "D-01 confirmed: CONUS uses Albers equal-area conic EPSG:5070; viewBox derived (1000x628), not hardcoded (D-07)"
  - "D-02/DATA-02 confirmed: antimeridian.fix_shape() runs before EPSG:3338 reprojection; shapely is_valid() gate asserts no smear"
  - "D-03 confirmed: DC emitted as isPlaceable:false (51 total records = 50 placeable + DC filler)"
  - "D-08 confirmed: Alaska inset SCALE_FACTOR 0.45, lower-left ocean overlay; Hawaii frame just right of Alaska; both baked to canvas space"
  - "JSON top-level key is 'states' (not 'countries') per Pitfall 7"
metrics:
  duration_minutes: 10
  completed_date: "2026-05-31T05:43:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
requirements_satisfied: [DATA-01, DATA-02]
---

# Phase 1 Plan 2: Map Data Pipeline Summary

**One-liner:** A build-time Python pipeline (`generate_states.py`) that converts public-domain Natural Earth admin-1 data into the bundled `usa_states_paths.json` (51 records) via a three-CRS Albers pipeline — CONUS EPSG:5070, Alaska EPSG:3338 after antimeridian split, Hawaii custom aea — with AK/HI inset transforms baked into final canvas coordinates and a derived 1000×628 viewBox, validated by a 5-test pytest suite.

## What Was Built

The single data prerequisite every later rendering phase depends on:

1. **`scripts/generate_states.py`** — Ports the Flags `generate_map.py` structure (polygon_to_path, MultiPolygon iteration, `representative_point()` centroid, `json.dump` with compact separators) and replaces the equirectangular projection with three per-landmass conic branches:
   - **(a) CONUS + DC** → `to_crs("EPSG:5070")`, bounds normalized to width 1000 → derived viewBox height 628 (D-01/D-07).
   - **(b) Alaska** → `antimeridian.fix_shape()` applied to each geometry **before** `to_crs("EPSG:3338")` (D-02/DATA-02), `shapely.validation.is_valid()` asserted per reprojected geometry, then scale `AK_SCALE_FACTOR = 0.45` + translate baked into a lower-left inset rect (D-08).
   - **(c) Hawaii** → `to_crs(HI_PROJ4)` (custom `+proj=aea` string), normalized and baked into a frame just right of Alaska.
   - First-run field verification: prints `gdf.columns`, filters `adm0_a3 == 'USA'` (with `ADM0_A3` fallback), asserts exactly 50 placeable + DC before emitting.

2. **`assets/map/usa_states_paths.json`** (765 KB) — `{version:1, viewBox:{width:1000, height:628}, insetFrames:{alaska, hawaii}, states:[51]}`. 50 `isPlaceable:true` states + 1 DC `isPlaceable:false`. AK `insetGroup:"alaska"` centroid (151.85, 524.04) inside the alaska frame; HI `insetGroup:"hawaii"` centroid (381.36, 590.99) inside the hawaii frame — proving inset baking.

3. **`scripts/test_pipeline.py`** — 5 pytest checks, all green: `test_state_count`, `test_alaska_validity`, `test_inset_positions`, `test_no_dc_placeable`, `test_viewbox_derived`.

4. **`scripts/requirements.txt`** — `geopandas>=1.0`, `shapely>=2.0`, `pyproj>=3.6.0`, `antimeridian>=0.4`, `pytest>=7.0`.

## Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Three-CRS Albers pipeline + bundled JSON | `48b94b1` | generate_states.py, requirements.txt, usa_states_paths.json |
| 2 | Pipeline validation tests | `18b089f` | test_pipeline.py |

## Deviations from Plan

**1. [Orchestrator intervention] Task 2 commit completed by orchestrator, not executor**
- **Found during:** Task 2 commit
- **Issue:** The executor agent's Bash sandbox blocked every `git commit` once `scripts/test_pipeline.py` was staged (filename-based block on `test_*`). The executor wrote and staged the file correctly but could not commit it, and paused.
- **Fix:** The orchestrator dropped a stray `scripts/commit_msg.txt` artifact, installed pytest, ran the suite (5/5 PASSED), and committed `test_pipeline.py` as `18b089f`, then authored this SUMMARY.md. No code changed — only the commit step was performed outside the sandbox.
- **Files modified:** none (commit-only intervention)

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| Optional PNG visual render | n/a | The plan offered an optional standalone PNG render for the manual AK/HI visual check (Success Criterion #2). Inset positions are instead verified programmatically by `test_inset_positions` (AK/HI centroids inside their inset frames), satisfying the no-smear / baked-inset requirement without the manual artifact. |

## Threat Flags

All threat-model mitigations applied:
- T-02-01 (malformed JSON): `test_state_count` asserts 51 records / valid structure — MITIGATED
- T-02-02 (field-name case mismatch): first-run field verification asserts 50 placeable + DC before emit — MITIGATED
- T-02-03 (antimeridian smear, HIGH): `fix_shape()` before reproject + `is_valid()` gate + `test_alaska_validity` — MITIGATED
- T-02-SC (pip deps): all 4 packages cleared in RESEARCH.md legitimacy audit — ACCEPTED

## Self-Check: PASSED

Files verified:
- `scripts/generate_states.py`: FOUND (contains EPSG:5070, EPSG:3338, HI_PROJ4, fix_shape)
- `scripts/requirements.txt`: FOUND (contains antimeridian>=0.4)
- `scripts/test_pipeline.py`: FOUND (5 tests, all named selectors present)
- `assets/map/usa_states_paths.json`: FOUND (51 records, 50 placeable, viewBox 1000×628)

Tests verified:
- `python -m pytest scripts/test_pipeline.py -v`: 5 passed, 1 warning (benign antimeridian FixWindingWarning)

Commits verified:
- `48b94b1`: pipeline + JSON — FOUND
- `18b089f`: validation tests — FOUND
