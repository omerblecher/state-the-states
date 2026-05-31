import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_states/core/data/user_prefs_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getMuted() defaults to false (unmuted)', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesUserPrefsRepository(prefs);

    expect(await repo.getMuted(), isFalse);
  });

  test('setMuted(true) persists; getMuted() returns true', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesUserPrefsRepository(prefs);

    await repo.setMuted(true);
    expect(await repo.getMuted(), isTrue);
  });

  test('setMuted(true) then setMuted(false) restores unmuted state', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesUserPrefsRepository(prefs);

    await repo.setMuted(true);
    await repo.setMuted(false);
    expect(await repo.getMuted(), isFalse);
  });

  test('setMuted persists across fresh repository instance (same prefs store)', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo1 = SharedPreferencesUserPrefsRepository(prefs);
    await repo1.setMuted(true);

    // Simulate fresh repository instance with same prefs store
    final repo2 = SharedPreferencesUserPrefsRepository(prefs);
    expect(await repo2.getMuted(), isTrue);
  });

  test('getTutorialSeen() defaults to false', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesUserPrefsRepository(prefs);

    expect(await repo.getTutorialSeen(), isFalse);
  });

  test('setTutorialSeen(true) persists; getTutorialSeen() returns true', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesUserPrefsRepository(prefs);

    await repo.setTutorialSeen(true);
    expect(await repo.getTutorialSeen(), isTrue);
  });
}
