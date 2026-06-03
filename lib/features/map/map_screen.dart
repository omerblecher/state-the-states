import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service_provider.dart';
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
  // Guards against duplicate startGame() calls across rebuilds (race fix).
  bool _gameStartRequested = false;

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

  // Phase 5: hint zoom animation
  late final AnimationController _hintZoomController;
  Animation<Matrix4>? _hintZoomAnimation;
  String? _hintPostal; // non-null during 3s glow window (D-H3)
  Timer? _hintGlowTimer;

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
    // Phase 5: hint zoom AnimationController (400ms, RESEARCH.md Pattern 4)
    _hintZoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _hintZoomController.addListener(_onHintZoomTick);
    // Pitfall 2: _fitMapToScreen() MUST be in addPostFrameCallback, never in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToScreen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _controller.removeListener(_onScaleChanged);
    _activeOverlay?.remove(); // Pitfall 4: always remove overlay on dispose
    _activeOverlay = null;
    _hintGlowTimer?.cancel(); // RESEARCH.md Pitfall 4 — MUST cancel before dispose (T-05-10)
    _hintZoomController.removeListener(_onHintZoomTick);
    _hintZoomController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScaleChanged() {
    final s = _controller.value.entry(0, 0);
    if ((s - _currentScale).abs() > 0.005) {
      setState(() => _currentScale = s);
    }
  }

  // ---------- Hint zoom animation (Phase 5) ------------------------------------

  /// Drives TransformationController from the hint zoom animation on each tick.
  void _onHintZoomTick() {
    if (_hintZoomAnimation != null && mounted) {
      _controller.value = _hintZoomAnimation!.value;
    }
  }

  /// Computes the Matrix4 that centers [sceneCentroid] on screen at an adaptive zoom.
  ///
  /// Template: _fitMapToScreen() matrix construction — MUST include setEntry(2,2)
  /// (RESEARCH.md Pitfall 1; T-05-12). Returns current matrix if context unavailable.
  /// [target] is used to pick zoom level: tiny states (area<400) get 6×, small
  /// states (area<1500) get 4×, everything else gets 2.5×.
  Matrix4 _computeHintMatrix(Offset sceneCentroid, [StateData? target]) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return _controller.value; // T-05-11: null-guard prevents crash
    double targetZoom = 2.5;
    if (target != null) {
      final area = target.boundingBox.rect.width * target.boundingBox.rect.height;
      if (area < 400) {
        targetZoom = 6.0;
      } else if (area < 1500) {
        targetZoom = 4.0;
      }
    }
    final double newScale = (_minScale * targetZoom).clamp(_minScale, _maxScale);
    final double tx = box.size.width / 2 - sceneCentroid.dx * newScale;
    final double ty = box.size.height / 2 - sceneCentroid.dy * newScale;
    return Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(2, 2, newScale) // Pitfall 1: NEVER omit — InteractiveViewer z-scale
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

  /// Triggers the zoom-to-target animation and 3-second glow for the current postal.
  ///
  /// Shared by both the direct hint path (_onHintPressed) and the rewarded-ad path
  /// (_showRewardedHintDialog) so that earning hints via ad also zooms to the target.
  void _applyHintAnimation() {
    final target = _stateIndex[_currentPostal];
    if (target == null) return;

    setState(() => _hintPostal = _currentPostal);

    final endMatrix = _computeHintMatrix(target.centroid, target);
    _hintZoomAnimation = Matrix4Tween(
      begin: _controller.value.clone(),
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _hintZoomController,
      curve: Curves.easeInOut, // Claude's discretion (RESEARCH.md §Pattern 4)
    ));
    _hintZoomController
      ..reset()
      ..forward();

    // 3-second glow window — clear hintPostal after glow (D-H2: viewport stays zoomed)
    _hintGlowTimer?.cancel();
    _hintGlowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hintPostal = null);
    });
  }

  /// Called when the hint button is tapped.
  ///
  /// Forks on hintsRemaining:
  /// - > 0: uses hint immediately (existing glow animation path).
  /// - == 0: shows rewarded-ad dialog (_showRewardedHintDialog).
  void _onHintPressed() {
    final session = ref.read(gameSessionProvider).value;
    if (session?.hintsRemaining == 0) {
      _showRewardedHintDialog();
      return;
    }

    final consumed = ref.read(gameSessionProvider.notifier).useHint();
    if (!consumed) return;
    _applyHintAnimation();
  }

  /// Shows an AlertDialog prompting the user to watch a rewarded ad for 2 more hints.
  ///
  /// T-08-04-01: refillHints/useHint are only called on earned == true.
  /// D-09: Snackbar copy is "No ad available right now — try again later."
  Future<void> _showRewardedHintDialog() async {
    final watch = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Watch an ad for 2 more hints?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );
    if (watch != true) return;
    final earned = await ref.read(adServiceProvider).showRewardedAd();
    if (!mounted) return;
    if (earned) {
      ref.read(gameSessionProvider.notifier).refillHints();
      final consumed = ref.read(gameSessionProvider.notifier).useHint();
      if (consumed) _applyHintAnimation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ad available right now — try again later.'),
        ),
      );
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
    _maxScale = fitScale * 12.0;
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
    // _fitMapToScreen only; startGame is deferred to _maybeStartGame so that
    // the race between stateDataProvider and gameSessionProvider is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToScreen());
  }

  /// Starts a fresh game as soon as both (a) state data is loaded
  /// (_sequenceInitialized) and (b) the session is in idle or completed phase.
  ///
  /// Called on every build pass from _buildMapStack.  The _gameStartRequested
  /// flag prevents duplicate calls when the phase transitions through states.
  void _maybeStartGame(GameSession? session) {
    if (!_sequenceInitialized || _gameStartRequested) return;
    final phase = session?.phase;
    // idle   → app just launched or navigated from home for the first time.
    // completed → user finished a game and came back via the router for another.
    // paused → restoreGame() was called; do NOT override it with startGame().
    if (phase != GamePhase.idle && phase != GamePhase.completed) return;
    _gameStartRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(gameSessionProvider.notifier).startGame(widget.mode);
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

    final rawScene = _toSceneFromGlobal(details.offset + StateTray.kPinAnchor);
    if (rawScene == null) return;

    final scale = _controller.value.getMaxScaleOnAxis();
    final hitPostal = stateHitTest(rawScene, _states, scale: scale);
    bool isCorrect = hitPostal == _currentPostal;

    // Forgiving fallback for tiny states (RI, DE, CT, etc.): if the drop missed
    // all polygons but landed inside the target's bounding box, accept as correct.
    if (!isCorrect && hitPostal == null) {
      final targetRect = _stateIndex[_currentPostal]?.boundingBox.rect;
      if (targetRect != null && targetRect.contains(rawScene)) {
        isCorrect = true;
      }
    }

    if (isCorrect) {
      ref.read(gameSessionProvider.notifier).recordDrop(hitPostal ?? _currentPostal, isCorrect: true);
      HapticFeedback.lightImpact();
      ref.read(audioServiceProvider).playCorrect();
      // Fly-to-centroid animation; advances sequence in whenComplete callback.
      _animateCorrectDrop(_currentPostal);
    } else {
      ref.read(gameSessionProvider.notifier).recordDrop(
          _currentPostal, isCorrect: false);
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
                      onPressed: () {
                        ref.read(gameSessionProvider.notifier).endGame();
                        context.go('/');
                      },
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
                _buildMapStack(mapData.states, session);
            return Stack(
              children: [
                mapWidget,
                // Countdown overlay — rendered on top of map during countdown phase
                if (session?.phase == GamePhase.countdown)
                  Positioned.fill(
                    child: _buildCountdownOverlay(
                        session?.countdownSecondsRemaining ?? 5),
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
    GameSession? session,
  ) {
    // Store states for _handleDrop; call _startSequence once, then try startGame.
    _states = states;
    _startSequence(states);
    _maybeStartGame(session);

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
      case GameMode.speedTyping:
        // speedTyping mode never reaches MapScreen in production;
        // uses Grand Master settings (no labels, no name) for compilability.
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
                              showLabels: showLabels,
                              mode: widget.mode,
                              viewScale: _controller.value.getMaxScaleOnAxis(),
                              hintPostal: _hintPostal, // Phase 5: yellow-green glow
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
                    onHintPressed: session?.phase == GamePhase.playing ? _onHintPressed : null,
                    stateData: _stateIndex[_currentPostal],
                  ),
          ),
        ],
      ),
    );
  }

}
