import 'package:flutter/material.dart';

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
  });

  /// The point within the feedback widget that sits at the pointer during drag.
  /// Centre of the 90×60 card: x=45, y=30. Kids aim the card center at the state.
  /// DragTargetDetails.offset = pointer_global − kPinAnchor, so callers must
  /// add this back to recover the actual drop coordinate.
  // ignore: constant_identifier_names
  static const kPinAnchor = Offset(45, 30);

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

  // Anchor point = centre of the card = kPinAnchor within the feedback.
  // Kids drag the centre of the card over the target state — more natural than a pin tip.
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
        // Pin tip — the actual drop-registration point.
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
        return Center(
          child: Text(
            widget.postal,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        );
    }
  }
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
