import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/state_data.dart';

/// Wraps the parsed map asset: the 51 state records and the two inset-frame
/// rectangles (Alaska, Hawaii) in scene-coordinate space.
///
/// Consumers read `.states` for drag-drop logic and `.insetFrameRects` to
/// draw the AK/HI inset frame borders on the canvas.
class MapData {
  final List<StateData> states;

  /// Index 0 = Alaska frame (x≈0, y≈462), index 1 = Hawaii frame (x≈255, y≈533).
  final List<Rect> insetFrameRects;

  const MapData({
    required this.states,
    required this.insetFrameRects,
  });
}

class StateDataService {
  Future<MapData> loadMapData() async {
    final jsonString =
        await rootBundle.loadString('assets/map/usa_states_paths.json');

    // Decode JSON in a background isolate — the bundled path data is large and
    // decoding on the main thread blocks the loading indicator from rendering.
    final rawData = await compute(_decodeJson, jsonString);

    // dart:ui Path objects must be created on the main thread.
    // Yield every 30 states so the loading spinner can animate.
    final result = <StateData>[];
    for (int i = 0; i < rawData.states.length; i++) {
      result.add(StateData.fromJson(rawData.states[i]));
      if (i % 30 == 29) await Future.delayed(Duration.zero);
    }

    // Parse inset frame rects in order: alaska first, hawaii second.
    final rects = rawData.frames
        .map((f) => Rect.fromLTWH(
              (f['x'] as num).toDouble(),
              (f['y'] as num).toDouble(),
              (f['w'] as num).toDouble(),
              (f['h'] as num).toDouble(),
            ))
        .toList();

    return MapData(states: result, insetFrameRects: rects);
  }

  // Reads the 'states' key (NOT 'countries' — Pitfall 7: the schema was renamed
  // from the Flags world map; reading the wrong key yields an empty data set).
  // Also reads 'insetFrames' to return alaska + hawaii frame rects.
  static ({List<Map<String, dynamic>> states, List<Map<String, dynamic>> frames})
      _decodeJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final states = (data['states'] as List).cast<Map<String, dynamic>>();
    // insetFrames: {"alaska": {x,y,w,h}, "hawaii": {x,y,w,h}}
    // Access by explicit key — do not rely on insertion order (WR-04).
    final insetFrames = data['insetFrames'] as Map<String, dynamic>;
    final frames = [
      insetFrames['alaska'] as Map<String, dynamic>,
      insetFrames['hawaii'] as Map<String, dynamic>,
    ];
    return (states: states, frames: frames);
  }
}

// Top-level provider — no codegen per project convention.
// Declared here (not in map_screen.dart) so other widgets can import it without
// depending on the full MapScreen widget.
final stateDataProvider = FutureProvider<MapData>(
  (ref) => StateDataService().loadMapData(),
);
