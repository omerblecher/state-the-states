import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/audio/audio_service.dart';
import 'package:state_states/core/audio/audio_service_provider.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/core/data/user_prefs_repository.dart';
import 'package:state_states/core/models/state_data.dart';
import 'package:state_states/features/welcome/welcome_screen.dart';

/// Stub audio service for tests — no-op so anthem calls don't crash in test env.
class _StubAudioService implements AudioService {
  const _StubAudioService();

  @override
  Future<void> init() async {}
  @override
  Future<void> playCorrect() async {}
  @override
  Future<void> playError() async {}
  @override
  Future<void> fadeInAnthem() async {}
  @override
  Future<void> fadeOutAnthem() async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> dispose() async {}
}

/// Stub prefs repository — reports tutorial not seen by default.
class _StubUserPrefsRepository implements UserPrefsRepository {
  const _StubUserPrefsRepository();

  @override
  Future<bool> getTutorialSeen() async => false;
  @override
  Future<void> setTutorialSeen(bool seen) async {}
  @override
  Future<bool> getMuted() async => false;
  @override
  Future<void> setMuted(bool muted) async {}
}

/// Builds a minimal [MapData] with 2 synthetic states so [UsaWelcomePainter]
/// does not crash during tests.
MapData _buildMinimalMapData() {
  // Two tiny rectangular paths in the 1000×628 viewBox.
  final pathA = Path()
    ..addRect(const Rect.fromLTWH(10, 10, 50, 30));
  final pathB = Path()
    ..addRect(const Rect.fromLTWH(100, 100, 60, 40));

  final stateA = StateData(
    postal: 'TX',
    name: 'Texas',
    pathStrings: const ['M10 10 L60 10 L60 40 L10 40 Z'],
    paths: [pathA],
    boundingBox: const BoundingBox(x: 10, y: 10, w: 50, h: 30),
    centroid: const Offset(35, 25),
    isPlaceable: true,
    insetGroup: null,
  );
  final stateB = StateData(
    postal: 'CA',
    name: 'California',
    pathStrings: const ['M100 100 L160 100 L160 140 L100 140 Z'],
    paths: [pathB],
    boundingBox: const BoundingBox(x: 100, y: 100, w: 60, h: 40),
    centroid: const Offset(130, 120),
    isPlaceable: true,
    insetGroup: null,
  );

  return MapData(
    states: [stateA, stateB],
    insetFrameRects: const [],
  );
}

Widget _buildTestApp() {
  final mapData = _buildMinimalMapData();

  return ProviderScope(
    overrides: [
      audioServiceProvider.overrideWithValue(const _StubAudioService()),
      stateDataProvider.overrideWith((_) async => mapData),
      userPrefsRepositoryProvider
          .overrideWith((_) async => const _StubUserPrefsRepository()),
    ],
    child: const MaterialApp(home: WelcomeScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WelcomeScreen', () {
    testWidgets('Test 1: smoke test — renders without throwing', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      // pump once to process post-frame callbacks and provider emissions
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // If no exception thrown, smoke test passes.
    });

    testWidgets('Test 2: contains GET STARTED button text', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('GET STARTED'), findsOneWidget);
    });

    testWidgets(
        'Test 3 (A11Y): meets androidTapTargetGuideline for GET STARTED button',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        tester,
        meetsGuideline(androidTapTargetGuideline),
      );

      handle.dispose();
    });

    testWidgets(
        'Test 4 (A11Y): meets labeledTapTargetGuideline — all interactive '
        'controls have Semantics labels', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
      );

      handle.dispose();
    });
  });
}
