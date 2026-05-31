# Phase 2: State Machine & Repositories — Research

**Researched:** 2026-05-31
**Domain:** Pure-Dart game logic — Riverpod 3.x AsyncNotifier state machine, Stopwatch-based timer, SharedPreferences repositories, AudioService lifecycle hardening, WidgetsBindingObserver lifecycle seam
**Confidence:** HIGH (all findings derived from direct codebase reads; no speculative web research needed for a port-with-deltas)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Keep a 5-second pre-game countdown. State machine is `idle → countdown → playing → paused → completed`. Countdown accrues no elapsed time and no score — Stopwatch does not start until "GO" (transition to `playing`).
- **D-02:** `Stopwatch` is the single source of truth for elapsed time. `pauseGame()` calls `_stopwatch.stop()`, `resumeGame()` calls `_stopwatch.start()`. A 1-second ticker exists ONLY to trigger a re-read of `_stopwatch.elapsed` and recompute the live score for the HUD — it never increments a counter.
- **D-03 (restore seam):** On restore, seed an offset: `elapsed = _restoredOffset + _stopwatch.elapsed`, with `_restoredOffset` = the persisted `elapsedSeconds` and the Stopwatch restarted from zero.
- **D-04:** `GameSession` carries `hintsRemaining` (starts at 2). Notifier exposes `useHint()` which applies +5 penalty and decrements `hintsRemaining`. Full scoring formula is unit-testable now.
- **D-05:** Persist `hintPenalty` (or hints-used count) EXPLICITLY in the snapshot. Do NOT reconstruct it by back-calculating from score. Store as a first-class field so the round-trip is exact (Criterion #4).
- **D-06:** Golf scoring is lower-is-better and uncapped. Score is always derived, never decremented.
- **D-07:** Save cadence = throttled 10s + flush on correct drop + on pause/background + immediate flush on every correct placement + `clearSession()` on completion.
- **D-08:** Corrupt/partial/old-schema snapshot → silently discard and start fresh. Any parse/validation failure returns `null`, clears the bad key, offers no error dialog.
- **D-09:** A restored session resumes into `GamePhase.paused` with the Stopwatch stopped. Player taps Resume to start the clock.
- **D-10:** Build `GameLifecycleObserver` (a `WidgetsBindingObserver`) in Phase 2, with its own widget test. NOT mounted to any screen until Phase 4.
- **D-11:** Auto-pause fires on `AppLifecycleState.paused` and `.hidden` only. `.inactive` is ignored.
- **D-12 (load-bearing):** Stopwatch uses a monotonic clock that keeps running while app is backgrounded. The ONLY thing that makes Criterion #2 ("30s backgrounded = +0s") true is auto-pause → `pauseGame()` → `_stopwatch.stop()`.

### Claude's Discretion

- `GameMode` enum rename: `flagsMaster` → `statesMaster`; enum is `{ learn, statesMaster, geographicalMaster, grandMaster }`.
- Snapshot JSON schema: `phase`, `mode`, `score`, `elapsedSeconds`, `errorCount`, `activePostal`, `hintsRemaining`, `hintPenalty` (D-05 explicit), `matchedPostals` (replaces `matchedIsoCodes`).
- High-score keys: port `high_score_repository.dart` verbatim, retargeted to renamed modes (`high_score_states_master`, etc.).
- Mute persistence: port `user_prefs_repository.dart` (`mute_pref` bool, default unmuted).
- WEL-04 audio work: harden + test existing Phase 1 audio service; no redesign.
- Ticker abstraction: keep Flags' `Ticker` / `RealTicker` / `FakeTicker` seam — tick is display-only per D-02.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 2 scope. Hint interaction UI (zoom/glow), "continue game" dialog, tutorial-seen flag usage, and mute-toggle widget are Phases 4–5.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCORE-01 | Golf scoring adds +1 point for every 10 seconds elapsed | Scoring formula: `(elapsed.inSeconds ~/ 10) + (errorCount * 5) + hintPenalty`; Stopwatch is the elapsed source (D-02); `_onTick` recalculates derived score from Stopwatch reading |
| SCORE-02 | Golf scoring adds +5 points for each token placed on incorrect state | `recordDrop(postal, isCorrect: false)` increments `errorCount` and recalculates score; `_hintPenalty` field holds accumulated hint cost |
| SCORE-05 | Best (lowest) score for each mode stored locally via SharedPreferences | `SharedPreferencesHighScoreRepository.saveBestScore` uses "lower wins" guard; `FutureProvider` awaits `SharedPreferences.getInstance()` |
| SESS-01 | Player can pause/resume; game auto-pauses when backgrounded (timer stops) | `GameLifecycleObserver` (WidgetsBindingObserver) calls `pauseGame()` on `.paused`/`.hidden`; `pauseGame()` calls `_stopwatch.stop()` (D-12 correctness point) |
| SESS-02 | Mute toggle preference persists across sessions | `SharedPreferencesUserPrefsRepository` with `mute_pref` bool key; `UserPrefsRepository` interface + `FutureProvider` |
| SESS-03 | In-progress session persists and can be resumed after relaunch | `SharedPreferencesGameStateRepository` with explicit `hintPenalty` field (D-05); `restoreGame()` lands in `GamePhase.paused` (D-09); `try/catch → null` silent discard (D-08) |
| WEL-04 | Audio service safely loads, plays, releases audio with no leaked players | RealAudioService (Phase 1) gets hardened dispose test; StubAudioService passes same interface assertions; mocktail used for mock wiring |

</phase_requirements>

---

## Summary

Phase 2 is a **port-with-deltas** from the Flags Around the World game layer. The Flags reference codebase provides complete, working implementations of every file needed — `GameSession`, `GameSessionNotifier`, `game_phase.dart`, `game_mode.dart`, `Ticker`, and all three repositories. The research task is to precisely specify which fields change, which fields are added, and which behavioral patterns must be replaced.

The single highest-risk correctness point is the timer model. Flags' notifier uses `_elapsedSeconds++` on each tick — a counter that becomes wrong the moment a tick is dropped, duplicated, or the app is backgrounded. The Stopwatch model replaces this: the Stopwatch is the elapsed source, the ticker is a display-only pulse that triggers a re-read. Critically, a Dart `Stopwatch` uses a monotonic clock that continues advancing while the app is backgrounded, so the ONLY mechanism that delivers "30s backgrounded = +0s" is `pauseGame()` calling `_stopwatch.stop()`. This must be both coded and deterministically tested.

The second most important delta is the snapshot round-trip. Flags reconstructs `hintPenalty` from `score - baseScore` arithmetic in `restoreGame()` — a fragile calculation that can round incorrectly. Phase 2 stores `hintPenalty` as an explicit first-class JSON field, so the round-trip is an identity operation.

**Primary recommendation:** Port the eight Flags source files directly, applying the three behavioral deltas (Stopwatch model, explicit hintPenalty, restore-to-paused), and unit-test each delta at the seam that proves it.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Scoring formula | Pure Dart (GameSessionNotifier) | — | Score is derived from fields owned by the notifier; no UI or persistence dependency |
| Elapsed time tracking | Pure Dart (Stopwatch inside notifier) | Display ticker (RealTicker/FakeTicker) | Stopwatch is truth; ticker is read-only pulse for HUD update |
| Countdown timer | Pure Dart (FakeTicker in tests) | — | Countdown uses same ticker seam; `_countdownTick` field incremented per tick |
| Session persistence | SharedPreferences (via repository) | FutureProvider (Riverpod) | Repository abstracts SharedPreferences; provider wires async init |
| High-score persistence | SharedPreferences (via repository) | — | Lower-wins guard lives in repository layer, not notifier |
| Mute preference | SharedPreferences (via repository) | — | Bool flag; no game-logic dependency |
| App lifecycle auto-pause | Flutter binding (GameLifecycleObserver) | Pure Dart (GameSessionNotifier.pauseGame) | Observer is the Flutter-binding touchpoint; notifier stays pure Dart |
| Audio lifecycle | just_audio (RealAudioService) | StubAudioService (test/default) | Three separate AudioPlayer instances; dispose is guarded by `_initialized` flag |

---

## Standard Stack

### Core (all already in pubspec.yaml — no new packages needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | `^3.3.1` | `AsyncNotifier` for GameSessionNotifier; `FutureProvider` for repositories | Locked by CLAUDE.md; direct Flags port |
| `riverpod_annotation` | `^4.0.2` | `@riverpod` codegen annotations | Locks codegen pattern from Flags |
| `shared_preferences` | `^2.5.5` | All three repositories' backing store | Locked by CLAUDE.md; COPPA-safe local-only |
| `just_audio` | `^0.10.5` | RealAudioService AudioPlayer instances | Locked by CLAUDE.md; already in Phase 1 |
| `mocktail` | `^1.0.5` | Mock AudioService, repositories in tests | Already in dev_dependencies |

No new packages are required. This phase uses only already-declared dependencies. [VERIFIED: direct pubspec.yaml read]

### Package Legitimacy Audit

> No new packages are installed in this phase — all dependencies were declared in Phase 1. This section is a confirmation, not a new audit.

| Package | Registry | Disposition |
|---------|----------|-------------|
| `flutter_riverpod` | pub.dev (flutter.dev) | Approved — Phase 1 |
| `shared_preferences` | pub.dev (flutter.dev) | Approved — Phase 1 |
| `just_audio` | pub.dev | Approved — Phase 1 |
| `mocktail` | pub.dev | Approved — Phase 1 |

**Packages removed due to slopcheck verdict:** none
**Packages flagged as suspicious:** none

---

## Architecture Patterns

### System Architecture Diagram

```
FakeTicker (test) ──────┐
RealTicker (prod) ───────┤─── 1s display pulse ──▶ GameSessionNotifier (AsyncNotifier<GameSession>)
                         │                              │
                         │   _stopwatch (Stopwatch)     │ state: AsyncData<GameSession>
                         │   _restoredOffset (int)      │
                         │   _countdownTick (int)       │
                         │   _hintPenalty (int)         │
                         │   _remainingPostals (List)   │
                         │                              ▼
GameLifecycleObserver ───┤── pauseGame() ──────▶  GamePhase state machine
(WidgetsBindingObserver) │   resumeGame()         idle → countdown → playing → paused → completed
                         │
                         ├── saveSession() ──────▶ SharedPreferencesGameStateRepository
                         │   loadSession()                │
                         │   clearSession()               └─▶ SharedPreferences
                         │                                        (key: game_session_snapshot)
                         ├── saveBestScore() ────▶ SharedPreferencesHighScoreRepository
                         │   getBestScore()               └─▶ SharedPreferences
                         │                                        (keys: high_score_*)
                         └── setMuted() ─────────▶ SharedPreferencesUserPrefsRepository
                             getMuted()                   └─▶ SharedPreferences
                                                                  (key: mute_pref)
```

### Recommended Project Structure

```
lib/
├── core/
│   ├── audio/                     # Phase 1 (harden + test only)
│   │   ├── audio_service.dart
│   │   ├── audio_service_provider.dart
│   │   ├── real_audio_service.dart
│   │   └── stub_audio_service.dart
│   ├── data/                      # Phase 2 NEW
│   │   ├── game_state_repository.dart
│   │   ├── high_score_repository.dart
│   │   └── user_prefs_repository.dart
│   ├── models/                    # Phase 1 (no changes)
│   │   └── state_data.dart
│   └── ticker.dart                # Phase 2 NEW (port from Flags)
├── features/
│   └── game/                      # Phase 2 NEW
│       ├── game_lifecycle_observer.dart
│       ├── game_mode.dart
│       ├── game_phase.dart
│       ├── game_session.dart
│       └── game_session_notifier.dart
test/
├── core/
│   ├── audio/                     # Phase 2 NEW
│   │   └── audio_service_test.dart
│   └── data/                      # Phase 2 NEW
│       ├── game_state_repository_test.dart
│       ├── high_score_repository_test.dart
│       └── user_prefs_repository_test.dart
└── features/
    └── game/                      # Phase 2 NEW
        ├── game_lifecycle_observer_test.dart
        ├── game_session_notifier_test.dart
        └── game_session_test.dart
```

---

## Precise Porting Deltas

### 1. game_mode.dart

**Flags source (line 1):**
```dart
enum GameMode { learn, flagsMaster, geographicalMaster, grandMaster }
```

**State States target:**
```dart
// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_mode.dart (renamed)
enum GameMode { learn, statesMaster, geographicalMaster, grandMaster }
```

**Impact downstream:** High-score SharedPreferences key for the second mode changes from `high_score_flags_master` to `high_score_states_master`. Update `_key()` switch in `high_score_repository.dart` accordingly.

### 2. game_phase.dart

Port verbatim — no changes required. [VERIFIED: direct read]

```dart
// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_phase.dart
enum GamePhase { idle, countdown, playing, paused, completed }
```

### 3. game_session.dart

**Fields to rename:**
- `activeIsoCode` → `activePostal` (type: `String?`, same sentinel pattern)
- `matchedIsoCodes` → `matchedPostals` (type: `List<String>`, same default `const []`)

**Fields unchanged:** `phase`, `mode`, `score`, `elapsed`, `errorCount`, `hintsRemaining`

**No new fields needed on `GameSession` itself.** `hintPenalty` is a notifier-internal field (`_hintPenalty`) that is persisted in the snapshot JSON but is NOT exposed on the value object — it is re-hydrated into `_hintPenalty` on `restoreGame()`. This preserves the clean separation: `GameSession` is the pure value object; the notifier owns mutable state. [VERIFIED: direct Flags source read + D-05 analysis]

The `copyWith` sentinel pattern, `_listEquals`, `==`/`hashCode` are all port-verbatim with field renames applied.

### 4. game_session_notifier.dart — The Critical Delta

**Fields in Flags to REMOVE:**
```dart
int _elapsedSeconds = 0;   // REMOVE — Stopwatch replaces this
```

**Fields to ADD:**
```dart
final Stopwatch _stopwatch = Stopwatch();
int _restoredOffset = 0;   // Seeded on restoreGame(); zero otherwise
```

**Fields to KEEP unchanged:**
```dart
int _countdownTick = 0;
int _hintPenalty = 0;
List<String> _remainingPostals = [];  // renamed from _remainingIsoCodes
```

**`startGame()` changes:**
- Add `_stopwatch.reset();` — reset offset too: `_restoredOffset = 0;`
- Remove `_elapsedSeconds = 0;`
- The `_ticker.start(_onTick)` call is kept — ticker still drives countdown

**`_onTick()` changes — the heart of D-02:**

Flags version (lines 83–101, the model to replace):
```dart
void _onTick() {
  if (current.phase == GamePhase.countdown) {
    _countdownTick++;
    if (_countdownTick >= 5) {
      state = AsyncData(current.copyWith(phase: GamePhase.playing));
    }
  } else if (current.phase == GamePhase.playing) {
    _elapsedSeconds++;                          // ← REMOVE THIS
    final score = (_elapsedSeconds ~/ 10) + ...
    state = AsyncData(current.copyWith(
      score: score,
      elapsed: Duration(seconds: _elapsedSeconds), // ← REMOVE THIS
    ));
  }
}
```

State States version:
```dart
void _onTick() {
  final current = state.value;
  if (current == null) return;
  if (current.phase == GamePhase.countdown) {
    _countdownTick++;
    if (_countdownTick >= 5) {
      // Start Stopwatch only when leaving countdown → playing (D-01)
      _stopwatch.start();
      state = AsyncData(current.copyWith(phase: GamePhase.playing));
    }
  } else if (current.phase == GamePhase.playing) {
    // Tick is display-only: read Stopwatch, never increment a counter (D-02)
    final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
    final score = (elapsedSecs ~/ 10) + (current.errorCount * 5) + _hintPenalty;
    state = AsyncData(current.copyWith(
      score: score,
      elapsed: Duration(seconds: elapsedSecs),
    ));
  }
}
```

**`pauseGame()` changes:**
```dart
void pauseGame() {
  _stopwatch.stop();        // D-02: Stopwatch stop is the ONLY thing that prevents
                            // background time from accumulating (D-12)
  _ticker.stop();
  state = AsyncData(state.value!.copyWith(phase: GamePhase.paused));
  _gameStateRepository?.saveSession(state.value!);  // D-07: flush on pause
}
```

**`resumeGame()` changes:**
```dart
void resumeGame() {
  state = AsyncData(state.value!.copyWith(phase: GamePhase.playing));
  _stopwatch.start();       // Resume Stopwatch from where it stopped
  _ticker.start(_onTick);
}
```

**`restoreGame()` changes — replacing Flags' back-calculation (D-05):**

Flags version (lines 113–124, the fragile model to replace):
```dart
void restoreGame(GameSession restoredSession) {
  _ticker.stop();
  _elapsedSeconds = restoredSession.elapsed.inSeconds;
  // Recover hintPenalty from persisted score. ← THIS IS THE FRAGILE PART
  final baseScore = (_elapsedSeconds ~/ 10) + (restoredSession.errorCount * 5);
  _hintPenalty = (restoredSession.score - baseScore).clamp(0, 9999).toInt();
  state = AsyncData(restoredSession.copyWith(phase: GamePhase.playing));  // ← wrong phase
  _ticker.start(_onTick);
}
```

State States version:
```dart
void restoreGame(GameSession restoredSession, {required int hintPenalty}) {
  _ticker.stop();
  _stopwatch.reset();            // Stopwatch starts from zero; offset carries the history
  _restoredOffset = restoredSession.elapsed.inSeconds;
  _hintPenalty = hintPenalty;   // D-05: explicit, not back-calculated
  _countdownTick = 0;
  // D-09: restore to paused — player taps Resume to start the clock
  state = AsyncData(restoredSession.copyWith(phase: GamePhase.paused));
  // Stopwatch is NOT started here — stays stopped until resumeGame()
}
```

**`recordDrop()` changes:**
- Rename `isoCode` parameter → `postal`
- Rename `matchedIsoCodes` → `matchedPostals`
- Elapsed read: replace `_elapsedSeconds ~/ 10` → `(_restoredOffset + _stopwatch.elapsed.inSeconds) ~/ 10`

**`completeGame()` changes:**
- Add `_stopwatch.stop()` before setting phase (Stopwatch has no more work to do)
- Rename `matchedIsoCodes` usages → `matchedPostals`

### 5. game_state_repository.dart — Snapshot Schema Delta

**Flags JSON fields (missing `hintPenalty`, using `matchedIsoCodes`):**
```json
{ "phase": "...", "mode": "...", "score": 0, "elapsedSeconds": 0,
  "errorCount": 0, "activeIsoCode": null, "hintsRemaining": 2,
  "matchedIsoCodes": [] }
```

**State States JSON schema (add `hintPenalty`, rename keys):**
```json
{ "phase": "...", "mode": "...", "score": 0, "elapsedSeconds": 0,
  "errorCount": 0, "activePostal": null, "hintsRemaining": 2,
  "hintPenalty": 0, "matchedPostals": [] }
```

**`saveSession()` delta:**
```dart
// Source: direct port of Flags game_state_repository.dart with field renames
Future<void> saveSession(GameSession session, {required int hintPenalty}) async {
  final json = {
    'phase': session.phase.name,
    'mode': session.mode.name,
    'score': session.score,
    'elapsedSeconds': session.elapsed.inSeconds,
    'errorCount': session.errorCount,
    'activePostal': session.activePostal,
    'hintsRemaining': session.hintsRemaining,
    'hintPenalty': hintPenalty,           // D-05: explicit field
    'matchedPostals': session.matchedPostals,
  };
  await _prefs.setString(_key, jsonEncode(json));
}
```

**`loadSession()` delta — returns a record with both session and hintPenalty:**

Since `hintPenalty` is NOT a field on `GameSession` (it is notifier-internal state), `loadSession()` must return it alongside the session. Options:
1. Return a `({GameSession session, int hintPenalty})` record (Dart 3.x named record — clean, no new class needed) [ASSUMED — syntactically correct for Dart 3.10, but verify with project style]
2. Add a separate `loadHintPenalty()` method
3. Store hintPenalty under a separate SharedPreferences key

**Recommendation:** Use option 1 (named record return type). Dart 3.x named records are idiomatic for small co-located return bundles. The caller (`GameSessionNotifier.build()`) reads both fields in a single await:
```dart
// In loadSession():
return (session: gameSession, hintPenalty: json['hintPenalty'] as int? ?? 0);
// In notifier build():
final loaded = await _gameStateRepository!.loadSession();
if (loaded != null) restoreGame(loaded.session, hintPenalty: loaded.hintPenalty);
```

**`loadSession()` silent-discard pattern (D-08) — port verbatim:**
```dart
// Source: direct port of Flags game_state_repository.dart — try/catch → null
@override
Future<({GameSession session, int hintPenalty})?> loadSession() async {
  try {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final gameSession = GameSession(
      phase: GamePhase.values.byName(json['phase'] as String),
      mode: GameMode.values.byName(json['mode'] as String),
      score: json['score'] as int,
      elapsed: Duration(seconds: json['elapsedSeconds'] as int),
      errorCount: json['errorCount'] as int,
      activePostal: json['activePostal'] as String?,
      hintsRemaining: json['hintsRemaining'] as int,
      matchedPostals: (json['matchedPostals'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
    return (session: gameSession, hintPenalty: json['hintPenalty'] as int? ?? 0);
  } catch (_) {
    // D-08: any parse failure → silent discard, clear the corrupted key
    await _prefs.remove(_key);
    return null;
  }
}
```

Note: Flags' `loadSession()` does NOT clear the bad key on failure — it just returns null and leaves garbage in storage. State States should add `_prefs.remove(_key)` in the catch block per D-08 ("clears the bad key").

### 6. high_score_repository.dart

Port verbatim with one change — the `_key()` switch:

```dart
// Source: direct port of Flags high_score_repository.dart
static String _key(GameMode mode) => switch (mode) {
  GameMode.learn               => 'high_score_learn',
  GameMode.statesMaster        => 'high_score_states_master',     // was flagsMaster
  GameMode.geographicalMaster  => 'high_score_geographical_master',
  GameMode.grandMaster         => 'high_score_grand_master',
};
```

`saveBestScore` "lower wins" guard ports verbatim — no changes.

### 7. user_prefs_repository.dart

Port verbatim — no changes required. [VERIFIED: direct read]

`_keyTutorial = 'tutorial_seen'` and `_keyMuted = 'mute_pref'` are stable cross-version.

### 8. ticker.dart

Port verbatim — no changes required. [VERIFIED: direct read]

`RealTicker` uses `Timer.periodic(const Duration(seconds: 1), ...)`. `FakeTicker` exposes a `tick()` method for deterministic test control.

### 9. game_lifecycle_observer.dart (NEW FILE — no Flags equivalent)

```dart
// New file — no Flags equivalent; implements D-10/D-11
import 'package:flutter/widgets.dart';
import '../features/game/game_session_notifier.dart'; // or via ref

class GameLifecycleObserver extends WidgetsBindingObserver {
  GameLifecycleObserver(this._notifier);
  final GameSessionNotifier _notifier;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // D-11: only .paused and .hidden trigger auto-pause.
    // .inactive is intentionally ignored (transient UI overlay, iOS control
    // center, incoming call banner — would cause false pauses).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _notifier.pauseGame();
    }
    // resumeGame() is NOT called on AppLifecycleState.resumed — the player
    // must explicitly tap Resume (D-09 principle extended to lifecycle resume).
  }
}
```

The observer is built and tested in Phase 2 but mounted to the game screen in Phase 4.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Elapsed time while paused | Custom tick counter | `Stopwatch.stop()` / `start()` | Stopwatch is monotonic; a counter drifts on dropped ticks and cannot exclude background time |
| hintPenalty round-trip | Back-calculate from `score - baseScore` | Store explicit `hintPenalty` in JSON | Arithmetic is fragile: `(elapsed ~/ 10)` truncates; rounding error corrupts the recovered value |
| Restore phase selection | Resume directly into `playing` | Restore into `GamePhase.paused` | Silent time-loss while player re-orients violates "forgiving above all" core value |
| SharedPreferences init | Synchronous init hack | `FutureProvider<T>((ref) async { final prefs = await SharedPreferences.getInstance(); ... })` | SharedPreferences.getInstance() is async on all platforms; sync access is undefined behavior |
| Corrupt snapshot handling | Error dialog to user | `try/catch → null` + `_prefs.remove(_key)` | Children must never see an error dialog from corrupted data (D-08 / core value) |
| App lifecycle auto-pause | Timer-based poll | `WidgetsBindingObserver.didChangeAppLifecycleState` | Platform callbacks are authoritative; polling adds latency and battery drain |

**Key insight:** The Stopwatch model, explicit hintPenalty persistence, and restore-to-paused are each a deliberate divergence from how Flags handled the same problem. The divergences exist because they fix real bugs visible in the Flags model under adversarial conditions (backgrounding, power-save, corrupt saves).

---

## Common Pitfalls

### Pitfall 1: Stopwatch Runs in Background Despite pauseGame()
**What goes wrong:** The `Stopwatch` uses a monotonic OS clock that is NOT stopped by process suspension. If `pauseGame()` is called but `_stopwatch.stop()` is omitted, elapsed time accumulated during 30s of backgrounding is included in the next HUD update.
**Why it happens:** Forgetting that `Stopwatch` != OS-process-paused; confusing "the ticker stopped" with "elapsed stopped".
**How to avoid:** `pauseGame()` must call `_stopwatch.stop()` AS ITS FIRST ACTION, before the state update. `resumeGame()` must call `_stopwatch.start()` before the state update.
**Warning signs:** Criterion #2 test passes in isolation (FakeTicker never advances the Stopwatch) but fails on device — need a test that simulates background time by advancing a FakeStowatch or using a real Stopwatch + explicit `stop()` verification.

### Pitfall 2: FakeTicker Does Not Fake the Stopwatch
**What goes wrong:** Tests use `FakeTicker` to control tick delivery but forget that `_stopwatch` is a real `Stopwatch`. Elapsed time in tests depends on wall-clock time of test execution, making tests non-deterministic.
**Why it happens:** `FakeTicker` was designed to fake the display-pulse trigger, not elapsed time.
**How to avoid:** In scoring/elapsed tests, do NOT test the exact number of seconds from a real Stopwatch. Instead:
  - Test that `score = (elapsed.inSeconds ~/ 10) + (errorCount * 5) + hintPenalty` with fixed inputs
  - Test that `pauseGame()` calls `_stopwatch.stop()` by verifying the Stopwatch's `isRunning` property
  - Use a Stopwatch injected via constructor to allow a mock/fake Stopwatch in tests if sub-second precision matters
**Alternative:** Inject `Stopwatch` as a constructor parameter alongside `Ticker` to enable full test isolation.

### Pitfall 3: hintPenalty Back-Calculation Silently Corrupts on Restore
**What goes wrong:** Flags' approach reconstructs `_hintPenalty = score - (elapsed ~/ 10) - (errorCount * 5)`. Due to integer truncation in `elapsed ~/ 10`, the recovered penalty can be off by ±1 or more, yielding a different score after the first tick post-restore.
**Why it happens:** The scoring formula uses integer truncation at two points: `elapsed.inSeconds ~/ 10`. A session with 19s elapsed has a time component of 1, not 1.9. On restore, the formula runs again and the slight elapsed drift changes the base score.
**How to avoid:** D-05 — store `hintPenalty` as an explicit JSON field. Criterion #4 round-trip test must include a session that has used hints.

### Pitfall 4: Autosave Races on Correct Drop
**What goes wrong:** `recordDrop(postal, isCorrect: true)` calls `_gameStateRepository?.saveSession(updated)` without awaiting. If the app is killed immediately after, the save may not have completed.
**Why it happens:** `saveSession()` is `async`; the notifier method is synchronous by convention (`void recordDrop`).
**How to avoid:** This is acceptable — `SharedPreferences.setString()` enqueues the write to the platform; a `kill -9` right after the call can lose the write. This is the documented tradeoff (D-07 says "immediate flush" meaning the call is made immediately, not that it is guaranteed atomic). Document this limitation in code comments.

### Pitfall 5: `GameLifecycleObserver` Mounted Without `WidgetsBinding` Registration
**What goes wrong:** Creating a `GameLifecycleObserver` instance does nothing unless it is registered with `WidgetsBinding.instance.addObserver(this)`.
**Why it happens:** The WidgetsBindingObserver pattern requires explicit registration; the class hierarchy alone does not register anything.
**How to avoid:** `GameLifecycleObserver` must call `WidgetsBinding.instance.addObserver(this)` in its constructor or attach method, and `WidgetsBinding.instance.removeObserver(this)` on dispose. The widget test must call `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused)` to simulate the lifecycle event, which bypasses the need for a real platform.

### Pitfall 6: `GameSessionNotifier` Provider Without Ticker Injection
**What goes wrong:** The Flags pattern declares the provider with `() => GameSessionNotifier(ticker: RealTicker())` hard-coded. This is not overridable in tests.
**Why it happens:** Hard-coded constructor arguments in provider factory lambdas.
**How to avoid:** Tests use `ProviderContainer` overrides:
```dart
final container = ProviderContainer(overrides: [
  gameSessionProvider.overrideWith(() => GameSessionNotifier(
    ticker: fakeTicker,
    gameStateRepository: fakeRepo,
    highScoreRepository: fakeRepo,
  )),
]);
```
This is the exact Flags pattern — the constructor already accepts optional repositories. Carry forward.

### Pitfall 7: `.inactive` Lifecycle State Causing False Auto-Pause on iOS
**What goes wrong:** iOS fires `AppLifecycleState.inactive` when the user pulls down Notification Center or swipes to the app switcher. Pausing on `.inactive` produces a jarring freeze during every notifications check.
**Why it happens:** iOS lifecycle state machine has more transitional states than Android.
**How to avoid:** D-11 — pause ONLY on `.paused` and `.hidden`. Never on `.inactive`.

### Pitfall 8: No-Op `dispose()` on RealAudioService When `_initialized = false`
**What goes wrong:** If `init()` fails (asset not found, platform error), `_initialized` is false. A subsequent `dispose()` call tries to dispose the `late AudioPlayer` fields that were assigned but then threw during asset load — the players are partially initialized.
**Why it happens:** `late` fields are assigned before the asset-loading `try` block; if the try fails, the players exist but are in an error state.
**How to avoid:** Current Phase 1 implementation assigns players before the try block, so dispose will always work (an `AudioPlayer` can be disposed even if `setAsset` failed). This is intentional — document it. The leak-free dispose test must verify this: init with a bad asset path → `_initialized = false` → dispose should not throw.

---

## Code Examples

### Scoring Formula (verified against SCORE-01/02/HINT-02)

```dart
// Source: derived from Flags game_session_notifier.dart line 95, with Stopwatch delta (D-02)
// Formula: (elapsedSeconds ~/ 10) + (errorCount * 5) + hintPenalty
// All three terms are non-negative; score can only increase (lower-is-better, D-06)
int _computeScore(int elapsedSeconds, int errorCount, int hintPenalty) {
  return (elapsedSeconds ~/ 10) + (errorCount * 5) + hintPenalty;
}
// Called from _onTick() using: _restoredOffset + _stopwatch.elapsed.inSeconds
```

### Stopwatch + Offset Elapsed Pattern (D-02/D-03)

```dart
// Source: design from D-02/D-03 context decisions
// NEVER read _stopwatch.elapsed alone after a restore — always add _restoredOffset
int get _currentElapsedSeconds => _restoredOffset + _stopwatch.elapsed.inSeconds;
```

### Snapshot JSON Round-Trip (D-05, Criterion #4)

```dart
// saveSession writes hintPenalty explicitly (contrast with Flags which omits it)
final json = {
  'phase': session.phase.name,
  'mode': session.mode.name,
  'score': session.score,
  'elapsedSeconds': session.elapsed.inSeconds,
  'errorCount': session.errorCount,
  'activePostal': session.activePostal,       // was activeIsoCode in Flags
  'hintsRemaining': session.hintsRemaining,
  'hintPenalty': hintPenalty,                 // NEW — first-class field (D-05)
  'matchedPostals': session.matchedPostals,   // was matchedIsoCodes in Flags
};
```

### FutureProvider Pattern for Repositories (Riverpod 3.x)

```dart
// Source: direct port of Flags game_state_repository.dart lines 66-69
// All three repositories follow this identical pattern
final gameStateRepositoryProvider = FutureProvider<GameStateRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesGameStateRepository(prefs);
});
```

### GameLifecycleObserver Widget Test Pattern (D-10)

```dart
// Tests fire didChangeAppLifecycleState via tester.binding — no platform needed
testWidgets('auto-pause fires on paused state', (tester) async {
  final fakeTicker = FakeTicker();
  // ... build observer with mock notifier ...
  await tester.pump();
  // Simulate backgrounding:
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  // Verify notifier.pauseGame() was called via mock assertion
});
```

### mocktail Mock Repository Pattern

```dart
// Source: mocktail ^1.0.5 — already in dev_dependencies
class MockGameStateRepository extends Mock implements GameStateRepository {}
class MockHighScoreRepository extends Mock implements HighScoreRepository {}

// In test setUp:
when(() => mockRepo.loadSession()).thenAnswer((_) async => null);
when(() => mockRepo.saveSession(any(), hintPenalty: any(named: 'hintPenalty')))
    .thenAnswer((_) async {});
```

---

## State of the Art

| Old Approach (Flags) | Current Approach (State States) | Reason for Change |
|----------------------|--------------------------------|-------------------|
| `_elapsedSeconds++` per tick | `Stopwatch.elapsed.inSeconds` + offset | Tick drops/duplicates corrupt a counter; Stopwatch is monotonic and immune |
| `restoreGame()` back-calculates hintPenalty | Explicit `hintPenalty` JSON field | Back-calculation silently corrupts on integer truncation edge cases |
| Restore to `GamePhase.playing` | Restore to `GamePhase.paused` | Child's placed-states work must be visible before clock restarts ("forgiving above all") |
| `flagsMaster` enum value | `statesMaster` enum value | Domain rename; SharedPreferences key changes accordingly |
| `matchedIsoCodes` / `activeIsoCode` | `matchedPostals` / `activePostal` | Canonical entity key is postal abbreviation (established Phase 1) |
| No explicit silent-discard `remove()` on bad snapshot | `_prefs.remove(_key)` in catch block | Prevents corrupt data from blocking every future load attempt |

---

## Runtime State Inventory

This is a greenfield phase (no rename of existing data). No runtime state exists in storage yet — the app has no installed user base, no SharedPreferences data to migrate. This section is N/A.

**Stored data:** None — verified by Phase 1 delivering a blank scaffold with no game sessions persisted.
**Live service config:** None — fully offline app.
**OS-registered state:** None.
**Secrets/env vars:** None relevant to this phase.
**Build artifacts:** None requiring migration.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dart 3.x named record syntax `({GameSession session, int hintPenalty})` is idiomatic for `loadSession()` return type in this project | Porting Deltas §5 | LOW — Dart 3.10 syntax is verified; risk is only stylistic. Alternative: separate method or wrapper class |
| A2 | Injecting `Stopwatch` as a constructor parameter to `GameSessionNotifier` is needed for deterministic elapsed-time tests | Common Pitfalls §2 | LOW — if tests only verify `isRunning` state (not exact elapsed), injection is not required. The `FakeTicker` already provides control over when ticks fire. |

---

## Open Questions

1. **Stopwatch injection for tests**
   - What we know: `FakeTicker` controls when ticks fire; the real `Stopwatch` inside the notifier accumulates wall-clock time during tests
   - What's unclear: Whether tests need sub-second Stopwatch precision (they likely don't — scoring tests use integer seconds, which are stable over a short test run)
   - Recommendation: Do NOT inject Stopwatch in Phase 2. Verify `isRunning` state in pause/resume tests; use fixed-input formula tests for scoring. If flakiness emerges in CI, add Stopwatch injection in Phase 3.

2. **`saveSession` signature with hintPenalty**
   - What we know: `GameStateRepository` interface currently has `Future<void> saveSession(GameSession session)`. Adding `hintPenalty` as a required parameter changes the interface.
   - What's unclear: Whether `GameSessionNotifier` should pass `_hintPenalty` as a parameter, or if `GameStateRepository` should instead store a richer snapshot type
   - Recommendation: Update the interface to `saveSession(GameSession session, {required int hintPenalty})`. This keeps `GameSession` as a pure value object and keeps `hintPenalty` as notifier-owned state. The named parameter makes call sites explicit.

---

## Environment Availability

This phase is code-only (pure Dart, no external tools, no native dependencies beyond what Phase 1 established). Flutter SDK and dart test runner are the only requirements.

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter SDK | All Dart files | ✓ | >=3.44.0 (from pubspec) | — |
| `shared_preferences` | Repositories | ✓ | ^2.5.5 (in pubspec) | — |
| `just_audio` | AudioService tests | ✓ | ^0.10.5 (in pubspec) | — |
| `mocktail` | All mock-based tests | ✓ | ^1.0.5 (in dev_dependencies) | — |
| `flutter_riverpod` | GameSessionNotifier | ✓ | ^3.3.1 (in pubspec) | — |

No missing dependencies. No blockers.

---

## Validation Architecture

> `nyquist_validation: true` in `.planning/config.json` — section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) + mocktail ^1.0.5 |
| Config file | none — flutter test uses pubspec.yaml test runner |
| Quick run command | `flutter test test/features/game/ test/core/data/ test/core/audio/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCORE-01 | `+1 per 10 elapsed seconds` in formula | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ Wave 0 |
| SCORE-01 | Stopwatch-based elapsed, not tick counter | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ Wave 0 |
| SCORE-02 | `+5 per wrong drop` in formula | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ Wave 0 |
| SCORE-02 | `+5 per hint used` in formula | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ Wave 0 |
| SCORE-05 | Best score written to SharedPreferences | unit | `flutter test test/core/data/high_score_repository_test.dart` | ❌ Wave 0 |
| SCORE-05 | Cold-launch re-read returns same value | unit | `flutter test test/core/data/high_score_repository_test.dart` | ❌ Wave 0 |
| SCORE-05 | Lower-wins guard (new score replaces only if better) | unit | `flutter test test/core/data/high_score_repository_test.dart` | ❌ Wave 0 |
| SESS-01 | Auto-pause fires on `.paused` lifecycle state | widget | `flutter test test/features/game/game_lifecycle_observer_test.dart` | ❌ Wave 0 |
| SESS-01 | Auto-pause fires on `.hidden` lifecycle state | widget | `flutter test test/features/game/game_lifecycle_observer_test.dart` | ❌ Wave 0 |
| SESS-01 | `.inactive` does NOT trigger pause | widget | `flutter test test/features/game/game_lifecycle_observer_test.dart` | ❌ Wave 0 |
| SESS-01 | Stopwatch.stop() is called in pauseGame() | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ Wave 0 |
| SESS-02 | Mute preference persists across sessions | unit | `flutter test test/core/data/user_prefs_repository_test.dart` | ❌ Wave 0 |
| SESS-03 | Snapshot round-trip: identical GameSession after save+load | unit | `flutter test test/core/data/game_state_repository_test.dart` | ❌ Wave 0 |
| SESS-03 | Round-trip includes hints-used (Criterion #4) | unit | `flutter test test/core/data/game_state_repository_test.dart` | ❌ Wave 0 |
| SESS-03 | Corrupt snapshot → null, key cleared, no exception | unit | `flutter test test/core/data/game_state_repository_test.dart` | ❌ Wave 0 |
| SESS-03 | Restored session lands in `GamePhase.paused` (D-09) | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ Wave 0 |
| WEL-04 | RealAudioService init, playCorrect/playError, dispose — no leaked players | unit | `flutter test test/core/audio/audio_service_test.dart` | ❌ Wave 0 |
| WEL-04 | StubAudioService is no-op and passes same interface assertions | unit | `flutter test test/core/audio/audio_service_test.dart` | ❌ Wave 0 |

### Criterion → Test Seam Mapping (Phase 2 Success Criteria)

| Criterion | Test Seam | Deterministic Mechanism |
|-----------|-----------|------------------------|
| #1 (scoring formula) | `GameSessionNotifier` with `FakeTicker` and fixed inputs | `FakeTicker.tick()` triggers one `_onTick`; assert `state.value!.score` against expected formula output with known `errorCount` and `hintPenalty` |
| #2 (30s background = +0s) | `pauseGame()` → assert `_stopwatch.isRunning == false`; then manually check `GameSessionNotifier` notifier state does NOT advance while stopwatch is stopped | `FakeTicker` never fires during paused phase; Stopwatch is stopped; time-check: record elapsed before pause, advance wall clock slightly via `Future.delayed`, resume, check elapsed did not jump |
| #3 (best score + mute persist) | `SharedPreferencesHighScoreRepository` + `SharedPreferencesUserPrefsRepository` with `SharedPreferences.setMockInitialValues({})` | `flutter_test` provides `SharedPreferences.setMockInitialValues`; write → dispose container → new container → read = same value |
| #4 (snapshot round-trip) | `SharedPreferencesGameStateRepository` save then load, compare via `==` | `GameSession` has `==`/`hashCode` from Flags port; include a session with `errorCount > 0` and `hintsRemaining < 2` to stress `hintPenalty` field |
| #5 (audio service) | `RealAudioService` unit test with real `just_audio` binding | `TestWidgetsFlutterBinding.ensureInitialized()` required; test init with missing asset path verifies `_initialized = false`; test dispose does not throw |

### Sampling Rate

- **Per task commit:** `flutter test test/features/game/game_session_notifier_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/features/game/game_session_notifier_test.dart` — covers SCORE-01, SCORE-02, SESS-01, SESS-03 (restored-to-paused)
- [ ] `test/features/game/game_session_test.dart` — covers `GameSession` `==`/`hashCode`/`copyWith` correctness
- [ ] `test/features/game/game_lifecycle_observer_test.dart` — covers SESS-01 (D-10/D-11)
- [ ] `test/core/data/game_state_repository_test.dart` — covers SESS-03 (snapshot round-trip, corrupt discard)
- [ ] `test/core/data/high_score_repository_test.dart` — covers SCORE-05
- [ ] `test/core/data/user_prefs_repository_test.dart` — covers SESS-02
- [ ] `test/core/audio/audio_service_test.dart` — covers WEL-04

---

## Security Domain

> `security_enforcement` is absent from config.json — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth in this app (COPPA: no accounts) |
| V3 Session Management | partial | Session snapshot is local-only SharedPreferences; no session tokens; no network |
| V4 Access Control | no | Single-user local app |
| V5 Input Validation | yes | Snapshot deserialization: `GamePhase.values.byName()` throws on unknown values; wrapped in `try/catch → null` (D-08) |
| V6 Cryptography | no | No encryption needed for local game state |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Snapshot injection via modified SharedPreferences (rooted device) | Tampering | `try/catch → null` silent discard (D-08) — corrupt or tampered data is treated as absent |
| Persistent identifier in snapshot | Info Disclosure (COPPA) | Snapshot fields contain ONLY game state values: mode, score, elapsed, matched postals. No device ID, no user ID, no install ID |
| `hintPenalty` negative value injection | Tampering | `_hintPenalty` is always positive (only added to, never subtracted); `saveBestScore` "lower wins" guard prevents a tampered low score from being stored as best |

**COPPA note:** The snapshot JSON must never contain any persistent identifier. The field set (`phase`, `mode`, `score`, `elapsedSeconds`, `errorCount`, `activePostal`, `hintsRemaining`, `hintPenalty`, `matchedPostals`) contains zero identity information. [VERIFIED: direct field enumeration, D-05, REQUIREMENTS.md COMP-01]

---

## Sources

### Primary (HIGH confidence)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session.dart` — direct read, authoritative GameSession value object template
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session_notifier.dart` — direct read, authoritative notifier template; identifies exact fields to change
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_phase.dart` — direct read, port-verbatim enum
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_mode.dart` — direct read, identifies `flagsMaster` → `statesMaster` rename
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\ticker.dart` — direct read, authoritative FakeTicker seam
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\game_state_repository.dart` — direct read; identifies missing `hintPenalty` field and missing `remove()` on error
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\high_score_repository.dart` — direct read, authoritative "lower wins" guard
- `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\user_prefs_repository.dart` — direct read, port-verbatim
- `C:\code\Claude\StateTheStates\lib\core\audio\audio_service.dart` — direct read, current interface
- `C:\code\Claude\StateTheStates\lib\core\audio\real_audio_service.dart` — direct read, Phase 1 implementation to harden
- `C:\code\Claude\StateTheStates\lib\core\audio\stub_audio_service.dart` — direct read, Phase 1 no-op
- `C:\code\Claude\StateTheStates\lib\core\models\state_data.dart` — direct read, confirms `postal` canonical key
- `C:\code\Claude\StateTheStates\pubspec.yaml` — direct read, confirms all dependencies already declared
- `.planning/phases/02-state-machine-repositories/02-CONTEXT.md` — direct read, all 12 locked decisions
- `.planning/REQUIREMENTS.md` — direct read, Phase 2 requirement text
- `.planning/ROADMAP.md` — direct read, 5 success criteria

### Secondary (MEDIUM confidence)
- None required — all claims derived from direct codebase reads.

### Tertiary (LOW confidence — flagged)
- None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already in pubspec.yaml, no new packages needed
- Architecture: HIGH — derived from direct reads of both Flags source and Phase 1 code
- Porting deltas: HIGH — derived from line-by-line comparison of Flags source against Context decisions
- Pitfalls: HIGH — derived from specific code patterns observed in both codebases + D-12 correctness analysis
- Validation seams: HIGH — test patterns derived from existing test infrastructure in this repo

**Research date:** 2026-05-31
**Valid until:** 2026-07-31 (stable stack; no fast-moving dependencies)
