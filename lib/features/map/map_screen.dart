import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/state_data_service.dart';
import 'usa_map_painter.dart';

/// Phase 1 blank-canvas proof of the data pipeline. Watches [stateDataProvider]
/// and renders the three AsyncValue states. The `data` branch builds a
/// [CustomPaint] over [UsaMapPainter], proving the JSON → compute isolate →
/// provider → painter chain is wired end-to-end without crashing.
///
/// The interactive drag-drop map (InteractiveViewer, hit detection, HUD, tray)
/// is built in Phase 3. The `/play` route is registered in plan 01-04's app.dart.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapData = ref.watch(stateDataProvider);

    return Scaffold(
      body: mapData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load map data: $error')),
        data: (states) => CustomPaint(
          painter: UsaMapPainter(states: states),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
