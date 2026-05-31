# Phase 2: State Machine & Repositories - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-31
**Phase:** 2-State Machine & Repositories
**Areas discussed:** Timer & countdown model, Hint scoring scope, Resume robustness, Lifecycle / auto-pause seam

---

## Timer & Countdown Model

### Pre-game countdown

| Option | Description | Selected |
|--------|-------------|----------|
| Start immediately | Mode tap → play begins; simpler state machine, fastest into the drag loop | |
| Keep 5s countdown | Port Flags' countdown phase (5-4-3-2-1, no accrual) before play | ✓ |
| Short 3s countdown | Brief 3-2-1 "get ready" beat | |

**User's choice:** Keep 5s countdown.
**Notes:** State machine is `idle → countdown → playing → paused → completed`; countdown accrues no elapsed/score.

### Authoritative elapsed source

| Option | Description | Selected |
|--------|-------------|----------|
| Stopwatch is truth, tick just redraws | Stopwatch is THE source; 1s tick only re-reads elapsed + recomputes score, never increments | ✓ |
| DateTime-span accumulation | Sum of (start,end) DateTime spans; no Stopwatch | |

**User's choice:** Stopwatch is truth, tick just redraws.
**Notes:** Deliberate deviation from Flags' `_elapsedSeconds++` per-tick model (forbidden by Criteria #1/#2). Restore seeds an offset since Stopwatch internal time can't be persisted. Locked corollary: Stopwatch starts at GO, countdown is free.

---

## Hint Scoring Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Scoring hooks + state now | `hintsRemaining` (starts 2) + `useHint()` applying +5; fully testable now, Phase 5 wires UI | ✓ |
| Penalty field only | `hintPenalty` in score math but no `hintsRemaining`/`useHint()` yet | |
| Defer hints entirely | No hint concept in Phase 2 (likely fails Criterion #1) | |

**User's choice:** Scoring hooks + state now.
**Notes:** Follow-up decision — persist `hintPenalty` explicitly in the snapshot rather than back-calculating `score - baseScore` (Flags' fragile approach).

---

## Resume Robustness

### Save cadence

| Option | Description | Selected |
|--------|-------------|----------|
| On every state-changing event | Save after every drop/hint/pause | |
| On pause/background only | Fewest writes; crash mid-play loses progress | |
| Throttled (every N seconds) | Periodic autosave + pause | ✓ |

**User's choice:** Throttled — refined to **10s interval + flush on every correct drop** (+ pause/bg, + clear on complete).
**Notes:** Placed states flush immediately (real work, never lost); time/score may lag up to ~10s on restore.

### Corrupt/partial/old-schema recovery

| Option | Description | Selected |
|--------|-------------|----------|
| Silently discard → fresh start | Parse failure → null, clear key, no dialog | ✓ |
| Discard but log | Same UX, plus debugPrint for diagnosability | |

**User's choice:** Silently discard → fresh start.
**Notes:** Matches "forgiving above all" core value; Flags' try/catch→null pattern.

### Restore-into phase

| Option | Description | Selected |
|--------|-------------|----------|
| Restore into paused | Lands paused, Stopwatch stopped; player taps Resume | ✓ |
| Restore into playing | Mirror Flags; clock runs immediately | |

**User's choice:** Restore into paused.
**Notes:** No surprise time-loss while re-orienting; gentler for 8+ audience.

---

## Lifecycle / Auto-Pause Seam

### Where the AppLifecycleState boundary sits

| Option | Description | Selected |
|--------|-------------|----------|
| Notifier pure; observer in Phase 4 | Build only pause/resume now; observer added Phase 4 | |
| Build the observer now | Build `GameLifecycleObserver` (WidgetsBindingObserver) in Phase 2 too, with tests | ✓ |

**User's choice:** Build the observer now.
**Notes:** Notifier stays pure Dart (`pauseGame`/`resumeGame`); observer is thin glue, built + widget-tested in Phase 2 but not mounted until Phase 4. Stopwatch keeps running in background, so auto-pause→stop() is what makes "30s = +0s" true.

### Which lifecycle states trigger auto-pause

| Option | Description | Selected |
|--------|-------------|----------|
| paused + hidden only | Ignore transient `inactive` (app-switcher peek, call banner) | ✓ |
| paused + hidden + inactive | Pause on any non-resumed state; jumpier | |

**User's choice:** paused + hidden only.
**Notes:** `inactive` ignored to avoid twitchy false pauses, especially on iOS.

---

## Claude's Discretion

- `GameMode` enum rename `flagsMaster` → `statesMaster` (derived from Roadmap Phase 4 naming); high-score keys follow.
- Snapshot JSON schema (mirror Flags + explicit `hintPenalty` + `matchedPostals`); schema-version field optional (silent-discard handles old shapes).
- High-score "lower wins" save guard and mute-pref persistence — port Flags repositories verbatim, retargeted to renamed modes.
- WEL-04 audio work is hardening + tests on the existing Phase 1 service, not a redesign.
- Keep the `Ticker`/`FakeTicker` seam for deterministic tests (tick is display-only).

## Deferred Ideas

None — discussion stayed within Phase 2 scope. Hint interaction UI, "continue game" dialog, tutorial flag, and mute-toggle widget are Phases 4–5.
