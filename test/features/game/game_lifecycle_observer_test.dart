import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/features/game/game_lifecycle_observer.dart';
import 'package:state_states/features/game/game_session_notifier.dart';

class MockGameSessionNotifier extends Mock implements GameSessionNotifier {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGameSessionNotifier mockNotifier;
  late GameLifecycleObserver observer;

  setUp(() {
    mockNotifier = MockGameSessionNotifier();
    // Stub pauseGame() to be a no-op (it's void so no thenAnswer needed by default,
    // but we need when() so verify() can count calls).
    when(() => mockNotifier.pauseGame()).thenReturn(null);
    observer = GameLifecycleObserver(mockNotifier);
  });

  // Note: each testWidgets manages its own addObserver / removeObserver to avoid
  // observer leaks between tests.

  testWidgets(
    'AppLifecycleState.paused triggers pauseGame() exactly once (D-11)',
    (tester) async {
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      verify(() => mockNotifier.pauseGame()).called(1);
    },
  );

  testWidgets(
    'AppLifecycleState.hidden triggers pauseGame() exactly once (D-11)',
    (tester) async {
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      verify(() => mockNotifier.pauseGame()).called(1);
    },
  );

  testWidgets(
    'AppLifecycleState.inactive does NOT trigger pauseGame() (D-11)',
    (tester) async {
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      verifyNever(() => mockNotifier.pauseGame());
    },
  );

  testWidgets(
    'AppLifecycleState.resumed does NOT trigger pauseGame() (D-09 principle)',
    (tester) async {
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      verifyNever(() => mockNotifier.pauseGame());
    },
  );
}
