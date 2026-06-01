# Phase 5: Polish, Welcome & Accessibility - Pattern Map

**Mapped:** 2026-06-01
**Files analyzed:** 11 new/modified files
**Analogs found:** 10 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/welcome/welcome_screen.dart` | component | request-response + event-driven | `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\welcome_screen.dart` | role-match (structure port; replace globe with USA painter) |
| `lib/features/welcome/usa_welcome_painter.dart` | utility | transform | `lib/features/map/usa_map_painter.dart` | exact (same CustomPainter pattern; different fill logic) |
| `lib/features/tutorial/tutorial_screen.dart` | component | request-response | `lib/features/home/home_screen.dart` (ConsumerStatefulWidget shell + go_router nav) | partial (same widget type + nav pattern; no analog for PageView onboarding) |
| `lib/features/home/session_restore_card.dart` | component | request-response | `lib/features/home/home_screen.dart` `_ModeCard` | role-match (card widget extracted from same screen) |
| `lib/features/map/map_screen.dart` | component | event-driven | itself (MODIFY) | exact |
| `lib/features/map/usa_map_painter.dart` | utility | transform | itself (MODIFY) | exact |
| `lib/core/audio/audio_service.dart` | service | request-response | itself (MODIFY) | exact |
| `lib/core/audio/real_audio_service.dart` | service | request-response | itself (MODIFY) | exact |
| `lib/core/audio/stub_audio_service.dart` | service | request-response | itself (MODIFY) | exact |
| `lib/features/home/home_screen.dart` | component | CRUD | itself (MODIFY) | exact |
| `lib/app.dart` | config | request-response | itself (MODIFY) | exact |

---

## Pattern Assignments

### `lib/features/welcome/welcome_screen.dart` (component, event-driven)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\welcome_screen.dart` — port the shell, replace `_GlobeHero` with the USA stagger painter.

**Imports pattern** (Flags lines 1–7, adapted for State States):
```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service_provider.dart';
import '../../core/data/state_data_service.dart';
import '../../core/data/user_prefs_repository.dart';
import 'usa_welcome_painter.dart';
```

**Widget declaration — use `ConsumerStatefulWidget + TickerProviderStateMixin`** (NOT `SingleTickerProviderStateMixin` as in Flags, because Phase 5 uses two controllers):
```dart
// Flags line 16-17 uses SingleTickerProviderStateMixin — upgrade to multi:
class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  Timer? _fadeTimer; // anthem fade — Timer.periodic, not AnimationController
  final _random = math.Random();
  late List<int> _staggerOrder; // populated in initState after stateDataProvider resolves
```

**initState pattern** (adapt Flags lines 21–28):
```dart
@override
void initState() {
  super.initState();
  _staggerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward(); // run once, no repeat (D-W2: ~1-2s total)
  // Anthem fade-in starts after first frame so audioServiceProvider is available.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(audioServiceProvider).fadeInAnthem();
  });
}
```

**dispose pattern** (Flags lines 30–33):
```dart
@override
void dispose() {
  _staggerController.dispose();
  // _fadeTimer is owned by RealAudioService — no cancel needed here
  super.dispose();
}
```

**Gradient background** (Flags lines 38–50, identical colors — D-W3 locks these):
```dart
decoration: const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D47A1), // deep blue
      Color(0xFF1565C0),
      Color(0xFF1976D2),
      Color(0xFF42A5F5), // sky blue
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  ),
),
```

**Hero area — replace `_GlobeHero` with `AnimatedBuilder` + `CustomPaint`:**
```dart
// Flags line 58: _GlobeHero(rotationController: _rotationController)
// Replace with:
ref.watch(stateDataProvider).when(
  loading: () => const SizedBox(height: 260),
  error: (_, __) => const SizedBox(height: 260),
  data: (mapData) {
    // Compute stagger order once on first data arrival
    if (_staggerOrder.isEmpty) {
      _staggerOrder = List.generate(mapData.states.length, (i) => i)
        ..shuffle(_random);
    }
    return SizedBox(
      width: double.infinity,
      height: 260,
      child: AnimatedBuilder(
        animation: _staggerController,
        builder: (_, __) => CustomPaint(
          painter: UsaWelcomePainter(
            states: mapData.states,
            staggerOrder: _staggerOrder,
            animValue: _staggerController.value,
          ),
        ),
      ),
    );
  },
),
```

**CTA button** (Flags lines 90–113 — keep exact sizing, update label + onPressed):
```dart
// Flags: height 56, backgroundColor white, foregroundColor 0xFF1565C0
// State States: identical sizing, updated label and async onPressed
SizedBox(
  width: double.infinity,
  height: 56,
  child: ElevatedButton(
    onPressed: _onStartPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1565C0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      elevation: 4,
    ),
    child: const Text(
      'GET STARTED',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  ),
),
```

**CTA handler — fire-and-forget fade, then navigate** (RESEARCH.md Pitfall 5):
```dart
void _onStartPressed() {
  ref.read(audioServiceProvider).fadeOutAnthem(); // fire and forget — do NOT await
  Future.delayed(const Duration(milliseconds: 850), () async {
    if (!mounted) return;
    final repo = await ref.read(userPrefsRepositoryProvider.future);
    final seen = await repo.getTutorialSeen();
    if (!mounted) return;
    context.go(seen ? '/' : '/tutorial');
  });
}
```

**Privacy footer** (Flags lines 119–155 — copy verbatim, update copyright):
```dart
// Copy Flags pattern exactly: Row with Privacy Policy TextButton + · separator + copyright Text
// Update: '© 2025 Otis & Brooke' → '© 2026 Otis & Brooke'
// Remove url_launcher call for now (same as HomeScreen which has an empty onPressed)
```

---

### `lib/features/welcome/usa_welcome_painter.dart` (utility, transform)

**Analog:** `lib/features/map/usa_map_painter.dart` — same `CustomPainter` base, different fill logic.

**Constructor + shouldRepaint pattern** (`lib/features/map/usa_map_painter.dart` lines 32–63):
```dart
class UsaWelcomePainter extends CustomPainter {
  const UsaWelcomePainter({
    required this.states,
    required this.staggerOrder,
    required this.animValue,
  });

  final List<StateData> states;
  final List<int> staggerOrder;  // pre-shuffled index list
  final double animValue;        // 0.0 → 1.0 from AnimationController

  @override
  bool shouldRepaint(covariant UsaWelcomePainter old) =>
      (old.animValue - animValue).abs() > 0.001; // RESEARCH.md Pitfall 6
```

**paint() pattern** (adapt `usa_map_painter.dart` lines 66–94):
```dart
@override
void paint(Canvas canvas, Size size) {
  // No ocean fill — transparent so gradient background shows through.

  // Scale the 1000×628 viewBox to fit the SizedBox while preserving aspect ratio.
  const mapW = 1000.0;
  const mapH = 628.0;
  final scaleX = size.width / mapW;
  final scaleY = size.height / mapH;
  final fitScale = math.min(scaleX, scaleY);
  final tx = (size.width  - mapW * fitScale) / 2;
  final ty = (size.height - mapH * fitScale) / 2;
  canvas.save();
  canvas.translate(tx, ty);
  canvas.scale(fitScale);

  final fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.white; // D-W3: solid white states

  for (int k = 0; k < staggerOrder.length; k++) {
    final threshold = k / staggerOrder.length; // 0..1 step per state
    if (animValue < threshold) continue;       // D-W2: stagger gate
    final state = states[staggerOrder[k]];
    for (final path in state.paths) {
      canvas.drawPath(path, fillPaint);
    }
  }

  canvas.restore();
}
```

---

### `lib/features/tutorial/tutorial_screen.dart` (component, request-response)

**Analog:** `lib/features/home/home_screen.dart` — same `ConsumerStatefulWidget` shell, go_router navigation, Riverpod repository reads.

**No exact analog for PageView onboarding** — use RESEARCH.md Pattern 5 directly.

**Imports pattern** (adapt `home_screen.dart` lines 1–8):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/user_prefs_repository.dart';
```

**Widget shell** (same ConsumerStatefulWidget pattern as `home_screen.dart` lines 9–16):
```dart
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});
  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
```

**Shared navigation helper — both Skip and Done MUST call this** (RESEARCH.md Pitfall 3):
```dart
// Extract to single method — called by BOTH skip and done taps.
Future<void> _completeTutorial() async {
  final repo = await ref.read(userPrefsRepositoryProvider.future);
  await repo.setTutorialSeen(true);
  if (mounted) context.go('/');
}
```

**FutureProvider read pattern** (same as `home_screen.dart` `ref.watch(highScoreRepositoryProvider)` pattern — lines 19–29):
```dart
// In build(), the tutorial screen does NOT need to watch a provider on every
// frame. Instead, call ref.read(...future) only on tap — same fire-and-forget
// async pattern used in home_screen.dart _ModeCard.onTap:
ElevatedButton(
  onPressed: () => _completeTutorial(),
  child: const Text('Done'),
),
TextButton(
  onPressed: () => _completeTutorial(), // IDENTICAL call — never skip this
  child: const Text('Skip'),
),
```

---

### `lib/features/home/session_restore_card.dart` (component, request-response)

**Analog:** `lib/features/home/home_screen.dart` `_ModeCard` (lines 141–331) — same card pattern: gradient decoration, Row layout, action buttons.

**Card decoration pattern** (`home_screen.dart` `_buildCard()` lines 196–230):
```dart
// Reuse the card container decoration pattern verbatim:
Container(
  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: LinearGradient(
      colors: [
        const Color(0xFF37474F), // blue-grey for resume card
        const Color(0xFF263238),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF37474F).withValues(alpha: 0.4),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  // ...
)
```

**Elapsed time format** — copy `GameHud`'s format exactly (`game_hud.dart` lines 35–37):
```dart
// Source: lib/features/game/game_hud.dart lines 35-37 — use IDENTICAL format
String _formatElapsed(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
```

**Semantics pattern** (`home_screen.dart` lines 323–327):
```dart
Semantics(
  button: true,
  label: 'Resume ${session.mode.name} game, score ${session.score}',
  child: /* card */,
)
```

---

### `lib/features/map/map_screen.dart` — MODIFY (component, event-driven)

**Analog:** itself. Extend the existing file.

**Add to state variables** (after `_isMuted` field, `map_screen.dart` ~line 89):
```dart
// Phase 5: hint zoom animation
late final AnimationController _hintZoomController;
Animation<Matrix4>? _hintZoomAnimation;
String? _hintPostal; // non-null during 3s glow window
Timer? _hintGlowTimer;
```

**Add to initState** (after `_controller = TransformationController()` line 107):
```dart
_hintZoomController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 400),
);
_hintZoomController.addListener(_onHintZoomTick);
```

**Add to dispose** (before `_controller.dispose()` line 119):
```dart
_hintGlowTimer?.cancel();        // RESEARCH.md Pitfall 4 — MUST cancel
_hintZoomController.removeListener(_onHintZoomTick);
_hintZoomController.dispose();
```

**_onHintZoomTick helper** (new method — drives TransformationController from animation):
```dart
void _onHintZoomTick() {
  if (_hintZoomAnimation != null && mounted) {
    _controller.value = _hintZoomAnimation!.value;
  }
}
```

**_computeHintMatrix** — copy `_fitMapToScreen` matrix construction as the template (RESEARCH.md Pitfall 1 note — must include `setEntry(2,2,newScale)`):
```dart
// Analog: _fitMapToScreen() lines 131–149 — SAME Matrix4 construction pattern.
Matrix4 _computeHintMatrix(Offset sceneCentroid) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return _controller.value;
  const double targetZoom = 2.5;
  final double newScale = (_minScale * targetZoom).clamp(_minScale, _maxScale);
  final double tx = box.size.width  / 2 - sceneCentroid.dx * newScale;
  final double ty = box.size.height / 2 - sceneCentroid.dy * newScale;
  return Matrix4.identity()
    ..setEntry(0, 0, newScale)
    ..setEntry(1, 1, newScale)
    ..setEntry(2, 2, newScale) // Pitfall 1 — NEVER omit
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
}
```

**_onHintPressed handler** (replaces `onHintPressed: () {}` in `_buildMapStack` at line 651):
```dart
void _onHintPressed() {
  final consumed = ref.read(gameSessionProvider.notifier).useHint();
  if (!consumed) return;
  final target = _stateIndex[_currentPostal];
  if (target == null) return;

  setState(() => _hintPostal = _currentPostal);

  final startMatrix = _controller.value.clone();
  final endMatrix = _computeHintMatrix(target.centroid);
  _hintZoomAnimation = Matrix4Tween(begin: startMatrix, end: endMatrix)
      .animate(CurvedAnimation(
        parent: _hintZoomController,
        curve: Curves.easeInOut, // Claude's discretion
      ));
  _hintZoomController
    ..reset()
    ..forward();

  _hintGlowTimer?.cancel();
  _hintGlowTimer = Timer(const Duration(seconds: 3), () {
    if (mounted) setState(() => _hintPostal = null);
  });
}
```

**Pass hintPostal to UsaMapPainter** (replace `UsaMapPainter(...)` call at `_buildMapStack` lines 588–596):
```dart
painter: UsaMapPainter(
  states: states,
  matchedPostals: _matchedPostals,
  insetFrameRects: insetFrameRects,
  showLabels: showLabels,
  mode: widget.mode,
  viewScale: _controller.value.getMaxScaleOnAxis(),
  hintPostal: _hintPostal, // Phase 5 addition
),
```

**Wire hint button** (replace `onHintPressed: () {}` at line 651):
```dart
onHintPressed: _onHintPressed,
```

---

### `lib/features/map/usa_map_painter.dart` — MODIFY (utility, transform)

**Analog:** itself. Add one constructor parameter and one paint step.

**Constructor** (add after `viewScale`, `usa_map_painter.dart` lines 32–40):
```dart
const UsaMapPainter({
  required this.states,
  required this.matchedPostals,
  required this.insetFrameRects,
  this.showLabels = false,
  this.mode,
  this.viewScale = 1.0,
  this.hintPostal,   // Phase 5: yellow-green glow target state
});

final String? hintPostal;
```

**shouldRepaint** (add `hintPostal` to existing comparison at lines 59–63):
```dart
@override
bool shouldRepaint(covariant UsaMapPainter old) =>
    !setEquals(old.matchedPostals, matchedPostals) ||
    old.showLabels != showLabels ||
    old.mode != mode ||
    (old.viewScale - viewScale).abs() > 0.001 ||
    old.hintPostal != hintPostal; // Phase 5: glow start/end must trigger repaint
```

**paint() hint glow step** (add after label pass, before close of `paint()` — ported from `HighlightPainter._drawHintHighlight()` lines 140–151):
```dart
// Step 5: Hint glow (Phase 5 — direct port of HighlightPainter._drawHintHighlight())
// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\map\highlight_painter.dart lines 140-151
if (hintPostal != null) {
  final hintState = states.firstWhereOrNull((s) => s.postal == hintPostal);
  if (hintState != null) {
    final hintPaint = Paint()
      ..color = const Color(0xFFBBFF44) // D-H3: locked yellow-green color
      ..style = PaintingStyle.fill;
    for (final path in hintState.paths) {
      canvas.drawPath(path, hintPaint);
    }
  }
}
```

Note: `firstWhereOrNull` requires `import 'package:collection/collection.dart'` — check if `collection` is already in pubspec (it is a transitive dependency of `flutter_riverpod`). If not available, use `states.cast<StateData?>().firstWhere((s) => s?.postal == hintPostal, orElse: () => null)`.

---

### `lib/core/audio/audio_service.dart` — MODIFY (service interface, request-response)

**Analog:** itself. Replace `playAnthem()`/`stopAnthem()` with `fadeInAnthem()`/`fadeOutAnthem()`.

**Current interface** (lines 1–15 — full file):
```dart
abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();
  Future<void> playAnthem();   // → replace with fadeInAnthem()
  Future<void> stopAnthem();   // → replace with fadeOutAnthem()
  Future<void> setMuted(bool muted);
  Future<void> dispose();
}
```

**Updated interface** (RESEARCH.md Open Question 1 resolution — clean rename):
```dart
abstract interface class AudioService {
  Future<void> init();
  Future<void> playCorrect();
  Future<void> playError();

  /// Plays the anthem from the start with a 500ms volume fade-in (D-A3).
  Future<void> fadeInAnthem();

  /// Ramps anthem volume to 0 over ~800ms then stops playback (D-A2).
  Future<void> fadeOutAnthem();

  Future<void> setMuted(bool muted);
  Future<void> dispose();
}
```

---

### `lib/core/audio/real_audio_service.dart` — MODIFY (service, request-response)

**Analog:** itself. The `playAnthem()`/`stopAnthem()` pattern (lines 56–70) is the direct template for the fade variants.

**Add Timer field** (after `bool _initialized = false` at line 11):
```dart
Timer? _fadeTimer;
bool _isMuted = false; // track mute state to skip volume changes when muted
```

**Replace `playAnthem()` with `fadeInAnthem()`** (replaces lines 56–62):
```dart
@override
Future<void> fadeInAnthem() async {
  if (!_initialized || _isMuted) return;
  _fadeTimer?.cancel();
  double volume = 0.0;
  const int ticks = 25;           // 25 × 20ms = 500ms (D-A3)
  const tickInterval = Duration(milliseconds: 20);
  try {
    await _anthemPlayer.setVolume(0.0);
    await _anthemPlayer.seek(Duration.zero);
    unawaited(_anthemPlayer.play());
  } catch (_) {}
  _fadeTimer = Timer.periodic(tickInterval, (timer) async {
    volume = math.min(1.0, volume + 1.0 / ticks);
    try { await _anthemPlayer.setVolume(volume); } catch (_) {}
    if (volume >= 1.0) timer.cancel();
  });
}
```

**Replace `stopAnthem()` with `fadeOutAnthem()`** (replaces lines 64–70):
```dart
@override
Future<void> fadeOutAnthem() async {
  if (!_initialized) return;
  _fadeTimer?.cancel();
  double volume = _isMuted ? 0.0 : 1.0;
  const int ticks = 40;           // 40 × 20ms = 800ms (D-A2)
  const tickInterval = Duration(milliseconds: 20);
  _fadeTimer = Timer.periodic(tickInterval, (timer) async {
    volume = math.max(0.0, volume - 1.0 / ticks);
    try { await _anthemPlayer.setVolume(volume); } catch (_) {}
    if (volume <= 0.0) {
      timer.cancel();
      try { await _anthemPlayer.stop(); } catch (_) {}
    }
  });
}
```

**Update `setMuted()`** (lines 73–80 — track `_isMuted` flag):
```dart
@override
Future<void> setMuted(bool muted) async {
  if (!_initialized) return;
  _isMuted = muted; // Phase 5: fade methods check this flag
  final volume = muted ? 0.0 : 1.0;
  try {
    await _correctPlayer.setVolume(volume);
    await _errorPlayer.setVolume(volume);
    await _anthemPlayer.setVolume(volume);
  } catch (_) {}
}
```

**Update `dispose()`** (add `_fadeTimer?.cancel()` before player disposes, lines 84–96):
```dart
@override
Future<void> dispose() async {
  _fadeTimer?.cancel(); // Phase 5: prevent timer firing after dispose
  await _correctPlayer.dispose();
  await _errorPlayer.dispose();
  await _anthemPlayer.dispose();
}
```

**Update `init()` asset path** (line 23 — rename from `anthem_placeholder.wav` to `anthem.wav`):
```dart
// Line 23: anthem asset rename (RESEARCH.md Pitfall 7)
await _anthemPlayer.setAsset('assets/audio/anthem.wav'); // was anthem_placeholder.wav
```

**Add import** (after existing imports at top of file):
```dart
import 'dart:async' show Timer, unawaited; // Timer already used; ensure Timer is imported
import 'dart:math' as math;
```

---

### `lib/core/audio/stub_audio_service.dart` — MODIFY (service, request-response)

**Analog:** itself (lines 1–28 — full file). Add no-op implementations of the two new methods.

**Replace `playAnthem()`/`stopAnthem()` with no-op fades** (lines 18–21):
```dart
// Replace:
@override
Future<void> playAnthem() async {}

@override
Future<void> stopAnthem() async {}

// With:
@override
Future<void> fadeInAnthem() async {}

@override
Future<void> fadeOutAnthem() async {}
```

---

### `lib/features/home/home_screen.dart` — MODIFY (component, CRUD)

**Analog:** itself. Add session restore card above the mode ListView in `_buildBody`.

**FutureBuilder pattern** (add at top of `_buildBody()` Column children, before the existing Header Padding — `home_screen.dart` lines 32–65):
```dart
// Source: home_screen.dart _buildBody() pattern — FutureBuilder wraps the
// optional card above the existing mode ListView.
// Mirrors the FutureBuilder<int?> already used in _ModeCard (lines 259-300).
FutureBuilder<({GameSession session, int hintPenalty})?>(
  future: ref.read(gameStateRepositoryProvider.future)
      .then((repo) => repo.loadSession()),
  builder: (context, snapshot) {
    if (!snapshot.hasData || snapshot.data == null) {
      return const SizedBox.shrink();
    }
    final saved = snapshot.data!;
    return SessionRestoreCard(
      session: saved.session,
      hintPenalty: saved.hintPenalty,
      onContinue: () {
        ref.read(gameSessionProvider.notifier)
            .restoreGame(saved.session, saved.hintPenalty);
        context.go('/play', extra: saved.session.mode);
      },
      onDismiss: () async {
        final repo = await ref.read(gameStateRepositoryProvider.future);
        await repo.clearSession();
        if (mounted) setState(() {});
      },
    );
  },
),
```

**Import additions** (add to existing imports at top of `home_screen.dart`):
```dart
import 'package:state_states/core/data/game_state_repository.dart';
import 'package:state_states/features/game/game_session_notifier.dart';
import 'session_restore_card.dart';
```

---

### `lib/app.dart` — MODIFY (config, request-response)

**Analog:** itself. Add `/welcome` as `initialLocation`, add `/tutorial` route.

**Updated router** (lines 13–45):
```dart
// Change initialLocation from '/' to '/welcome'
final _router = GoRouter(
  initialLocation: '/welcome', // Phase 5: welcome screen is the entry point
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/tutorial',
      builder: (context, state) => const TutorialScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    // ... existing /play, /complete, /spike routes unchanged
  ],
);
```

**Import additions** (add to existing imports):
```dart
import 'features/welcome/welcome_screen.dart';
import 'features/tutorial/tutorial_screen.dart';
```

---

## Shared Patterns

### ConsumerStatefulWidget + TickerProviderStateMixin
**Source:** `lib/features/map/map_screen.dart` lines 60–61
**Apply to:** `WelcomeScreen` (needs stagger `AnimationController`), `TutorialScreen` (PageController only — `StatefulWidget` is sufficient but `ConsumerStatefulWidget` needed for Riverpod reads)
```dart
class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
```

### FutureProvider read pattern (async repository access)
**Source:** `lib/features/home/home_screen.dart` `_ModeCard.onTap` (line 77) + `lib/features/map/map_screen.dart` `_advanceToNextPostal` (lines 258–260)
**Apply to:** `TutorialScreen._completeTutorial()`, `SessionRestoreCard.onDismiss`
```dart
// Pattern: await ref.read(someProvider.future) inside async method
final repo = await ref.read(userPrefsRepositoryProvider.future);
await repo.setTutorialSeen(true);
if (mounted) context.go('/');
```

### Mounted guard before setState/navigation
**Source:** `lib/features/map/map_screen.dart` line 405 (`if (mounted) _advanceToNextPostal()`)
**Apply to:** All async callbacks in `WelcomeScreen`, `TutorialScreen`, `HomeScreen` session card
```dart
if (!mounted) return;
```

### Timer cancel in dispose()
**Source:** `lib/features/map/map_screen.dart` dispose pattern (lines 114–121)
**Apply to:** `MapScreen.dispose()` for `_hintGlowTimer`, `RealAudioService.dispose()` for `_fadeTimer`
```dart
_hintGlowTimer?.cancel(); // always before super.dispose()
```

### Semantics button wrapper
**Source:** `lib/features/home/home_screen.dart` lines 323–327, `lib/features/game/game_hud.dart` lines 86–101
**Apply to:** All interactive controls in `WelcomeScreen`, `TutorialScreen`, `SessionRestoreCard`
```dart
Semantics(
  button: true,
  label: 'descriptive label for screen reader',
  child: ElevatedButton(/* ... */),
)
```

### go_router navigation
**Source:** `lib/app.dart` + `lib/features/home/home_screen.dart` line 77
**Apply to:** `WelcomeScreen._onStartPressed()`, `TutorialScreen._completeTutorial()`
```dart
context.go('/tutorial'); // replace current route (no back stack)
context.go('/');         // same — no back navigation to welcome/tutorial
```

### AnimationController + CurvedAnimation + Tween wiring
**Source:** `lib/features/map/map_screen.dart` `_animateCorrectDrop()` lines 368–378
**Apply to:** `MapScreen._onHintPressed()` (`Matrix4Tween` + `CurvedAnimation`)
```dart
// Established pattern: Tween.animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut))
final posAnim = Tween<Offset>(begin: startOffset, end: endOffset)
    .animate(CurvedAnimation(parent: animController, curve: Curves.easeInOut));
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `scripts/render_anthem.sh` | build script | batch | No shell scripts exist in this repo; one-time FluidSynth CLI task (see RESEARCH.md Pattern 2 for exact commands) |

---

## Metadata

**Analog search scope:**
- `C:\code\Claude\StateTheStates\lib\` (full codebase)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\welcome_screen.dart` (port source)
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\highlight_painter.dart` (hint glow source)

**Files scanned:** 12 source files read directly; pattern extraction from 10 unique analogs

**Pattern extraction date:** 2026-06-01

**Critical cross-file invariant:** `playAnthem()`/`stopAnthem()` are renamed to `fadeInAnthem()`/`fadeOutAnthem()` across all three audio files (`audio_service.dart`, `real_audio_service.dart`, `stub_audio_service.dart`) and their call sites. Any existing test file calling `playAnthem()` or `stopAnthem()` on `AudioService` must be updated in the same task as the interface change.

**Critical cross-file invariant:** `anthem_placeholder.wav` is renamed to `anthem.wav`. The `setAsset()` call in `real_audio_service.dart` line 23 must be updated in the same task as the asset file rename/replace. `pubspec.yaml` declares `assets/audio/` at directory level — no change needed there.
