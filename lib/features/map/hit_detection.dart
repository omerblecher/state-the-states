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

// Per-island touch radius for Hawaii (dp). Applied independently to every island
// polygon rather than to the state centroid, because the island chain spans
// ~130 scene units — a single-centroid circle misses Oahu and Maui entirely.
// 24dp is half the 48dp minimum touch target, giving a 48dp-diameter hit zone
// centered on each island's bounding-box centre.
const double _kHiIslandTouchRadiusDp = 24.0;

/// Returns the postal code of the state that the [scenePoint] falls in,
/// or `null` if no state matches.
///
/// [scale] is the current InteractiveViewer scale (scene→screen factor).
///
/// Three-tier lookup — each tier is only consulted when the one above is empty:
/// 1. Exact-path: states whose SVG polygon contains the point.
/// 2. Bbox-expansion: states whose scale-aware expanded bbox contains the point
///    (accessibility guarantee for small states — ACCS-03).
/// 3. Tiebreaker: closest effective centroid (handles border overlaps).
///
/// Exact-path candidates are kept strictly separate from bbox candidates so
/// that a nearby state's bbox can never outrank a state whose polygon actually
/// contains the drop point (e.g. OK bbox overlapping TX panhandle territory).
String? stateHitTest(Offset scenePoint, List<StateData> states,
    {double scale = 1.0}) {
  final minSceneDiag = _kMinScreenDiagonal / scale;

  // 1. Exact-path candidates: polygon contains the drop point.
  final exactHits = states
      .where((s) => s.paths.any((p) => p.contains(scenePoint)))
      .toList();

  // 2. Bbox-expansion candidates: only consulted when no exact hit exists.
  //    Ensures small states (RI, DC) remain hittable at low zoom and catches
  //    drops that land just outside a coastline polygon.
  //    Hawaii uses per-island radial expansion instead of the state centroid,
  //    because the island chain spans ~130 scene units and a single-centroid
  //    circle misses Oahu / Maui when the Big Island is the representative point.
  final pool = exactHits.isNotEmpty
      ? exactHits
      : states
          .where((s) {
            if (s.insetGroup == InsetGroup.hawaii) {
              return _hawaiiRadialHit(s, scenePoint, scale);
            }
            return _expandedBbox(s, minSceneDiag, scale: scale).contains(scenePoint);
          })
          .toList();

  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.postal;

  // 3. Tiebreaker: closest effective centroid wins.
  //    Needed when two states share a border and both paths contain the point.
  pool.sort((a, b) {
    final aDist =
        (_effectiveCentroid(a, scenePoint) - scenePoint).distanceSquared;
    final bDist =
        (_effectiveCentroid(b, scenePoint) - scenePoint).distanceSquared;
    return aDist.compareTo(bDist);
  });

  return pool.first.postal;
}

/// Returns true if [point] lands within [_kHiIslandTouchRadiusDp] dp of the
/// bounding-box centre of **any** individual island polygon in [state].
///
/// Used exclusively for Hawaii (insetGroup == InsetGroup.hawaii).  The standard
/// [_expandedBbox] collapses the whole island chain to one centroid (the Big
/// Island) — this function checks each island independently so that drops near
/// Oahu or Maui also resolve to HI.
bool _hawaiiRadialHit(StateData state, Offset point, double scale) {
  final radiusScene = _kHiIslandTouchRadiusDp / scale;
  final rr = radiusScene * radiusScene;
  for (final path in state.paths) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) continue;
    final dx = point.dx - bounds.center.dx;
    final dy = point.dy - bounds.center.dy;
    if (dx * dx + dy * dy <= rr) return true;
  }
  return false;
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
