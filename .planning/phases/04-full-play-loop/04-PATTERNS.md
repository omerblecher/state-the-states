# Phase 4: Full Play Loop — Pattern Map

**Mapped:** 2026-06-01
**Files analyzed:** 8 (5 new, 3 modified)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/features/game/state_tray.dart` | component | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\flag_tray.dart` | exact |
| `lib/features/map/completion_screen.dart` | component | CRUD | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart` | exact |
| `lib/features/game/game_hud.dart` | component | request-response | `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_hud.dart` | exact |
| `lib/features/map/map_screen.dart` (extend) | component | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` | exact |
| `lib/features/home/home_screen.dart` (replace body) | component | CRUD | `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\home_screen.dart` | exact |
| `lib/app.dart` (routing changes) | config | request-response | `lib/app.dart` (current) | self |
| `test/features/home/home_screen_test.dart` | test | — | `test/features/map/map_screen_test.dart` | role-match |
| `test/features/map/completion_screen_test.dart` | test | — | `test/features/game/game_session_notifier_test.dart` | role-match |
| `test/features/map/state_tray_test.dart` | test | — | `test/features/map/map_screen_test.dart` | role-match |

---

## Pattern Assignments

### `lib/features/game/state_tray.dart` (component, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\flag_tray.dart`

**Imports pattern** (Flags flag_tray.dart lines 1–5 — adapt package name, drop flutter_svg):
```dart
import 'package:flutter/material.dart';
import 'package:state_states/features/game/game_mode.dart';
```

**Constructor + constants** (Flags flag_tray.dart lines 6–32):
```dart
class StateTray extends StatefulWidget {
  final String postal;        // replaces currentIsoCode
  final String stateName;     // replaces countryName
  final GameMode mode;        // NEW — drives card face content
  final int sequenceIndex;    // NEW — Grand Master palette color index
  final GlobalKey cardKey;
  final bool showName;
  final int hintsRemaining;
  final VoidCallback onHintPressed;

  const StateTray({
    super.key,
    required this.postal,
    required this.stateName,
    required this.mode,
    required this.sequenceIndex,
    required this.cardKey,
    this.showName = true,
    this.hintsRemaining = 2,
    this.onHintPressed = _noOp,
  });

  static void _noOp() {}

  // kPinAnchor is IDENTICAL to FlagTray — do not change.
  // Width 90 → centre x = 45; card height 60 + triangle 10 → tip y = 70.
  static const kPinAnchor = Offset(45, 70);

  @override
  State<StateTray> createState() => StateTrayState();
}
```

**Bounce animation in State** (Flags flag_tray.dart lines 35–60):
```dart
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
    ).animate(CurvedAnimation(
        parent: _bounceController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void triggerBounce() {
    _bounceController.forward().then((_) => _bounceController.reverse());
  }
```

**Container shell + AnimatedBuilder** (Flags flag_tray.dart lines 62–104):
```dart
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
```

**Draggable card builder** (Flags flag_tray.dart lines 129–154 — adapt GlobalKey guard comment):
```dart
  Widget _buildDraggableCard(BuildContext context) {
    return Semantics(
      label: 'State token: ${widget.stateName}',
      child: Draggable<String>(
        data: widget.postal,
        dragAnchorStrategy: _pinAnchorStrategy,
        feedback: _buildFeedback(),
        // GlobalKey is only on `child` — feedback and childWhenDragging must NOT
        // share it or Flutter throws a duplicate-GlobalKey error during drag.
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
```

**Card shell — mode-driven content** (Flags flag_tray.dart lines 179–205 — replace SvgPicture with mode switch):
```dart
  // Palette for Grand Master — order matches UsaMapPainter palette colors.
  static const _palette = [
    Color(0xFF8DB87F), Color(0xFFD4B483), Color(0xFFE8A055),
    Color(0xFFE89090), Color(0xFFA07EC8), Color(0xFFE8D870),
  ];

  Widget _cardShell({Key? key}) {
    return Container(
      key: key,
      width: 90,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(blurRadius: 4, offset: Offset(2, 2), color: Color(0x44000000)),
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
        final color = _palette[widget.sequenceIndex % 6];
        return Container(color: color);
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
```

**`_DownTriangle` clipper** (Flags flag_tray.dart lines 209–221 — copy verbatim):
```dart
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
```

---

### `lib/features/game/game_hud.dart` (component, request-response)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_hud.dart`

**Full file — copy verbatim, 3 changes only** (Flags game_hud.dart lines 1–114):

1. Change package import from `flags_around_the_world` to `state_states`.
2. Drop `AppLocalizations` dependency — hardcode string literals directly (no l10n in Phase 4).
3. The constructor signature is **identical**; no parameter changes needed.

```dart
import 'package:flutter/material.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.score,
    required this.elapsed,
    required this.matchedCount,
    required this.totalFlags,   // pass 50, not 196
    required this.onPause,
    this.isMuted = false,
    this.onMuteToggle,
  });

  final int score;
  final Duration elapsed;
  final int matchedCount;
  final int totalFlags;
  final VoidCallback onPause;
  final bool isMuted;
  final VoidCallback? onMuteToggle;
```

**Progress bar pattern** (Flags game_hud.dart lines 31–62 — copy verbatim):
```dart
  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final progress = totalFlags > 0 ? matchedCount / totalFlags : 0.0;

    return Container(
      height: 48,
      color: Colors.grey.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text('Score: $score',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade600,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ),
          ),
          // ... mute + pause icon buttons (48dp each, Semantics-wrapped)
        ],
      ),
    );
  }
```

---

### `lib/features/map/map_screen.dart` (extend — component, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart`

**State class mixin change** (Flags map_screen.dart line 51):
```dart
// CURRENT (Phase 3):
class _MapScreenState extends ConsumerState<MapScreen> {

// REQUIRED (Phase 4) — TickerProviderStateMixin for multiple AnimationControllers:
class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
```

**New state fields to add** (Flags map_screen.dart lines 59–99):
```dart
  // Sequence state
  String _currentPostal = '';
  List<String> _remainingPostals = [];
  Set<String> _matchedPostals = {};
  bool _sequenceInitialized = false;

  // Tray keys — re-created on each advance (AnimatedSwitcher trigger)
  GlobalKey<StateTrayState> _trayKey = GlobalKey<StateTrayState>();
  GlobalKey _trayCardKey = GlobalKey();

  // Overlay animation — ref held for dispose() cleanup
  OverlayEntry? _activeOverlay;

  // Pause overlay visibility
  bool _isPauseOverlayVisible = false;

  // Mute state
  bool _isMuted = false;
```

**initState additions** (Flags map_screen.dart lines 109–118):
```dart
  @override
  void initState() {
    super.initState();
    // D-08: mount GameLifecycleObserver (built Phase 2, mounted Phase 4)
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _controller = TransformationController();
    _controller.addListener(_onScaleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToScreen());
  }

  late final GameLifecycleObserver _lifecycleObserver = GameLifecycleObserver(
    ref.read(gameSessionProvider.notifier),
  );
```

**dispose additions** (Flags map_screen.dart lines 134–144):
```dart
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _controller.removeListener(_onScaleChanged);
    _activeOverlay?.remove();   // Pitfall 4: always remove overlay on dispose
    _activeOverlay = null;
    _controller.dispose();
    super.dispose();
  }
```

**Sequence start** (Flags map_screen.dart lines 220–241 — simplified, no tutorial branch):
```dart
  void _startSequence(List<StateData> states) {
    if (_sequenceInitialized) return;
    _sequenceInitialized = true;
    // Filter DC (postal == 'DC') — 50 placeable states only (Pitfall 7)
    final playable = states
        .where((s) => s.postal != 'DC')
        .map((s) => s.postal)
        .toList()
      ..shuffle();
    _remainingPostals = playable;
    if (_remainingPostals.isNotEmpty) _currentPostal = _remainingPostals.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToScreen();
      ref.read(gameSessionProvider.notifier).startGame(widget.mode);
    });
  }
```

**`_centroidToScreen` helper** (Flags map_screen.dart lines 443–451 — copy verbatim):
```dart
  Offset _centroidToScreen(Offset sceneCentroid) {
    final matrix = _controller.value;
    final viewportLocal = MatrixUtils.transformPoint(matrix, sceneCentroid);
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(viewportLocal);
  }
```

**`_animateCorrectDrop`** (Flags map_screen.dart lines 457–523 — adapt: replace SvgPicture with `_cardShell()` equivalent):
```dart
  void _animateCorrectDrop(String postal) {
    final trayBox =
        _trayCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (trayBox == null) {
      _advanceToNextPostal();
      return;
    }
    final startOffset = trayBox.localToGlobal(Offset.zero);

    // Centroid lookup from _stateIndex (built when data loads)
    final state = _stateIndex[postal];
    if (state == null) { _advanceToNextPostal(); return; }
    final endOffset = _centroidToScreen(state.centroid);

    final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final posAnim = Tween<Offset>(begin: startOffset, end: endOffset)
        .animate(CurvedAnimation(parent: animController, curve: Curves.easeInOut));
    final scaleAnim = Tween<double>(begin: 1.0, end: 0.15)
        .animate(CurvedAnimation(parent: animController, curve: Curves.easeInOut));
    final opacityAnim = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: animController, curve: Curves.easeInOut));

    _activeOverlay?.remove();
    _activeOverlay = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: animController,
        builder: (ctx, child) => Positioned(
          left: posAnim.value.dx,
          top: posAnim.value.dy,
          child: Opacity(
            opacity: opacityAnim.value,
            child: Transform.scale(scale: scaleAnim.value, child: child),
          ),
        ),
        // Replace SvgPicture with the card face for state token
        child: SizedBox(width: 90, height: 60, child: _buildTokenPreview(postal)),
      ),
    );
    Overlay.of(context).insert(_activeOverlay!);

    animController.forward().whenComplete(() {
      _activeOverlay?.remove();
      _activeOverlay = null;
      animController.dispose();
      if (mounted) _advanceToNextPostal();   // Risk 2: mounted guard
    });
  }
```

**`_advanceToNextPostal`** (Flags map_screen.dart lines 369–399 — adapt names):
```dart
  Future<void> _advanceToNextPostal() async {
    if (_remainingPostals.isEmpty) return;
    setState(() {
      _matchedPostals = {..._matchedPostals, _currentPostal};  // new Set for shouldRepaint
      _remainingPostals.removeAt(0);
    });
    if (_remainingPostals.isEmpty) {
      final sessionBeforeComplete = ref.read(gameSessionProvider).value!;
      final repo = await ref.read(highScoreRepositoryProvider.future);
      final previousBest = await repo.getBestScore(sessionBeforeComplete.mode);
      await ref.read(gameSessionProvider.notifier).completeGame();
      if (!mounted) return;
      final completedSession = ref.read(gameSessionProvider).value;
      if (completedSession == null) return;
      context.go('/complete', extra: {
        'session': completedSession,
        'previousBest': previousBest,
      });
    } else {
      setState(() {
        _currentPostal = _remainingPostals.first;
        _trayKey = GlobalKey<StateTrayState>();   // Risk 3: new keys on each advance
        _trayCardKey = GlobalKey();
      });
    }
  }
```

**Drop handler** (Flags map_screen.dart lines 529–561 — adapt names, use `StateTray.kPinAnchor`):
```dart
  void _handleDrop(DragTargetDetails<String> details) {
    final session = ref.read(gameSessionProvider).value;
    if (session?.phase != GamePhase.playing) return;  // Risk 5: phase guard
    if (_currentPostal.isEmpty) return;               // Risk 4: uninitialized guard

    final rawScene = _toSceneFromGlobal(details.offset + StateTray.kPinAnchor);
    if (rawScene == null) return;
    final scale = _controller.value.getMaxScaleOnAxis();
    final hitPostal = stateHitTest(rawScene, _states, scale: scale);
    final isCorrect = hitPostal == _currentPostal;

    if (isCorrect) {
      ref.read(gameSessionProvider.notifier).recordDrop(hitPostal!, isCorrect: true);
      HapticFeedback.lightImpact();
      ref.read(audioServiceProvider).playCorrect();
      _animateCorrectDrop(_currentPostal);
    } else {
      ref.read(gameSessionProvider.notifier).recordDrop(
          hitPostal ?? _currentPostal, isCorrect: false);
      HapticFeedback.mediumImpact();
      ref.read(audioServiceProvider).playError();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: const Text('Not quite — try again!',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          // Risk 6: float above 120dp tray + 16dp gap
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 136),
        ));
      _trayKey.currentState?.triggerBounce();
    }
  }
```

**Pause overlay** (Flags map_screen.dart lines 577–653 — copy verbatim, replace l10n strings with literals):
```dart
  void _onPausePressed() {
    ref.read(gameSessionProvider.notifier).pauseGame();
    setState(() => _isPauseOverlayVisible = true);
  }

  void _dismissPauseOverlay() {
    ref.read(gameSessionProvider.notifier).resumeGame();
    setState(() => _isPauseOverlayVisible = false);
  }

  Widget _buildPauseOverlay() {
    return GestureDetector(
      onTap: () {},  // consume taps
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Paused',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, height: 48,
                    child: ElevatedButton(onPressed: _dismissPauseOverlay,
                        child: const Text('Resume'))),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _toggleMute,
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      label: Text(_isMuted ? 'Unmute' : 'Mute'),
                    )),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, height: 48,
                    child: TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('End Game',
                          style: TextStyle(color: Colors.red)),
                    )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
```

**DragTarget inside InteractiveViewer child** (Flags map_screen.dart lines 851–901 — single DragTarget strategy):
```dart
  // Inside _buildMapStack(), as the last layer inside SizedBox(1000, 628):
  DragTarget<String>(
    builder: (ctx, _, __) => const SizedBox.expand(),
    onWillAcceptWithDetails: (_) => true,  // no hover glow in Phase 4
    onAcceptWithDetails: _handleDrop,
  ),
```

**Back-button guard** (Flags map_screen.dart lines 970–984 — copy verbatim, adapt):
```dart
  void _onBackPressed() {
    final session = ref.read(gameSessionProvider).value;
    if (session == null) { context.go('/'); return; }
    if (session.phase == GamePhase.playing) {
      ref.read(gameSessionProvider.notifier).pauseGame();
      setState(() => _isPauseOverlayVisible = true);
    } else if (session.phase == GamePhase.paused) {
      setState(() => _isPauseOverlayVisible = true);
    } else {
      context.go('/');
    }
  }
```

**PopScope wrapping Scaffold** (Flags map_screen.dart lines 1023–1047):
```dart
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        body: ref.watch(stateDataProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load map: $e')),
          data: (mapData) => _buildMapStack(mapData.states, mapData.insetFrameRects),
        ),
      ),
    );
  }
```

**Countdown overlay** (new — no Flags equivalent; follows pause overlay structure):
```dart
  Widget _buildCountdownOverlay(int secondsRemaining) {
    return IgnorePointer(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Text(
          secondsRemaining > 0 ? '$secondsRemaining' : 'GO!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  // Rendered in build() Stack when session?.phase == GamePhase.countdown
```

**Tray AnimatedSwitcher integration** (Flags map_screen.dart lines 936–957 — adapt names):
```dart
  // In Column children (after Expanded map area, before pause overlay stack):
  AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    // FadeTransition ONLY — SlideTransition moves hit-test area, Draggable
    // becomes unreachable during transition (Flags map_screen.dart line 942 comment)
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: _currentPostal.isEmpty
        ? const SizedBox.shrink()
        : StateTray(
            key: _trayKey,
            postal: _currentPostal,
            stateName: _stateName(_currentPostal),  // lookup from _stateIndex
            mode: widget.mode,
            sequenceIndex: 50 - _remainingPostals.length,  // index in full sequence
            cardKey: _trayCardKey,
            showName: showName,
            hintsRemaining: session?.hintsRemaining ?? 2,
            onHintPressed: () {},  // Phase 4: no-op; Phase 5 wires hint zoom
          ),
  ),
```

---

### `lib/features/map/completion_screen.dart` (component, CRUD)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart`

**Imports** (Flags completion_screen.dart lines 1–15 — drop share_plus, drop ads, change package):
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_session.dart';
```

**Star formula** (Flags completion_screen.dart lines 20–25 — copy verbatim, rename to match D-11):
```dart
int computeStarCount(int score, int? previousBest) {
  if (previousBest == null) return 3;
  if (score < previousBest) return 3;
  if (score <= (previousBest * 1.20).ceil()) return 2;
  return 1;
}
```

**initState — PB detection + confetti** (Flags completion_screen.dart lines 53–89 — omit ad call):
```dart
  @override
  void initState() {
    super.initState();
    final prev = widget.previousBest;
    final score = widget.session.score;
    if (prev == null) {
      _isNewPb = false; _starCount = 3;
    } else if (score < prev) {
      _isNewPb = true;  _starCount = 3;
    } else if (score <= (prev * 1.20).ceil()) {
      _isNewPb = false; _starCount = 2;
    } else {
      _isNewPb = false; _starCount = 1;
    }

    _pbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (_isNewPb) {
      setState(() => _showPbOverlay = true);
      _pbController.forward().whenComplete(() {
        if (mounted) setState(() => _showPbOverlay = false);
      });
    }
    // NOTE: NO ad call here (D-13 — v2 only)
  }
```

**Confetti overlay** (Flags completion_screen.dart lines 428–447 — copy verbatim):
```dart
  if (_showPbOverlay)
    AnimatedBuilder(
      animation: _pbController,
      builder: (ctx, _) {
        final opacity = _pbController.value < 0.8
            ? 1.0
            : (1.0 - ((_pbController.value - 0.8) / 0.2)).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Positioned.fill(
              child: CustomPaint(
                painter: _ConfettiPainter(progress: _pbController.value),
              ),
            ),
          ),
        );
      },
    ),
```

**`_ConfettiPainter`** (Flags completion_screen.dart lines 510–552 — copy verbatim):
```dart
class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final List<_Particle> _particles = _generateParticles();
  const _ConfettiPainter({required this.progress});

  static List<_Particle> _generateParticles() {
    final rng = math.Random(42);  // seed 42 = deterministic
    final colors = [Colors.red, Colors.blue, Colors.green,
                    Colors.yellow, Colors.purple, Colors.orange];
    return List.generate(40, (i) => _Particle(
      x: rng.nextDouble(),
      speed: 0.5 + rng.nextDouble(),
      color: colors[i % colors.length],
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final px = p.x * size.width +
          math.sin(progress * math.pi * 3 + p.x * math.pi * 2) * 20;
      final py = progress * p.speed * size.height;
      final opacity = (1.0 - progress * 1.2).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(px, py), 6, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
```

**CTA buttons** (Flags completion_screen.dart lines 360–422 — omit share button, adapt route):
```dart
  // Primary CTA — back to home
  SizedBox(
    width: double.infinity, height: 56,
    child: ElevatedButton.icon(
      onPressed: () => context.go('/'),
      style: ElevatedButton.styleFrom(
        backgroundColor: modeColor, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.home),
      label: const Text('Back to Menu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  ),
  const SizedBox(height: 12),
  // Secondary CTA — play again same mode
  SizedBox(
    width: double.infinity, height: 48,
    child: OutlinedButton.icon(
      onPressed: () => context.go('/play', extra: widget.session.mode),
      style: OutlinedButton.styleFrom(
        foregroundColor: modeColor, side: BorderSide(color: modeColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.replay),
      label: const Text('Play Again'),
    ),
  ),
  // NOTE: NO share button (D-13 — v2 only)
```

**Mode color helper** (Flags completion_screen.dart lines 223–228 — rename flagsMaster → statesMaster):
```dart
  Color _modeColor(GameMode mode) => switch (mode) {
    GameMode.learn               => const Color(0xFF2E7D32),
    GameMode.statesMaster        => const Color(0xFF1565C0),
    GameMode.geographicalMaster  => const Color(0xFFE65100),
    GameMode.grandMaster         => const Color(0xFF4A148C),
  };
```

---

### `lib/features/home/home_screen.dart` (replace body — component, CRUD)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\home_screen.dart`

**Imports** (Flags home_screen.dart lines 1–16 — drop ads, drop url_launcher for Phase 4, change package):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/core/data/high_score_repository.dart';
```

**Body structure** (Flags home_screen.dart lines 203–311 — adapt, omit ad slot, omit `_checkSavedSession`):
```dart
  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(highScoreRepositoryProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (repo) => _buildBody(context, repo),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HighScoreRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
          child: Row(children: [
            const Icon(Icons.map, color: Color(0xFF1565C0), size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('State the States',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2E6B)))),
          ]),
        ),
        // Mode cards
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ModeCard(mode: GameMode.learn, /* ... */,
                  bestScoreFuture: repo.getBestScore(GameMode.learn),
                  onTap: () => context.go('/play', extra: GameMode.learn)),
              // × 3 more modes
            ],
          ),
        ),
      ],
    );
  }
```

**`_ModeCard` widget** (Flags home_screen.dart lines 343–524 — copy verbatim, replace mode names/descriptions/icons):

Key constructor fields to preserve exactly:
```dart
class _ModeCard extends StatefulWidget {
  final GameMode mode;
  final String name;
  final String description;
  final IconData icon;
  final Color cardColor;
  final Future<int?> bestScoreFuture;
  final VoidCallback onTap;
```

**`_starsForScore` in `_ModeCardState`** (Flags home_screen.dart lines 390–395 — copy verbatim):
```dart
  int _starsForScore(int? score) {
    if (score == null) return 0;
    if (score <= 80) return 3;
    if (score <= 150) return 2;
    return 1;
  }
```

**Scale press animation in card** (Flags home_screen.dart lines 399–411 — copy verbatim):
```dart
  return GestureDetector(
    onTapDown: (_) => _scaleController.forward(),
    onTapUp: (_) { _scaleController.reverse(); widget.onTap(); },
    onTapCancel: () => _scaleController.reverse(),
    child: AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
      child: /* gradient Container */,
    ),
  );
```

**`FutureBuilder` for score + stars** (Flags home_screen.dart lines 472–518 — copy verbatim):
```dart
  FutureBuilder<int?>(
    future: widget.bestScoreFuture,
    builder: (ctx, snap) {
      final stars = snap.hasData ? _starsForScore(snap.data) : 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i < stars ? Colors.amber : Colors.white.withValues(alpha: 0.4),
              size: 18,
            ))),
          const SizedBox(height: 4),
          if (snap.hasData && snap.data != null)
            Text('Best: ${snap.data}', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 11))
          else
            Text('Not played', style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        ],
      );
    },
  ),
```

---

### `lib/app.dart` (routing changes — config, request-response)

**Analog:** `lib/app.dart` (current file, self-referential)

**Current `/play` route** (current app.dart lines 18–20):
```dart
GoRoute(
  path: '/play',
  builder: (context, state) => const MapScreen(),
),
```

**Required change — `/play` receives `GameMode` extra**:
```dart
GoRoute(
  path: '/play',
  builder: (context, state) {
    final mode = state.extra as GameMode? ?? GameMode.learn;
    return MapScreen(mode: mode);
  },
),
```

**New `/complete` route to add**:
```dart
GoRoute(
  path: '/complete',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return CompletionScreen(
      session: extra['session'] as GameSession,
      previousBest: extra['previousBest'] as int?,
    );
  },
),
```

**`MapScreen` constructor change** (current map_screen.dart lines 26–32 — `mode` stays optional for test backward-compat, Risk 7):
```dart
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    this.matchedPostals = const {},
    this.showLabels = false,
    this.mode = GameMode.learn,   // default for test backward-compat (Risk 7)
  });

  final Set<String> matchedPostals;
  final bool showLabels;
  final GameMode mode;   // non-nullable with default
```

---

### `test/features/home/home_screen_test.dart` (test, Wave 0 stub)

**Analog:** `test/features/map/map_screen_test.dart`

**Test file structure** (map_screen_test.dart lines 1–11):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/home/home_screen.dart';

class MockHighScoreRepository extends Mock implements HighScoreRepository {}
```

**Provider override pattern** (map_screen_test.dart lines 23–37 — adapt for repo mock):
```dart
  testWidgets('HomeScreen shows 4 mode cards', (tester) async {
    final mockRepo = MockHighScoreRepository();
    when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        highScoreRepositoryProvider.overrideWith((_) async => mockRepo),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump();  // let FutureProvider emit
    await tester.pump();
    // assertions ...
  });
```

---

### `test/features/map/completion_screen_test.dart` (test, Wave 0 stub)

**Analog:** `test/features/game/game_session_notifier_test.dart`

**Unit test pattern for pure logic** (game_session_notifier_test.dart lines 1–28 — adapt for star formula):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/map/completion_screen.dart';

void main() {
  group('computeStarCount', () {
    test('returns 3 for first game (previousBest == null)', () {
      expect(computeStarCount(100, null), equals(3));
    });
    test('returns 3 for personal best', () {
      expect(computeStarCount(50, 100), equals(3));
    });
    test('returns 2 for score within 20% of best', () {
      expect(computeStarCount(115, 100), equals(2)); // 115 <= ceil(100*1.20)=120
    });
    test('returns 1 for score more than 20% above best', () {
      expect(computeStarCount(125, 100), equals(1)); // 125 > 120
    });
  });
}
```

---

### `test/features/map/state_tray_test.dart` (test, Wave 0 stub)

**Analog:** `test/features/map/map_screen_test.dart`

**Widget test structure** (map_screen_test.dart lines 19–47 — adapt for StateTray):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/state_tray.dart';

void main() {
  testWidgets('StateTray in Learn mode shows postal on face and name below',
      (tester) async {
    final cardKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StateTray(
          postal: 'CA',
          stateName: 'California',
          mode: GameMode.learn,
          sequenceIndex: 0,
          cardKey: cardKey,
          showName: true,
          hintsRemaining: 2,
        ),
      ),
    ));
    expect(find.text('CA'), findsOneWidget);
    expect(find.text('California'), findsOneWidget);
  });
}
```

---

## Shared Patterns

### Riverpod provider watching in ConsumerStatefulWidget
**Source:** `lib/features/map/map_screen.dart` (Phase 3 production), lines 153–159
**Apply to:** `MapScreen` (extended), `HomeScreen` (body replacement), `CompletionScreen`
```dart
ref.watch(stateDataProvider).when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Center(child: Text('Could not load map: $e')),
  data: (mapData) => _buildMapStack(mapData.states, mapData.insetFrameRects),
);
```
Pattern: always use `.when()` on async providers; three branches required; `data:` branch calls a separate `_build*` helper to keep `build()` readable.

### Audio service calls
**Source:** `lib/core/audio/audio_service.dart` lines 1–15; `lib/core/audio/audio_service_provider.dart` lines 8–9
**Apply to:** `MapScreen` drop handler (correct + incorrect)
```dart
// Correct drop:
ref.read(audioServiceProvider).playCorrect();
// Incorrect drop:
ref.read(audioServiceProvider).playError();
```
Method names confirmed from `AudioService` interface: `playCorrect()` and `playError()`. No async needed — fire-and-forget.

### HighScoreRepository FutureProvider pattern
**Source:** `lib/core/data/high_score_repository.dart` lines 34–37
**Apply to:** `HomeScreen._buildBody()`, `MapScreen._advanceToNextPostal()`, `CompletionScreen`
```dart
// In HomeScreen: watch the provider, handle async states
final repoAsync = ref.watch(highScoreRepositoryProvider);

// In MapScreen._advanceToNextPostal(): await the future directly
final repo = await ref.read(highScoreRepositoryProvider.future);
final previousBest = await repo.getBestScore(sessionBeforeComplete.mode);
```

### GoRouter navigation with `extra`
**Source:** `lib/app.dart` current + Flags map_screen.dart lines 387–391
**Apply to:** `HomeScreen` (tap-to-play), `MapScreen` (completion navigation)
```dart
// Home → play:
context.go('/play', extra: mode);  // mode is GameMode enum value

// MapScreen → completion:
context.go('/complete', extra: {
  'session': completedSession,
  'previousBest': previousBest,
});

// CompletionScreen → home:
context.go('/');

// CompletionScreen → play again:
context.go('/play', extra: widget.session.mode);
```

### Test ProviderScope override pattern
**Source:** `test/features/map/map_screen_test.dart` lines 23–37
**Apply to:** All three new test files
```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      someProvider.overrideWith((ref) async => mockInstance),
    ],
    child: const MaterialApp(home: WidgetUnderTest()),
  ),
);
await tester.pump();   // let FutureProvider emit
await tester.pump();   // let postFrameCallback fire
```

### `GameSessionNotifier.recordDrop` API (confirmed from Phase 2 source)
**Source:** `lib/features/game/game_session_notifier.dart` lines 166–189
**Apply to:** `MapScreen` drop handler
```dart
// Correct drop:
ref.read(gameSessionProvider.notifier).recordDrop(postal, isCorrect: true);
// Incorrect drop:
ref.read(gameSessionProvider.notifier).recordDrop(postal, isCorrect: false);
```
**CRITICAL:** The CONTEXT.md uses `placeState()` — this name does NOT exist. The Phase 2 implementation uses `recordDrop(postal, isCorrect: bool)`. The planner must use `recordDrop`.

### `shouldRepaint` new-Set trigger
**Source:** Flags map_screen.dart line 374; confirmed by RESEARCH.md discretion notes
**Apply to:** `MapScreen._advanceToNextPostal()`
```dart
// Spread into new Set so UsaMapPainter.shouldRepaint receives distinct
// object references and correctly triggers a repaint.
_matchedPostals = {..._matchedPostals, _currentPostal};
```

---

## No Analog Found

All files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:**
- `C:\code\Claude\StateTheStates\lib\` (all Dart files — 27 files)
- `C:\code\Claude\StateTheStates\test\` (all Dart files — 14 files)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart`
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\flag_tray.dart`
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_hud.dart`
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart`
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\home_screen.dart`

**Files scanned:** 27 (StateTheStates) + 5 (Flags analogs) = 32
**Pattern extraction date:** 2026-06-01
