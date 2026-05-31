import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_mode.dart';

abstract interface class GameStateRepository {
  Future<void> saveSession(GameSession session, {required int hintPenalty});
  Future<({GameSession session, int hintPenalty})?>  loadSession();
  Future<void> clearSession();
}

class SharedPreferencesGameStateRepository implements GameStateRepository {
  SharedPreferencesGameStateRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'game_session_snapshot';

  @override
  Future<void> saveSession(GameSession session, {required int hintPenalty}) async {
    final json = {
      'phase': session.phase.name,
      'mode': session.mode.name,
      'score': session.score,
      'elapsedSeconds': session.elapsed.inSeconds,
      'errorCount': session.errorCount,
      'activePostal': session.activePostal,
      'hintsRemaining': session.hintsRemaining,
      'hintPenalty': hintPenalty, // D-05: explicit first-class field, never back-calculated
      'matchedPostals': session.matchedPostals,
    };
    await _prefs.setString(_key, jsonEncode(json));
  }

  @override
  Future<({GameSession session, int hintPenalty})?>  loadSession() async {
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

  @override
  Future<void> clearSession() async {
    await _prefs.remove(_key);
  }
}

final gameStateRepositoryProvider = FutureProvider<GameStateRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesGameStateRepository(prefs);
});
