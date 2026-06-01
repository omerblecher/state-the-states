import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service_provider.dart';
import '../../core/data/high_score_repository.dart';
import '../../core/data/state_data_service.dart';
import '../../core/models/state_data.dart';
import '../../features/game/game_hud.dart';
import '../../features/game/game_lifecycle_observer.dart';
import '../../features/game/game_mode.dart';
import '../../features/game/game_phase.dart';
import '../../features/game/game_session.dart';
import '../../features/game/game_session_notifier.dart';
import '../../features/game/state_tray.dart';
import 'hit_detection.dart';
import 'usa_map_painter.dart';

/// Production MapScreen — ConsumerStatefulWidget with InteractiveViewer,
/// TransformationController, zoom buttons, and Phase 4 game loop.
///
/// Phase 4 additions (Plan 02):
/// - TickerProviderStateMixin for multiple AnimationControllers
/// - GameLifecycleObserver mount/unmount (D-08)
/// - _startSequence: shuffled 50-state postal sequence, DC filtered
/// - _handleDrop: DragTarget wiring, stateHitTest, correct/incorrect paths
/// - PopScope back-button guard with pause overlay
/// - Countdown overlay (3-2-1-GO!)
/// - Mode→showLabels/showName matrix
///
/// Key design decisions (see 03-RESEARCH.md / 04-RESEARCH.md):
/// - D-12: AnimatedBuilder wraps ONLY the CustomPaint subtree, not the whole Scaffold.
/// - D-11: _zoom(1.5) / _zoom(1/1.5) for zoom-in / zoom-out FABs.
/// - D-09: matchedPostals, showLabels, mode constructor params expose Phase 4 handoff.
/// - Pitfall 1: _zoom() MUST set m.setEntry(2, 2, newScale).
/// - Pitfall 2: _fitMapToScreen() in addPostFrameCallback, NOT in initState.
/// - Pitfall 3: viewBox height is 628.0 NOT 620.0.
/// - Pitfall 4: _activeOverlay?.remove() in dispose() before _controller.dispose().
/// - Risk 3: _trayKey and _trayCardKey re-created on each advance (AnimatedSwitcher trigger).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    this.matchedPostals = const {},
    this.showLabels = false,
    this.mode = GameMode.learn,
  });

  final Set<String> matchedPostals;
  final bool showLabels;
  final GameMode mode;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  late final TransformationController _controller;
  final GlobalKey _ivKey = GlobalKey();

  double _currentScale = 1.0;
  double _minScale = 0.08;
  double _maxScale = 4.0;

  // ---------- Sequence state --------------------------------------------------

  String _currentPostal = '';
  List<String> _remainingPostals = [];
  Set<String> _matchedPostals = {};
  bool _sequenceInitialized = false;

  // Tray keys — re-created on each advance (AnimatedSwitcher trigger, Risk 3)
  // _trayKey typed as GlobalKey<StateTrayState> so MapScreen can call triggerBounce().
  GlobalKey<StateTrayState> _trayKey = GlobalKey<StateTrayState>();
  GlobalKey _trayCardKey = GlobalKey();

  // Overlay animation — ref held for dispose() cleanup (Pitfall 4)
  OverlayEntry? _activeOverlay;

  // Pause overlay visibility
  bool _isPauseOverlayVisible = false;

  // Mute state
  bool _isMuted = false;

  // State index: postal → StateData (for centroid lookups in Plan 04 fly animation)
  Map<String, StateData> _stateIndex = {};

  // States list — stored from mapData for _handleDrop
  List<StateData> _states = [];

  // Lifecycle observer (D-08)
  late final GameLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    // D-08: mount lifecycle observer immediately
    _lifecycleObserver = GameLifecycleObserver(
      ref.read(gameSessionProvider.notifier),
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _controller = TransformationController();
    _controller.addListener(_onScaleChanged);
    // Pitfall 2: _fitMapToScreen() MUST be in addPostFrameCallback, never in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToScreen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _controller.removeListener(_onScaleChanged);
    _activeOverlay?.remove(); // Pitfall 4: always remove overlay on dispose
    _activeOverlay = null;
    _controller.dispose();
    super.dispose();
  }

  void _onScaleChanged() {
    final s = _controller.value.entry(0, 0);
    if ((s - _currentScale).abs() > 0.005) {
      setState(() => _currentScale = s);
    }
  }

  /// Fits the 1000×628 viewBox into the available screen area.
  void _fitMapToScreen() {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    const mapW = 1000.0;
    const mapH = 628.0; // Pitfall 3: 628 NOT 620
    final fitScale =
        math.min(box.size.width / mapW, box.size.height / mapH).clamp(0.08, 1.0);
    _minScale = fitScale;
    _maxScale = fitScale * 4.0;
    final tx = (box.size.width - mapW * fitScale) / 2;
    final ty = (box.size.height - mapH * fitScale) / 2;
    final m = Matrix4.identity()
      ..setEntry(0, 0, fitScale)
      ..setEntry(1, 1, fitScale)
      ..setEntry(2, 2, fitScale) // Pitfall 1
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    _controller.value = m;
    if (mounted) setState(() => _currentScale = fitScale);
  }

  void _zoom(double factor) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final double cx = box.size.width / 2;
    final double cy = box.size.height / 2;

    final Matrix4 m = _controller.value.clone();
    final double currentScale = m.getMaxScaleOnAxis();
    final double newScale = (currentScale * factor).clamp(_minScale, _maxScale);
    final double actualFactor = newScale / currentScale;
    if ((actualFactor - 1.0).abs() < 1e-6) return;

    final double tx = m.entry(0, 3);
    final double ty = m.entry(1, 3);
    m.setEntry(0, 0, newScale);
    m.setEntry(1, 1, newScale);
    m.setEntry(2, 2, newScale); // Pitfall 1
    m.setEntry(0, 3, cx + (tx - cx) * actualFactor);
    m.setEntry(1, 3, cy + (ty - cy) * actualFactor);
    _controller.value = m;
  }

  void _zoomIn() => _zoom(1.5);
  void _zoomOut() => _zoom(1 / 1.5);

  /// Converts a global pointer offset to scene (InteractiveViewer child) coordinates.
  Offset? _toSceneFromGlobal(Offset globalOffset) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _controller.toScene(box.globalToLocal(globalOffset));
  }

  // ---------- Sequence initialization -----------------------------------------

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
    _stateIndex = {for (final s in states) s.postal: s};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToScreen();
      ref.read(gameSessionProvider.notifier).startGame(widget.mode);
    });
  }

  String _stateNameFor(String postal) => _stateIndex[postal]?.name ?? postal;

  // ---------- Pause / mute / back-button --------------------------------------

  void _onPausePressed() {
    ref.read(gameSessionProvider.notifier).pauseGame();
    setState(() => _isPauseOverlayVisible = true);
  }

  void _dismissPauseOverlay() {
    ref.read(gameSessionProvider.notifier).resumeGame();
    setState(() => _isPauseOverlayVisible = false);
  }

  void _toggleMute() {
    try {
      ref.read(audioServiceProvider).setMuted(!_isMuted);
    } catch (_) {
      // StubAudioService may not implement setMuted — silence it.
    }
    setState(() => _isMuted = !_isMuted);
  }

  void _onBackPressed() {
    final session = ref.read(gameSessionProvider).value;
    if (session == null) {
      context.go('/');
      return;
    }
    if (session.phase == GamePhase.playing) {
      ref.read(gameSessionProvider.notifier).pauseGame();
      setState(() => _isPauseOverlayVisible = true);
    } else if (session.phase == GamePhase.paused) {
      setState(() => _isPauseOverlayVisible = true);
    } else {
      context.go('/');
    }
  }

  // ---------- Sequence advance ------------------------------------------------

  Future<void> _advanceToNextPostal() async {
    if (_remainingPostals.isEmpty) return;
    setState(() {
      // Spread into new Set so UsaMapPainter.shouldRepaint receives distinct
      // object references and correctly triggers a repaint (shouldRepaint pattern).
      _matchedPostals = {..._matchedPostals, _currentPostal};
      _remainingPostals.removeAt(0);
    });
    if (_remainingPostals.isEmpty) {
      // Game complete — read score before completeGame() mutates state.
      final sessionBeforeComplete = ref.read(gameSessionProvider).value;
      if (sessionBeforeComplete == null) return;
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
        // Risk 3: re-create keys so AnimatedSwitcher correctly detects a new widget.
        _trayKey = GlobalKey<StateTrayState>();
        _trayCardKey = GlobalKey();
      });
    }
  }

  // ---------- Drop handler ----------------------------------------------------

  void _handleDrop(DragTargetDetails<String> details) {
    final session = ref.read(gameSessionProvider).value;
    if (session?.phase != GamePhase.playing) return; // Risk 5: phase guard
    if (_currentPostal.isEmpty) return; // Risk 4: uninitialized guard

    // StateTray.kPinAnchor = Offset(45, 70): tip of the draggable pin token.
    final rawScene = _toSceneFromGlobal(details.offset + const Offset(45, 70));
    if (rawScene == null) return;

    final scale = _controller.value.getMaxScaleOnAxis();
    final hitPostal = stateHitTest(rawScene, _states, scale: scale);
    final isCorrect = hitPostal == _currentPostal;

    if (isCorrect) {
      ref.read(gameSessionProvider.notifier).recordDrop(hitPostal!, isCorrect: true);
      HapticFeedback.lightImpact();
      ref.read(audioServiceProvider).playCorrect();
      // Fly-to-centroid animation; advances sequence in whenComplete callback.
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

  // ---------- Fly-to-centroid animation ----------------------------------------

  /// Converts a scene-coordinate centroid to a global screen offset.
  Offset _centroidToScreen(Offset sceneCentroid) {
    final matrix = _controller.value;
    final viewportLocal = MatrixUtils.transformPoint(matrix, sceneCentroid);
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(viewportLocal);
  }

  /// Simple token preview used in the fly-to-centroid overlay.
  Widget _buildTokenPreview(String postal) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 90,
        height: 60,
        child: Center(
          child: Text(
            postal,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  /// Animates the token card from the tray card position to the state centroid.
  ///
  /// Creates an OverlayEntry with a 500ms fly animation (position, scale, opacity).
  /// On completion: removes overlay, disposes controller, advances to next postal
  /// (with mounted guard — Risk 2).
  void _animateCorrectDrop(String postal) {
    final trayBox =
        _trayCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (trayBox == null) {
      _advanceToNextPostal();
      return;
    }
    final startOffset = trayBox.localToGlobal(Offset.zero);

    final state = _stateIndex[postal];
    if (state == null) {
      _advanceToNextPostal();
      return;
    }
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

    // Remove any previous overlay before inserting a new one (Pitfall 4).
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
        child: SizedBox(
          width: 90,
          height: 60,
          child: _buildTokenPreview(postal),
        ),
      ),
    );
    Overlay.of(context).insert(_activeOverlay!);

    animController.forward().whenComplete(() {
      _activeOverlay?.remove();
      _activeOverlay = null;
      animController.dispose();
      if (mounted) _advanceToNextPostal(); // Risk 2: mounted guard
    });
  }

  // ---------- Overlays --------------------------------------------------------

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

  Widget _buildPauseOverlay() {
    return GestureDetector(
      onTap: () {}, // consume taps
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _dismissPauseOverlay,
                      child: const Text('Resume'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _toggleMute,
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      label: Text(_isMuted ? 'Unmute' : 'Mute'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('End Game',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Silence unused-variable lint for kDebugMode; kept for parity with Flags port.
    assert(() {
      kDebugMode;
      return true;
    }());

    final sessionAsync = ref.watch(gameSessionProvider);
    final session = sessionAsync.value;
    final notifier = ref.read(gameSessionProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        body: ref.watch(stateDataProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load map: $e')),
          data: (mapData) {
            final mapWidget =
                _buildMapStack(mapData.states, mapData.insetFrameRects, session);
            return Stack(
              children: [
                mapWidget,
                // Countdown overlay — rendered on top of map during countdown phase
                if (session?.phase == GamePhase.countdown)
                  Positioned.fill(
                    child: _buildCountdownOverlay(notifier.countdownSecondsRemaining),
                  ),
                // Pause overlay — rendered when user pauses or presses back
                if (_isPauseOverlayVisible)
                  Positioned.fill(child: _buildPauseOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapStack(
    List<StateData> states,
    List<Rect> insetFrameRects,
    GameSession? session,
  ) {
    // Store states for _handleDrop; call _startSequence once.
    _states = states;
    _startSequence(states);

    // Mode → showLabels / showName matrix (per plan spec)
    final bool showLabels;
    final bool showName;
    switch (widget.mode) {
      case GameMode.learn:
        showLabels = true;
        showName = true;
      case GameMode.statesMaster:
        showLabels = false;
        showName = true;
      case GameMode.geographicalMaster:
        showLabels = true;
        showName = false;
      case GameMode.grandMaster:
        showLabels = false;
        showName = false;
    }

    return ColoredBox(
      color: const Color(0xFFA8D5E8), // ocean colour fills letterbox area
      child: Column(
        children: [
          // Row 1: Real GameHud — score, timer, progress bar, mute/pause
          GameHud(
            score: session?.score ?? 0,
            elapsed: session?.elapsed ?? Duration.zero,
            matchedCount: _matchedPostals.length,
            totalFlags: 50,
            onPause: _onPausePressed,
            isMuted: _isMuted,
            onMuteToggle: _toggleMute,
          ),
          // Row 2: Map area
          Expanded(
            child: Stack(
              children: [
                InteractiveViewer(
                  key: _ivKey,
                  transformationController: _controller,
                  constrained: false,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  child: SizedBox(
                    width: 1000,
                    height: 628,
                    // D-12: AnimatedBuilder wraps ONLY the CustomPaint subtree.
                    child: Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (_, child) => CustomPaint(
                            isComplex: true,
                            size: const Size(1000, 628),
                            painter: UsaMapPainter(
                              states: states,
                              matchedPostals: _matchedPostals,
                              insetFrameRects: insetFrameRects,
                              showLabels: showLabels,
                              mode: widget.mode,
                              viewScale: _controller.value.getMaxScaleOnAxis(),
                            ),
                          ),
                        ),
                        // DragTarget covers the full map canvas — last in stack
                        DragTarget<String>(
                          builder: (context2, candidate, rejected) =>
                              const SizedBox.expand(),
                          onWillAcceptWithDetails: (_) => true,
                          onAcceptWithDetails: _handleDrop,
                        ),
                      ],
                    ),
                  ),
                ),
                // Zoom FABs — outside InteractiveViewer so they stay fixed on screen.
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: _zoomIn,
                        tooltip: 'Zoom in',
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: _zoomOut,
                        tooltip: 'Zoom out',
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Row 3: Real StateTray in AnimatedSwitcher (FadeTransition only — Risk: SlideTransition moves hit-test area)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _currentPostal.isEmpty
                ? const SizedBox.shrink()
                : StateTray(
                    key: _trayKey,
                    postal: _currentPostal,
                    stateName: _stateNameFor(_currentPostal),
                    mode: widget.mode,
                    sequenceIndex: 50 - _remainingPostals.length,
                    cardKey: _trayCardKey,
                    showName: showName,
                    hintsRemaining: session?.hintsRemaining ?? 2,
                    onHintPressed: () {}, // Phase 5 wires hint zoom
                  ),
          ),
        ],
      ),
    );
  }

}
