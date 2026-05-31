---
phase: 02-state-machine-repositories
verified: 2026-05-31T12:30:00Z
status: passed
score: 13/13 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 10/13
  gaps_closed:
    - "pauseGame() null-guard: state.value force-unwrap crash at cold start (CR-01)"
    - "pauseGame() phase guard: phantom snapshot on idle/completed background (CR-02)"
    - "RealTicker.start() timer-leak: double-fire if start() called without prior stop() (CR-03)"
  gaps_remaining: []
  regressions: []
---

# Phase 2: State Machine & Repositories Verification Report

**Phase Goal:** All game logic — scoring, timer, state machine transitions, and local persistence — is implemented in pure Dart and unit-tested before any widget depends on it.
**Verified:** 2026-05-31T12:30:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (commits 1e93412, d9fd7de)

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|---------|
| 1  | GamePhase enum exposes idle, countdown, playing, paused, completed | VERIFIED | `lib/features/game/game_phase.dart`: `enum GamePhase { idle, countdown, playing, paused, completed }` |
| 2  | GameMode enum exposes learn, statesMaster, geographicalMaster, grandMaster | VERIFIED | `lib/features/game/game_mode.dart`: statesMaster present, flagsMaster absent |
| 3  | Two GameSession values with identical fields compare equal and share a hashCode | VERIFIED | `game_session.dart` implements `operator ==` and `hashCode` with `Object.hash`; 8 tests pass |
| 4  | copyWith(activePostal: null) clears the field via the sentinel pattern | VERIFIED | `_sentinel = Object()` pattern in `game_session.dart`; sentinel test passes |
| 5  | FakeTicker.tick() invokes the registered onTick callback exactly once | VERIFIED | `lib/core/ticker.dart` line 41: `void tick() => _onTick?.call()`; FakeTicker tests pass |
| 6  | A GameSession + hintPenalty saved by GameStateRepository round-trips to an identical GameSession and identical hintPenalty (D-05) | VERIFIED | `game_state_repository.dart` serializes hintPenalty as explicit JSON field; round-trip test passes |
| 7  | A corrupt/unparseable snapshot returns null AND clears the stored key (D-08) | VERIFIED | `loadSession()` catch block: `await _prefs.remove(_key); return null;`; corrupt-snapshot test passes |
| 8  | saveBestScore writes a new score only when it is lower than the stored value (lower-wins) | VERIFIED | `high_score_repository.dart`: `if (current == null \|\| score < current)`; lower-wins 20→25→15=15 test passes |
| 9  | A best score written then re-read from a fresh repository instance returns the same value | VERIFIED | Cold-read test in `high_score_repository_test.dart` passes |
| 10 | setMuted(true) persists and getMuted() returns true on a fresh instance; default is unmuted | VERIFIED | `user_prefs_repository.dart` with `mute_pref` key; mute persistence tests pass |
| 11 | Score equals (elapsed.inSeconds ~/ 10) + (errorCount * 5) + hintPenalty via Stopwatch, not tick counter (D-02) | VERIFIED | `_onTick()` reads `_stopwatch.elapsed.inSeconds`; no `_elapsedSeconds` counter exists; scoring formula test asserts 15 |
| 12 | pauseGame() leaves the internal Stopwatch stopped — the sole guarantee behind '30s backgrounded = +0s' | VERIFIED | `_stopwatch.stop()` is first action in pauseGame() (line 137 after null/phase guards); null-guard on line 127-128 prevents NPE at cold start (CR-01 fixed); phase guard on lines 131-134 prevents idle/completed phantom snapshot (CR-02 fixed); 6 targeted tests pass |
| 13 | RealAudioService init/dispose is leak-free; StubAudioService passes all interface assertions (WEL-04) | VERIFIED | StubAudioService: fully verified. RealAudioService: `dispose()` unconditional after init(); WR-01 (`late` fields) is an accepted WARNING documented in 02-REVIEW.md; init→dispose test passes |

**Score:** 13/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/game/game_phase.dart` | GamePhase enum (5 values) | VERIFIED | 1 line, correct values |
| `lib/features/game/game_mode.dart` | GameMode with statesMaster | VERIFIED | statesMaster present, flagsMaster absent |
| `lib/features/game/game_session.dart` | Value object with sentinel copyWith, ==/hashCode | VERIFIED | 88 lines, fully implemented |
| `lib/core/ticker.dart` | Ticker + RealTicker + FakeTicker | VERIFIED | FakeTicker correct; RealTicker.start() cancels existing timer before creating new one (CR-03 fixed: `_timer?.cancel()` line 15) |
| `lib/core/data/game_state_repository.dart` | Snapshot save/load/clear with hintPenalty + silent-discard | VERIFIED | 75 lines, hintPenalty explicit, D-08 remove() in catch |
| `lib/core/data/high_score_repository.dart` | Best-score-per-mode lower-wins, statesMaster key | VERIFIED | `high_score_states_master` key present, guard `score < current` present |
| `lib/core/data/user_prefs_repository.dart` | Mute + tutorial-seen persistence | VERIFIED | `mute_pref` and `tutorial_seen` keys present |
| `lib/features/game/game_session_notifier.dart` | AsyncNotifier with Stopwatch, scoring, restore-to-paused | VERIFIED | Stopwatch-as-truth; scoring correct; null guards on all 4 mutators (CR-01); phase guard on pauseGame (CR-02); WR-03 (unawaited saveSession) documented as accepted tradeoff per D-07 |
| `lib/features/game/game_lifecycle_observer.dart` | WidgetsBindingObserver (.paused/.hidden only) | VERIFIED | 44 lines; correct conditional; .inactive and .resumed do not trigger pauseGame |
| `lib/core/audio/real_audio_service.dart` | Hardened RealAudioService with unconditional dispose | VERIFIED | Dispose is unconditional after init(); WR-01 (`late` fields, never-init path) is accepted WARNING per 02-REVIEW.md |
| `test/features/game/game_session_test.dart` | GameSession equality + copyWith sentinel tests | VERIFIED | 8 tests, all passing |
| `test/core/data/game_state_repository_test.dart` | Round-trip + corrupt-discard tests | VERIFIED | 4 tests; round-trip + corrupt-discard + absent-key + clearSession all pass |
| `test/core/data/high_score_repository_test.dart` | Lower-wins + cold-read tests | VERIFIED | 5 tests; lower-wins sequence 20→25→15=15 asserted |
| `test/core/data/user_prefs_repository_test.dart` | Mute persistence test | VERIFIED | 6 tests; default unmuted + setMuted(true) persistence both verified |
| `test/features/game/game_session_notifier_test.dart` | Scoring formula + pause + restore-to-paused + CR-01/CR-02 regression tests | VERIFIED | 23 tests total; includes CR-01 null-guard tests for all 4 mutators and CR-02 phase-guard tests for idle and completed phases |
| `test/features/game/game_lifecycle_observer_test.dart` | Lifecycle .paused/.hidden pause, .inactive no-pause | VERIFIED | 4 tests; verifyNever for .inactive, .called(1) for .paused/.hidden |
| `test/core/audio/audio_service_test.dart` | WEL-04 lifecycle + interface-parity tests | VERIFIED | 2 tests; StubAudioService no-throw parity, RealAudioService init→dispose completes |
| `test/core/ticker_test.dart` | CR-03 regression tests for RealTicker double-fire | VERIFIED | 4 tests; start()-twice test asserts tickCount==1; stop()+start() test asserts normal rate |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `game_session.dart` | `game_phase.dart` | `import 'game_phase.dart'` | WIRED | Import present; GamePhase field used |
| `game_session.dart` | `game_mode.dart` | `import 'game_mode.dart'` | WIRED | Import present; GameMode field used |
| `game_state_repository.dart` | `game_session.dart` | import + GameSession (de)serialization | WIRED | Package import present; GameSession constructed in loadSession |
| `high_score_repository.dart` | `game_mode.dart` | import + `_key(GameMode)` switch | WIRED | Import present; switch on GameMode with `GameMode.statesMaster` branch |
| `game_state_repository.dart` | SharedPreferences | `_prefs.setString/getString/remove` on `game_session_snapshot` | WIRED | Lines 34, 40, 60, 67 |
| `game_session_notifier.dart` | `ticker.dart` | `_ticker.start(_onTick)` | WIRED | Lines 98, 150; `_ticker.stop()` on lines 138, 156, 216 |
| `game_session_notifier.dart` | `game_state_repository.dart` | `saveSession(.., hintPenalty:)` on pause/drop/hint; `clearSession` on complete | WIRED | Lines 142, 178, 210, 225 |
| `game_lifecycle_observer.dart` | `game_session_notifier.dart` | `_notifier.pauseGame()` on background lifecycle | WIRED | Line 39 |

### Data-Flow Trace (Level 4)

N/A — Phase 2 produces pure-Dart service classes and an AsyncNotifier. No widget rendering of dynamic data; data flows to tests via ProviderContainer and verified through mocktail verify() calls.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 70 tests pass | `flutter test --reporter=compact` | 70/70 pass | PASS |
| `flutter analyze` clean | `flutter analyze` | No issues found | PASS |
| No `_elapsedSeconds` counter | grep `_elapsedSeconds` in notifier | Only in DO NOT USE comment | PASS |
| No ad imports in notifier | grep `import.*ads` in notifier | No matches | PASS |
| No flagsMaster token in source | grep `flagsMaster` in lib/ | Only in rename comment | PASS |
| No isoCode token in data layer | grep `isoCode` in lib/core/data/ | No matches | PASS |
| CR-01: null guard present in pauseGame | Source line 127-128 | `final current = state.value; if (current == null) return;` | PASS |
| CR-01: null guard present in resumeGame | Source line 146-147 | `final current = state.value; if (current == null) return;` | PASS |
| CR-01: null guard present in recordDrop | Source line 167-168 | `final current = state.value; if (current == null) return;` | PASS |
| CR-01: null guard present in completeGame | Source line 217-218 | `final current = state.value; if (current == null) return;` | PASS |
| CR-02: phase guard in pauseGame | Source lines 131-134 | Guards playing and countdown only; returns early for idle/completed | PASS |
| CR-03: `_timer?.cancel()` in RealTicker.start() | Source line 15 | `_timer?.cancel(); // cancel any live timer before overwriting (CR-03)` | PASS |

### Probe Execution

No probes declared for Phase 2. Skipped.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| SCORE-01 | 02-01, 02-03 | Golf scoring: +1 per 10s elapsed | SATISFIED | `_onTick` computes `(elapsedSecs ~/ 10)`; scoring formula test asserts correct result |
| SCORE-02 | 02-01, 02-03 | Golf scoring: +5 per wrong drop | SATISFIED | `recordDrop(isCorrect: false)` increments errorCount; score += errorCount * 5; test passes |
| SCORE-05 | 02-02 | Best (lowest) score stored in SharedPreferences | SATISFIED | `HighScoreRepository.saveBestScore` with lower-wins guard; tests pass |
| SESS-01 | 02-03 | Pause/resume; auto-pause on background | SATISFIED | `pauseGame()` stops Stopwatch first; null guard (CR-01) and phase guard (CR-02) both present; GameLifecycleObserver wires .paused/.hidden; all lifecycle tests pass |
| SESS-02 | 02-02 | Mute preference persists | SATISFIED | UserPrefsRepository with `mute_pref` key; persistence tests pass |
| SESS-03 | 02-01, 02-02, 02-03 | In-progress session persists across relaunch | SATISFIED | GameStateRepository round-trip test passes; snapshot flushed on pause/correct-drop. WR-03 (unawaited saveSession) is an accepted documented tradeoff (D-07 comment at line 175-176) — the SESS-03 contract is met; the fire-and-forget write is a hardening follow-up deferred to Phase 4 |
| WEL-04 | 02-04 | Audio service init/play/dispose without leaked players | SATISFIED | RealAudioService dispose() unconditional after init(); test passes. WR-01 (`late` fields, never-init path) is an accepted WARNING per 02-REVIEW.md |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/game/game_session_notifier.dart` | 175-176 | `saveSession` unawaited | WARNING | Process-death: snapshot write dispatched but not awaited — may not commit before SIGKILL (WR-03). Documented tradeoff, follow-up deferred to Phase 4 hardening |
| `lib/core/audio/real_audio_service.dart` | 8-10 | `late` AudioPlayer fields | WARNING | LateInitializationError in dispose() if init() never called (WR-01). Phase 5 will mount the real audio service; never-init path is not exercised in Phase 2 |
| `lib/features/game/game_session_notifier.dart` | 48 | `// ignore: unused_field` | INFO | _remainingPostals carried forward to Phase 4; lint suppression noted |

All previously-classified BLOCKER anti-patterns (CR-01, CR-02, CR-03) are resolved.

### Human Verification Required

None — all Phase 2 deliverables are pure-Dart units testable programmatically. Visual behavior, lifecycle on real devices, and session-restore UX are deferred to Phase 4/5.

### Gaps Summary

No gaps. All 3 blockers from the initial verification are closed:

- **CR-01** (commit 1e93412): `pauseGame()`, `resumeGame()`, `recordDrop()`, and `completeGame()` all now open with `final current = state.value; if (current == null) return;`. The force-unwrap crash path is eliminated. Confirmed by 4 dedicated null-guard regression tests.

- **CR-02** (commit 1e93412): `pauseGame()` now has a phase guard — returns early unless phase is `playing` or `countdown`. Backgrounding in `idle` or `completed` no longer writes a phantom snapshot. Confirmed by 2 phase-guard regression tests (idle, completed).

- **CR-03** (commit d9fd7de): `RealTicker.start()` now opens with `_timer?.cancel();` before assigning the new `Timer.periodic`. Double-fire on back-to-back `start()` calls is eliminated. Confirmed by 2 RealTicker regression tests in `test/core/ticker_test.dart`.

The remaining WR-03 (unawaited `saveSession`) is classified as an accepted WARNING follow-up for Phase 4 hardening. The D-07 tradeoff is documented inline and the SESS-03 round-trip contract passes.

---

_Verified: 2026-05-31T12:30:00Z_
_Verifier: Claude (gsd-verifier)_
