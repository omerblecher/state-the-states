import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/state_data_service.dart';
import '../../features/game/game_mode.dart';
import 'usa_map_painter.dart';

/// Production MapScreen — ConsumerStatefulWidget with InteractiveViewer,
/// TransformationController, zoom buttons, and Phase 4 handoff constructor.
///
/// Replaces the Phase 1 ConsumerWidget stub. The /play route continues to call
/// `const MapScreen()` unchanged — default parameters are backward-compatible.
///
/// Key design decisions (see 03-RESEARCH.md):
/// - D-12: AnimatedBuilder wraps ONLY the CustomPaint subtree, not the whole Scaffold.
/// - D-11: _zoom(1.5) / _zoom(1/1.5) for zoom-in / zoom-out FABs.
/// - D-09: matchedPostals, showLabels, mode constructor params expose Phase 4 handoff.
/// - Pitfall 1: _zoom() MUST set m.setEntry(2, 2, newScale) — keeps getMaxScaleOnAxis() in sync.
/// - Pitfall 2: _fitMapToScreen() in addPostFrameCallback, NOT in initState.
/// - Pitfall 3: viewBox height is 628.0 NOT 620.0.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    this.matchedPostals = const {},
    this.showLabels = false,
    this.mode,
  });

  final Set<String> matchedPostals;
  final bool showLabels;
  final GameMode? mode;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final TransformationController _controller;
  final GlobalKey _ivKey = GlobalKey();

  double _currentScale = 1.0;
  double _minScale = 0.08;
  double _maxScale = 4.0;
  bool _mapPaintReady = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(_onScaleChanged);
    // Pitfall 2: _fitMapToScreen() MUST be in addPostFrameCallback, never in initState.
    // Calling in initState gives a null RenderBox because the widget hasn't been laid out yet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToScreen());
  }

  @override
  void dispose() {
    _controller.removeListener(_onScaleChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onScaleChanged() {
    // Read entry(0,0) directly — getMaxScaleOnAxis() is equivalent when scale
    // is uniform, but entry(0,0) avoids the sqrt computation on every frame.
    final s = _controller.value.entry(0, 0);
    if ((s - _currentScale).abs() > 0.005) {
      setState(() => _currentScale = s);
    }
  }

  /// Fits the 1000×628 viewBox into the available screen area.
  ///
  /// Called once from addPostFrameCallback (Pitfall 2 guard). Sets entry(0,0),
  /// entry(1,1), and entry(2,2) (Pitfall 1 — all three diagonal entries must
  /// match so getMaxScaleOnAxis() returns the correct 2D scale).
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
      ..setEntry(2, 2, fitScale) // Pitfall 1: all three diagonal entries must be set
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    _controller.value = m;
    if (mounted) setState(() => _currentScale = fitScale);
  }

  /// Zoom by [factor] anchored on the viewport centre.
  ///
  /// Production version: entry(2,2) IS set (Pitfall 1). Without this,
  /// getMaxScaleOnAxis() returns the stale Z-axis default (1.0) after the
  /// first zoom and subsequent _zoom() calls compute the wrong actualFactor,
  /// causing a wild scale jump.
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
    // Pitfall 1: entry(2,2) must stay in sync with entry(0,0)/(1,1) so
    // getMaxScaleOnAxis() returns the correct 2D scale.
    m.setEntry(2, 2, newScale);
    // Anchor zoom on viewport centre so the map doesn't drift off-screen.
    m.setEntry(0, 3, cx + (tx - cx) * actualFactor);
    m.setEntry(1, 3, cy + (ty - cy) * actualFactor);
    _controller.value = m;
  }

  void _zoomIn() => _zoom(1.5);
  void _zoomOut() => _zoom(1 / 1.5);

  /// Converts a global pointer offset to scene (InteractiveViewer child) coordinates.
  /// Returns null if the viewer box is not yet laid out.
  Offset? _toSceneFromGlobal(Offset globalOffset) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _controller.toScene(box.globalToLocal(globalOffset));
  }

  @override
  Widget build(BuildContext context) {
    // Silence unused-variable lint for _toSceneFromGlobal and kDebugMode;
    // both are used in Phase 4. kDebugMode import kept for parity with Flags port.
    assert(() {
      _toSceneFromGlobal; // referenced in Phase 4 DragTarget
      kDebugMode;
      return true;
    }());

    return Scaffold(
      body: ref.watch(stateDataProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load map: $e')),
        data: (mapData) => _buildMapStack(mapData.states, mapData.insetFrameRects),
      ),
    );
  }

  Widget _buildMapStack(
    List<dynamic> states,
    List<Rect> insetFrameRects,
  ) {
    // Reveal the map after the first frame is painted — before that the canvas
    // is at 1:1 scale and _fitMapToScreen hasn't run yet.
    if (!_mapPaintReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _mapPaintReady = true);
      });
    }

    return ColoredBox(
      color: const Color(0xFFA8D5E8), // ocean colour fills letterbox area
      child: Stack(
        children: [
          // InteractiveViewer — constrained:false allows the 1000×628 canvas to
          // exceed the viewport bounds for pan/zoom. The key is used in
          // _fitMapToScreen and _zoom to obtain the RenderBox size.
          InteractiveViewer(
            key: _ivKey,
            transformationController: _controller,
            constrained: false,
            minScale: _minScale,
            maxScale: _maxScale,
            child: SizedBox(
              width: 1000,
              height: 628,
              // D-12: AnimatedBuilder wraps ONLY the CustomPaint subtree, not
              // the whole Scaffold. This avoids rebuilding the entire widget
              // tree on every controller notification.
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => CustomPaint(
                  isComplex: true,
                  size: const Size(1000, 628),
                  painter: UsaMapPainter(
                    states: states.cast(),
                    matchedPostals: widget.matchedPostals,
                    insetFrameRects: insetFrameRects,
                    showLabels: widget.showLabels,
                    mode: widget.mode,
                    // Passes current scale so UsaMapPainter can keep border
                    // widths at ~1 screen pixel regardless of zoom (D-13).
                    viewScale: _controller.value.getMaxScaleOnAxis(),
                  ),
                ),
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
    );
  }
}
