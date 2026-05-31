import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/models/state_data.dart';
import 'package:state_states/features/map/hit_detection.dart';

List<StateData> _loadRealStates() {
  final raw = File('assets/map/usa_states_paths.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return (data['states'] as List)
      .cast<Map<String, dynamic>>()
      .map(StateData.fromJson)
      .toList();
}

void main() {
  // Required: StateData.fromJson calls parseSvgPathData() which needs the Flutter
  // engine binding for dart:ui Path creation — even though these are pure-Dart tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<StateData> states;
  setUpAll(() {
    states = _loadRealStates();
  });

  group('stateHitTest — NE micro-states at scale 1.0', () {
    for (final postal in ['RI', 'DE', 'CT', 'NJ', 'MD']) {
      test('centroid of $postal at scale 1.0 returns $postal', () {
        final s = states.firstWhere((s) => s.postal == postal);
        expect(stateHitTest(s.centroid, states, scale: 1.0), equals(postal));
      });
    }
  });

  group('stateHitTest — NE micro-states at scale 4.0', () {
    for (final postal in ['RI', 'DE', 'CT', 'NJ', 'MD']) {
      test('centroid of $postal at scale 4.0 returns $postal', () {
        final s = states.firstWhere((s) => s.postal == postal);
        expect(stateHitTest(s.centroid, states, scale: 4.0), equals(postal));
      });
    }
  });

  group('stateHitTest — edge cases', () {
    test('ocean point (5.0, 5.0) returns null', () {
      expect(stateHitTest(const Offset(5.0, 5.0), states), isNull);
    });

    test('TX centroid at scale 1.0 returns TX', () {
      final s = states.firstWhere((s) => s.postal == 'TX');
      expect(stateHitTest(s.centroid, states, scale: 1.0), equals('TX'));
    });

    test('CA centroid at scale 1.0 returns CA', () {
      final s = states.firstWhere((s) => s.postal == 'CA');
      expect(stateHitTest(s.centroid, states, scale: 1.0), equals('CA'));
    });
  });
}
