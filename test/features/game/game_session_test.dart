import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_mode.dart';

void main() {
  group('GameSession', () {
    // Helper to build a fully-specified session
    GameSession makeSession({
      GamePhase phase = GamePhase.idle,
      GameMode mode = GameMode.learn,
      int score = 0,
      Duration elapsed = Duration.zero,
      int errorCount = 0,
      String? activePostal,
      int hintsRemaining = 2,
      List<String> matchedPostals = const [],
    }) {
      return GameSession(
        phase: phase,
        mode: mode,
        score: score,
        elapsed: elapsed,
        errorCount: errorCount,
        activePostal: activePostal,
        hintsRemaining: hintsRemaining,
        matchedPostals: matchedPostals,
      );
    }

    test('two identical sessions are equal and share hashCode', () {
      final a = makeSession(
        phase: GamePhase.playing,
        mode: GameMode.statesMaster,
        score: 10,
        elapsed: const Duration(seconds: 30),
        errorCount: 2,
        activePostal: 'TX',
        hintsRemaining: 1,
        matchedPostals: ['AL', 'AK'],
      );
      final b = makeSession(
        phase: GamePhase.playing,
        mode: GameMode.statesMaster,
        score: 10,
        elapsed: const Duration(seconds: 30),
        errorCount: 2,
        activePostal: 'TX',
        hintsRemaining: 1,
        matchedPostals: ['AL', 'AK'],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('sessions with different fields are not equal', () {
      final a = makeSession(score: 0);
      final b = makeSession(score: 5);
      expect(a, isNot(equals(b)));
    });

    test('copyWith replaces only changed fields; unchanged fields are preserved', () {
      final original = makeSession(
        phase: GamePhase.idle,
        mode: GameMode.learn,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        activePostal: 'AL',
        hintsRemaining: 2,
        matchedPostals: const ['AK'],
      );
      final updated = original.copyWith(score: 5, errorCount: 1);
      expect(updated.score, 5);
      expect(updated.errorCount, 1);
      // All other fields must match the original
      expect(updated.phase, original.phase);
      expect(updated.mode, original.mode);
      expect(updated.elapsed, original.elapsed);
      expect(updated.activePostal, original.activePostal);
      expect(updated.hintsRemaining, original.hintsRemaining);
      expect(updated.matchedPostals, original.matchedPostals);
    });

    test('copyWith(activePostal: null) clears the field via sentinel', () {
      final session = makeSession(activePostal: 'TX');
      expect(session.activePostal, 'TX');

      final cleared = session.copyWith(activePostal: null);
      expect(cleared.activePostal, isNull);
    });

    test('copyWith() with activePostal omitted preserves the prior value', () {
      final session = makeSession(activePostal: 'TX');
      final preserved = session.copyWith(score: 1);
      expect(preserved.activePostal, 'TX');
    });

    test('matchedPostals list equality: two sessions with equal-content lists compare equal', () {
      final a = makeSession(matchedPostals: ['AL', 'AK', 'TX']);
      final b = makeSession(matchedPostals: ['AL', 'AK', 'TX']);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('matchedPostals list inequality: different list content yields not-equal', () {
      final a = makeSession(matchedPostals: ['AL', 'AK']);
      final b = makeSession(matchedPostals: ['AL', 'TX']);
      expect(a, isNot(equals(b)));
    });

    test('copyWith(matchedPostals: [...]) replaces the list', () {
      final original = makeSession(matchedPostals: const ['AL']);
      final updated = original.copyWith(matchedPostals: ['AL', 'AK']);
      expect(updated.matchedPostals, ['AL', 'AK']);
    });
  });
}
