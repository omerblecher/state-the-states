---
phase: 02-state-machine-repositories
verified: 2026-05-31T11:46:00Z
status: gaps_found
score: 10/13 must-haves verified
gaps:
  - truth: "pauseGame() leaves the internal Stopwatch stopped — the sole guarantee behind '30s backgrounded = +0s'"
    status: partial
    reason: "pauseGame() correctly stops the Stopwatch first (D-12 contract met), but the method lacks a null-guard on state.value (force-unwrap crash when provider still loading) and lacks a phase guard (unconditionally transitions idle/completed to paused and writes a phantom snapshot). The Stopwatch invariant itself is correctly implemented; the crashes and repository pollution are real runtime defects."
    artifacts:
      - path: "lib/features/game/game_session_notifier.dart"
        issue: "Line 131: state.value! force-unwrap — NPE crash if backgrounded at cold start before build() resolves. Line 131-133: no phase guard — pauseGame() on idle/completed phases corrupts the snapshot repository and flips the phase to paused."
    missing:
      - "Add `final current = state.value; if (current == null) return;` early guard to pauseGame()"
      - "Add phase guard: if (current.phase != GamePhase.playing && current.phase != GamePhase.countdown) return;"
      - "Apply matching null guard to resumeGame() (line 137), recordDrop() (line 156), and completeGame() (line 205)"
  - truth: "saveSession is flushed on pause/background and on every correct drop, autosaved on a throttled ~10s cadence, and clearSession runs on completion (D-07)"
    status: partial
    reason: "pauseGame() saveSession call is unawaited (void method dispatches the Future and returns). For the process-death survival contract (SESS-03), the OS can SIGKILL between the dispatch and the platform channel write completing, leaving the snapshot not persisted. This is the weakest link in the SESS-03 guarantee. Functionally the code does flush; it just has no write-completion contract."
    artifacts:
      - path: "lib/features/game/game_session_notifier.dart"
        issue: "Line 133: `_gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);` — unawaited Future. pauseGame() is void and cannot await. Changing to `Future<void>` + await would provide stronger crash-survival guarantee."
    missing:
      - "Change pauseGame() to `Future<void>` and await the saveSession call to give the OS-kill grace window a meaningful improvement (recommended by 02-REVIEW.md WR-03)"
  - truth: "RealTicker.start() — only verified via FakeTicker in tests; RealTicker has a timer-leak defect"
    status: failed
    reason: "RealTicker.start() assigns a new Timer.periodic without cancelling any existing timer first (CR-03). If start() is called twice (startGame on active game, or resumeGame on already-playing session), the old Timer is orphaned, fires indefinitely, and _onTick fires at 2x rate — countdown ends in ~2.5s, score accrues at 2x speed. FakeTicker (used in all tests) does not have this bug, so tests pass but the production implementation is defective."
    artifacts:
      - path: "lib/core/ticker.dart"
        issue: "Line 14-16: start() overwrites _timer without `_timer?.cancel()` first. See 02-REVIEW.md CR-03."
    missing:
      - "Add `_timer?.cancel();` as the first line of RealTicker.start() before assigning the new Timer.periodic"
---

# Phase 2: State Machine & Repositories Verification Report

**Phase Goal:** All game logic — scoring, timer, state machine transitions, and local persistence — is implemented in pure Dart and unit-tested before any widget depends on it.
**Verified:** 2026-05-31T11:46:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|---------|
| 1  | GamePhase enum exposes idle, countdown, playing, paused, completed | VERIFIED | `lib/features/game/game_phase.dart` line 1: `enum GamePhase { idle, countdown, playing, paused, completed }` |
| 2  | GameMode enum exposes learn, statesMaster, geographicalMaster, grandMaster | VERIFIED | `lib/features/game/game_mode.dart` line 3: contains `statesMaster`, no `flagsMaster` |
| 3  | Two GameSession values with identical fields compare equal and share a hashCode | VERIFIED | `game_session.dart` implements `operator ==` and `hashCode` with `Object.hash`; tests pass (59/59) |
| 4  | copyWith(activePostal: null) clears the field via the sentinel pattern | VERIFIED | `_sentinel = Object()` pattern in `game_session.dart` line 29-52; sentinel test passes |
| 5  | FakeTicker.tick() invokes the registered onTick callback exactly once | VERIFIED | `lib/core/ticker.dart` lines 39-40: `void tick() => _onTick?.call()` — correct single-call implementation |
| 6  | A GameSession + hintPenalty saved by GameStateRepository round-trips to an identical GameSession and identical hintPenalty (D-05) | VERIFIED | `game_state_repository.dart` serializes hintPenalty as explicit JSON field; round-trip test passes |
| 7  | A corrupt/unparseable snapshot returns null AND clears the stored key (D-08) | VERIFIED | `loadSession()` catch block: `await _prefs.remove(_key); return null;`; corrupt-snapshot test passes |
| 8  | saveBestScore writes a new score only when it is lower than the stored value (lower-wins) | VERIFIED | `high_score_repository.dart` line 28: `if (current == null \|\| score < current)`; lower-wins test 20→25→15=15 passes |
| 9  | A best score written then re-read from a fresh repository instance returns the same value | VERIFIED | Cold-read test in `high_score_repository_test.dart` passes |
| 10 | setMuted(true) persists and getMuted() returns true on a fresh instance; default is unmuted | VERIFIED | `user_prefs_repository.dart` with `mute_pref` key; mute persistence tests pass |
| 11 | Score equals (elapsed.inSeconds ~/ 10) + (errorCount * 5) + hintPenalty via Stopwatch, not tick counter (D-02) | VERIFIED | `_onTick()` reads `_stopwatch.elapsed.inSeconds`; no `_elapsedSeconds` counter exists; scoring formula test passes with correct result of 15 |
| 12 | pauseGame() leaves the internal Stopwatch stopped — the sole guarantee behind '30s backgrounded = +0s' | PARTIAL | Stopwatch.stop() IS called first (line 129, D-12 satisfied). BUT: no null guard (force-unwrap crash on line 131 if state.value is null at cold start), and no phase guard (pauseGame in idle/completed corrupts repository). The Stopwatch invariant works correctly in happy path; runtime defects in edge cases (CR-01 + CR-02 from 02-REVIEW.md). |
| 13 | RealAudioService init/dispose is leak-free; StubAudioService passes all interface assertions (WEL-04) | PARTIAL | StubAudioService: fully verified. RealAudioService: dispose() is unconditional after init() call (comment + test verify Pitfall 8). HOWEVER: `late` player fields (lines 8-10) mean calling dispose() WITHOUT ever calling init() would throw LateInitializationError (WR-01 from 02-REVIEW.md). Phase 2 test exercises init→dispose only; never-init→dispose path is untested and uncovered. |

**Score:** 10/13 truths verified (11 VERIFIED + 2 PARTIAL — but the 2 partial truths each have a confirmed runtime defect)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/game/game_phase.dart` | GamePhase enum (5 values) | VERIFIED | 1 line, correct values |
| `lib/features/game/game_mode.dart` | GameMode with statesMaster | VERIFIED | statesMaster present, flagsMaster absent |
| `lib/features/game/game_session.dart` | Value object with sentinel copyWith, ==/hashCode | VERIFIED | 88 lines, fully implemented |
| `lib/core/ticker.dart` | Ticker + RealTicker + FakeTicker | VERIFIED with gap | FakeTicker correct; RealTicker has timer-leak bug in start() (CR-03) |
| `lib/core/data/game_state_repository.dart` | Snapshot save/load/clear with hintPenalty + silent-discard | VERIFIED | 75 lines, hintPenalty explicit, D-08 remove() in catch |
| `lib/core/data/high_score_repository.dart` | Best-score-per-mode lower-wins, statesMaster key | VERIFIED | `high_score_states_master` key present, guard `score < current` present |
| `lib/core/data/user_prefs_repository.dart` | Mute + tutorial-seen persistence | VERIFIED | `mute_pref` and `tutorial_seen` keys present |
| `lib/features/game/game_session_notifier.dart` | AsyncNotifier with Stopwatch, scoring, restore-to-paused | VERIFIED with gaps | Stopwatch-as-truth implemented; scoring correct; restoreGame to paused correct. Gaps: missing null guards on pauseGame/resumeGame/recordDrop/completeGame (CR-01) and missing phase guard on pauseGame (CR-02) |
| `lib/features/game/game_lifecycle_observer.dart` | WidgetsBindingObserver (.paused/.hidden only) | VERIFIED | 44 lines; correct conditional; .inactive and .resumed do not trigger pauseGame |
| `lib/core/audio/real_audio_service.dart` | Hardened RealAudioService with unconditional dispose | VERIFIED with gap | Dispose is unconditional after init(); doc comment present. Gap: `late` fields not guarded for never-init path (WR-01) |
| `test/features/game/game_session_test.dart` | GameSession equality + copyWith sentinel tests | VERIFIED | 8 tests, all passing; covers sentinel, equality, matchedPostals list equality |
| `test/core/data/game_state_repository_test.dart` | Round-trip + corrupt-discard tests | VERIFIED | 4 tests; round-trip + corrupt-discard + absent-key + clearSession all pass |
| `test/core/data/high_score_repository_test.dart` | Lower-wins + cold-read tests | VERIFIED | 5 tests; lower-wins sequence 20→25→15=15 asserted |
| `test/core/data/user_prefs_repository_test.dart` | Mute persistence test | VERIFIED | 6 tests; default unmuted + setMuted(true) persistence both verified |
| `test/features/game/game_session_notifier_test.dart` | Scoring formula + pause + restore-to-paused tests | VERIFIED | 17 tests; scoring formula asserts 15, restoreGame asserts GamePhase.paused, FakeTicker used |
| `test/features/game/game_lifecycle_observer_test.dart` | Lifecycle .paused/.hidden pause, .inactive no-pause | VERIFIED | 4 tests; verifyNever for .inactive, .called(1) for .paused/.hidden |
| `test/core/audio/audio_service_test.dart` | WEL-04 lifecycle + interface-parity tests | VERIFIED | 2 tests; StubAudioService no-throw parity, RealAudioService init→dispose completes |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `game_session.dart` | `game_phase.dart` | `import 'game_phase.dart'` | WIRED | Line 5 import; GamePhase field used |
| `game_session.dart` | `game_mode.dart` | `import 'game_mode.dart'` | WIRED | Line 6 import; GameMode field used |
| `game_state_repository.dart` | `game_session.dart` | import + GameSession (de)serialization | WIRED | Package import present; GameSession constructed in loadSession |
| `high_score_repository.dart` | `game_mode.dart` | import + `_key(GameMode)` switch | WIRED | Line 3 import; switch on GameMode with `GameMode.statesMaster` branch |
| `game_state_repository.dart` | SharedPreferences | `_prefs.setString/getString/remove` on `game_session_snapshot` | WIRED | Lines 34, 40, 60, 67 |
| `game_session_notifier.dart` | `ticker.dart` | `_ticker.start(_onTick)` | WIRED | Lines 98, 139; `_ticker.stop()` on lines 130, 145, 204 |
| `game_session_notifier.dart` | `game_state_repository.dart` | `saveSession(.., hintPenalty:)` on pause/drop/hint; `clearSession` on complete | WIRED | Lines 133, 166, 198, 212 |
| `game_lifecycle_observer.dart` | `game_session_notifier.dart` | `_notifier.pauseGame()` on background lifecycle | WIRED | Line 39 |

### Data-Flow Trace (Level 4)

N/A — Phase 2 produces pure-Dart service classes and an AsyncNotifier. No widget rendering of dynamic data; data flows to tests via ProviderContainer and verified through mocktail verify() calls.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All 59 tests pass | `flutter test --reporter=compact` | 59/59 pass | PASS |
| `flutter analyze` clean | `flutter analyze` | No issues found | PASS |
| No `_elapsedSeconds` counter | grep `_elapsedSeconds` in notifier | Only in comments (DO NOT USE directive) | PASS |
| No ad imports in notifier | grep `import.*ads` in notifier | No matches | PASS |
| No flagsMaster token in source | grep `flagsMaster` in lib/ | Only in rename comment | PASS |
| No isoCode token in data layer | grep `isoCode` in lib/core/data/ | No matches | PASS |

### Probe Execution

No probes declared for Phase 2. Skipped.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| SCORE-01 | 02-01, 02-03 | Golf scoring: +1 per 10s elapsed | SATISFIED | `_onTick` computes `(elapsedSecs ~/ 10)`; scoring formula test asserts correct result |
| SCORE-02 | 02-01, 02-03 | Golf scoring: +5 per wrong drop | SATISFIED | `recordDrop(isCorrect: false)` increments errorCount; score += errorCount * 5; test passes |
| SCORE-05 | 02-02 | Best (lowest) score stored in SharedPreferences | SATISFIED | `HighScoreRepository.saveBestScore` with lower-wins guard; tests pass |
| SESS-01 | 02-03 | Pause/resume; auto-pause on background | SATISFIED (with gaps) | pauseGame() stops Stopwatch first; GameLifecycleObserver wires .paused/.hidden. Gap: null crash + phase-guard repo pollution (CR-01/CR-02) weakens SESS-01 in edge cases |
| SESS-02 | 02-02 | Mute preference persists | SATISFIED | UserPrefsRepository with `mute_pref` key; persistence tests pass |
| SESS-03 | 02-01, 02-02, 02-03 | In-progress session persists across relaunch | SATISFIED (with gap) | GameStateRepository round-trip test passes; snapshot flushed on pause/correct-drop. Gap: saveSession in pauseGame is unawaited (WR-03) — write may not complete before OS kill |
| WEL-04 | 02-04 | Audio service init/play/dispose without leaked players | SATISFIED (with gap) | RealAudioService dispose() unconditional after init(); test passes. Gap: never-init→dispose path would throw LateInitializationError (WR-01) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/game/game_session_notifier.dart` | 131 | `state.value!` force-unwrap | BLOCKER | Crash on backgrounding at cold start before provider build() resolves (CR-01) |
| `lib/features/game/game_session_notifier.dart` | 133 | `state.value!` force-unwrap (second use) | BLOCKER | Same crash path |
| `lib/features/game/game_session_notifier.dart` | 137 | `state.value!` force-unwrap in resumeGame | BLOCKER | Crash if resume called before provider ready |
| `lib/features/game/game_session_notifier.dart` | 156 | `state.value!` force-unwrap in recordDrop | BLOCKER | Crash if drop event received before provider ready |
| `lib/features/game/game_session_notifier.dart` | 205 | `state.value!` force-unwrap in completeGame | BLOCKER | Crash if complete called before provider ready |
| `lib/features/game/game_session_notifier.dart` | 126-134 | No phase guard in pauseGame | BLOCKER | pauseGame in idle/completed phase writes phantom snapshot and corrupts repo (CR-02) |
| `lib/core/ticker.dart` | 14-16 | `RealTicker.start()` no prior cancel | BLOCKER | Timer leak: double-fire of _onTick at 2x rate if start() called without stop() (CR-03) |
| `lib/features/game/game_session_notifier.dart` | 133 | `saveSession` unawaited | WARNING | Process-death: snapshot write dispatched but not awaited — may not commit before SIGKILL (WR-03) |
| `lib/core/audio/real_audio_service.dart` | 8-10 | `late` AudioPlayer fields | WARNING | LateInitializationError in dispose() if init() never called (WR-01) |
| `lib/features/game/game_session_notifier.dart` | 48 | `// ignore: unused_field` | INFO | _remainingPostals carried forward to Phase 4; lint suppression noted |

### Human Verification Required

None — all phase 2 deliverables are pure-Dart units testable programmatically. Visual behavior, lifecycle on real devices, and session-restore UX are deferred to Phase 4/5.

### Gaps Summary

**3 BLOCKER gaps:**

**Gap 1 (CR-01 + CR-02): pauseGame() / resumeGame() / recordDrop() / completeGame() are unsafe**

`pauseGame()` (and three other mutators) force-unwrap `state.value!` without a null guard. During provider initialization (async `SharedPreferences.getInstance()` call in `build()`), `state.value` is null. `GameLifecycleObserver` calls `pauseGame()` unconditionally on background events — backgrounding the app during cold start will crash with `Null check operator used on a null value`.

Additionally, `pauseGame()` has no phase guard. Backgrounding in the `idle` or `completed` phase silently writes a phantom "resumable game" snapshot to `SharedPreferences`, polluting the repository. Phase 4's "continue game" dialog would offer to resume a game that was never started.

The `startGame()` method correctly has `if (current == null) return;` — the fix is applying this same pattern to all four unguarded mutators plus adding the phase guard to `pauseGame()`.

**Gap 2 (CR-03): RealTicker.start() leaks Timer on double-call**

`RealTicker.start()` overwrites `_timer` without cancelling the existing timer. Calling `startGame()` on an active game (UI back-button flow) or `resumeGame()` on an already-playing session orphans the old timer. The orphaned timer fires indefinitely: countdown ends in ~2.5s instead of 5s; playing score accrues at 2x speed. The fix is one line: `_timer?.cancel();` at the start of `start()`.

**Note:** All 59 tests pass because tests use FakeTicker exclusively. CR-03 is a production-only defect.

**Gap 3 (WR-03): saveSession in pauseGame is unawaited — weakens SESS-03 process-death guarantee**

`pauseGame()` dispatches `saveSession()` as a fire-and-forget unawaited Future. For the crash-survival contract (SESS-03), the OS may SIGKILL the process between the Future dispatch and the platform channel write committing to disk. Changing `pauseGame()` to `Future<void>` and awaiting the write gives a meaningful improvement (the platform's post-`AppLifecycleState.paused` grace period is sufficient for SharedPreferences to flush). This is classified WARNING rather than BLOCKER because: (1) SharedPreferences writes are fast and the write usually completes; (2) the SESS-03 round-trip test passes; (3) the design decision is documented as a known tradeoff (D-07). However, the SESS-03 process-death survival guarantee is weaker than the plan specifies.

---

_Verified: 2026-05-31T11:46:00Z_
_Verifier: Claude (gsd-verifier)_
