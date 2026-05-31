import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/core/data/game_state_repository.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trip: save then load returns identical GameSession + hintPenalty', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesGameStateRepository(prefs);
    const session = GameSession(
      phase: GamePhase.playing,
      mode: GameMode.statesMaster,
      score: 15,
      elapsed: Duration(seconds: 120),
      errorCount: 2,
      activePostal: 'CA',
      hintsRemaining: 1,
      matchedPostals: ['TX', 'FL', 'NY'],
    );
    const hintPenalty = 5;

    await repo.saveSession(session, hintPenalty: hintPenalty);
    final loaded = await repo.loadSession();

    expect(loaded, isNotNull);
    expect(loaded!.session, equals(session));
    expect(loaded.hintPenalty, equals(hintPenalty));
  });

  test('loadSession() on absent key returns null', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesGameStateRepository(prefs);

    final result = await repo.loadSession();

    expect(result, isNull);
  });

  test('corrupt snapshot returns null and clears the key (D-08)', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('game_session_snapshot', 'not valid json {{');
    final repo = SharedPreferencesGameStateRepository(prefs);

    final result = await repo.loadSession();

    expect(result, isNull);
    // D-08: key must be cleared after corrupt-discard so subsequent loads also return null
    expect(prefs.getString('game_session_snapshot'), isNull);
  });

  test('clearSession() removes the snapshot key', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesGameStateRepository(prefs);
    const session = GameSession(
      phase: GamePhase.paused,
      mode: GameMode.learn,
      score: 0,
      elapsed: Duration.zero,
      errorCount: 0,
      hintsRemaining: 2,
    );

    await repo.saveSession(session, hintPenalty: 0);
    expect(prefs.getString('game_session_snapshot'), isNotNull);

    await repo.clearSession();
    expect(prefs.getString('game_session_snapshot'), isNull);
  });
}
