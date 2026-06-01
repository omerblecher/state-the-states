import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/data/user_prefs_repository.dart';
import 'package:state_states/features/tutorial/tutorial_screen.dart';

class MockUserPrefsRepository extends Mock implements UserPrefsRepository {}

/// Builds a GoRouter that renders [TutorialScreen] at '/' and
/// captures any navigation to a separate route so tests can verify
/// that context.go('/') was called without a real navigation stack.
Widget _buildTestApp(UserPrefsRepository mockRepo) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TutorialScreen(),
      ),
      // Stub home route so context.go('/') from _completeTutorial succeeds.
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      userPrefsRepositoryProvider.overrideWith((_) async => mockRepo),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUserPrefsRepository mockRepo;

  setUp(() {
    mockRepo = MockUserPrefsRepository();
    when(() => mockRepo.setTutorialSeen(any())).thenAnswer((_) async {});
    when(() => mockRepo.getTutorialSeen()).thenAnswer((_) async => false);
    when(() => mockRepo.getMuted()).thenAnswer((_) async => false);
    when(() => mockRepo.setMuted(any())).thenAnswer((_) async {});
  });

  group('TutorialScreen', () {
    testWidgets('Test 1 (Skip path): tapping Skip calls setTutorialSeen(true)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(mockRepo));
      await tester.pumpAndSettle();

      // Find and tap the Skip button
      final skipFinder = find.text('Skip');
      expect(skipFinder, findsOneWidget);

      await tester.tap(skipFinder);
      await tester.pumpAndSettle();

      verify(() => mockRepo.setTutorialSeen(true)).called(1);
    });

    testWidgets(
        'Test 2 (Done path): navigating to last slide and tapping GET STARTED calls setTutorialSeen(true)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(mockRepo));
      await tester.pumpAndSettle();

      // Swipe through slides to reach the last one (slide index 3)
      for (int i = 0; i < 3; i++) {
        await tester.fling(
          find.byType(PageView),
          const Offset(-400, 0),
          1000,
        );
        await tester.pumpAndSettle();
      }

      // On the last slide, the action button should be 'GET STARTED'
      final doneFinder = find.text('GET STARTED');
      expect(doneFinder, findsOneWidget);

      await tester.tap(doneFinder);
      await tester.pumpAndSettle();

      verify(() => mockRepo.setTutorialSeen(true)).called(1);
    });

    testWidgets(
        'Test 3 (initial state): first slide title is visible on load',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Learn All 50 States!'), findsAtLeastNWidgets(1));
    });
  });
}
