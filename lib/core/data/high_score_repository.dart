import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/features/game/game_mode.dart';

abstract interface class HighScoreRepository {
  Future<int?> getBestScore(GameMode mode);
  Future<void> saveBestScore(GameMode mode, int score);
}

class SharedPreferencesHighScoreRepository implements HighScoreRepository {
  SharedPreferencesHighScoreRepository(this._prefs);

  final SharedPreferences _prefs;

  static String _key(GameMode mode) => switch (mode) {
        GameMode.learn               => 'high_score_learn',
        GameMode.statesMaster        => 'high_score_states_master',
        GameMode.geographicalMaster  => 'high_score_geographical_master',
        GameMode.grandMaster         => 'high_score_grand_master',
      };

  @override
  Future<int?> getBestScore(GameMode mode) async => _prefs.getInt(_key(mode));

  @override
  Future<void> saveBestScore(GameMode mode, int score) async {
    final current = _prefs.getInt(_key(mode));
    if (current == null || score < current) {
      await _prefs.setInt(_key(mode), score);
    }
  }
}

final highScoreRepositoryProvider = FutureProvider<HighScoreRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesHighScoreRepository(prefs);
});
