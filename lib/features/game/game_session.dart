// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session.dart
// Field renames applied: activeIsoCode → activePostal, matchedIsoCodes → matchedPostals
// NOTE: hintPenalty is NOT a field here — it is notifier-internal state (Plan 03),
// persisted separately in the snapshot (Plan 02). See RESEARCH.md §3.
import 'game_phase.dart';
import 'game_mode.dart';

class GameSession {
  const GameSession({
    required this.phase,
    required this.mode,
    required this.score,
    required this.elapsed,
    required this.errorCount,
    this.activePostal,
    required this.hintsRemaining,
    this.matchedPostals = const [],
    this.countdownSecondsRemaining = 0,
  });

  final GamePhase phase;
  final GameMode mode;
  final int score;
  final Duration elapsed;
  final int errorCount;
  final String? activePostal;
  final int hintsRemaining;
  final List<String> matchedPostals;
  /// Counts down from 5 to 1 during the countdown phase; 0 at all other times.
  final int countdownSecondsRemaining;

  static const Object _sentinel = Object();

  GameSession copyWith({
    GamePhase? phase,
    GameMode? mode,
    int? score,
    Duration? elapsed,
    int? errorCount,
    Object? activePostal = _sentinel,
    int? hintsRemaining,
    List<String>? matchedPostals,
    int? countdownSecondsRemaining,
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
      countdownSecondsRemaining:
          countdownSecondsRemaining ?? this.countdownSecondsRemaining,
    );
  }

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
          countdownSecondsRemaining == other.countdownSecondsRemaining &&
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
        countdownSecondsRemaining,
        Object.hashAll(matchedPostals),
      );
}
