import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/models/state_data.dart';

/// A minimal valid SVG path string for fromJson unit cases.
const _kPath = 'M0,0 L1,0 L1,1 Z';

Map<String, dynamic> _record({
  required String postal,
  required String name,
  bool? isPlaceable,
  String? insetGroup,
}) => {
  'postal': postal,
  'name': name,
  'paths': [_kPath],
  'boundingBox': {'x': 10.0, 'y': 20.0, 'w': 30.0, 'h': 40.0},
  'centroid': {'x': 25.0, 'y': 40.0},
  if (isPlaceable != null) 'isPlaceable': isPlaceable,
  'insetGroup': insetGroup,
};

void main() {
  group('StateData.fromJson', () {
    test('parses postal, name, paths, boundingBox, centroid', () {
      final s = StateData.fromJson(_record(postal: 'AL', name: 'Alabama'));
      expect(s.postal, 'AL');
      expect(s.name, 'Alabama');
      expect(s.pathStrings, [_kPath]);
      expect(s.paths.length, 1);
      expect(s.centroid, const Offset(25.0, 40.0));
      expect(s.boundingBox.rect, const Rect.fromLTWH(10.0, 20.0, 30.0, 40.0));
    });

    test('isPlaceable defaults to true when absent', () {
      final s = StateData.fromJson(_record(postal: 'AL', name: 'Alabama'));
      expect(s.isPlaceable, isTrue);
    });

    test('DC-shaped JSON yields isPlaceable == false', () {
      final dc = StateData.fromJson(
        _record(postal: 'DC', name: 'District of Columbia', isPlaceable: false),
      );
      expect(dc.isPlaceable, isFalse);
    });

    test('AK-shaped JSON yields insetGroup == InsetGroup.alaska', () {
      final ak = StateData.fromJson(
        _record(postal: 'AK', name: 'Alaska', insetGroup: 'alaska'),
      );
      expect(ak.insetGroup, InsetGroup.alaska);
    });

    test('HI-shaped JSON yields insetGroup == InsetGroup.hawaii', () {
      final hi = StateData.fromJson(
        _record(postal: 'HI', name: 'Hawaii', insetGroup: 'hawaii'),
      );
      expect(hi.insetGroup, InsetGroup.hawaii);
    });

    test('mainland JSON (insetGroup null) yields insetGroup == null', () {
      final s = StateData.fromJson(_record(postal: 'TX', name: 'Texas'));
      expect(s.insetGroup, isNull);
    });
  });

  group('BoundingBox.fromJson', () {
    test('round-trips x/y/w/h and exposes .rect', () {
      final bb = BoundingBox.fromJson({'x': 1.0, 'y': 2.0, 'w': 3.0, 'h': 4.0});
      expect(bb.x, 1.0);
      expect(bb.y, 2.0);
      expect(bb.w, 3.0);
      expect(bb.h, 4.0);
      expect(bb.rect, const Rect.fromLTWH(1.0, 2.0, 3.0, 4.0));
    });
  });

  test('testAlaskaCentroidInset: real AK centroid lies inside the alaska inset frame', () {
    final raw = File('assets/map/usa_states_paths.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final frame = data['insetFrames']['alaska'] as Map<String, dynamic>;
    final rect = Rect.fromLTWH(
      (frame['x'] as num).toDouble(),
      (frame['y'] as num).toDouble(),
      (frame['w'] as num).toDouble(),
      (frame['h'] as num).toDouble(),
    );

    final states = (data['states'] as List).cast<Map<String, dynamic>>();
    final akJson = states.firstWhere((s) => s['postal'] == 'AK');
    final ak = StateData.fromJson(akJson);

    expect(ak.insetGroup, InsetGroup.alaska);
    expect(rect.contains(ak.centroid), isTrue,
        reason: 'AK centroid ${ak.centroid} must fall inside alaska inset $rect');
  });
}
