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
/// with scale-adaptive borders. AK and HI are drawn in the same loop as
/// continental states — no separate frame rectangles or clipping regions.
///
/// Ported from Flags' [WorldMapPainter]:
/// - `isoCode` → `postal`
/// - `matchedIsoCodes` → `matchedPostals`
/// - `_drawWorldCopy()` removed (US map is single canvas; insets baked by pipeline)
/// - `isDegenerate` branch removed (US states are never degenerate)
/// - `countryNames` map removed (state names are bundled in `StateData.name`)
/// - `showLabels` and `mode` declared for Phase 4; draw nothing in Phase 3
/// - `insetFrameRects` removed: AK/HI blend into the ocean canvas seamlessly
///
/// Phase 4 will add label rendering via the `showLabels` / `mode` parameters.
class UsaMapPainter extends CustomPainter {
  const UsaMapPainter({
    required this.states,
    required this.matchedPostals,
    this.showLabels = false,
    this.mode,
    this.viewScale = 1.0,
    this.hintPostal, // Phase 5: yellow-green glow target state
  });

  final List<StateData> states;
  final Set<String> matchedPostals;

  /// Declared for Phase 4 (label pass); has no effect in Phase 3.
  final bool showLabels;

  /// Declared for Phase 4 (mode-specific label styles); has no effect in Phase 3.
  final GameMode? mode;

  /// Current InteractiveViewer scale factor; drives scale-adaptive border width.
  final double viewScale;

  /// Phase 5: if non-null, this state postal is rendered with the D-H3
  /// yellow-green glow color (0xFFBBFF44) during the 3-second hint window.
  final String? hintPostal;

  @override
  bool shouldRepaint(covariant UsaMapPainter old) =>
      !setEquals(old.matchedPostals, matchedPostals) || // setEquals avoids reference-equality trap (Pitfall 5)
      old.showLabels != showLabels ||
      old.mode != mode ||
      (old.viewScale - viewScale).abs() > 0.001 || // threshold avoids sub-pixel thrash
      old.hintPostal != hintPostal; // Phase 5: glow start/end must trigger repaint (D-H3)

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

    // Step 3: Label pass — postal abbreviations at unmatched state centroids.
    if (showLabels) {
      final fontSize = (11.0 / viewScale).clamp(7.0, 14.0);
      for (final state in states) {
        if (!state.isPlaceable) continue;
        if (matchedPostals.contains(state.postal)) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: state.postal,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFFFFF),
              shadows: const [Shadow(color: Color(0x88000000), blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, state.centroid - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Step 4: Hint glow (Phase 5 — direct port of HighlightPainter._drawHintHighlight())
    // Source: FlagsRoundTheWorld/lib/features/map/highlight_painter.dart lines 140-151
    // Drawn AFTER labels so the glow appears on top of everything.
    if (hintPostal != null) {
      final hintState = states.cast<StateData?>().firstWhere(
        (s) => s?.postal == hintPostal,
        orElse: () => null,
      );
      if (hintState != null) {
        final hintPaint = Paint()
          ..color = const Color(0xFFBBFF44) // D-H3: locked yellow-green color
          ..style = PaintingStyle.fill;
        for (final path in hintState.paths) {
          canvas.drawPath(path, hintPaint);
        }
      }
    }
  }
}
