# Phase 1: Foundation - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 delivers a COPPA-compliant Flutter skeleton plus a build-time Python
pipeline that emits `assets/map/usa_states_paths.json` — the single data
prerequisite every later phase depends on. Concretely:

- A Python pipeline (port of Flags' `generate_map.py`) that converts Natural
  Earth admin-1 (public domain) into bundled, pre-transformed state path data
  with per-state centroids and baked Alaska/Hawaii inset transforms; Alaska's
  Aleutian antimeridian geometry is split so it passes `shapely` validity and
  renders without a horizontal smear.
- COPPA baseline: no Firebase anywhere, `AD_ID` permission blocked via
  `tools:remove` in `AndroidManifest.xml`, ad layer present but stubbed
  (`StubAdService`, `AdLoadState.failed`) as a walled garden with zero ad
  imports reachable from `GameSessionNotifier`, App ID
  `com.otis.brooke.state.the.state`, max content rating G/PG.
- Service stubs + a `StateDataService` that loads/parses the JSON in a compute
  isolate, proven end-to-end by a blank `CustomPaint` canvas that renders
  without error.
- LICENSES file documenting anthem provenance.

This phase clarifies HOW to implement the above. New capabilities (game logic,
rendering polish, drag-drop, modes) belong to Phases 2–5.

</domain>

<decisions>
## Implementation Decisions

### Map Projection
- **D-01:** Use **Albers equal-area conic** for the mainland 48 states (not
  equirectangular lon/lat). The Flags `generate_map.py` equirectangular
  approach is the structural baseline, but the projection step is replaced:
  reproject geometry (via `pyproj`/`geopandas`) into Albers before extracting
  path strings. Rationale: a US-only equirectangular map looks visibly
  stretched/skewed; Albers is the conventional, classroom-familiar US-map look
  with a naturally curving northern border.
- **D-02:** **Alaska and Hawaii each get their own landmass-centered conic
  projection parameters** (the d3 `AlbersUsa` strategy) BEFORE being scaled and
  translated into their inset frames — NOT the CONUS Albers parameters. Reusing
  CONUS parameters shears Alaska badly because it sits far outside the CONUS
  standard parallels. Each landmass must look geometrically correct in its
  inset.

### D.C. Handling
- **D-03:** Render Washington **D.C. as a non-placeable filler**. Emit its path
  in the JSON flagged `isPlaceable: false` so the mid-Atlantic has no visible
  hole, but it is never a tray token and never a valid drop target. The 50
  states are the only placeable/scorable entities.
- **D-04 (schema impact):** The JSON therefore contains **51 records: 50
  placeable states + 1 non-placeable D.C.** ⚠ Note for verification: Phase 1
  Success Criterion #1 says "50 state records" — that refers to the 50
  placeable states; D.C. is an additional `isPlaceable:false` record, not one of
  the 50. The pipeline/tests should assert "50 placeable records" rather than
  "exactly 50 total records." The schema needs an `isPlaceable` boolean per
  record.

### Anthem Sourcing
- **D-05:** **Document provenance now; defer the actual render to Phase 5.**
  Phase 1 writes the LICENSES entry naming the public-domain composition source,
  the rendering tool, and the soundfont, and ships a short placeholder/silent
  audio asset so the app builds. The real instrumental render lands in Phase 5
  where WEL-02/WEL-03 actually play it. This satisfies Success Criterion #4
  (LICENSES documents anthem provenance with explicit source, rendering tool,
  and soundfont) without front-loading audio production into a foundation phase.
- **D-06:** Toolchain to document (and use in Phase 5): **MuseScore + a free,
  redistributable SoundFont** (e.g. GeneralUser GS, or MuseScore's bundled
  FluidR3-derived set), engraving/exporting the public-domain "Star-Spangled
  Banner" score. ⚠ Researcher MUST verify the exact chosen soundfont's
  redistribution license is unambiguous for shipping in a commercial Families
  app before it is named in LICENSES.

### Inset Frame Layout
- **D-07:** **Do not hardcode the viewBox.** Let the Albers-projected CONUS
  bounds define the natural aspect ratio (~1.6:1), normalize width to **1000**,
  and let height follow (~620–625). Avoids letterboxing and guesswork. This
  supersedes the CLAUDE.md "Map Data Pipeline" suggestion of a fixed 1000×620
  viewBox and the Flags 2000×1000 viewBox — the dimensions are *derived*, with
  ~1000-wide as the normalization target.
- **D-08:** **AK and HI overlay the empty lower-left ocean area** (classic
  US-map convention), not a separate extended letterbox band. Alaska scaled to
  ~**0.45×** of its true projected size so it reads clearly; Hawaii placed just
  to Alaska's right. Bake thin **inset-frame rectangles** around each group into
  the data/coordinate space (Phase 3 actually draws them). The exact
  scale/translate numbers are computed from the projected bounds during the
  pipeline build.

### Claude's Discretion
- JSON schema field set beyond the locked essentials (path string, centroid,
  abbreviation/postal key, full name, `isPlaceable`, inset-group flag,
  bounding box) — researcher/planner finalize, guided by the Flags
  `country_data.dart` schema. Micro-state proximity hit-box radius data is a
  Phase 3/4 concern but the schema should leave room for it (centroid +
  bounding box are sufficient inputs).
- Flutter project scaffolding details (directory layout) follow the Flags
  feature-first structure verbatim — not re-litigated here.
- Exact AK/HI inset scale/translate numbers (within the D-08 convention).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specs (this repo)
- `CLAUDE.md` — locked stack/versions, Map Data Pipeline section, AK/HI inset
  strategy, "What NOT to Use", deltas from Flags lockfile. Note: D-01/D-07
  intentionally refine the pipeline's projection and viewBox beyond what this
  file suggests.
- `.planning/REQUIREMENTS.md` — Phase 1 requirements: DATA-01, DATA-02, COMP-01,
  COMP-02, COMP-03, COMP-04, SESS-05.
- `.planning/ROADMAP.md` §"Phase 1: Foundation" — goal + 5 success criteria
  (the verification target).
- `.planning/PROJECT.md` — Context + Key Decisions (50 states no D.C., baseline
  from Flags, `just_audio`, no Firebase).

### Research (this repo)
- `.planning/research/STACK.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/PITFALLS.md`
- `.planning/research/FEATURES.md`
- `.planning/research/SUMMARY.md`

### Reference Codebase (Flags Around the World — adapt directly)
- `C:\code\Claude\FlagsRoundTheWorld\scripts\generate_map.py` — pipeline to
  port; equirectangular projection step is REPLACED by Albers (D-01) and
  per-landmass conic insets (D-02).
- `C:\code\Claude\FlagsRoundTheWorld\scripts\requirements.txt` — Python deps
  baseline (add `pyproj` if not already present for reprojection).
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\models\country_data.dart` — JSON
  schema + `path_drawing` parse pattern to mirror for `StateData`.
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart` —
  compute-isolate load pattern for `StateDataService`.
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\audio\real_audio_service.dart` —
  `just_audio` service pattern (stub/real split established in Phase 2).
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ads\` — stub/real ad service split
  to mirror for `StubAdService` walled garden.
- `C:\code\Claude\FlagsRoundTheWorld\CLAUDE.md` — locked architecture decisions
  (CustomPainter, no Firebase, no flutter_map, no Syncfusion).
- `C:\code\Claude\FlagsRoundTheWorld\pubspec.yaml` / `pubspec.lock` —
  authoritative lockfile baseline.

### External Data Source
- Natural Earth admin-1 10m states/provinces (public domain):
  https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/
  — fields `adm0_a3` (filter `=='USA'`), `postal` (canonical key), `name`,
  `iso_3166_2`. ⚠ Verify exact field names on first download (MEDIUM confidence).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The entire Flags codebase is the baseline. Phase 1 ports: `generate_map.py`
  (pipeline), `country_data.dart` (→ `StateData` model + JSON schema),
  `country_data_service.dart` (→ `StateDataService` isolate loader), the
  `ads` stub/real split (→ `StubAdService`).

### Established Patterns
- Feature-first layout `lib/core/{ads,audio,data,models,l10n}` +
  `lib/features/{home,game,map,ads}` (from PROJECT.md Context).
- Riverpod 3.x + codegen; `path_drawing.parseSvgPathData()` converts bundled
  path strings to `dart:ui` Path at load time.
- `aapt dump badging` is the verification tool for the absent `AD_ID`
  permission (Success Criterion #3).

### Integration Points
- `StateDataService` (compute isolate) → blank `CustomPaint` canvas: the
  end-to-end wiring proof for this phase (Success Criterion #5).
- `GameSessionNotifier` must have ZERO reachable ad imports (Success
  Criterion #3 / COMP-03).

</code_context>

<specifics>
## Specific Ideas

- "Looks right to anyone who's seen a US map / what kids see in class" was the
  driver for choosing Albers over equirectangular — visual familiarity matters
  even at the foundation/data layer because it sets the map's resting look.
- D.C. filler exists purely to avoid a visible mid-Atlantic hole, never to be
  interactive.
- AK/HI insets follow the classic atlas convention (lower-left ocean overlay
  with framing rectangles), not an invented layout.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 1 scope. (JSON schema extras like
proximity hit-box radius are Phase 3/4 concerns; the schema is left extensible
but not built out here.)

</deferred>

---

*Phase: 1-Foundation*
*Context gathered: 2026-05-30*
