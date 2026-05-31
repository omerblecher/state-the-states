import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/state_data_service.dart';
import 'hit_detection.dart';

// 6 named regions for Criterion 1 validation (TX, CA, FL, NY + insets AK, HI)
const _regionPostals = ['TX', 'CA', 'FL', 'NY', 'AK', 'HI'];

// Distinct colors for visual region identification during manual testing
const _regionColors = [
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
];

/// Dev-only spike screen for Criterion 1 coordinate-transform validation.
///
/// Renders 6 named DragTarget regions using real state bounding boxes
/// (TX, CA, FL, NY from mainland; AK and HI from their inset canvas positions).
/// Drag the postal-code chips onto their colored regions at 1×, 2×, and 4× zoom
/// — the status bar must show the correct postal code for all 18 drops.
///
/// This screen is only reachable in debug builds via the /spike route.
/// See RESEARCH.md Criterion 1 for the manual verification protocol.
class SpikeMapScreen extends ConsumerStatefulWidget {
  const SpikeMapScreen({super.key});

  @override
  ConsumerState<SpikeMapScreen> createState() => _SpikeMapScreenState();
}

class _SpikeMapScreenState extends ConsumerState<SpikeMapScreen> {
  late final TransformationController _controller;
  final GlobalKey _ivKey = GlobalKey();

  double _minScale = 0.08;
  double _maxScale = 10.0;

  String _lastHit = '—';
  Offset _lastScene = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    // Pitfall 2: _fitMapToScreen MUST be in addPostFrameCallback, never in initState.
    // Calling in initState gives a null RenderBox because the widget is not laid out yet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToScreen());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fits the 1000×628 viewBox into the available screen area.
  ///
  /// Spike uses a wider maxScale (fitScale * 10.0) so manual testers can zoom
  /// further than the production 4.0× range. Called once from postFrameCallback.
  void _fitMapToScreen() {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    const mapW = 1000.0;
    const mapH = 628.0; // Pitfall 3: 628 NOT 620
    final fitScale =
        math.min(box.size.width / mapW, box.size.height / mapH).clamp(0.08, 1.0);
    _minScale = fitScale;
    _maxScale = fitScale * 10.0; // Wider range for manual spike testing
    final tx = (box.size.width - mapW * fitScale) / 2;
    final ty = (box.size.height - mapH * fitScale) / 2;
    final m = Matrix4.identity()
      ..setEntry(0, 0, fitScale)
      ..setEntry(1, 1, fitScale)
      ..setEntry(2, 2, fitScale) // Pitfall 1: all three diagonal entries must be set
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    _controller.value = m;
    if (mounted) setState(() {});
  }

  /// Zoom by [factor] anchored on the viewport centre.
  ///
  /// PRODUCTION version: entry(2,2) IS set — Pitfall 1 guard.
  /// Without this, getMaxScaleOnAxis() returns the stale Z-axis default (1.0)
  /// after the first zoom, causing subsequent _zoom() calls to compute the wrong
  /// actualFactor and produce a wild scale jump.
  // CRITICAL: setEntry(2,2) keeps getMaxScaleOnAxis() accurate — see RESEARCH.md Pitfall 1
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

  /// Converts a global pointer offset to scene (InteractiveViewer child) coordinates.
  ///
  /// Non-nullable bang is acceptable in this dev-only spike — a null context IS
  /// a test failure that must surface immediately, not be silently swallowed.
  ///
  /// Pitfall 6 guard: globalToLocal() MUST be applied BEFORE toScene().
  /// Passing raw global offset to toScene() gives wrong scene coordinates because
  /// toScene() expects a local (viewport-relative) offset, not a screen-absolute one.
  Offset _toSceneFromGlobal(Offset globalOffset) {
    final box = _ivKey.currentContext!.findRenderObject()! as RenderBox;
    return _controller.toScene(box.globalToLocal(globalOffset));
  }

  @override
  Widget build(BuildContext context) {
    // Secondary guard: SpikeMapScreen must never appear in release builds.
    // Primary guard is the kDebugMode check in app.dart route registration.
    assert(kDebugMode, 'SpikeMapScreen must not appear in release builds');

    return Scaffold(
      appBar: AppBar(title: const Text('Coordinate Transform Spike — Criterion 1')),
      body: ref.watch(stateDataProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load map: $e')),
        data: (mapData) {
          // Derive the 6 region states from real JSON bounding boxes.
          final regions = _regionPostals
              .map((p) => mapData.states.firstWhere(
                    (s) => s.postal == p,
                    orElse: () => throw StateError('[SpikeMapScreen] postal $p missing from map data'),
                  ))
              .toList();

          return Column(
            children: [
              // ----------------------------------------------------------------
              // Status bar — shows last hit, scene coordinates, and current zoom.
              // Read this during manual Criterion 1 validation.
              // ----------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('Hit: $_lastHit',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'Scene: (${_lastScene.dx.toStringAsFixed(1)}, ${_lastScene.dy.toStringAsFixed(1)})',
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => Text(
                        'Zoom: ${_controller.value.getMaxScaleOnAxis().toStringAsFixed(2)}x',
                      ),
                    ),
                  ],
                ),
              ),
              // ----------------------------------------------------------------
              // Draggable chip row — one chip per postal code for manual testing.
              // ----------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final postal in _regionPostals)
                      Draggable<String>(
                        data: postal,
                        feedback: Material(
                          child: Chip(label: Text(postal)),
                        ),
                        child: Chip(label: Text(postal)),
                      ),
                  ],
                ),
              ),
              // ----------------------------------------------------------------
              // Map viewer — 1000×628 canvas with 6 named DragTarget regions
              // and an outer catch-all DragTarget for coordinate validation.
              // ----------------------------------------------------------------
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
                        child: Stack(
                          children: [
                            // Ocean background
                            Container(
                              width: 1000,
                              height: 628,
                              color: const Color(0xFFA8D5E8),
                            ),
                            // 6 named DragTarget regions — colored semi-transparent
                            // boxes positioned at real state bounding boxes.
                            for (int i = 0; i < regions.length; i++)
                              Positioned.fromRect(
                                rect: regions[i].boundingBox.rect,
                                child: DragTarget<String>(
                                  builder: (ctx, candidateData, rejectedData) => Container(
                                    color: _regionColors[i].withValues(alpha: 0.4),
                                    child: Center(
                                      child: Text(
                                        regions[i].postal,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Outer full-size catch-all DragTarget — validates
                            // coordinate transform accuracy via stateHitTest().
                            Positioned.fill(
                              child: DragTarget<String>(
                                onAcceptWithDetails: (details) {
                                  final scene =
                                      _toSceneFromGlobal(details.offset);
                                  final hit = stateHitTest(
                                    scene,
                                    mapData.states,
                                    scale: _controller.value
                                        .getMaxScaleOnAxis(),
                                  );
                                  setState(() {
                                    _lastHit = hit ?? 'miss';
                                    _lastScene = scene;
                                  });
                                  debugPrint(
                                    '[SpikeMapScreen] drop: scene=$scene '
                                    'hit=$hit '
                                    'zoom=${_controller.value.getMaxScaleOnAxis().toStringAsFixed(2)}x',
                                  );
                                },
                                builder: (ctx, candidateData, rejectedData) =>
                                    const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Zoom FABs — outside InteractiveViewer so they stay fixed.
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'spike_zoom_in',
                            onPressed: () => _zoom(1.5),
                            tooltip: 'Zoom in',
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'spike_zoom_out',
                            onPressed: () => _zoom(1 / 1.5),
                            tooltip: 'Zoom out',
                            child: const Icon(Icons.remove),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
