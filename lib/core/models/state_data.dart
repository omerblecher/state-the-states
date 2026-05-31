import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';

/// Which lower-left inset frame a state's coordinates were baked into by the
/// build-time pipeline (generate_states.py). Mainland states are `null`.
enum InsetGroup { alaska, hawaii }

class BoundingBox {
  final double x, y, w, h;
  const BoundingBox({required this.x, required this.y, required this.w, required this.h});
  Rect get rect => Rect.fromLTWH(x, y, w, h);
  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    h: (json['h'] as num).toDouble(),
  );
}

/// A single U.S. state (or DC) parsed from the bundled `usa_states_paths.json`.
///
/// Ported from Flags' `CountryData`: `isoCode` → `postal`, plus `name`
/// (full state name, bundled in the JSON), `isPlaceable` (DC is non-placeable
/// filler — D-03), and `insetGroup` (AK/HI inset membership — D-08). The Flags
/// `isDegenerate` field is dropped: U.S. state geometry is never degenerate.
class StateData {
  final String postal;
  final String name;
  final List<String> pathStrings;
  final List<Path> paths;
  final BoundingBox boundingBox;
  final Offset centroid;
  final bool isPlaceable;
  final InsetGroup? insetGroup;

  const StateData({
    required this.postal,
    required this.name,
    required this.pathStrings,
    required this.paths,
    required this.boundingBox,
    required this.centroid,
    required this.isPlaceable,
    required this.insetGroup,
  });

  factory StateData.fromJson(Map<String, dynamic> json) {
    final pathStrings = List<String>.from(json['paths'] as List);
    final paths = pathStrings.map((s) => parseSvgPathData(s)).toList();
    final bb = BoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>);
    final c = json['centroid'] as Map<String, dynamic>;
    return StateData(
      postal: json['postal'] as String,
      name: json['name'] as String,
      pathStrings: pathStrings,
      paths: paths,
      boundingBox: bb,
      centroid: Offset((c['x'] as num).toDouble(), (c['y'] as num).toDouble()),
      isPlaceable: (json['isPlaceable'] as bool?) ?? true,
      insetGroup: _parseInsetGroup(json['insetGroup'] as String?),
    );
  }

  static InsetGroup? _parseInsetGroup(String? value) {
    if (value == null) return null;
    return InsetGroup.values.firstWhere((e) => e.name == value);
  }
}
