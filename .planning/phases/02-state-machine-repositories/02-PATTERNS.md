# Phase 2: State Machine & Repositories - Pattern Map

**Mapped:** 2026-05-31
**Files analyzed:** 17 (10 source files + 7 test files)
**Analogs found:** 16 / 17 (game_lifecycle_observer.dart has no analog — new file)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/game/game_session.dart` | model | transform | `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session.dart` | exact (port-with-renames) |
| `lib/features/game/game_session_notifier.dart` | service | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session_notifier.dart` | exact (port-with-deltas) |
| `lib/features/game/game_phase.dart` | model | — | `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_phase.dart` | exact (verbatim port) |
| `lib/features/game/game_mode.dart` | model | — | `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_mode.dart` | exact (one rename) |
| `lib/features/game/game_lifecycle_observer.dart` | middleware | event-driven | none | no analog |
| `lib/core/ticker.dart` | utility | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\core\ticker.dart` | exact (verbatim port) |
| `lib/core/data/game_state_repository.dart` | service | CRUD | `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\game_state_repository.dart` | exact (port-with-deltas) |
| `lib/core/data/high_score_repository.dart` | service | CRUD | `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\high_score_repository.dart` | exact (one key rename) |
| `lib/core/data/user_prefs_repository.dart` | service | CRUD | `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\user_prefs_repository.dart` | exact (verbatim port) |
| `lib/core/audio/real_audio_service.dart` | service | event-driven | `lib/core/audio/real_audio_service.dart` (Phase 1, this repo) | exact (harden only) |
| `lib/core/audio/stub_audio_service.dart` | service | — | `lib/core/audio/stub_audio_service.dart` (Phase 1, this repo) | exact (no code changes) |
| `test/features/game/game_session_test.dart` | test | — | `test/core/models/state_data_test.dart` (Phase 1, this repo) | role-match |
| `test/features/game/game_session_notifier_test.dart` | test | event-driven | `test/core/data/state_data_service_test.dart` (Phase 1, this repo) | role-match |
| `test/features/game/game_lifecycle_observer_test.dart` | test | event-driven | `test/core/data/state_data_service_test.dart` (Phase 1, this repo) | role-match (widget test) |
| `test/core/data/game_state_repository_test.dart` | test | CRUD | `test/core/data/state_data_service_test.dart` (Phase 1, this repo) | role-match |
| `test/core/data/high_score_repository_test.dart` | test | CRUD | `test/core/data/state_data_service_test.dart` (Phase 1, this repo) | role-match |
| `test/core/data/user_prefs_repository_test.dart` | test | CRUD | `test/core/data/state_data_service_test.dart` (Phase 1, this repo) | role-match |
| `test/core/audio/audio_service_test.dart` | test | event-driven | `lib/core/audio/real_audio_service.dart` (Phase 1, this repo) | role-match |

---

## Pattern Assignments

### `lib/features/game/game_phase.dart` (model)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_phase.dart`
**Action:** Verbatim port — no changes.

**Complete file** (line 1):
```dart
enum GamePhase { idle, countdown, playing, paused, completed }
```

---

### `lib/features/game/game_mode.dart` (model)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_mode.dart`
**Action:** One rename: `flagsMaster` → `statesMaster`.

**Flags source** (line 1):
```dart
enum GameMode { learn, flagsMaster, geographicalMaster, grandMaster }
```

**State States target:**
```dart
enum GameMode { learn, statesMaster, geographicalMaster, grandMaster }
```

---

### `lib/features/game/game_session.dart` (model, transform)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session.dart`
**Action:** Port with field renames: `activeIsoCode` → `activePostal`, `matchedIsoCodes` → `matchedPostals`. All other fields, `copyWith` sentinel pattern, `_listEquals`, `==`/`hashCode` are verbatim.

**Imports pattern** (lines 1–2):
```dart
import 'game_phase.dart';
import 'game_mode.dart';
```

**Constructor and fields** (lines 4–23):
```dart
class GameSession {
  const GameSession({
    required this.phase,
    required this.mode,
    required this.score,
    required this.elapsed,
    required this.errorCount,
    this.activePostal,            // renamed from activeIsoCode
    required this.hintsRemaining,
    this.matchedPostals = const [],  // renamed from matchedIsoCodes
  });

  final GamePhase phase;
  final GameMode mode;
  final int score;
  final Duration elapsed;
  final int errorCount;
  final String? activePostal;
  final int hintsRemaining;
  final List<String> matchedPostals;
```

**copyWith sentinel pattern** (lines 25–49 of analog):
```dart
  static const Object _sentinel = Object();

  GameSession copyWith({
    GamePhase? phase,
    GameMode? mode,
    int? score,
    Duration? elapsed,
    int? errorCount,
    Object? activePostal = _sentinel,   // renamed; sentinel enables null pass-through
    int? hintsRemaining,
    List<String>? matchedPostals,       // renamed
  }) {
    return GameSession(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      score: score ?? this.score,
      elapsed: elapsed ?? this.elapsed,
      errorCount: errorCount ?? this.errorCount,
      activePostal: activePostal == _sentinel
          ? this.activePostal
          : activePostal as String?,
      hintsRemaining: hintsRemaining ?? this.hintsRemaining,
      matchedPostals: matchedPostals ?? this.matchedPostals,
    );
  }
```

**Equality pattern** (lines 51–82 of analog — verbatim except field renames):
```dart
  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSession &&
          phase == other.phase &&
          mode == other.mode &&
          score == other.score &&
          elapsed == other.elapsed &&
          errorCount == other.errorCount &&
          activePostal == other.activePostal &&
          hintsRemaining == other.hintsRemaining &&
          _listEquals(matchedPostals, other.matchedPostals);

  @override
  int get hashCode => Object.hash(
        phase,
        mode,
        score,
        elapsed,
        errorCount,
        activePostal,
        hintsRemaining,
        Object.hashAll(matchedPostals),
      );
```

---

### `lib/features/game/game_session_notifier.dart` (service, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session_notifier.dart`
**Action:** Port with three behavioral deltas (D-02 Stopwatch, D-05 explicit hintPenalty, D-09 restore-to-paused) and field renames.

**Imports pattern** (lines 1–7 of analog — update package name):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/core/ticker.dart';
import 'package:state_states/core/data/game_state_repository.dart';
import 'package:state_states/core/data/high_score_repository.dart';
```

**Provider declaration pattern** (lines 9–12 of analog):
```dart
final gameSessionProvider =
    AsyncNotifierProvider<GameSessionNotifier, GameSession>(
  () => GameSessionNotifier(ticker: RealTicker()),
);
```

**Class + constructor + fields** (lines 14–33 of analog — REPLACE `_elapsedSeconds`, ADD Stopwatch fields, rename `_remainingIsoCodes`):
```dart
class GameSessionNotifier extends AsyncNotifier<GameSession> {
  GameSessionNotifier({
    required Ticker ticker,
    GameStateRepository? gameStateRepository,
    HighScoreRepository? highScoreRepository,
  })  : _ticker = ticker,
        _gameStateRepository = gameStateRepository,
        _highScoreRepository = highScoreRepository;

  final Ticker _ticker;
  GameStateRepository? _gameStateRepository;
  HighScoreRepository? _highScoreRepository;

  // D-02: Stopwatch is the single source of truth for elapsed time.
  // REMOVE _elapsedSeconds — it was the Flags model; Stopwatch replaces it.
  final Stopwatch _stopwatch = Stopwatch();
  int _restoredOffset = 0;   // D-03: seeded on restoreGame(); zero on fresh start
  int _countdownTick = 0;
  int _hintPenalty = 0;
  List<String> _remainingPostals = [];  // renamed from _remainingIsoCodes
```

**build() pattern** (lines 36–57 of analog — update field names, initial value uses `activePostal`):
```dart
  @override
  Future<GameSession> build() async {
    _countdownTick = 0;
    _hintPenalty = 0;
    _restoredOffset = 0;
    ref.onDispose(_ticker.stop);

    _gameStateRepository ??=
        await ref.watch(gameStateRepositoryProvider.future);
    _highScoreRepository ??=
        await ref.watch(highScoreRepositoryProvider.future);

    return const GameSession(
      phase: GamePhase.idle,
      mode: GameMode.learn,
      score: 0,
      elapsed: Duration.zero,
      errorCount: 0,
      activePostal: null,
      hintsRemaining: 2,
    );
  }
```

**startGame() pattern** (lines 62–81 of analog — rename fields, reset Stopwatch):
```dart
  void startGame(GameMode mode) {
    final current = state.value;
    if (current == null) return;
    _stopwatch.reset();     // D-02: fresh Stopwatch; Stopwatch does NOT start yet
    _restoredOffset = 0;
    _countdownTick = 0;
    _hintPenalty = 0;
    _remainingPostals = [];
    state = AsyncData(
      current.copyWith(
        phase: GamePhase.countdown,
        mode: mode,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        activePostal: null,
        hintsRemaining: 2,
      ),
    );
    _ticker.start(_onTick);
  }
```

**_onTick() — the critical delta** (lines 83–101 of analog — REPLACE elapsed model):
```dart
  // D-02: Stopwatch is the elapsed source. The ticker is a display-only pulse.
  // A dropped/late/duplicated tick cannot corrupt elapsed.
  void _onTick() {
    final current = state.value;
    if (current == null) return;

    if (current.phase == GamePhase.countdown) {
      _countdownTick++;
      if (_countdownTick >= 5) {
        // D-01: Stopwatch starts ONLY when leaving countdown → playing.
        _stopwatch.start();
        state = AsyncData(current.copyWith(phase: GamePhase.playing));
      }
    } else if (current.phase == GamePhase.playing) {
      // D-02: read Stopwatch + offset; never increment a counter.
      final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
      final score = (elapsedSecs ~/ 10) + (current.errorCount * 5) + _hintPenalty;
      state = AsyncData(current.copyWith(
        score: score,
        elapsed: Duration(seconds: elapsedSecs),
      ));
    }
  }
```

**pauseGame() — Stopwatch.stop() is load-bearing** (lines 103–106 of analog — ADD stopwatch.stop(), ADD snapshot flush):
```dart
  void pauseGame() {
    // D-02/D-12: _stopwatch.stop() is the ONLY thing that prevents background
    // time from accumulating. Must come before the state update.
    _stopwatch.stop();
    _ticker.stop();
    state = AsyncData(state.value!.copyWith(phase: GamePhase.paused));
    _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
  }
```

**resumeGame()** (lines 108–111 of analog):
```dart
  void resumeGame() {
    state = AsyncData(state.value!.copyWith(phase: GamePhase.playing));
    _stopwatch.start();    // Resume Stopwatch from where it stopped
    _ticker.start(_onTick);
  }
```

**restoreGame() — replaces Flags' fragile back-calculation** (lines 113–124 of analog — REPLACE entire body, D-05/D-09):
```dart
  // D-05: hintPenalty is passed explicitly from loadSession() — NOT back-calculated.
  // D-09: restore to paused; player taps Resume to start the clock.
  void restoreGame(GameSession restoredSession, {required int hintPenalty}) {
    _ticker.stop();
    _stopwatch.reset();           // Stopwatch starts from zero; offset carries history
    _restoredOffset = restoredSession.elapsed.inSeconds;
    _hintPenalty = hintPenalty;
    _countdownTick = 0;
    state = AsyncData(restoredSession.copyWith(phase: GamePhase.paused));
    // Stopwatch is NOT started here — stays stopped until resumeGame().
  }
```

**recordDrop() pattern** (lines 126–143 of analog — rename isoCode→postal, matchedIsoCodes→matchedPostals, fix elapsed read):
```dart
  void recordDrop(String postal, {required bool isCorrect}) {
    final current = state.value!;
    if (isCorrect) {
      final updated = current.copyWith(
        matchedPostals: [...current.matchedPostals, postal],
      );
      state = AsyncData(updated);
      _gameStateRepository?.saveSession(updated, hintPenalty: _hintPenalty);
    } else {
      final newErrorCount = current.errorCount + 1;
      final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
      final newScore = (elapsedSecs ~/ 10) + (newErrorCount * 5) + _hintPenalty;
      state = AsyncData(current.copyWith(
        errorCount: newErrorCount,
        score: newScore,
      ));
    }
  }
```

**useHint() pattern** (lines 150–166 of analog — fix elapsed read):
```dart
  bool useHint() {
    final current = state.value;
    if (current == null ||
        current.phase != GamePhase.playing ||
        current.hintsRemaining <= 0) {
      return false;
    }
    _hintPenalty += 5;
    final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
    final newScore = (elapsedSecs ~/ 10) + (current.errorCount * 5) + _hintPenalty;
    state = AsyncData(current.copyWith(
      hintsRemaining: current.hintsRemaining - 1,
      score: newScore,
    ));
    _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
    return true;
  }
```

**completeGame() pattern** (lines 177–187 of analog — ADD stopwatch.stop(), rename matchedIsoCodes):
```dart
  Future<void> completeGame() async {
    _stopwatch.stop();    // Stopwatch has no more work to do
    _ticker.stop();
    final current = state.value!;
    state = AsyncData(current.copyWith(phase: GamePhase.completed));
    if (_highScoreRepository != null) {
      await _highScoreRepository!.saveBestScore(current.mode, current.score);
    }
    await _gameStateRepository?.clearSession();
  }
```

---

### `lib/core/ticker.dart` (utility, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\ticker.dart`
**Action:** Verbatim port — no changes.

**Complete file** (lines 1–40):
```dart
import 'dart:async';

abstract class Ticker {
  void start(void Function() onTick);
  void stop();
}

class RealTicker implements Ticker {
  Timer? _timer;
  void Function()? _onTick;

  @override
  void start(void Function() onTick) {
    _onTick = onTick;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick!());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

class FakeTicker implements Ticker {
  void Function()? _onTick;

  @override
  void start(void Function() onTick) {
    _onTick = onTick;
  }

  @override
  void stop() {
    _onTick = null;
  }

  /// Call from tests to simulate one elapsed second.
  void tick() => _onTick?.call();
}
```

---

### `lib/core/data/game_state_repository.dart` (service, CRUD)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\game_state_repository.dart`
**Action:** Port with schema deltas: add `hintPenalty` field (D-05), rename `activeIsoCode`→`activePostal` / `matchedIsoCodes`→`matchedPostals`, change `saveSession` signature to accept `hintPenalty`, change `loadSession` return type to named record, add `_prefs.remove(_key)` in catch block (D-08).

**Imports pattern** (lines 1–7 of analog — update package name):
```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_mode.dart';
```

**Interface declaration** (lines 8–12 of analog — updated signatures):
```dart
abstract interface class GameStateRepository {
  Future<void> saveSession(GameSession session, {required int hintPenalty});
  Future<({GameSession session, int hintPenalty})?> loadSession();
  Future<void> clearSession();
}
```

**saveSession() with explicit hintPenalty** (lines 22–34 of analog — field renames + hintPenalty):
```dart
  @override
  Future<void> saveSession(GameSession session, {required int hintPenalty}) async {
    final json = {
      'phase': session.phase.name,
      'mode': session.mode.name,
      'score': session.score,
      'elapsedSeconds': session.elapsed.inSeconds,
      'errorCount': session.errorCount,
      'activePostal': session.activePostal,         // renamed
      'hintsRemaining': session.hintsRemaining,
      'hintPenalty': hintPenalty,                   // D-05: explicit first-class field
      'matchedPostals': session.matchedPostals,     // renamed
    };
    await _prefs.setString(_key, jsonEncode(json));
  }
```

**loadSession() with named record return + silent-discard + key clear** (lines 36–58 of analog — full delta):
```dart
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
      // D-08: any parse failure → silent discard + clear the corrupted key.
      // Flags omits the remove() — State States adds it to prevent repeat failures.
      await _prefs.remove(_key);
      return null;
    }
  }
```

**clearSession() verbatim** (lines 60–63 of analog):
```dart
  @override
  Future<void> clearSession() async {
    await _prefs.remove(_key);
  }
```

**FutureProvider declaration** (lines 66–69 of analog):
```dart
final gameStateRepositoryProvider = FutureProvider<GameStateRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesGameStateRepository(prefs);
});
```

---

### `lib/core/data/high_score_repository.dart` (service, CRUD)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\high_score_repository.dart`
**Action:** Verbatim port with one change: `flagsMaster` → `statesMaster` in the `_key()` switch. The "lower wins" guard and FutureProvider pattern are unchanged.

**Imports pattern** (lines 1–3 of analog):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/features/game/game_mode.dart';
```

**Interface + implementation** (lines 5–32 of analog — only _key() changes):
```dart
abstract interface class HighScoreRepository {
  Future<int?> getBestScore(GameMode mode);
  Future<void> saveBestScore(GameMode mode, int score);
}

class SharedPreferencesHighScoreRepository implements HighScoreRepository {
  SharedPreferencesHighScoreRepository(this._prefs);

  final SharedPreferences _prefs;

  static String _key(GameMode mode) => switch (mode) {
    GameMode.learn               => 'high_score_learn',
    GameMode.statesMaster        => 'high_score_states_master',     // was flagsMaster
    GameMode.geographicalMaster  => 'high_score_geographical_master',
    GameMode.grandMaster         => 'high_score_grand_master',
  };

  @override
  Future<int?> getBestScore(GameMode mode) async => _prefs.getInt(_key(mode));

  @override
  Future<void> saveBestScore(GameMode mode, int score) async {
    final current = _prefs.getInt(_key(mode));
    if (current == null || score < current) {   // "lower wins" guard — verbatim
      await _prefs.setInt(_key(mode), score);
    }
  }
}
```

**FutureProvider declaration** (lines 34–37 of analog):
```dart
final highScoreRepositoryProvider = FutureProvider<HighScoreRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesHighScoreRepository(prefs);
});
```

---

### `lib/core/data/user_prefs_repository.dart` (service, CRUD)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\user_prefs_repository.dart`
**Action:** Verbatim port — update package name in imports only.

**Complete file** (lines 1–36 of analog):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class UserPrefsRepository {
  Future<bool> getTutorialSeen();
  Future<void> setTutorialSeen(bool seen);
  Future<bool> getMuted();
  Future<void> setMuted(bool muted);
}

class SharedPreferencesUserPrefsRepository implements UserPrefsRepository {
  SharedPreferencesUserPrefsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyTutorial = 'tutorial_seen';
  static const _keyMuted = 'mute_pref';

  @override
  Future<bool> getTutorialSeen() async => _prefs.getBool(_keyTutorial) ?? false;

  @override
  Future<void> setTutorialSeen(bool seen) async =>
      _prefs.setBool(_keyTutorial, seen);

  @override
  Future<bool> getMuted() async => _prefs.getBool(_keyMuted) ?? false;

  @override
  Future<void> setMuted(bool muted) async => _prefs.setBool(_keyMuted, muted);
}

final userPrefsRepositoryProvider = FutureProvider<UserPrefsRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesUserPrefsRepository(prefs);
});
```

---

### `lib/features/game/game_lifecycle_observer.dart` (middleware, event-driven)

**Analog:** None — new file with no Flags equivalent.
**Action:** Implement per RESEARCH.md §9 specification exactly. See "No Analog Found" section.

---

### `lib/core/audio/real_audio_service.dart` (service, event-driven)

**Analog:** `lib/core/audio/real_audio_service.dart` (Phase 1, this repo — lines 1–89)
**Action:** Harden only. The `_initialized` guard and try/catch blocks already exist. The single hardening delta: the `dispose()` method (line 84) does NOT check `_initialized` — this is intentional (an AudioPlayer can be disposed even if `setAsset` failed, since players are assigned before the try block). Document this in a code comment.

**dispose() — add clarifying comment** (lines 84–88):
```dart
  @override
  Future<void> dispose() async {
    // Safe to dispose unconditionally: _correctPlayer/_errorPlayer/_anthemPlayer
    // are assigned before the try block in init(), so they always exist even if
    // _initialized is false (init failed after assignment). AudioPlayer.dispose()
    // is idempotent on partially-initialized instances.
    await _correctPlayer.dispose();
    await _errorPlayer.dispose();
    await _anthemPlayer.dispose();
  }
```

---

### `lib/core/audio/stub_audio_service.dart` (service)

**Analog:** `lib/core/audio/stub_audio_service.dart` (Phase 1, this repo — lines 1–28)
**Action:** No code changes. Tests verify it satisfies the same interface assertions as `RealAudioService`.

---

## Test File Patterns

### `test/features/game/game_session_test.dart` (unit test)

**Analog:** `test/core/models/state_data_test.dart` (Phase 1, this repo)

**Test structure pattern** (lines 1–8 of analog):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_mode.dart';

void main() {
  group('GameSession', () {
    // == and hashCode
    // copyWith sentinel (nullable activePostal pass-through)
    // copyWith list identity (matchedPostals)
  });
}
```

**group/test structure pattern** (lines 26–68 of analog):
```dart
    test('two identical sessions are equal', () {
      final a = GameSession(...);
      final b = GameSession(...);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith replaces changed fields only', () { ... });

    test('copyWith(activePostal: null) clears the field via sentinel', () { ... });
```

---

### `test/features/game/game_session_notifier_test.dart` (unit test)

**Analog:** `test/core/data/state_data_service_test.dart` (Phase 1, this repo) for ProviderContainer pattern; RESEARCH.md §Pitfall 6 for override pattern.

**ProviderContainer + FakeTicker override pattern** (from RESEARCH.md):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/features/game/game_session_notifier.dart';
import 'package:state_states/core/ticker.dart';

class MockGameStateRepository extends Mock implements GameStateRepository {}
class MockHighScoreRepository extends Mock implements HighScoreRepository {}

void main() {
  late FakeTicker fakeTicker;
  late MockGameStateRepository mockGameRepo;
  late MockHighScoreRepository mockHighScoreRepo;
  late ProviderContainer container;

  setUp(() {
    fakeTicker = FakeTicker();
    mockGameRepo = MockGameStateRepository();
    mockHighScoreRepo = MockHighScoreRepository();
    container = ProviderContainer(overrides: [
      gameSessionProvider.overrideWith(() => GameSessionNotifier(
        ticker: fakeTicker,
        gameStateRepository: mockGameRepo,
        highScoreRepository: mockHighScoreRepo,
      )),
    ]);
    addTearDown(container.dispose);
  });
```

**Scoring formula test pattern** (from RESEARCH.md §Criterion #1):
```dart
  test('score formula: (elapsed ~/ 10) + (errorCount * 5) + hintPenalty', () async {
    final notifier = container.read(gameSessionProvider.notifier);
    await container.read(gameSessionProvider.future);
    notifier.startGame(GameMode.learn);
    // Tick 5x to leave countdown → playing (Stopwatch starts on tick 5)
    for (var i = 0; i < 5; i++) fakeTicker.tick();
    // ... verify score with known inputs via fixed errorCount + useHint()
  });
```

**Stopwatch.stop() verification pattern** (from RESEARCH.md §Criterion #2):
```dart
  test('pauseGame() stops the Stopwatch', () async {
    // ... startGame, tick through countdown, start playing ...
    notifier.pauseGame();
    // Access notifier's stopwatch via a test accessor OR verify indirectly:
    // pause → advance wall clock slightly → resume → check elapsed did not jump
    final session = container.read(gameSessionProvider).value!;
    expect(session.phase, GamePhase.paused);
    // elapsed must not have advanced since pause
  });
```

---

### `test/features/game/game_lifecycle_observer_test.dart` (widget test)

**Analog:** `test/core/data/state_data_service_test.dart` for binding init; RESEARCH.md §GameLifecycleObserver Widget Test Pattern.

**Widget test binding + lifecycle simulation pattern** (from RESEARCH.md):
```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/features/game/game_lifecycle_observer.dart';
import 'package:state_states/features/game/game_session_notifier.dart';

class MockGameSessionNotifier extends Mock implements GameSessionNotifier {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auto-pause fires on AppLifecycleState.paused', (tester) async {
    final mockNotifier = MockGameSessionNotifier();
    final observer = GameLifecycleObserver(mockNotifier);
    tester.binding.addObserver(observer);
    addTearDown(() => tester.binding.removeObserver(observer));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    verify(() => mockNotifier.pauseGame()).called(1);
  });

  testWidgets('auto-pause fires on AppLifecycleState.hidden', (tester) async { ... });

  testWidgets('.inactive does NOT trigger pause', (tester) async {
    // D-11: .inactive is ignored
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    verifyNever(() => mockNotifier.pauseGame());
  });
}
```

---

### `test/core/data/game_state_repository_test.dart` (unit test)

**Analog:** `test/core/data/state_data_service_test.dart` (Phase 1, this repo) for SharedPreferences mock pattern; RESEARCH.md §Criterion #4.

**SharedPreferences mock + round-trip pattern**:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/core/data/game_state_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trip: save then load returns identical GameSession + hintPenalty', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesGameStateRepository(prefs);
    final session = GameSession(/* ... with errorCount > 0, hintsRemaining < 2 ... */);
    const hintPenalty = 5;

    await repo.saveSession(session, hintPenalty: hintPenalty);
    final loaded = await repo.loadSession();

    expect(loaded, isNotNull);
    expect(loaded!.session, equals(session));
    expect(loaded.hintPenalty, equals(hintPenalty));
  });

  test('corrupt snapshot returns null and clears the key', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('game_session_snapshot', 'not valid json {{');
    final repo = SharedPreferencesGameStateRepository(prefs);

    final result = await repo.loadSession();

    expect(result, isNull);
    expect(prefs.getString('game_session_snapshot'), isNull);  // D-08: key cleared
  });
}
```

---

### `test/core/data/high_score_repository_test.dart` (unit test)

**SharedPreferences mock + lower-wins guard pattern**:
```dart
  test('saveBestScore only replaces when new score is lower', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesHighScoreRepository(prefs);

    await repo.saveBestScore(GameMode.statesMaster, 20);
    await repo.saveBestScore(GameMode.statesMaster, 25); // higher — should NOT replace
    await repo.saveBestScore(GameMode.statesMaster, 15); // lower — SHOULD replace

    expect(await repo.getBestScore(GameMode.statesMaster), 15);
  });
```

---

### `test/core/data/user_prefs_repository_test.dart` (unit test)

**Mute toggle persistence pattern**:
```dart
  test('setMuted persists across new instance', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesUserPrefsRepository(prefs);

    expect(await repo.getMuted(), isFalse); // default unmuted
    await repo.setMuted(true);
    expect(await repo.getMuted(), isTrue);
  });
```

---

### `test/core/audio/audio_service_test.dart` (unit test)

**Analog:** `lib/core/audio/real_audio_service.dart` (Phase 1, this repo) — WEL-04.

**Interface parity + dispose-no-throw pattern** (from RESEARCH.md §Criterion #5):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/audio/real_audio_service.dart';
import 'package:state_states/core/audio/stub_audio_service.dart';
import 'package:state_states/core/audio/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StubAudioService', () {
    test('satisfies AudioService interface with no-ops', () async {
      final stub = StubAudioService();
      // All methods are callable and return without throwing
      await stub.init();
      await stub.playCorrect();
      await stub.playError();
      await stub.playAnthem();
      await stub.stopAnthem();
      await stub.setMuted(true);
      await stub.dispose();
    });
  });

  group('RealAudioService', () {
    test('init with missing asset → _initialized false, dispose does not throw', () async {
      // just_audio will throw PlayerException or similar for missing assets.
      // Verify: _initialized == false, and dispose() completes without error.
      final service = RealAudioService();
      await service.init(); // expected to fail gracefully on missing asset in test env
      // dispose must not throw even when _initialized == false
      await expectLater(service.dispose(), completes);
    });
  });
}
```

---

## Shared Patterns

### Riverpod AsyncNotifier Provider Declaration

**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session_notifier.dart` lines 9–12
**Apply to:** `lib/features/game/game_session_notifier.dart`

```dart
final gameSessionProvider =
    AsyncNotifierProvider<GameSessionNotifier, GameSession>(
  () => GameSessionNotifier(ticker: RealTicker()),
);
```

### FutureProvider Repository Pattern

**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\game_state_repository.dart` lines 66–69
**Apply to:** All three repository files (`game_state_repository.dart`, `high_score_repository.dart`, `user_prefs_repository.dart`)

```dart
final <name>RepositoryProvider = FutureProvider<RepositoryInterface>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferences<Name>Repository(prefs);
});
```

Note: `SharedPreferences.getInstance()` is always `async` — never use a synchronous init hack.

### abstract interface class + SharedPreferences Implementation Pattern

**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\high_score_repository.dart` lines 5–32
**Apply to:** All three repository files

```dart
abstract interface class XRepository {
  // method declarations only
}

class SharedPreferencesXRepository implements XRepository {
  SharedPreferencesXRepository(this._prefs);
  final SharedPreferences _prefs;
  // implementations
}
```

### ProviderContainer Override Pattern (Tests)

**Source:** `test/core/data/state_data_service_test.dart` lines 1–17 (Phase 1, this repo) + RESEARCH.md §Pitfall 6
**Apply to:** All test files using Riverpod providers

```dart
final container = ProviderContainer(overrides: [
  someProvider.overrideWith(() => SomeNotifier(dep: fakeDep)),
]);
addTearDown(container.dispose);
```

### SharedPreferences Mock Init Pattern (Tests)

**Source:** Flutter test SDK — `SharedPreferences.setMockInitialValues`
**Apply to:** `test/core/data/game_state_repository_test.dart`, `test/core/data/high_score_repository_test.dart`, `test/core/data/user_prefs_repository_test.dart`

```dart
setUp(() {
  SharedPreferences.setMockInitialValues({});
});
```

### mocktail Mock Class Pattern

**Source:** RESEARCH.md §mocktail Mock Repository Pattern
**Apply to:** `test/features/game/game_session_notifier_test.dart`, `test/features/game/game_lifecycle_observer_test.dart`

```dart
class MockGameStateRepository extends Mock implements GameStateRepository {}
class MockHighScoreRepository extends Mock implements HighScoreRepository {}

// Stub setup:
when(() => mockRepo.loadSession()).thenAnswer((_) async => null);
when(() => mockRepo.saveSession(any(), hintPenalty: any(named: 'hintPenalty')))
    .thenAnswer((_) async {});
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/features/game/game_lifecycle_observer.dart` | middleware | event-driven | No WidgetsBindingObserver exists in either repo. The pattern is pure Flutter-SDK: extend `WidgetsBindingObserver`, override `didChangeAppLifecycleState`, register with `WidgetsBinding.instance.addObserver(this)`. See RESEARCH.md §9 for the full implementation spec including D-11 (`.inactive` ignored). |

**Implementation spec for game_lifecycle_observer.dart** (from RESEARCH.md §9):
```dart
import 'package:flutter/widgets.dart';
// Import GameSessionNotifier or accept a callback — prefer concrete notifier
// reference so the widget test can use a mock.

class GameLifecycleObserver extends WidgetsBindingObserver {
  GameLifecycleObserver(this._notifier);
  final GameSessionNotifier _notifier;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // D-11: ONLY .paused and .hidden trigger auto-pause.
    // .inactive is intentionally ignored (transient overlays, iOS control center,
    // incoming call banner — would cause jarring false pauses on iOS).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _notifier.pauseGame();
    }
    // resumeGame() is NOT called on .resumed — player must tap Resume explicitly.
  }
}
```

Registration pattern (used in Phase 4 when mounted to game screen):
```dart
// In StatefulWidget.initState():
WidgetsBinding.instance.addObserver(_observer);
// In State.dispose():
WidgetsBinding.instance.removeObserver(_observer);
```

---

## Metadata

**Analog search scope:** `C:\code\Claude\FlagsRoundTheWorld\lib\` (primary), `C:\code\Claude\StateTheStates\lib\` + `test\` (in-repo Phase 1)
**Files scanned:** 13 source files (8 Flags analogs + 5 Phase 1 files) + 2 Phase 1 test files
**Pattern extraction date:** 2026-05-31
