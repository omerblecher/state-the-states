import 'dart:ui' show Offset, Path;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/audio/audio_service.dart';
import 'package:state_states/core/audio/audio_service_provider.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/core/models/state_data.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/core/ticker.dart';
import 'package:state_states/features/game/game_session_notifier.dart';
import 'package:state_states/features/typing/speed_typing_screen.dart';

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class MockAudioService extends Mock implements AudioService {}

class MockHighScoreRepository extends Mock implements HighScoreRepository {}

// ---------------------------------------------------------------------------
// State fixture — 5 states, replicated inline (do not cross-import test files)
// ---------------------------------------------------------------------------

List<StateData> _stateFixture() => [
      const StateData(
        postal: 'GA',
        name: 'Georgia',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'CA',
        name: 'California',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'NY',
        name: 'New York',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'TX',
        name: 'Texas',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'AK',
        name: 'Alaska',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: InsetGroup.alaska,
      ),
    ];

// ---------------------------------------------------------------------------
// Test helper — builds SpeedTypingScreen inside ProviderScope + MaterialApp.router
// ---------------------------------------------------------------------------

Widget _buildTypingScreen(
  GameSession initialSession, {
  List<StateData>? states,
  MockHighScoreRepository? mockHighScoreRepo,
  MockAudioService? mockAudioService,
}) {
  final stateList = states ?? _stateFixture();
  final highScoreRepo = mockHighScoreRepo ?? MockHighScoreRepository();
  final audioService = mockAudioService ?? MockAudioService();

  when(() => highScoreRepo.getBestScore(any())).thenAnswer((_) async => null);
  when(() => audioService.playCorrect()).thenAnswer((_) async {});
  when(() => audioService.playError()).thenAnswer((_) async {});
  when(() => audioService.setMuted(any())).thenAnswer((_) async {});

  final router = GoRouter(
    initialLocation: '/type',
    routes: [
      GoRoute(
        path: '/type',
        builder: (context, state) => const SpeedTypingScreen(),
      ),
      GoRoute(
        path: '/complete',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('completion stub')),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('home stub')),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      gameSessionProvider.overrideWith(() => _FakeGameSessionNotifier(initialSession)),
      stateDataProvider.overrideWith(
        (ref) async => MapData(states: stateList, insetFrameRects: const []),
      ),
      highScoreRepositoryProvider.overrideWith((_) async => highScoreRepo),
      audioServiceProvider.overrideWithValue(audioService),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Fake GameSessionNotifier — returns a fixed session; no real ticker needed
// ---------------------------------------------------------------------------

class _FakeGameSessionNotifier extends GameSessionNotifier {
  _FakeGameSessionNotifier(this._initialSession)
      : super(ticker: _NoOpTicker());

  final GameSession _initialSession;

  @override
  Future<GameSession> build() async => _initialSession;

  @override
  void startGame(GameMode mode, {bool skipCountdown = false}) {
    state = AsyncData(_initialSession.copyWith(phase: GamePhase.playing));
  }
}

class _NoOpTicker implements Ticker {
  @override
  void start(void Function() callback) {}

  @override
  void stop() {}
}

// ---------------------------------------------------------------------------
// Widget tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(GameMode.learn);
  });

  group('SpeedTypingScreen', () {
    testWidgets('renders AppBar with title Speed Typing', (tester) async {
      final session = GameSession(
        phase: GamePhase.playing,
        mode: GameMode.speedTyping,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        hintsRemaining: 2,
        matchedPostals: const [],
      );

      await tester.pumpWidget(_buildTypingScreen(session));
      await tester.pump(); // let FutureProvider emit

      expect(find.text('Speed Typing'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'TextField has TextCapitalization.characters (TYPING-03)',
        (tester) async {
      final session = GameSession(
        phase: GamePhase.playing,
        mode: GameMode.speedTyping,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        hintsRemaining: 2,
        matchedPostals: const [],
      );

      await tester.pumpWidget(_buildTypingScreen(session));
      await tester.pump();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(
        textField.textCapitalization,
        equals(TextCapitalization.characters),
      );
    });

    testWidgets('chip grid is empty before any state is matched (TYPING-06)',
        (tester) async {
      final session = GameSession(
        phase: GamePhase.playing,
        mode: GameMode.speedTyping,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        hintsRemaining: 2,
        matchedPostals: const [],
      );

      await tester.pumpWidget(_buildTypingScreen(session));
      await tester.pump();

      // The Wrap widget for chips exists but has no Chip children
      final chips = find.byType(Chip);
      expect(chips, findsNothing);
    });

    testWidgets(
        'chip grid shows chip after matched state (TYPING-06)',
        (tester) async {
      final session = GameSession(
        phase: GamePhase.playing,
        mode: GameMode.speedTyping,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        hintsRemaining: 2,
        matchedPostals: const ['GA'],
      );

      await tester.pumpWidget(_buildTypingScreen(session));
      await tester.pump(); // let stateDataProvider emit

      // Should find a Chip with the label 'Georgia'
      expect(find.text('Georgia'), findsAtLeastNWidgets(1));
      expect(find.byType(Chip), findsAtLeastNWidgets(1));
    });
  });
}
