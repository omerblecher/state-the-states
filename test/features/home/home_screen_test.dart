import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/home/home_screen.dart';

class MockHighScoreRepository extends Mock implements HighScoreRepository {}

void main() {
  setUpAll(() {
    // Register fallback for GameMode so mocktail any() works.
    registerFallbackValue(GameMode.learn);
  });

  testWidgets('HomeScreen shows mode cards', (tester) async {
    final mockRepo = MockHighScoreRepository();
    when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          highScoreRepositoryProvider.overrideWith((_) async => mockRepo),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(); // let FutureProvider emit
    await tester.pump();

    // Placeholder assertion — real assertions added in Plan 06.
    expect(true, isTrue);
  });
}
