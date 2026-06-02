import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:state_states/core/models/state_data.dart';
import 'package:state_states/features/game/game_mode.dart';

/// StateTray — draggable state token widget.
///
/// Direct port of FlagTray (FlagsRoundTheWorld) with mode-driven card face
/// replacing the SvgPicture. The bounce animation, pin anchor offset, and
/// GlobalKey discipline are load-bearing for the drop-coordinate math
/// validated by the Phase 3 spike.
///
/// Critical invariants:
/// - [kPinAnchor] == Offset(45, 70) — DO NOT CHANGE. Matches MapScreen drop math.
///   Width 90 → centre x=45; card 60 + triangle 10 → tip y=70. The pointer sits
///   at the pin tip during drag, so the drop fires exactly where the user aims.
/// - [cardKey] is assigned ONLY to Draggable.child. Never to feedback or
///   childWhenDragging — sharing a GlobalKey causes a duplicate-key crash during drag.
class StateTray extends StatefulWidget {
  final String postal; // abbreviation, used as Draggable.data
  final String stateName; // full state name
  final GameMode mode; // drives card face content
  final int sequenceIndex; // Grand Master palette index: palette[sequenceIndex % 6]
  final GlobalKey cardKey; // ONLY assigned to Draggable.child, not feedback
  final bool showName; // true for Learn + StatesMaster; false for Geo/GrandMaster
  final int hintsRemaining;
  /// Null during countdown — button is disabled until game phase is playing.
  final VoidCallback? onHintPressed;
  /// Provides state shape paths for silhouette rendering in learn/geo modes.
  final StateData? stateData;

  const StateTray({
    super.key,
    required this.postal,
    required this.stateName,
    required this.mode,
    required this.sequenceIndex,
    required this.cardKey,
    this.showName = true,
    this.hintsRemaining = 2,
    this.onHintPressed,
    this.stateData,
  });

  /// The point within the feedback widget that sits at the pointer during drag.
  /// Tip of the pin triangle: x=45 (centre of 90px card), y=70 (card 60 + tip 10).
  /// DragTargetDetails.offset = pointer_global − kPinAnchor, so callers must
  /// add this back to recover the actual drop coordinate.
  // ignore: constant_identifier_names
  static const kPinAnchor = Offset(45, 70);

  @override
  State<StateTray> createState() => StateTrayState();
}

class StateTrayState extends State<StateTray>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<Offset> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(20, -10),
    ).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  /// Triggers a brief elastic bounce animation on the card.
  /// Called by MapScreen when the player drops on the wrong state.
  void triggerBounce() {
    _bounceController.forward().then((_) => _bounceController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: Colors.grey.shade200,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHintButton(context),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _bounceAnim,
              builder: (ctx, child) => Transform.translate(
                offset: _bounceAnim.value,
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDraggableCard(context),
                  if (widget.showName)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 90,
                        child: Text(
                          widget.stateName,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintButton(BuildContext context) {
    final enabled = widget.onHintPressed != null && widget.hintsRemaining > 0;
    return Semantics(
      label: 'Hint button, ${widget.hintsRemaining} hints remaining',
      button: true,
      enabled: enabled,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        onPressed: enabled ? widget.onHintPressed : null,
        icon: const Icon(Icons.lightbulb_outline, size: 18),
        label: Text('Hint ×${widget.hintsRemaining}'),
      ),
    );
  }

  Widget _buildDraggableCard(BuildContext context) {
    return Semantics(
      label: 'State token: ${widget.stateName}',
      child: Draggable<String>(
        data: widget.postal,
        dragAnchorStrategy: _pinAnchorStrategy,
        feedback: _buildFeedback(),
        // GlobalKey is only on `child` — feedback and childWhenDragging must NOT
        // share it, or Flutter throws a duplicate-GlobalKey error during the drag.
        childWhenDragging: Opacity(opacity: 0.3, child: _cardShell()),
        child: _cardShell(key: widget.cardKey),
      ),
    );
  }

  static Offset _pinAnchorStrategy(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) =>
      StateTray.kPinAnchor;

  Widget _buildFeedback() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: _cardShell(),
        ),
        // Pin tip — the actual drop-registration point (y=70 from feedback top).
        // The player aims this triangle at the target state; the pointer sits at
        // the tip so the hit test fires exactly where it points.
        ClipPath(
          clipper: const _DownTriangle(),
          child: Container(
            width: 20,
            height: 10,
            color: const Color(0xFFFF6600),
          ),
        ),
      ],
    );
  }

  // Palette for Grand Master — order matches UsaMapPainter palette colors.
  static const _palette = [
    Color(0xFF8DB87F),
    Color(0xFFD4B483),
    Color(0xFFE8A055),
    Color(0xFFE89090),
    Color(0xFFA07EC8),
    Color(0xFFE8D870),
  ];

  /// Card shell — optionally keyed. Content is always the mode-driven card face.
  /// Separating key from content prevents the GlobalKey from appearing in
  /// both the Overlay (feedback) and the widget tree (childWhenDragging)
  /// simultaneously.
  Widget _cardShell({Key? key}) {
    return Container(
      key: key,
      width: 90,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            offset: Offset(2, 2),
            color: Color(0x44000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _cardFace(),
      ),
    );
  }

  Widget _cardFace() {
    switch (widget.mode) {
      case GameMode.grandMaster:
        return Container(color: _palette[widget.sequenceIndex % 6]);
      case GameMode.statesMaster:
        return Center(
          child: Text(
            widget.stateName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      case GameMode.learn:
      case GameMode.geographicalMaster:
        final sd = widget.stateData;
        if (sd != null) {
          return CustomPaint(
            painter: _StateShapePainter(
              paths: sd.paths,
              bbox: sd.boundingBox,
            ),
          );
        }
        // Fallback when stateData not yet available.
        return Center(
          child: Text(
            widget.postal,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        );
    }
  }
}

/// Renders the state's silhouette centered and scaled to the card bounds.
/// Paths are in the original map coordinate space; the painter applies a
/// transform to fit them within the card with 85% coverage for padding.
class _StateShapePainter extends CustomPainter {
  const _StateShapePainter({required this.paths, required this.bbox});

  final List<Path> paths;
  final BoundingBox bbox;

  static const _fillColor = Color(0xFFB8D4E8); // ocean-blue tint
  static const _strokeColor = Color(0xFF3A6B8A);

  @override
  void paint(Canvas canvas, Size size) {
    if (paths.isEmpty || bbox.w == 0 || bbox.h == 0) return;

    const coverage = 0.85;
    final scale = math.min(
      size.width * coverage / bbox.w,
      size.height * coverage / bbox.h,
    );
    final tx = (size.width - bbox.w * scale) / 2 - bbox.x * scale;
    final ty = (size.height - bbox.h * scale) / 2 - bbox.y * scale;

    final m = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);

    canvas.save();
    canvas.transform(m.storage);

    final fillPaint = Paint()
      ..color = _fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = _strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / scale;

    for (final path in paths) {
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_StateShapePainter old) =>
      old.bbox.x != bbox.x ||
      old.bbox.y != bbox.y ||
      old.bbox.w != bbox.w ||
      old.bbox.h != bbox.h;
}

/// Downward-pointing triangle clipper for the pin tip.
class _DownTriangle extends CustomClipper<Path> {
  const _DownTriangle();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();

  @override
  bool shouldReclip(_DownTriangle old) => false;
}

