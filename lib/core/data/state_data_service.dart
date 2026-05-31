import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/state_data.dart';

class StateDataService {
  Future<List<StateData>> loadMapData() async {
    final jsonString =
        await rootBundle.loadString('assets/map/usa_states_paths.json');

    // Decode JSON in a background isolate — the bundled path data is large and
    // decoding on the main thread blocks the loading indicator from rendering.
    final rawEntries = await compute(_decodeJson, jsonString);

    // dart:ui Path objects must be created on the main thread.
    // Yield every 30 states so the loading spinner can animate.
    final result = <StateData>[];
    for (int i = 0; i < rawEntries.length; i++) {
      result.add(StateData.fromJson(rawEntries[i]));
      if (i % 30 == 29) await Future.delayed(Duration.zero);
    }
    return result;
  }

  // Reads the 'states' key (NOT 'countries' — Pitfall 7: the schema was renamed
  // from the Flags world map; reading the wrong key yields an empty data set).
  static List<Map<String, dynamic>> _decodeJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    return (data['states'] as List).cast<Map<String, dynamic>>();
  }
}

// Top-level provider — no codegen per project convention.
// Declared here (not in map_screen.dart) so other widgets can import it without
// depending on the full MapScreen widget.
final stateDataProvider = FutureProvider<List<StateData>>(
  (ref) => StateDataService().loadMapData(),
);
