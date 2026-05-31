# Phase 2: State Machine & Repositories - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 delivers all game logic in **pure Dart, unit-tested before any widget
depends on it**:

- **Golf scoring** — `(elapsed.inSeconds ~/ 10) + (errorCount * 5) +
  (hintsUsed * 5)` (SCORE-01, SCORE-02; hint term per Roadmap Criterion #1).
- **Wall-clock timer** — `Stopwatch`-based elapsed (NOT `Timer.periodic` tick
  counting), so a backgrounded round adds 0 seconds (SESS-01, Criteria #1/#2).
- **`GameSession` state machine** — `idle → countdown → playing → paused →
  completed`, ported from Flags with `postal` replacing `isoCode`.
- **Persistence** — best-score-per-mode + mute via `SharedPreferences`
  (SCORE-05, SESS-02); mid-game snapshot save/restore (SESS-03) round-trips to
  an identical `GameSession` (Criterion #4).
- **Audio service lifecycle hardening + tests** — `RealAudioService` /
  `StubAudioService` already exist from Phase 1; WEL-04 is proving init/play/
  dispose with no leaked players and a no-op stub passing the same interface
  assertions (Criterion #5).
- **`GameLifecycleObserver`** — a `WidgetsBindingObserver` built and tested in
  THIS phase (mounted to the game screen later in Phase 4) that calls
  `pauseGame()` on background.

This phase clarifies HOW to implement the above. Map rendering, the coordinate
spike, drag-drop, HUD, mode-specific board setup, and the home/completion
screens belong to Phases 3–5.

</domain>

<decisions>
## Implementation Decisions

### Timer & Countdown
- **D-01:** **Keep a 5-second pre-game countdown.** State machine is
  `idle → countdown → playing → paused → completed` (port Flags' `GamePhase`).
  The countdown accrues **no elapsed time and no score** — the Stopwatch does
  not start until "GO" (transition to `playing`).
- **D-02:** **`Stopwatch` is the single source of truth for elapsed time.**
  `pauseGame()` calls `_stopwatch.stop()`, `resumeGame()` calls
  `_stopwatch.start()`. A 1-second ticker exists ONLY to trigger a re-read of
  `_stopwatch.elapsed` and recompute the live score for the HUD — it never
  increments a counter. This is the deliberate deviation from Flags'
  `_elapsedSeconds++` per-tick model, which Roadmap Criteria #1/#2 forbid.
  ⚠ A dropped/late/duplicated tick must not corrupt elapsed — the tick is
  display-only.
- **D-03 (restore seam):** A `Stopwatch`'s internal time can't be serialized.
  On restore, **seed an offset**: `elapsed = _restoredOffset + _stopwatch.elapsed`,
  with the Stopwatch restarted from zero and `_restoredOffset` = the persisted
  `elapsedSeconds`. (Researcher/planner finalize the exact field naming.)

### Scoring & Hints
- **D-04:** **Build hint scoring hooks + state in Phase 2.** `GameSession`
  carries `hintsRemaining` (starts at **2**, per Roadmap Phase 5 Criterion #2);
  the notifier exposes `useHint()` which applies the **+5** penalty and
  decrements `hintsRemaining`. The full scoring formula is unit-testable now.
  Phase 5 wires the zoom-to-centroid / glow hint UI to the existing
  `useHint()` — it adds no new scoring logic.
- **D-05:** **Persist `hintPenalty` (or hints-used count) EXPLICITLY in the
  snapshot.** Do NOT reconstruct it by back-calculating `score - baseScore` the
  way Flags' `restoreGame()` does — that arithmetic is fragile. Store it as a
  first-class field so the round-trip is exact (Criterion #4).
- **D-06:** Golf scoring is **lower-is-better** and uncapped (errors and hints
  accumulate without ceiling). Score is always derived, never decremented.

### Resume Robustness (mid-game snapshot — SESS-03)
- **D-07:** **Save cadence = throttled 10s + flush on correct drop.** Autosave
  every **10 seconds**, plus on pause/background, plus an **immediate flush on
  every correct placement** (placed states are the real work and must never be
  lost), plus `clearSession()` on completion. Time/score may lag up to ~10s on
  restore; placed states never lag.
- **D-08:** **Corrupt / partial / old-schema snapshot → silently discard and
  start fresh.** Any parse/validation failure returns `null`, clears the bad
  key, and offers no "continue" prompt. No error dialog ever reaches the child
  (the "forgiving above all" core value). Follows Flags' `try/catch → null`
  pattern in `loadSession()`.
- **D-09:** **A restored session resumes into `GamePhase.paused`** with the
  Stopwatch stopped. The player taps Resume to start the clock — no surprise
  time-loss while re-orienting. (The "continue game" dialog that triggers this
  lives in Phase 5, Criterion #3; Phase 2 only guarantees `restoreGame()`
  lands in `paused`.)

### Lifecycle / Auto-Pause Seam (SESS-01)
- **D-10:** **Build `GameLifecycleObserver` (a `WidgetsBindingObserver`) in
  Phase 2**, with its own widget test that fires
  `didChangeAppLifecycleState(...)`. It is NOT mounted to any screen until
  Phase 4 (no game screen exists yet) — it sits built-and-tested until then.
  The `GameSessionNotifier` itself stays pure Dart and exposes
  `pauseGame()` / `resumeGame()`; the observer is the thin glue that calls them.
- **D-11:** **Auto-pause fires on `AppLifecycleState.paused` and `.hidden`
  only.** `.inactive` is ignored — it fires on transient interruptions
  (app-switcher peek, incoming-call banner, notification shade) and would cause
  twitchy false pauses, especially on iOS.
- **D-12 (load-bearing):** A `Stopwatch` uses a monotonic clock that **keeps
  running while the app is backgrounded.** Therefore the ONLY thing that makes
  Criterion #2 ("30s backgrounded adds 0s") true is auto-pause →
  `pauseGame()` → `_stopwatch.stop()`. This must be explicitly tested. The
  pause path also writes a snapshot (per D-07).

### Claude's Discretion
- **`GameMode` enum rename:** Flags' `flagsMaster` → **`statesMaster`**; enum is
  `{ learn, statesMaster, geographicalMaster, grandMaster }` (derived from
  Roadmap Phase 4 Criterion #1 naming). High-score `SharedPreferences` keys
  derive from these names.
- **Snapshot JSON schema:** mirror Flags' `game_state_repository.dart` field
  set (`phase`, `mode`, `score`, `elapsedSeconds`, `errorCount`,
  `activePostal`, `hintsRemaining`, plus the explicit `hintPenalty` from D-05,
  and `matchedPostals` replacing `matchedIsoCodes`). A schema-version field is
  optional — D-08's silent-discard already handles old/unknown shapes safely.
- **High-score keys & "lower wins" save guard:** port Flags'
  `high_score_repository.dart` verbatim (`saveBestScore` only writes when
  `score < current`), retargeted to the renamed modes.
- **Mute persistence:** port Flags' `user_prefs_repository.dart`
  (`mute_pref` bool, default unmuted; toggling persists immediately).
- **WEL-04 audio work:** the audio service already exists from Phase 1 — this
  phase HARDENS (guarded dispose / re-entrancy already partly present via
  `_initialized` + try/catch) and ADDS the leak-free init/play/dispose tests
  plus the `StubAudioService` no-op interface-parity assertions. No redesign.
- **Ticker abstraction:** keep Flags' `Ticker` / `RealTicker` / `FakeTicker`
  seam for deterministic tests — but the tick is display-only per D-02, not the
  elapsed source.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specs (this repo)
- `.planning/ROADMAP.md` §"Phase 2: State Machine & Repositories" — goal + 5
  success criteria (the verification target). Note Criteria #1/#2 mandate
  `Stopwatch`+`DateTime`, NOT tick counting (see D-02).
- `.planning/REQUIREMENTS.md` — Phase 2 requirements: SCORE-01, SCORE-02,
  SCORE-05, SESS-01, SESS-02, SESS-03, WEL-04.
- `.planning/PROJECT.md` — core value ("smooth, forgiving, rewarding above all"
  — drives D-08/D-09), COPPA constraints (no persistent IDs in any persisted
  data), 50 placeable states / DC non-scorable.
- `.planning/phases/01-foundation/01-CONTEXT.md` — Phase 1 decisions; `postal`
  is the canonical entity key (replaces Flags' `isoCode`).

### Existing Phase 1 Code (this repo — extend/test, don't rewrite)
- `lib/core/audio/audio_service.dart` — `AudioService` interface (WEL-04 target).
- `lib/core/audio/real_audio_service.dart` — already guarded with `_initialized`
  + try/catch; harden + add leak-free dispose tests here.
- `lib/core/audio/stub_audio_service.dart` — no-op; must pass the same interface
  assertions (Criterion #5).
- `lib/core/models/state_data.dart` — `StateData.postal` canonical key,
  `isPlaceable`; the 50 placeable states the scoring/matching logic operates on.

### Reference Codebase (Flags Around the World — port directly, retarget keys)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session.dart` —
  `GameSession` value object (copyWith sentinel, `==`/`hashCode`); rename
  `isoCode`→`postal`, `matchedIsoCodes`→`matchedPostals`.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session_notifier.dart`
  — `AsyncNotifier` state machine. ⚠ REPLACE its `_onTick`/`_elapsedSeconds++`
  elapsed model with the Stopwatch-as-truth model (D-02); persist `hintPenalty`
  explicitly instead of its `restoreGame()` back-calculation (D-05); restore to
  `paused` not `playing` (D-09).
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_phase.dart` —
  `GamePhase` enum (`idle/countdown/playing/paused/completed`) — port as-is.
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_mode.dart` —
  rename `flagsMaster`→`statesMaster` (D, Claude's discretion).
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ticker.dart` — `Ticker` /
  `RealTicker` / `FakeTicker` seam; keep, but tick is display-only (D-02).
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\game_state_repository.dart` —
  snapshot save/load/clear JSON pattern; add explicit `hintPenalty`,
  `matchedPostals`; keep `try/catch → null` (D-08).
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\high_score_repository.dart` —
  best-score-per-mode, "lower wins" guard.
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\user_prefs_repository.dart` —
  mute (and tutorial-seen, though tutorial is Phase 5) prefs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Audio service** (`lib/core/audio/`): already built in Phase 1 with the
  `just_audio` real/stub split + `_initialized` guard. WEL-04 = harden + test,
  not build.
- **`StateData` / `StateDataService`**: provide the 50 placeable `postal` keys
  that scoring/matching operate on; `postal` is the canonical session key.
- **Flags game layer**: a near-complete template for `GameSession`,
  `GameSessionNotifier`, and all three repositories — ported with the timer,
  hint-persistence, restore-phase, and naming deltas listed in `<decisions>`.

### Established Patterns
- Riverpod 3.x + codegen; `AsyncNotifierProvider` for `GameSessionNotifier`;
  `FutureProvider` for repositories (each awaits `SharedPreferences.getInstance()`).
- `Ticker`/`FakeTicker` seam enables deterministic timer tests without real time.
- Feature-first layout: game logic under `lib/features/game/`, repositories
  under `lib/core/data/`.

### Integration Points
- `GameSessionNotifier` stays pure Dart with ZERO ad imports (carry forward
  Phase 1 COMP-03 walled garden) — the new `GameLifecycleObserver` is the only
  Flutter-binding touchpoint, and it lives separately (D-10).
- Persisted snapshot/score/mute data must contain **no persistent identifiers**
  (COPPA) — only game state values.
- `pauseGame()` is the single chokepoint that both stops the Stopwatch and
  writes a snapshot — invoked by the user pause button AND the lifecycle
  observer (D-12).

</code_context>

<specifics>
## Specific Ideas

- The "forgiving above all" core value directly shaped two decisions: a corrupt
  save never shows a child an error (D-08, silent discard), and a restored game
  never silently burns their time before they're ready (D-09, restore-to-paused).
- The single most important correctness point in this phase: **the Stopwatch
  keeps ticking in the background**, so auto-pause stopping it is what makes the
  "30s backgrounded = +0s" guarantee real (D-12) — not an incidental detail.
- Placed states are treated as more precious than elapsed time in the autosave
  policy (flush-on-correct-drop, D-07) because re-placing states is real effort
  while re-accruing seconds is cosmetic.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 2 scope. Hint *interaction* UI
(zoom/glow), the "continue game" dialog, tutorial-seen flag usage, and the
mute-toggle widget are Phases 4–5; Phase 2 only builds the logic/state hooks
they will call.

</deferred>

---

*Phase: 2-State Machine & Repositories*
*Context gathered: 2026-05-31*
