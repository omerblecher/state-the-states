import 'dart:math' show sqrt, pi;
import 'dart:ui' show Offset, Rect;

import '../../core/models/state_data.dart';

// Minimum tap target expressed in logical screen pixels.
// At any zoom level, every state is expanded so its on-screen diagonal
// reaches at least this many pixels — making it reliably hittable.
const double _kMinScreenDiagonal = 40.0;

// Minimum on-screen bounding-box area in logical pixels (ACCS-03).
// Any state whose on-screen bbox area falls below this threshold receives
// a centroid-based circular expansion guaranteeing a physical 48dp tap target.
// Value: 48 × 48 = 2304 logical pixels².
const double _kMinScreenArea = 2304.0;

/// Returns the postal code of the state that the [scenePoint] falls in,
/// or `null` if no state matches.
///
/// [scale] is the current InteractiveViewer scale (scene→screen factor).
///
/// Algorithm:
/// 1. Exact-path candidates: states whose SVG path contains the point.
/// 2. Bbox-expansion candidates: states whose scale-aware expanded bbox
///    contains the point (catches drops near small states).
/// 3. Fallback: expanded bbox for ALL states (catches ocean drops near coasts).
/// 4. Tiebreaker: closest *effective centroid* to the drop point.
///    — For candidates with an exact path match, the effective centroid is the
///      bbox centre of the MATCHING POLYGON, not the state centroid.  This
///      correctly handles multi-polygon states (e.g. Hawaii: state centroid is
///      on a different island than where the user dropped).
///    — For bbox-only candidates (small states), the state centroid is used.
String? stateHitTest(Offset scenePoint, List<StateData> states,
    {double scale = 1.0}) {
  final minSceneDiag = _kMinScreenDiagonal / scale;

  // 1 & 2. Collect candidates from exact path OR expanded bbox.
  final candidates = states
      .where((s) => _primaryContains(s, scenePoint, minSceneDiag, scale: scale))
      .toList();

  // 3. Fallback to expanded bbox for all states when nothing hit above.
  final pool = candidates.isNotEmpty
      ? candidates
      : states
          .where((s) => _expandedBbox(s, minSceneDiag, scale: scale).contains(scenePoint))
          .toList();

  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.postal;

  // 4. Tiebreaker: closest effective centroid wins.
  pool.sort((a, b) {
    final aDist =
        (_effectiveCentroid(a, scenePoint) - scenePoint).distanceSquared;
    final bDist =
        (_effectiveCentroid(b, scenePoint) - scenePoint).distanceSquared;
    return aDist.compareTo(bDist);
  });

  return pool.first.postal;
}

/// For states that have an exact path containing [point], returns the
/// centre of that polygon's bounding box.  This is a much better proxy for
/// "which state did the user intend" than the state-level centroid when
/// the state has non-contiguous territories.
/// Falls back to [state.centroid] when no path contains the point (i.e.
/// the candidate was added via expanded-bbox expansion).
Offset _effectiveCentroid(StateData state, Offset point) {
  for (final path in state.paths) {
    if (path.contains(point)) {
      final polyCenter = path.getBounds().center;
      // Prefer the polygon bbox-center only when it's closer to the drop point
      // than the state centroid.  This keeps the multi-polygon advantage
      // while fixing cases where a large single-polygon's bbox center is far
      // from the intended target.
      final polyDist = (polyCenter - point).distanceSquared;
      final centDist = (state.centroid - point).distanceSquared;
      return polyDist < centDist ? polyCenter : state.centroid;
    }
  }
  return state.centroid;
}

bool _primaryContains(StateData state, Offset point, double minSceneDiag, {double scale = 1.0}) {
  if (state.paths.any((p) => p.contains(point))) return true;
  return _expandedBbox(state, minSceneDiag, scale: scale).contains(point);
}

Rect _expandedBbox(StateData state, double minSceneDiag, {double scale = 1.0}) {
  final rect = state.boundingBox.rect;

  // Viewport-area threshold (VIS-02 / ACCS-03): if on-screen bbox area is
  // smaller than a 48×48dp square, guarantee a circular expansion of that
  // minimum area regardless of shape or diagonal.
  final screenArea = rect.width * rect.height * scale * scale;
  if (screenArea < _kMinScreenArea) {
    final expansionRadius = sqrt(_kMinScreenArea / pi) / scale;
    return Rect.fromCenter(
      center: state.centroid,
      width: expansionRadius * 2,
      height: expansionRadius * 2,
    );
  }

  final diagonal = sqrt(rect.width * rect.width + rect.height * rect.height);
  if (diagonal < 1e-6) {
    // Guard for degenerate edge case (geometry with near-zero extent).
    return Rect.fromCenter(
      center: state.centroid,
      width: minSceneDiag,
      height: minSceneDiag,
    );
  }
  // US states always have real geometry (isDegenerate branch is not needed).
  if (diagonal >= minSceneDiag) return rect;
  final scaleFactor = minSceneDiag / diagonal;
  return Rect.fromCenter(
    center: state.centroid,
    width: rect.width * scaleFactor,
    height: rect.height * scaleFactor,
  );
}
