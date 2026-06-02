import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/state_data.dart';

/// Renders the USA silhouette on the WelcomeScreen with a stagger-fill animation.
///
/// States fill in one-by-one with a random stagger order over the animation
/// duration (~1.5s, driven by [animValue] 0.0→1.0 from [AnimationController]).
///
/// Supports a [fillColor] and optional [strokeColor] so the welcome screen can
/// use a patriotic parchment/gold palette while this same painter remains
/// reusable with default white for other contexts.
///
/// Analog: [UsaMapPainter] — same CustomPainter base, different fill logic.
class UsaWelcomePainter extends CustomPainter {
  const UsaWelcomePainter({
    required this.states,
    required this.staggerOrder,
    required this.animValue,
    this.fillColor = Colors.white,
    this.strokeColor,
    this.strokeWidth = 0.8,
  });

  final List<StateData> states;

  /// Pre-shuffled index list — each entry is an index into [states].
  final List<int> staggerOrder;

  /// Current animation value 0.0 → 1.0 from the [AnimationController].
  final double animValue;

  /// Fill color for state polygons. Defaults to opaque white.
  final Color fillColor;

  /// Stroke color drawn on top of fill. Null means no stroke.
  final Color? strokeColor;

  /// Desired visual stroke width in logical pixels. The painter corrects for
  /// the canvas scale so the stroke looks consistent at any map size.
  final double strokeWidth;

  @override
  bool shouldRepaint(covariant UsaWelcomePainter old) =>
      (old.animValue - animValue).abs() > 0.001 ||
      old.fillColor != fillColor ||
      old.strokeColor != strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the 1000×628 viewBox to fit the available area while preserving
    // the map's aspect ratio and centering it within the canvas.
    const mapW = 1000.0;
    const mapH = 628.0;
    final scaleX = size.width / mapW;
    final scaleY = size.height / mapH;
    final fitScale = math.min(scaleX, scaleY);
    final tx = (size.width - mapW * fitScale) / 2;
    final ty = (size.height - mapH * fitScale) / 2;

    canvas.save();
    canvas.translate(tx, ty);
    canvas.scale(fitScale);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;

    // Divide requested visual width by fitScale so that after canvas.scale()
    // the rendered stroke is exactly [strokeWidth] logical pixels wide.
    final strokePaint = strokeColor != null
        ? (Paint()
          ..style = PaintingStyle.stroke
          ..color = strokeColor!
          ..strokeWidth = strokeWidth / fitScale
          ..strokeJoin = StrokeJoin.round)
        : null;

    for (int k = 0; k < staggerOrder.length; k++) {
      final threshold = k / staggerOrder.length; // 0..1 step per state
      if (animValue < threshold) continue; // stagger gate
      final state = states[staggerOrder[k]];
      for (final path in state.paths) {
        canvas.drawPath(path, fillPaint);
        if (strokePaint != null) {
          canvas.drawPath(path, strokePaint);
        }
      }
    }

    canvas.restore();
  }
}
