import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/core/models/state_data.dart';
import 'package:state_states/features/map/spike_map_screen.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/// Minimal valid SVG path for fixture StateData records.
const _kPath = 'M0,0 L1,0 L1,1 Z';

/// Build a minimal but valid StateData from direct constructor fields.
/// Uses the same field names as StateData.fromJson().
StateData _makeState({
  required String postal,
  required Map<String, dynamic> bbox,
  required Map<String, dynamic> centroid,
  String? insetGroup,
}) {
  return StateData.fromJson({
    'postal': postal,
    'name': postal,
    'paths': [_kPath],
    'boundingBox': bbox,
    'centroid': centroid,
    'isPlaceable': true,
    'insetGroup': insetGroup,
  });
}

/// 6 StateData fixtures matching the SpikeMapScreen _regionPostals list.
/// Bounding boxes are real-ish values from RESEARCH.md Pattern 9.
List<StateData> _makeFixtures() {
  return [
    _makeState(
      postal: 'TX',
      bbox: {'x': 293.9, 'y': 358.3, 'w': 268.2, 'h': 261.3},
      centroid: {'x': 428.0, 'y': 488.9},
    ),
    _makeState(
      postal: 'CA',
      bbox: {'x': 0.0, 'y': 155.7, 'w': 154.2, 'h': 262.4},
      centroid: {'x': 77.1, 'y': 287.0},
    ),
    _makeState(
      postal: 'FL',
      bbox: {'x': 683.7, 'y': 479.1, 'w': 174.0, 'h': 148.8},
      centroid: {'x': 770.7, 'y': 553.5},
    ),
    _makeState(
      postal: 'NY',
      bbox: {'x': 796.8, 'y': 111.3, 'w': 145.7, 'h': 109.7},
      centroid: {'x': 869.7, 'y': 166.2},
    ),
    _makeState(
      postal: 'AK',
      bbox: {'x': 0.0, 'y': 462.4, 'w': 250.0, 'h': 134.2},
      centroid: {'x': 125.0, 'y': 529.5},
      insetGroup: 'alaska',
    ),
    _makeState(
      postal: 'HI',
      bbox: {'x': 255.0, 'y': 533.9, 'w': 130.0, 'h': 61.2},
      centroid: {'x': 320.0, 'y': 564.5},
      insetGroup: 'hawaii',
    ),
  ];
}

MapData _makeMapData() {
  return MapData(
    states: _makeFixtures(),
    insetFrameRects: [
      Rect.fromLTWH(0, 462.38, 250, 134.24), // Alaska inset frame
      Rect.fromLTWH(255, 533.88, 130, 61.24), // Hawaii inset frame
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // rootBundle access and path_drawing require the binding to be initialized.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SpikeMapScreen renders without exception with fixture states',
    (tester) async {
      final mapData = _makeMapData();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stateDataProvider.overrideWith((ref) async => mapData),
          ],
          child: const MaterialApp(home: SpikeMapScreen()),
        ),
      );
      // Two pumps: first lets the FutureProvider emit data,
      // second lets postFrameCallback fire and rebuild the widget tree.
      await tester.pump();
      await tester.pump();

      // InteractiveViewer must be present — the map canvas is rendered.
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // At least one TX text widget should be visible: the draggable chip label
      // and/or the region label inside the colored DragTarget box.
      expect(find.text('TX'), findsWidgets);
    },
  );

  testWidgets(
    'SpikeMapScreen zoom buttons are present',
    (tester) async {
      final mapData = _makeMapData();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stateDataProvider.overrideWith((ref) async => mapData),
          ],
          child: const MaterialApp(home: SpikeMapScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    },
  );
}
