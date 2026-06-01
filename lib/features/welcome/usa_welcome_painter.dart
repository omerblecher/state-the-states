import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/state_data.dart';

/// Renders the USA silhouette on the WelcomeScreen with a stagger-fill animation.
///
/// States fill in one-by-one with a random stagger order over the animation
/// duration (~1.5s, driven by [animValue] 0.0→1.0 from [AnimationController]).
///
/// Analog: [UsaMapPainter] — same CustomPainter base, different fill logic.
/// No ocean fill — transparent background so the gradient behind shows through.
class UsaWelcomePainter extends CustomPainter {
  const UsaWelcomePainter({
    required this.states,
    required this.staggerOrder,
    required this.animValue,
  });

  final List<StateData> states;

  /// Pre-shuffled index list — each entry is an index into [states].
  final List<int> staggerOrder;

  /// Current animation value 0.0 → 1.0 from the [AnimationController].
  final double animValue;

  @override
  bool shouldRepaint(covariant UsaWelcomePainter old) =>
      (old.animValue - animValue).abs() > 0.001; // RESEARCH.md Pitfall 6

  @override
  void paint(Canvas canvas, Size size) {
    // No ocean fill — transparent so gradient background shows through.

    // Scale the 1000×628 viewBox to fit the SizedBox while preserving aspect ratio.
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
      ..color = Colors.white; // D-W3: solid white states

    for (int k = 0; k < staggerOrder.length; k++) {
      final threshold = k / staggerOrder.length; // 0..1 step per state
      if (animValue < threshold) continue; // D-W2: stagger gate
      final state = states[staggerOrder[k]];
      for (final path in state.paths) {
        canvas.drawPath(path, fillPaint);
      }
    }

    canvas.restore();
  }
}
