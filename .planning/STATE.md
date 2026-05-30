# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-30)

**Core value:** A child can drag a state onto its correct place on the U.S. map and immediately feel they got it right — the interactive map placement loop must be smooth, forgiving, and rewarding above everything else.
**Current focus:** Phase 1 — Foundation

## Current Position

Phase: 1 of 5 (Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-05-30 — Roadmap created; all 42 v1 requirements mapped to 5 phases

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: none yet
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Python pipeline (DATA-01/02) gates all rendering work — Phase 1 must complete before Phase 3 begins.
- Roadmap: Coordinate-transform spike in Phase 3 is a hard gate — Phase 4 must not begin until spike passes at 1×/2×/4× zoom including AK/HI inset regions.
- Roadmap: COPPA baseline (COMP-01/02/03/04) placed in Phase 1 — AD_ID blocked and StubAdService wired from first commit.
- Roadmap: Ad layer (Phase 6 in research) is v2 scope only; v1 stubs it entirely and no mediation SDKs enter pubspec until v2.

### Pending Todos

None yet.

### Blockers/Concerns

- **Phase 3 (MEDIUM):** Coordinate-transform spike is highest technical risk; do not parallelize Phase 4 until spike passes.
- **Phase 5 (MEDIUM):** FluidSynth + SF2 anthem rendering toolchain not in Flags reference; verify before committing Phase 5 timing.
- **General:** Natural Earth shapefile field names (adm0_a3, postal) are MEDIUM confidence — verify against actual shapefile on first download before writing pipeline filter logic.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v2 | Full AdMob + mediation (Phase 6) | Deferred | Roadmap creation |
| v2 | Mode 5 — Speed Typing Challenge | Deferred | Roadmap creation |
| v2 | Gated social sharing (parental math gate + share_plus) | Deferred | Roadmap creation |
| v2 | Rewarded-ad hint refill | Deferred | Roadmap creation |

## Session Continuity

Last session: 2026-05-30
Stopped at: Roadmap and STATE.md created; REQUIREMENTS.md traceability table updated.
Resume file: None
