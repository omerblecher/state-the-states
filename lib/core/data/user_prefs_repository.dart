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
