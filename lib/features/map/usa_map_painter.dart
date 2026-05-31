import 'package:flutter/material.dart';
import '../../core/models/state_data.dart';

/// Phase 1 end-to-end proof painter: takes the loaded state list but paints
/// nothing. The real map rendering (fills, borders, AK/HI insets, labels) is
/// built in Phase 3. This exists only to prove the JSON → isolate → provider →
/// painter pipeline is wired without crashing (ROADMAP Success Criterion #5).
class UsaMapPainter extends CustomPainter {
  final List<StateData> states;

  const UsaMapPainter({required this.states});

  @override
  void paint(Canvas canvas, Size size) {
    // Intentionally blank in Phase 1 — see class doc.
  }

  @override
  bool shouldRepaint(covariant UsaMapPainter oldDelegate) => false;
}
