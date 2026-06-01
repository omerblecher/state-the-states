import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/home/home_screen.dart';

class MockHighScoreRepository extends Mock implements HighScoreRepository {}

Widget buildHomeScreen(MockHighScoreRepository mockRepo) {
  return ProviderScope(
    overrides: [
      highScoreRepositoryProvider.overrideWith((_) async => mockRepo),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  setUpAll(() {
    // Register fallback for GameMode so mocktail any() works.
    registerFallbackValue(GameMode.learn);
  });

  group('HomeScreen mode cards', () {
    testWidgets('shows 4 mode cards with correct names', (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildHomeScreen(mockRepo));
      await tester.pump(); // let FutureProvider emit
      await tester.pump(); // let FutureBuilder resolve

      expect(find.text('Learn'), findsAtLeastNWidgets(1));
      expect(find.text('States Master'), findsAtLeastNWidgets(1));
      expect(find.text('Geographical Master'), findsAtLeastNWidgets(1));
      expect(find.text('Grand Master'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Not played when no score stored', (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildHomeScreen(mockRepo));
      await tester.pump();
      await tester.pump();

      expect(find.text('Not played'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Best: N when score available', (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(GameMode.learn))
          .thenAnswer((_) async => 50);
      when(() => mockRepo.getBestScore(GameMode.statesMaster))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getBestScore(GameMode.geographicalMaster))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getBestScore(GameMode.grandMaster))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(buildHomeScreen(mockRepo));
      await tester.pump();
      await tester.pump();

      expect(find.text('Best: 50'), findsOneWidget);
      // Other 3 modes have no score
      expect(find.text('Not played'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders without crashing in loading state', (tester) async {
      // Use a future that never completes to keep provider in loading state.
      final completer = Completer<HighScoreRepository>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            highScoreRepositoryProvider
                .overrideWith((_) => completer.future),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump(); // one pump — provider still loading

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up: complete the future so the Completer is not leaked.
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);
      completer.complete(mockRepo);
    });
  });
}
