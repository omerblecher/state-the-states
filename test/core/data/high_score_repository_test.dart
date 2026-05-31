import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/features/game/game_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getBestScore returns null when never written', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesHighScoreRepository(prefs);

    expect(await repo.getBestScore(GameMode.statesMaster), isNull);
  });

  test('saveBestScore only replaces when new score is lower (lower-wins, golf scoring)', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesHighScoreRepository(prefs);

    await repo.saveBestScore(GameMode.statesMaster, 20); // initial
    await repo.saveBestScore(GameMode.statesMaster, 25); // higher — should NOT replace
    await repo.saveBestScore(GameMode.statesMaster, 15); // lower — SHOULD replace

    expect(await repo.getBestScore(GameMode.statesMaster), 15);
  });

  test('saveBestScore replaces when new score equals current (edge: no change at equality)', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesHighScoreRepository(prefs);

    await repo.saveBestScore(GameMode.learn, 20);
    await repo.saveBestScore(GameMode.learn, 20); // equal — guard is strict < so no write

    expect(await repo.getBestScore(GameMode.learn), 20);
  });

  test('cold-read: score written then read from fresh repository instance returns same value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo1 = SharedPreferencesHighScoreRepository(prefs);
    await repo1.saveBestScore(GameMode.statesMaster, 42);

    // Simulate fresh repository instance with same prefs store
    final repo2 = SharedPreferencesHighScoreRepository(prefs);
    expect(await repo2.getBestScore(GameMode.statesMaster), 42);
  });

  test('scores for different modes are independent', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesHighScoreRepository(prefs);

    await repo.saveBestScore(GameMode.learn, 10);
    await repo.saveBestScore(GameMode.statesMaster, 20);
    await repo.saveBestScore(GameMode.geographicalMaster, 30);
    await repo.saveBestScore(GameMode.grandMaster, 40);

    expect(await repo.getBestScore(GameMode.learn), 10);
    expect(await repo.getBestScore(GameMode.statesMaster), 20);
    expect(await repo.getBestScore(GameMode.geographicalMaster), 30);
    expect(await repo.getBestScore(GameMode.grandMaster), 40);
  });
}
