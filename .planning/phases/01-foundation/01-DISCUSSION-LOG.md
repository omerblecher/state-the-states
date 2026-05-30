# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 1-Foundation
**Areas discussed:** Map projection, D.C. on the map, Anthem sourcing, Inset frame layout

---

## Map Projection

| Option | Description | Selected |
|--------|-------------|----------|
| Albers USA conic | Standard US-map projection; equal-area conic; northern border curves naturally, states keep familiar proportions. pyproj/geopandas reproject before path extraction. | ✓ |
| Equirectangular lon/lat | Direct port of Flags' generate_map.py; simplest, zero new projection code, but US-only equirect looks stretched/skewed. | |

**User's choice:** Albers USA conic
**Notes:** Driver was visual familiarity — "what kids see in class." Projection step replaces the equirectangular logic in the ported `generate_map.py`.

### Follow-up: AK/HI projection within insets

| Option | Description | Selected |
|--------|-------------|----------|
| Own conic params each | Project AK with an Alaska-centered Albers and HI with a Hawaii-centered one (d3 AlbersUsa approach), then scale/translate into insets. Each landmass looks correct. | ✓ |
| Reuse CONUS Albers for all | One projection then scale/translate; simpler but Alaska comes out sheared since it's far outside CONUS standard parallels. | |

**User's choice:** Own conic params each

---

## D.C. on the map

| Option | Description | Selected |
|--------|-------------|----------|
| Render as non-placeable filler | Emit D.C. path flagged `isPlaceable:false` — no mid-Atlantic hole, never a token/drop target. Cleanest look, one schema flag. | ✓ |
| Omit D.C. entirely | Filter D.C. out; exactly 50 records but leaves a small visible gap. | |
| Merge D.C. into Maryland | Dissolve D.C. into Maryland; no gap, no extra record, but Maryland shape non-canonical. | |

**User's choice:** Render as non-placeable filler
**Notes:** Implies the JSON holds 51 records (50 placeable + 1 non-placeable D.C.); verification should assert "50 placeable records," not "exactly 50 total." Schema gains an `isPlaceable` boolean.

---

## Anthem sourcing

| Option | Description | Selected |
|--------|-------------|----------|
| Document provenance now, render in Phase 5 | LICENSES entry locked now (source/tool/soundfont) + placeholder asset; real render in Phase 5 where WEL-02/03 use it. | ✓ |
| Full self-rendered instrumental now | Produce real render in Phase 1 and document it; done early but audio-production work nothing yet plays. | |

**User's choice:** Document provenance now, render in Phase 5

### Follow-up: Toolchain to document

| Option | Description | Selected |
|--------|-------------|----------|
| MuseScore + free SoundFont | Engrave PD score in MuseScore; export audio with a redistributable soundfont (GeneralUser GS / FluidR3-derived). | ✓ |
| MIDI + FluidSynth + FluidR3_GM | Scripted PD MIDI rendered via FluidSynth CLI with FluidR3_GM (MIT). Fully reproducible/automatable. | |
| You pick the cleanest | Defer toolchain choice to research/planning. | |

**User's choice:** MuseScore + free SoundFont
**Notes:** Researcher must verify the exact soundfont's redistribution license is unambiguous for a commercial Families app before naming it in LICENSES.

---

## Inset frame layout

| Option | Description | Selected |
|--------|-------------|----------|
| Sized to projected CONUS bounds | No hardcoded viewBox; Albers CONUS bounds set aspect (~1.6:1), normalize width to 1000, height follows (~620). | ✓ |
| Fixed 1000×620 (CLAUDE.md suggestion) | Matches CLAUDE.md inset coords; predictable but may letterbox. | |
| Fixed 2000×1000 (Flags parity) | Match Flags viewBox; larger numbers, 2:1 aspect wider than CONUS. | |

**User's choice:** Sized to projected CONUS bounds

### Follow-up: Inset placement & sizing

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom-left overlay, AK ~0.45× | Classic convention: AK ~0.45× in lower-left ocean below CA/Mexico; HI to its right; thin framing rects; no separate band. | ✓ |
| Dedicated bottom band below CONUS | Extend canvas height ~15% for a reserved strip; no overlap but more dead space. | |
| You pick exact values | Lock the convention, compute exact numbers during pipeline build. | |

**User's choice:** Bottom-left overlay, AK ~0.45× (exact scale/translate computed from projected bounds during build)

---

## Claude's Discretion

- Full JSON schema field set beyond locked essentials (follow Flags `country_data.dart`).
- Flutter project scaffolding/directory layout (follow Flags feature-first structure verbatim).
- Exact AK/HI inset scale/translate numbers within the chosen convention.

## Deferred Ideas

None — discussion stayed within Phase 1 scope. (Micro-state proximity hit-box radius data is a Phase 3/4 concern; schema left extensible but not built here.)
