# Phase 3: Map Render + Coordinate Transform Spike - Pattern Map

**Mapped:** 2026-05-31
**Files analyzed:** 10 (4 production files to replace/create/modify + 4 test files to create + 2 service files to extend)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/map/usa_map_painter.dart` | painter (CustomPainter) | transform | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\world_map_painter.dart` | exact (direct port) |
| `lib/features/map/map_screen.dart` | screen (ConsumerStatefulWidget) | request-response + event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` | exact (direct port, stripped) |
| `lib/features/map/spike_map_screen.dart` | screen (StatefulWidget, dev-only) | event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\spike_map_screen.dart` | exact (direct port, adapted) |
| `lib/features/map/hit_detection.dart` | utility (pure Dart) | transform | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\hit_detection.dart` | exact (direct port, minor rename) |
| `lib/app.dart` | config/routing | request-response | `lib/app.dart` (self, existing) + `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` lines 1029–1035 (`kDebugMode` guard) | role-match |
| `lib/core/data/state_data_service.dart` | service | CRUD | `lib/core/data/state_data_service.dart` (self, existing) | exact (extend) |
| `test/features/map/hit_detection_test.dart` | test (unit) | — | `test/core/models/state_data_test.dart` (JSON fixture pattern) | role-match |
| `test/features/map/usa_map_painter_test.dart` | test (widget smoke) | — | `test/core/data/state_data_service_test.dart` (binding init + provider) | role-match |
| `test/features/map/map_screen_test.dart` | test (widget) | — | `test/features/game/game_session_notifier_test.dart` (ProviderContainer override) | role-match |
| `test/features/map/spike_map_screen_test.dart` | test (widget) | — | `test/features/game/game_session_notifier_test.dart` (ProviderContainer override) | role-match |

---

## Pattern Assignments

### `lib/features/map/usa_map_painter.dart` (painter, transform)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\world_map_painter.dart`
**Action:** Replace the Phase 1 blank stub. Fill `paint()` body; add constructor parameters.

**Imports pattern** (analog lines 1–5):
```dart
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import '../../core/models/state_data.dart';
import '../../features/game/game_mode.dart';
```
Drop the `CountryData` import; add `state_data.dart` and `game_mode.dart`. No `flutter_svg` needed.

**Constructor / fields pattern** (analog lines 26–39, adapted per RESEARCH.md Code Examples):
```dart
const _palette = [
  Color(0xFF8DB87F), // soft green
  Color(0xFFD4B483), // tan
  Color(0xFFE8A055), // orange
  Color(0xFFE89090), // pink
  Color(0xFFA07EC8), // purple
  Color(0xFFE8D870), // yellow
];
const _matchedColor = Color(0xFFAAAAAA);
const _oceanColor   = Color(0xFFA8D5E8);
const _borderColor  = Color(0xFF555555);

class UsaMapPainter extends CustomPainter {
  const UsaMapPainter({
    required this.states,
    required this.matchedPostals,
    required this.insetFrameRects,   // List<Rect> from JSON insetFrames key
    this.showLabels = false,          // declared for Phase 4; draws nothing in Phase 3
    this.mode,
    this.viewScale = 1.0,
  });

  final List<StateData> states;
  final Set<String> matchedPostals;
  final List<Rect> insetFrameRects;
  final bool showLabels;
  final GameMode? mode;
  final double viewScale;
```

**shouldRepaint pattern** (analog lines 42–46, adapted per RESEARCH.md Pattern 7):
```dart
// Analog: world_map_painter.dart lines 42-46
@override
bool shouldRepaint(UsaMapPainter old) =>
    !setEquals(old.matchedPostals, matchedPostals) ||  // setEquals avoids reference-equality trap
    old.showLabels != showLabels ||
    old.mode != mode ||
    (old.viewScale - viewScale).abs() > 0.001;  // threshold avoids sub-pixel thrash
```
Note: `setEquals` from `package:flutter/foundation.dart` (already imported). Drop `!identical(old.countryNames, countryNames)` — `StateData.name` is bundled in the model.

**Core paint() pattern** (analog lines 49–120, stripped to two passes per RESEARCH.md Pattern 5):
```dart
// Analog: world_map_painter.dart _drawWorldCopy() lines 65-120
@override
void paint(Canvas canvas, Size size) {
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _oceanColor);

  final fillPaint = Paint()..style = PaintingStyle.fill;
  final borderPaint = Paint()
    ..style       = PaintingStyle.stroke
    ..color       = _borderColor
    ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);  // D-13

  // Pass 1: fills + borders (no isDegenerate branch — US states are never degenerate)
  for (int i = 0; i < states.length; i++) {
    final state = states[i];
    final isMatched = matchedPostals.contains(state.postal);  // isoCode → postal
    fillPaint.color = isMatched ? _matchedColor : _palette[i % _palette.length];
    for (final path in state.paths) {
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  // Pass 2: inset frame rectangles (D-04; rects come from JSON insetFrames key)
  final framePaint = Paint()
    ..style       = PaintingStyle.stroke
    ..color       = _borderColor
    ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);
  for (final frameRect in insetFrameRects) {
    canvas.drawRect(frameRect, framePaint);
  }
  // showLabels pass deferred to Phase 4 (MODE-01/03)
}
```

**What to drop from analog:**
- `_drawWorldCopy()` wrapper with double-canvas translate — US map is single canvas, no date-line wrap
- Pass 2 degenerate-dot rendering (`isDegenerate` branch + `drawCircle`) — US states have real geometry
- Label pass (`showLabels` block) — Phase 4 concern; parameter is declared but draws nothing

---

### `lib/features/map/map_screen.dart` (ConsumerStatefulWidget, request-response + event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart`
**Action:** Replace Phase 1 `ConsumerWidget` placeholder with `ConsumerStatefulWidget` + `InteractiveViewer` + `AnimatedBuilder`.

**Imports pattern** (analog lines 1–27, stripped to Phase 3 needs):
```dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/state_data_service.dart';
import '../../features/game/game_mode.dart';
import 'usa_map_painter.dart';
```
Drop ads, audio, l10n, flag_tray, game_session, highlight_painter — those are Phase 4+ concerns.

**Widget class + constructor pattern** (analog lines 32–47; adapted per D-09):
```dart
// Phase 1 ConsumerWidget → Phase 3 ConsumerStatefulWidget
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
```

**State class fields pattern** (analog lines 50–83, stripped):
```dart
class _MapScreenState extends ConsumerState<MapScreen> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _ivKey = GlobalKey();

  double _currentScale = 1.0;
  bool _mapPaintReady = false;

  // Fit-to-width computed at layout time (D-10)
  double minScale = 0.08;
  double maxScale = 4.0;  // 4x relative to fit-to-width, clamped after _fitMapToScreen
```

**initState + dispose pattern** (analog lines 109–144, stripped to controller lifecycle only):
```dart
// Analog: map_screen.dart lines 109-144 (stripped)
@override
void initState() {
  super.initState();
  _controller.addListener(_onScaleChanged);
}

void _onScaleChanged() {
  final s = _controller.value.entry(0, 0);
  if ((s - _currentScale).abs() > 0.005) {
    setState(() => _currentScale = s);
  }
}

@override
void dispose() {
  _controller.removeListener(_onScaleChanged);
  _controller.dispose();
  super.dispose();
}
```

**_fitMapToScreen() pattern** (analog lines 251–267; adapt mapW/mapH to 1000×628):
```dart
// Analog: map_screen.dart lines 251-267
// CRITICAL: call only inside WidgetsBinding.addPostFrameCallback — not in initState()
void _fitMapToScreen() {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  const mapW = 1000.0;  // actual JSON viewBox.width
  const mapH = 628.0;   // actual JSON viewBox.height — NOT 620 or 625
  final fitScale = math.min(box.size.width / mapW, box.size.height / mapH)
      .clamp(0.08, 1.0);
  minScale = fitScale;
  maxScale = fitScale * 4.0;  // D-10: max = 4x fit-to-width
  final tx = (box.size.width - mapW * fitScale) / 2;
  final ty = (box.size.height - mapH * fitScale) / 2;
  final m = Matrix4.identity()
    ..setEntry(0, 0, fitScale)
    ..setEntry(1, 1, fitScale)
    ..setEntry(2, 2, fitScale)  // CRITICAL: keep in sync with (0,0) and (1,1)
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
  _controller.value = m;
}
```

**_zoom() pattern — PRODUCTION VERSION** (analog lines 405–428; use this, NOT the spike version):
```dart
// Analog: map_screen.dart lines 405-428
// WARNING: spike_map_screen.dart _zoom() omits setEntry(2,2) — do NOT copy that version
void _zoom(double factor) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  final double cx = box.size.width / 2;
  final double cy = box.size.height / 2;

  final Matrix4 m = _controller.value.clone();
  final double currentScale = m.getMaxScaleOnAxis();
  final double newScale = (currentScale * factor).clamp(minScale, maxScale);
  final double actualFactor = newScale / currentScale;
  if ((actualFactor - 1.0).abs() < 1e-6) return;

  final double tx = m.entry(0, 3);
  final double ty = m.entry(1, 3);
  m.setEntry(0, 0, newScale);
  m.setEntry(1, 1, newScale);
  m.setEntry(2, 2, newScale);  // CRITICAL: keeps getMaxScaleOnAxis() accurate
  m.setEntry(0, 3, cx + (tx - cx) * actualFactor);
  m.setEntry(1, 3, cy + (ty - cy) * actualFactor);
  _controller.value = m;
}

void _zoomIn()  => _zoom(1.5);   // D-11: 1.5x per press
void _zoomOut() => _zoom(1 / 1.5);
```

**_toSceneFromGlobal() pattern — production nullable variant** (analog lines 437–441):
```dart
// Analog: map_screen.dart lines 437-441
Offset? _toSceneFromGlobal(Offset globalOffset) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```

**build() / InteractiveViewer wiring** (analog lines 803–828, adapted for 1000×628 and stripped):
```dart
// Analog: map_screen.dart lines 803-828
// Note: Flags uses _currentScale via listener; RESEARCH.md recommends AnimatedBuilder
// for Phase 3 since the screen is simpler (no HighlightPainter, no RepaintBoundary split).
// Both patterns are valid; choose one and be consistent.
Widget _buildMap(List<StateData> states, List<Rect> insetFrameRects) {
  if (!_mapPaintReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToScreen();
      if (mounted) setState(() => _mapPaintReady = true);
    });
  }
  return Stack(
    children: [
      InteractiveViewer(
        key: _ivKey,
        transformationController: _controller,
        constrained: false,
        minScale: minScale,
        maxScale: maxScale,
        child: SizedBox(
          width: 1000,
          height: 628,
          child: CustomPaint(
            isComplex: true,
            painter: UsaMapPainter(
              states: states,
              matchedPostals: widget.matchedPostals,
              insetFrameRects: insetFrameRects,
              showLabels: widget.showLabels,
              mode: widget.mode,
              viewScale: _currentScale,
            ),
            size: const Size(1000, 628),
          ),
        ),
      ),
      // Zoom buttons outside InteractiveViewer (D-11, MAP-04)
      Positioned(
        bottom: 16, right: 16,
        child: Column(children: [
          FloatingActionButton.small(
            onPressed: _zoomIn, heroTag: 'zoom_in',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed: _zoomOut, heroTag: 'zoom_out',
            child: const Icon(Icons.remove),
          ),
        ]),
      ),
    ],
  );
}
```

**kDebugMode guard pattern** (analog lines 1029–1035 — for debug FABs):
```dart
// Analog: map_screen.dart lines 1029-1035
// Phase 3 uses same pattern for the /spike route registration in app.dart
floatingActionButton: kDebugMode
    ? FloatingActionButton.small(
        onPressed: ...,
        tooltip: 'DEBUG: ...',
        child: const Icon(Icons.skip_next),
      )
    : null,
```

---

### `lib/features/map/spike_map_screen.dart` (StatefulWidget, event-driven, dev-only)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\spike_map_screen.dart`
**Action:** Create new file. Port directly; replace abstract hardcoded rects with real state bboxes from `stateDataProvider`.

**Full class skeleton** (analog lines 1–181, adapted per D-07 and RESEARCH.md Pattern 9):
```dart
// Analog: spike_map_screen.dart lines 1-181
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/state_data_service.dart';
import '../../core/models/state_data.dart';

class SpikeMapScreen extends ConsumerStatefulWidget {
  const SpikeMapScreen({super.key});
  @override
  ConsumerState<SpikeMapScreen> createState() => _SpikeMapScreenState();
}

class _SpikeMapScreenState extends ConsumerState<SpikeMapScreen> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _ivKey = GlobalKey();

  // Named regions use real JSON bounding boxes (D-07, RESEARCH.md Pattern 9)
  // Populated after stateDataProvider resolves
  static const _regionPostals = ['TX', 'CA', 'FL', 'NY', 'AK', 'HI'];
```

**_toSceneFromGlobal() pattern** (analog lines 37–39; use non-null bang here as spike crashes deliberately):
```dart
// Analog: spike_map_screen.dart lines 37-39
// Non-nullable bang is acceptable in the spike — a null context is a test failure
Offset _toSceneFromGlobal(Offset globalOffset) {
  final box = _ivKey.currentContext!.findRenderObject()! as RenderBox;
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```

**_zoom() for spike** (use PRODUCTION version from map_screen.dart, NOT the spike version):
```dart
// Use map_screen.dart lines 405-428 version (setEntry(2,2,newScale) present)
// The spike_map_screen.dart analog (lines 49-68) is MISSING setEntry(2,2)
// — this is the known bug (RESEARCH.md Pitfall 1). Use the production pattern.
```

**InteractiveViewer structure** (analog lines 75–174, adapted):
```dart
// Analog: spike_map_screen.dart lines 75-174
// Key differences from Flags spike:
// - SizedBox 1000×628 (not 2000×1000)
// - Regions derived from StateData.boundingBox.rect (not hardcoded Rects)
// - Outer DragTarget catches all drops + calls stateHitTest() from hit_detection.dart
// - _fitMapToScreen() called via postFrameCallback (same pattern as MapScreen)
InteractiveViewer(
  key: _ivKey,
  transformationController: _controller,
  constrained: false,
  minScale: 0.08,
  maxScale: 10.0,  // spike uses wider range for manual testing
  child: SizedBox(
    width: 1000,
    height: 628,
    child: Stack(
      children: [
        Container(color: const Color(0xFFA8D5E8)),
        // Named DragTarget regions (real state bboxes)
        for (int i = 0; i < _regions.length; i++)
          Positioned(
            left: _regions[i].rect.left, top: _regions[i].rect.top,
            width: _regions[i].rect.width, height: _regions[i].rect.height,
            child: Container(
              color: _colors[i].withValues(alpha: 0.5),
              child: Center(child: Text(_regions[i].name, ...)),
            ),
          ),
        // Catch-all DragTarget for coordinate transform validation
        DragTarget<String>(
          builder: (ctx, _, __) => const SizedBox.expand(),
          onAcceptWithDetails: (details) {
            final scenePoint = _toSceneFromGlobal(details.offset);
            // stateHitTest() from hit_detection.dart (Phase 3 new file)
            final hit = stateHitTest(
              scenePoint, _allStates,
              scale: _controller.value.getMaxScaleOnAxis(),
            );
            debugPrint('Hit: $hit at scene=$scenePoint zoom=${_controller.value.getMaxScaleOnAxis().toStringAsFixed(2)}x');
          },
        ),
      ],
    ),
  ),
),
```

---

### `lib/features/map/hit_detection.dart` (pure-Dart utility, transform)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\hit_detection.dart`
**Action:** Create new file. Port directly; rename `CountryData` → `StateData`, `isoCode` → `postal`; remove `isDegenerate` branch.

**Imports pattern** (analog lines 1–4):
```dart
import 'dart:math' show max, sqrt, pi;
import 'dart:ui' show Offset, Rect;
// NO flutter/material.dart — pure Dart for unit-testability without widget harness
import '../../core/models/state_data.dart';
```

**Constants** (analog lines 7–15 — identical values):
```dart
const double _kMinScreenDiagonal = 40.0;
const double _kMinScreenArea = 2304.0;  // 48×48 dp²
```

**Top-level function signature** (analog lines 35–36, renamed):
```dart
// Analog: hit_detection.dart lines 35-64
// Rename: hitTest → stateHitTest, CountryData → StateData, isoCode → postal
String? stateHitTest(
  Offset scenePoint,
  List<StateData> states, {
  double scale = 1.0,
}) {
  final minSceneDiag = _kMinScreenDiagonal / scale;

  final candidates = states
      .where((s) => _primaryContains(s, scenePoint, minSceneDiag, scale: scale))
      .toList();

  final pool = candidates.isNotEmpty
      ? candidates
      : states
          .where((s) => _expandedBbox(s, minSceneDiag, scale: scale).contains(scenePoint))
          .toList();

  if (pool.isEmpty) return null;
  if (pool.length == 1) return pool.first.postal;  // isoCode → postal

  pool.sort((a, b) {
    final aDist = (_effectiveCentroid(a, scenePoint) - scenePoint).distanceSquared;
    final bDist = (_effectiveCentroid(b, scenePoint) - scenePoint).distanceSquared;
    return aDist.compareTo(bDist);
  });
  return pool.first.postal;  // isoCode → postal
}
```

**_effectiveCentroid pattern** (analog lines 72–87, renamed):
```dart
// Analog: hit_detection.dart lines 72-87
// Rename only: CountryData → StateData
Offset _effectiveCentroid(StateData state, Offset point) {
  for (final path in state.paths) {
    if (path.contains(point)) {
      final polyCenter = path.getBounds().center;
      final polyDist = (polyCenter - point).distanceSquared;
      final centDist = (state.centroid - point).distanceSquared;
      return polyDist < centDist ? polyCenter : state.centroid;
    }
  }
  return state.centroid;
}
```

**_primaryContains pattern** (analog lines 89–92):
```dart
// Analog: hit_detection.dart lines 89-92
bool _primaryContains(StateData state, Offset point, double minSceneDiag, {double scale = 1.0}) {
  if (state.paths.any((p) => p.contains(point))) return true;
  return _expandedBbox(state, minSceneDiag, scale: scale).contains(point);
}
```

**_expandedBbox pattern** (analog lines 94–133, drop isDegenerate branch):
```dart
// Analog: hit_detection.dart lines 94-133
// KEY CHANGE: remove isDegenerate branch (US states are never degenerate)
// The _kMinScreenArea path alone handles all 5 NE micro-states (RI, DE, CT, NJ, MD)
Rect _expandedBbox(StateData state, double minSceneDiag, {double scale = 1.0}) {
  final rect = state.boundingBox.rect;
  final screenArea = rect.width * rect.height * scale * scale;
  if (screenArea < _kMinScreenArea) {
    // Circular expansion to guarantee 48dp tap target (handles RI/DE at all zoom levels)
    final expansionRadius = sqrt(_kMinScreenArea / pi) / scale;
    return Rect.fromCenter(
      center: state.centroid,
      width: expansionRadius * 2,
      height: expansionRadius * 2,
    );
  }
  final diagonal = sqrt(rect.width * rect.width + rect.height * rect.height);
  if (diagonal < 1e-6) {
    return Rect.fromCenter(center: state.centroid, width: minSceneDiag, height: minSceneDiag);
  }
  // Drop isDegenerate max(minSceneDiag, diagonal*2) branch — not applicable for US states
  if (diagonal >= minSceneDiag) return rect;
  final scaleFactor = minSceneDiag / diagonal;
  return Rect.fromCenter(
    center: state.centroid,
    width: rect.width * scaleFactor,
    height: rect.height * scaleFactor,
  );
}
```

---

### `lib/app.dart` (routing, request-response — modify existing)

**Analog:** `lib/app.dart` (self, existing) — analog for `/spike` guard: `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` lines 1029–1035 (`kDebugMode` FAB pattern)
**Action:** Add `import 'package:flutter/foundation.dart' show kDebugMode;` and a `/spike` route guarded by `kDebugMode`.

**Imports to add** (self lines 1–5, add kDebugMode):
```dart
// Add to existing imports in lib/app.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'features/map/spike_map_screen.dart';  // dev-only
```

**Route registration pattern** (self lines 9–19, add spike route):
```dart
// Analog: map_screen.dart lines 1029-1035 (kDebugMode guard pattern)
// Extend existing _router in lib/app.dart:
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/play', builder: (context, state) => const MapScreen()),
    // Debug-only spike route — absent in release builds (D-06, RESEARCH.md Pattern 10)
    if (kDebugMode)
      GoRoute(path: '/spike', builder: (context, state) => const SpikeMapScreen()),
  ],
);
```

---

### `lib/core/data/state_data_service.dart` (service, CRUD — modify existing)

**Analog:** `lib/core/data/state_data_service.dart` (self, existing) + `C:\code\Claude\FlagsRoundTheWorld\lib\core\data\country_data_service.dart`
**Action:** Extend to also parse and expose `insetFrameRects` from the JSON top-level `insetFrames` key.

**Existing pattern to preserve** (self lines 1–39 — keep unchanged):
- `StateDataService.loadMapData()` background-isolate pattern
- `_decodeJson()` reading `data['states']` key (NOT `data['countries']` — Pitfall 7)
- `stateDataProvider` declaration at file scope

**Extension options** (from RESEARCH.md Open Question 1 — planner decides):

Option A — Return wrapper class (cleanest, requires provider API change):
```dart
// New wrapper class at top of state_data_service.dart
class MapData {
  final List<StateData> states;
  final List<Rect> insetFrameRects;
  const MapData({required this.states, required this.insetFrameRects});
}

// Change stateDataProvider return type
final stateDataProvider = FutureProvider<MapData>(
  (ref) => StateDataService().loadMapData(),
);
```

Option B — Hardcode as constants in UsaMapPainter (simplest, avoids provider change):
```dart
// In usa_map_painter.dart — stable constants from the JSON pipeline output
// (insetFrames.alaska verified: x:0.0, y:462.38, w:250.0, h:134.24)
// (insetFrames.hawaii verified: x:255.0, y:533.88, w:130.0, h:61.24)
static const _insetFrameRects = [
  Rect.fromLTWH(0.0, 462.38, 250.0, 134.24),   // Alaska
  Rect.fromLTWH(255.0, 533.88, 130.0, 61.24),  // Hawaii
];
```

**JSON parsing pattern for insetFrames** (analog: self `_decodeJson` lines 28–31):
```dart
// If Option A: extend _decodeJson to also return insetFrames
static ({List<Map<String, dynamic>> states, List<Map<String, dynamic>> frames})
    _decodeJson(String jsonString) {
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  final frames = data['insetFrames'] as Map<String, dynamic>;
  return (
    states: (data['states'] as List).cast<Map<String, dynamic>>(),
    frames: frames.values.cast<Map<String, dynamic>>().toList(),
  );
}
// Rect.fromLTWH((f['x'] as num).toDouble(), (f['y'] as num).toDouble(), ...)
```

---

## Test File Pattern Assignments

### `test/features/map/hit_detection_test.dart` (unit test)

**Analog:** `test/core/models/state_data_test.dart`
**Pattern:** Pure-Dart unit tests, no `TestWidgetsFlutterBinding`, fixture-based `StateData` construction.

**Imports + fixture pattern** (analog lines 1–24):
```dart
import 'dart:io';
import 'dart:convert';
import 'dart:math' show pi, sqrt;
import 'dart:ui' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/models/state_data.dart';
import 'package:state_states/features/map/hit_detection.dart';

// Load real JSON for centroid tests (same pattern as state_data_test.dart lines 82-84)
// This gives real geometry without asset mocking
List<StateData> _loadRealStates() {
  final raw = File('assets/map/usa_states_paths.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return (data['states'] as List)
      .cast<Map<String, dynamic>>()
      .map(StateData.fromJson)
      .toList();
}
```

**Test structure pattern** (analog: state_data_test.dart lines 26–99, adapted for 10 centroid assertions):
```dart
// Analog: state_data_test.dart group/test structure
void main() {
  late List<StateData> states;
  setUpAll(() => states = _loadRealStates());  // load once, use across groups

  group('stateHitTest — NE micro-states at scale 1.0', () {
    // 5 assertions: RI, DE, CT, NJ, MD (RESEARCH.md Validation Dimension 2)
    for (final postal in ['RI', 'DE', 'CT', 'NJ', 'MD']) {
      test('centroid of $postal at scale 1.0 → $postal', () {
        final state = states.firstWhere((s) => s.postal == postal);
        expect(stateHitTest(state.centroid, states, scale: 1.0), postal);
      });
    }
  });

  group('stateHitTest — NE micro-states at scale 4.0', () {
    // 5 more assertions at 4x zoom
    for (final postal in ['RI', 'DE', 'CT', 'NJ', 'MD']) {
      test('centroid of $postal at scale 4.0 → $postal', () {
        final state = states.firstWhere((s) => s.postal == postal);
        expect(stateHitTest(state.centroid, states, scale: 4.0), postal);
      });
    }
  });

  test('ocean point (far from any state) → null', () {
    // Point in the ocean far from any state (top-left corner of scene)
    expect(stateHitTest(const Offset(5, 5), states), isNull);
  });
}
```

---

### `test/features/map/usa_map_painter_test.dart` (widget smoke test)

**Analog:** `test/core/data/state_data_service_test.dart` (binding init + provider pattern)

**Binding + provider pattern** (analog lines 1–17):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/map/usa_map_painter.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UsaMapPainter renders without exception', (tester) async {
    final container = ProviderContainer();
    addTeardown(container.dispose);
    final states = await container.read(stateDataProvider.future);

    await tester.pumpWidget(MaterialApp(
      home: CustomPaint(
        painter: UsaMapPainter(
          states: states,
          matchedPostals: const {},
          insetFrameRects: const [
            Rect.fromLTWH(0.0, 462.38, 250.0, 134.24),
            Rect.fromLTWH(255.0, 533.88, 130.0, 61.24),
          ],
          viewScale: 1.0,
        ),
        size: const Size(1000, 628),
      ),
    ));
    // Smoke: no exception thrown; CustomPaint rendered to non-zero size
    expect(find.byType(CustomPaint), findsOneWidget);
  });
}
```

---

### `test/features/map/map_screen_test.dart` (widget test — zoom button + scale)

**Analog:** `test/features/game/game_session_notifier_test.dart` (ProviderContainer override pattern, lines 1–60)

**ProviderContainer override + widget pump pattern** (analog lines 1–60):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/map/map_screen.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/core/models/state_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Use real stateDataProvider (loaded from real JSON) — established pattern
  // from state_data_service_test.dart lines 6-17
  testWidgets('zoom in button multiplies scale by 1.5', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MapScreen())),
    );
    await tester.pumpAndSettle();  // wait for stateDataProvider + postFrameCallback

    // Get controller via key or find the zoom button
    // Assert getMaxScaleOnAxis() before and after tap
    final zoomInButton = find.byIcon(Icons.add);
    // ... (RESEARCH.md Validation Dimension 4 pattern)
  });
}
```

---

### `test/features/map/spike_map_screen_test.dart` (widget test — coordinate transform)

**Analog:** `test/features/game/game_session_notifier_test.dart` (ProviderContainer override) + `test/core/data/state_data_service_test.dart` (binding init)

**Widget test with provider override pattern** (per RESEARCH.md Open Question 2 — mock `stateDataProvider` with 6 fixture states):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/map/spike_map_screen.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/core/models/state_data.dart';

// 6 hand-crafted StateData fixtures (TX, CA, FL, NY, AK, HI) matching
// the established _record() helper pattern from state_data_test.dart lines 11-24
const _kPath = 'M0,0 L1,0 L1,1 Z';
// ... build fixtures with real-ish bboxes from RESEARCH.md Pattern 9

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SpikeMapScreen renders without exception', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stateDataProvider.overrideWith((ref) async => _fixtures),
        ],
        child: const MaterialApp(home: SpikeMapScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
```

---

## Shared Patterns

### TransformationController Lifecycle
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` lines 52, 109–144
**Apply to:** `lib/features/map/map_screen.dart`, `lib/features/map/spike_map_screen.dart`
```dart
// Field declaration
final TransformationController _controller = TransformationController();
final GlobalKey _ivKey = GlobalKey();

// initState
_controller.addListener(_onScaleChanged);

// dispose — MUST call removeListener before dispose
_controller.removeListener(_onScaleChanged);
_controller.dispose();
```

### kDebugMode Guard
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` lines 4, 1029–1035
**Apply to:** `lib/app.dart` (spike route), `lib/features/map/map_screen.dart` (any debug UI)
```dart
import 'package:flutter/foundation.dart' show kDebugMode;
// Usage: if (kDebugMode) ... or ternary kDebugMode ? widget : null
```

### postFrameCallback for Layout-Dependent Initialization
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\map_screen.dart` lines 761–763
**Apply to:** `lib/features/map/map_screen.dart`, `lib/features/map/spike_map_screen.dart`
```dart
// NEVER call _fitMapToScreen() in initState() — RenderBox is not yet attached
// Call it only after the first frame:
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    _fitMapToScreen();
    setState(() => _mapPaintReady = true);
  }
});
```

### setEquals for Set Comparison in shouldRepaint
**Source:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\world_map_painter.dart` lines 3, 42–43
**Apply to:** `lib/features/map/usa_map_painter.dart`
```dart
import 'package:flutter/foundation.dart' show setEquals;
// In shouldRepaint:
!setEquals(old.matchedPostals, matchedPostals)
// Never use == on Set — reference equality always fails for new Set instances
```

### ProviderContainer in Tests (no ProviderScope)
**Source:** `C:\code\Claude\StateTheStates\test\core\data\state_data_service_test.dart` lines 10–17
**Apply to:** `test/features/map/usa_map_painter_test.dart`
```dart
final container = ProviderContainer();
addTeardown(container.dispose);
final states = await container.read(stateDataProvider.future);
```

### ProviderScope Override in Widget Tests
**Source:** `C:\code\Claude\StateTheStates\test\features\game\game_session_notifier_test.dart` lines 58–70
**Apply to:** `test/features/map/spike_map_screen_test.dart`, `test/features/map/map_screen_test.dart`
```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      stateDataProvider.overrideWith((ref) async => _fixtures),
    ],
    child: const MaterialApp(home: SpikeMapScreen()),
  ),
);
```

### Real JSON Loading in Tests (no asset mocking)
**Source:** `C:\code\Claude\StateTheStates\test\core\models\state_data_test.dart` lines 82–84
**Apply to:** `test/features/map/hit_detection_test.dart`
```dart
// Reads the JSON file directly using dart:io — no rootBundle, no asset mocking
final raw = File('assets/map/usa_states_paths.json').readAsStringSync();
final data = jsonDecode(raw) as Map<String, dynamic>;
```

---

## No Analog Found

All files have close analogs. No entries in this section.

---

## Critical Porting Notes

| Risk | Source | Mitigation |
|------|--------|------------|
| `_zoom()` missing `setEntry(2,2,newScale)` | `spike_map_screen.dart` lines 64–68 (omits it) | Use `map_screen.dart` lines 405–428 version for BOTH screens |
| ViewBox height = 628, not 620/625 | RESEARCH.md Pitfall 3 | `SizedBox(width: 1000, height: 628)` everywhere |
| `shouldRepaint` Set reference equality | Pitfall 5 in RESEARCH.md | `setEquals()` from `flutter/foundation.dart` |
| `_fitMapToScreen()` before layout | Pitfall 2 in RESEARCH.md | Only in `addPostFrameCallback`, never in `initState()` |
| JSON key `'states'` not `'countries'` | `state_data_service.dart` line 26–27 comment | Preserved from Phase 1 — do not regress |
| `isDegenerate` branch in hit detection | Not applicable for US states | Drop the entire branch; `_kMinScreenArea` handles micro-states |

---

## Metadata

**Analog search scope:** `C:\code\Claude\StateTheStates\lib\`, `C:\code\Claude\StateTheStates\test\`, `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\`
**Files scanned:** 15
**Pattern extraction date:** 2026-05-31
