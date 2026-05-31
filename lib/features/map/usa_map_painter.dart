import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import '../../core/models/state_data.dart';
import '../../features/game/game_mode.dart';

/// Atlas palette — one fill color per state, cycling by list index.
const _palette = [
  Color(0xFF8DB87F), // soft green
  Color(0xFFD4B483), // tan
  Color(0xFFE8A055), // orange
  Color(0xFFE89090), // pink
  Color(0xFFA07EC8), // purple
  Color(0xFFE8D870), // yellow
];

const _matchedColor = Color(0xFFAAAAAA); // grey for already-matched states
const _oceanColor = Color(0xFFA8D5E8); // light blue background
const _borderColor = Color(0xFF555555); // dark state borders

/// Renders all 51 U.S. state records (50 placeable + DC) as filled polygons
/// with scale-adaptive borders, plus the AK/HI inset frame rectangles.
///
/// Ported from Flags' [WorldMapPainter]:
/// - `isoCode` → `postal`
/// - `matchedIsoCodes` → `matchedPostals`
/// - `_drawWorldCopy()` removed (US map is single canvas; insets baked by pipeline)
/// - `isDegenerate` branch removed (US states are never degenerate)
/// - `countryNames` map removed (state names are bundled in `StateData.name`)
/// - `showLabels` and `mode` declared for Phase 4; draw nothing in Phase 3
///
/// Phase 4 will add label rendering via the `showLabels` / `mode` parameters.
class UsaMapPainter extends CustomPainter {
  const UsaMapPainter({
    required this.states,
    required this.matchedPostals,
    required this.insetFrameRects,
    this.showLabels = false,
    this.mode,
    this.viewScale = 1.0,
  });

  final List<StateData> states;
  final Set<String> matchedPostals;

  /// Index 0 = Alaska frame, index 1 = Hawaii frame — supplied from
  /// [MapData.insetFrameRects] (sourced from the JSON `insetFrames` key).
  final List<Rect> insetFrameRects;

  /// Declared for Phase 4 (label pass); has no effect in Phase 3.
  final bool showLabels;

  /// Declared for Phase 4 (mode-specific label styles); has no effect in Phase 3.
  final GameMode? mode;

  /// Current InteractiveViewer scale factor; drives scale-adaptive border width.
  final double viewScale;

  @override
  bool shouldRepaint(covariant UsaMapPainter old) =>
      !setEquals(old.matchedPostals, matchedPostals) || // setEquals avoids reference-equality trap (Pitfall 5)
      old.showLabels != showLabels ||
      old.mode != mode ||
      (old.viewScale - viewScale).abs() > 0.001; // threshold avoids sub-pixel thrash

  @override
  void paint(Canvas canvas, Size size) {
    // Step 1: Ocean background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _oceanColor,
    );

    // Reusable paints created outside the loop to avoid per-frame allocation.
    final fillPaint = Paint()..style = PaintingStyle.fill;
    // Stroke width in scene units: 1.0 / viewScale keeps borders at ~1 screen
    // pixel regardless of zoom level (D-13).
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _borderColor
      ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);

    // Step 2: Fills + borders for all 51 state records (no isDegenerate branch —
    // US states are never degenerate). Palette indexed by list position i, not
    // by postal, so color assignment is deterministic and stable.
    for (int i = 0; i < states.length; i++) {
      final state = states[i];
      final isMatched = matchedPostals.contains(state.postal);
      fillPaint.color = isMatched ? _matchedColor : _palette[i % _palette.length];
      for (final path in state.paths) {
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      }
    }

    // Step 3: Inset frame rectangles (D-04). One thin border rect around the
    // AK inset region and one around the HI inset region.
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _borderColor
      ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);
    for (final frameRect in insetFrameRects) {
      canvas.drawRect(frameRect, framePaint);
    }

    // Phase 4: label pass (showLabels / mode) goes here
  }
}
