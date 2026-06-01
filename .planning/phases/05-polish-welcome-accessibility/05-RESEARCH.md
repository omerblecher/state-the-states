# Phase 5: Polish, Welcome & Accessibility - Research

**Researched:** 2026-06-01
**Domain:** Flutter animation, audio rendering pipeline, accessibility, onboarding UX
**Confidence:** HIGH (Flutter patterns verified in codebase; MEDIUM on anthem toolchain — FluidSynth not pre-installed)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Welcome Screen Visual**
- D-W1: Animated fill-in USA silhouette via CustomPainter from `usa_states_paths.json`. States fill in one by one using the same path data already loaded for the game map.
- D-W2: Random stagger order, ~10–30ms delay per state. Organic, covers the whole map quickly.
- D-W3: Solid white states on deep blue gradient background `[Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)]`.
- D-W4: Include Alaska and Hawaii insets using same inset layout and transforms from `usa_states_paths.json`.

**Anthem**
- D-A1: Anthem must be rendered as part of Phase 5 using FluidSynth + SF2 soundfont pipeline; replaces `assets/audio/anthem_placeholder.wav`.
- D-A2: Volume tween fade-out (~800ms ramp to 0) before stop. `RealAudioService.stopAnthem()` ramps `AudioPlayer.setVolume()` to 0 over ~800ms, then calls `stop()`.
- D-A3: Auto-play on welcome screen load with 500ms fade-in; anthem starts at volume 0, ramps to full over 500ms.

**Tutorial**
- D-T1: Full-screen onboarding `PageView` (4 slides), first launch only. Skippable via top-right button.
- D-T2: Slides: Welcome → Drag & Drop → Scoring → Hints.
- D-T3: Welcome → Tutorial (first launch only) → Home. `UserPrefsRepository.getTutorialSeen()` checked after anthem starts.

**Hints**
- D-H1: `AnimationController` tween on `TransformationController` matrix. Zoom to target state's centroid at ~2.5× zoom.
- D-H2: Stay zoomed in after glow ends. No reverse animation.
- D-H3: Hint glow color `0xFFBBFF44` yellow-green. `UsaMapPainter` gains `hintPostal: String?`.

**Session Restore**
- D-S1: Prominent card at top of home screen (above mode cards). Shows mode, score, elapsed, states placed. Two buttons: "Continue" and "Dismiss."
- D-S2: Auto-dismisses when new game starts. Reads from `GameStateRepository.loadSession()` on each home screen build.

### Claude's Discretion
- Exact timing curve for `Matrix4Tween` zoom (e.g., `Curves.easeInOut` vs `Curves.fastOutSlowIn`).
- `AnimatedSwitcher` or `AnimatedContainer` transition for tutorial `PageView`.
- Welcome screen title/subtitle copy and CTA label.
- Tutorial slide illustration/icon choices.
- Stagger timing distribution (uniform random vs. weighted center-first).
- `shouldRepaint` logic for welcome screen `CustomPainter`.
- Whether `fadeOutAnthem()` is a new method or replaces `stopAnthem()` in the interface.

### Deferred Ideas (OUT OF SCOPE)
- AdMob + mediation (v2)
- Rewarded-ad hint refill (v2)
- Gated social sharing (v2)
- Mode 5 Speed Typing (v2)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WEL-01 | Premium opening screen with stylized USA vector silhouette (no spinning globe) | CustomPainter stagger animation pattern documented in §Pattern 1 |
| WEL-02 | Self-rendered, rights-clean Star-Spangled Banner instrumental plays on opening screen | FluidSynth CLI pipeline + MIDI/SF2 sources documented in §Anthem Rendering Pipeline |
| WEL-03 | Anthem fades out seamlessly when transitioning from opening screen | Volume ramp via AnimationController + setVolume() documented in §Pattern 3 |
| HINT-01 | 2 hints per round; using one animates zoom to centroid with ~3-second highlight glow | Matrix4Tween + TransformationController pattern documented in §Pattern 4 |
| HINT-02 | Each hint adds +5 score penalty (no rewarded-ad refill in v1) | Already implemented in `useHint()` — Phase 5 only wires the animation |
| SESS-04 | 4-step skippable tutorial runs once; "seen" flag persists | PageView onboarding pattern documented in §Pattern 5; `getTutorialSeen()` already exists |
| HOME-03 | On relaunch with saved session, home screen shows continue dialog | `loadSession()` already returns full session record; FutureBuilder/FutureProvider pattern documented |
| A11Y-01 | All interactive controls ≥48×48dp with Semantics labels | Flutter `meetsGuideline(androidTapTargetGuideline)` test documented in §Validation Architecture |
| A11Y-02 | Correct/incorrect outcomes multimodal (haptic + audio + visual), never color alone | Already implemented in Phase 4 (haptic + SFX + visual); Phase 5 audits and confirms |
</phase_requirements>

---

## Summary

Phase 5 is a polish and finishing phase. Most infrastructure is already in place: `UserPrefsRepository.getTutorialSeen()/setTutorialSeen()` exists, `GameStateRepository.loadSession()` exists, `RealAudioService._anthemPlayer` exists with `LoopMode.one`, `useHint()` returns `bool` and already applies the +5 penalty, and `MapScreen._controller` (`TransformationController`) is the exact object the hint zoom tween needs to animate. The phase wires these together and produces two new assets (anthem WAV, potentially a tutorial background).

The only non-trivial technical risk is the **anthem rendering pipeline**: FluidSynth is not pre-installed on the developer's Windows 11 machine and is not available via winget. Installation via Chocolatey (`choco install fluidsynth`) or direct download from GitHub Releases (pre-built Windows binary, v2.5.4 as of April 2026) is required. The MIDI source is the Wikimedia Commons public-domain file. The soundfont recommendation is GeneralUser GS (no attribution requirement for output audio, confirmed free commercial use) as a lightweight alternative to the MIT-licensed MuseScore General SF2 (requires attribution notice in LICENSES file).

The Flutter implementation work divides into six areas: (1) `WelcomeScreen` with stagger CustomPainter and anthem; (2) `TutorialScreen` PageView; (3) `AudioService` fade interface extension; (4) `MapScreen` hint zoom + glow; (5) `HomeScreen` session-restore card; (6) accessibility audit.

**Primary recommendation:** Anthem rendering is a one-time manual task (not automated code) — plan it as an isolated Wave 0 task with a concrete shell script, so it is complete before the welcome screen widget is wired to the real asset. All Flutter widget work can proceed in parallel once the audio shape (fade-in/out interface) is settled.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Welcome screen animation (stagger fill) | Frontend Widget | — | Pure CustomPainter + AnimationController in WelcomeScreen widget |
| Anthem playback + fade | Service Layer (`RealAudioService`) | Widget layer (WelcomeScreen calls service methods) | Audio lifecycle lives in service; fade logic belongs in service, not widget, so StubAudioService keeps interface parity |
| Tutorial first-launch check | Widget + Repository | — | WelcomeScreen reads `UserPrefsRepository`; navigation decision is in widget |
| Hint zoom animation | MapScreen widget | `GameSessionNotifier` (calls `useHint()`) | Matrix4Tween lives in MapScreen; score penalty lives in notifier |
| Hint glow render | `UsaMapPainter` | — | Single-parameter addition to existing painter; no new layer |
| Session restore card | HomeScreen widget | `GameStateRepository` | Card reads `loadSession()` on each build; no new state |
| Accessibility audit | All interactive widgets | — | Semantics labels added to existing widgets; automated via `meetsGuideline()` |
| COPPA re-audit (`aapt dump badging`) | Build / CI | — | Manual shell command; no Flutter code |

---

## Standard Stack

### Core (no new packages — existing stack only)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | `^3.3.1` | `ConsumerStatefulWidget` + `TickerProviderStateMixin` for animation controllers | Already in pubspec; all Phase 5 screens follow this pattern |
| `just_audio` | `^0.10.5` | `AudioPlayer.setVolume()` for anthem fade | Already wired in `RealAudioService`; `_anthemPlayer` already configured with `LoopMode.one` |
| `shared_preferences` | `^2.5.5` | `getTutorialSeen()` / `setTutorialSeen()` via `UserPrefsRepository` | Already in pubspec; repository already implemented |
| `go_router` | `^17.2.3` | `/welcome` initial route, `/tutorial` new route | Already wired in `app.dart`; Phase 5 adds two routes |
| `path_drawing` | `^1.0.1` | State paths already parsed into `dart:ui Path` objects at startup | No new usage; `StateData.path` already available |

**No new pub.dev packages are introduced in Phase 5.** All Flutter work uses existing dependencies.

### Off-Device Tools (anthem rendering pipeline — one-time use)

| Tool | Version | Purpose | Source |
|------|---------|---------|--------|
| FluidSynth | 2.5.4 | Render MIDI → WAV via SF2 soundfont | `choco install fluidsynth` or GitHub Releases binary |
| GeneralUser GS SF2 | 2.0.0+ | High-quality GM soundfont; no attribution on output audio | https://schristiancollins.com/generaluser.php |
| Star-Spangled Banner MIDI | Wikimedia (2012) | Public-domain MIDI source | https://en.wikipedia.org/wiki/File:2_Star_Spangled_Banner.mid |

**No Python packages required** for the anthem pipeline — FluidSynth is invoked directly as a CLI tool.

### Package Legitimacy Audit

> No new packages are installed by this phase. The existing pubspec is unchanged. Slopcheck not required.

| Package | Registry | Status |
|---------|----------|--------|
| (no new packages) | — | N/A |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
App launch
    │
    ▼
[app.dart] initialLocation: '/welcome'
    │
    ▼
[WelcomeScreen] ConsumerStatefulWidget
    ├─ initState:
    │     ├─ Start stagger AnimationController (repeat: false, ~1.5s total)
    │     └─ Call audioService.playAnthem() → wait 500ms fade-in via AnimationController
    ├─ CustomPaint(UsaWelcomePainter)  ← reads stateDataProvider (same FutureProvider as MapScreen)
    │     └─ Draws states white, fills in staggered by animValue progress
    └─ CTA "START" button:
          └─ audioService.fadeOutAnthem()  (~800ms async ramp)
          └─ userPrefsRepo.getTutorialSeen()
                ├─ false → context.go('/tutorial')
                └─ true  → context.go('/')
    │
    ▼ (first launch only)
[TutorialScreen] StatefulWidget + PageController
    ├─ PageView: 4 slides, swipe or "Next" button
    ├─ "Skip" button (top-right, always visible)
    └─ Both paths: userPrefsRepo.setTutorialSeen(true) → context.go('/')
    │
    ▼
[HomeScreen]
    ├─ FutureBuilder(gameStateRepository.loadSession())
    │     ├─ non-null → SessionRestoreCard (above mode cards)
    │     └─ null    → nothing
    └─ Mode cards (existing)
    │
    ▼ (hint pressed during game)
[MapScreen] — existing, extended
    ├─ onHintPressed: ref.read(gameSessionProvider.notifier).useHint()
    │     └─ true: trigger _hintZoomController.forward()
    │                └─ AnimationController + Matrix4Tween → TransformationController.value
    │                └─ setState(_hintPostal = _currentPostal)
    │                └─ Timer(3s) → setState(_hintPostal = null)
    └─ UsaMapPainter(hintPostal: _hintPostal)
              └─ If hintPostal != null → draw state with 0xFFBBFF44 fill
```

### Recommended Project Structure

```
lib/
├── features/
│   ├── welcome/
│   │   ├── welcome_screen.dart       # NEW — ConsumerStatefulWidget, stagger painter, anthem
│   │   └── usa_welcome_painter.dart  # NEW — stagger-fill silhouette CustomPainter
│   ├── tutorial/
│   │   └── tutorial_screen.dart      # NEW — PageView 4 slides, UserPrefsRepository
│   ├── home/
│   │   ├── home_screen.dart          # EXTEND — add session restore card
│   │   └── session_restore_card.dart # NEW — extracted card widget
│   └── map/
│       ├── map_screen.dart           # EXTEND — hint zoom AnimationController, hintPostal state
│       └── usa_map_painter.dart      # EXTEND — add hintPostal: String? parameter
├── core/
│   └── audio/
│       ├── audio_service.dart        # EXTEND — add fadeOutAnthem() or update stopAnthem() contract
│       ├── real_audio_service.dart   # EXTEND — implement volume ramp logic
│       └── stub_audio_service.dart   # EXTEND — no-op implementation for new method
test/
├── features/
│   ├── welcome/
│   │   └── welcome_screen_test.dart  # NEW — Wave 0 stub
│   └── tutorial/
│       └── tutorial_screen_test.dart # NEW — Wave 0 stub
assets/
└── audio/
    └── anthem.wav                    # REPLACE anthem_placeholder.wav (FluidSynth output)
```

### Pattern 1: Stagger-fill USA Silhouette (WEL-01)

**What:** `AnimationController` drives a float 0.0→1.0 over ~1.5s. A pre-shuffled list of 50 state indices is stored in `initState`. In `paint()`, for each state `i`, draw it filled if `animValue > i / 50.0` (or use per-state delay offsets of `i * (1.5s / 50) + random(0..20ms)` computed once in `initState`).

**When to use:** Welcome screen only. The same `stateDataProvider` FutureProvider used by `MapScreen` supplies the path data — no second JSON load.

**Example:**
```dart
// Source: Flags welcome_screen.dart pattern + D-W1/W2/W3 decisions
// initState:
_staggerController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1500),
);
// Pre-shuffle state indices once:
_staggerOrder = List.generate(states.length, (i) => i)..shuffle(_random);
// Random per-state delay offsets (uniform 0..20ms):
_staggerDelays = List.generate(states.length,
    (_) => (_random.nextDouble() * 20).round()); // ms

// In CustomPainter.paint():
//   animValue = controller.value (0.0 → 1.0)
//   For state at position k in _staggerOrder:
//     threshold = (k / stateCount) + (_staggerDelays[k] / totalDurationMs)
//     draw white if animValue >= threshold
```

**`shouldRepaint`:** Must compare `animValue` (a double) — use `(old.animValue - animValue).abs() > 0.001`.

### Pattern 2: Anthem Rendering Pipeline (WEL-02, D-A1)

**What:** One-time off-device CLI task to produce `anthem.wav` from a public-domain MIDI file via FluidSynth. Output replaces `assets/audio/anthem_placeholder.wav`.

**Concrete commands:**

Step 1 — Install FluidSynth on Windows (choose one):
```powershell
# Option A: Chocolatey (requires choco installed)
choco install fluidsynth

# Option B: GitHub direct download (pre-built Windows binary)
# Download fluidsynth-2.5.4-win64.zip from:
# https://github.com/FluidSynth/fluidsynth/releases/tag/v2.5.4
# Extract, add to PATH.
```

Step 2 — Download assets:
```powershell
# Star-Spangled Banner MIDI (public domain, Wikimedia Commons):
# https://commons.wikimedia.org/wiki/File:2_Star_Spangled_Banner.mid
# Save as: scripts/anthem/star_spangled_banner.mid

# GeneralUser GS SF2 (free commercial use, no attribution on output):
# https://schristiancollins.com/generaluser.php
# Save as: scripts/anthem/GeneralUser_GS.sf2
```

Step 3 — Render:
```powershell
# Render MIDI → WAV at 44100 Hz, gain 0.8 (prevents clipping)
fluidsynth -ni -F scripts/anthem/anthem_rendered.wav -r 44100 -g 0.8 `
    scripts/anthem/GeneralUser_GS.sf2 `
    scripts/anthem/star_spangled_banner.mid

# Copy output to assets:
Copy-Item scripts/anthem/anthem_rendered.wav assets/audio/anthem_placeholder.wav
```

**Expected output:** ~90–120s instrumental WAV at ~16 MB (44100 Hz / 16-bit stereo). This is acceptable for a bundled asset; mobile bundle size is primarily driven by the SF2 not being bundled.

**FluidSynth flags used:** [VERIFIED: https://www.fluidsynth.org/wiki/UserManual/]
- `-n` — disable MIDI in
- `-i` — non-interactive (exit when done)
- `-F <file>` — fast-render output file
- `-r 44100` — sample rate
- `-g 0.8` — gain (default 0.2 is too quiet; 1.0 can clip brass; 0.8 is safe)

**LICENSES.md entry required:** Per ROADMAP Phase 1 success criterion 4, `LICENSES` must document anthem provenance. Add:
```
anthem.wav — Star-Spangled Banner (Francis Scott Key, 1814, public domain composition).
MIDI source: Wikimedia Commons, 2_Star_Spangled_Banner.mid by Hyacinth (2012),
released under Creative Commons Public Domain Mark 1.0.
Rendered using FluidSynth 2.5.4 with GeneralUser GS soundfont by S. Christian Collins
(free for commercial use; see https://schristiancollins.com/generaluser.php).
```

### Pattern 3: Anthem Volume Fade (WEL-03, D-A2, D-A3)

**What:** Implement `fadeInAnthem()` (500ms, 0.0→1.0) and `fadeOutAnthem()` (800ms, current→0.0) using a `Timer.periodic` loop calling `_anthemPlayer.setVolume()`. The `AnimationController` approach is cleaner but requires `TickerProvider`, which `RealAudioService` does not have. Timer.periodic at 20ms intervals (25 ticks for 500ms, 40 ticks for 800ms) is the pragmatic choice for a pure-Dart service class.

**Concrete implementation in `RealAudioService`:**
```dart
// Source: just_audio AudioPlayer.setVolume() API + Timer.periodic pattern
// [VERIFIED: https://pub.dev/documentation/just_audio/latest/just_audio/AudioPlayer-class.html]

Timer? _fadeTimer;

Future<void> fadeInAnthem() async {
  if (!_initialized) return;
  _fadeTimer?.cancel();
  double volume = 0.0;
  const int ticks = 25;         // 25 × 20ms = 500ms
  const tickInterval = Duration(milliseconds: 20);
  await _anthemPlayer.setVolume(0.0);
  await _anthemPlayer.seek(Duration.zero);
  unawaited(_anthemPlayer.play());
  _fadeTimer = Timer.periodic(tickInterval, (timer) async {
    volume = math.min(1.0, volume + 1.0 / ticks);
    try { await _anthemPlayer.setVolume(volume); } catch (_) {}
    if (volume >= 1.0) timer.cancel();
  });
}

Future<void> fadeOutAnthem() async {
  if (!_initialized) return;
  _fadeTimer?.cancel();
  double volume = 1.0;
  const int ticks = 40;         // 40 × 20ms = 800ms
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

**`AudioService` interface change:** Replace `playAnthem()` + `stopAnthem()` with `fadeInAnthem()` + `fadeOutAnthem()`. `StubAudioService` gets no-op implementations of both new methods. `audio_service_test.dart` adds assertions for both.

**Muted state interaction:** When the app is muted, `setMuted(true)` already sets `_anthemPlayer.setVolume(0.0)`. Fade logic should check `_isMuted` flag (or skip volume set entirely when muted). Simplest approach: fade functions no-op when `_isMuted == true`.

### Pattern 4: Hint Zoom Animation (HINT-01, D-H1)

**What:** `MapScreen` adds a `_hintZoomController` (`AnimationController`, 400ms) and a `Matrix4Tween` from `_controller.value` to a computed target matrix. The target matrix centers the hint state's centroid on screen at 2.5× zoom.

**Computing the target Matrix4:**
```dart
// Source: InteractiveViewer TransformationController API
// [CITED: https://api.flutter.dev/flutter/widgets/InteractiveViewer/transformationController.html]

Matrix4 _computeHintMatrix(Offset sceneCentroid) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return _controller.value;

  const double targetZoom = 2.5;
  final double zoomBase = _minScale; // fit-to-screen scale
  final double newScale = (zoomBase * targetZoom).clamp(_minScale, _maxScale);

  // Target: centroid at screen center
  final double tx = box.size.width / 2  - sceneCentroid.dx * newScale;
  final double ty = box.size.height / 2 - sceneCentroid.dy * newScale;

  return Matrix4.identity()
    ..setEntry(0, 0, newScale)
    ..setEntry(1, 1, newScale)
    ..setEntry(2, 2, newScale)  // Pitfall 1: always set (2,2)
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
}
```

**Animation wiring:**
```dart
// In _onHintPressed():
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
      curve: Curves.easeInOut,      // Claude's discretion
    ));
_hintZoomController
  ..reset()
  ..forward();

// 3-second glow window — clear hintPostal after glow:
_hintGlowTimer?.cancel();
_hintGlowTimer = Timer(const Duration(seconds: 3), () {
  if (mounted) setState(() => _hintPostal = null);
});
```

**AnimatedBuilder hook:** Add `_hintZoomAnimation?.addListener(() { if (mounted) _controller.value = _hintZoomAnimation!.value; });` or use an `AnimatedBuilder` listening to `_hintZoomController` that sets `_controller.value`. The direct listener approach is simpler; dispose the listener in `dispose()`.

**`UsaMapPainter` change:** Add `hintPostal: String?` constructor parameter. In `paint()`, after drawing matched states, if `hintPostal != null`, draw that state with fill color `const Color(0xFFBBFF44)` (ported from `HighlightPainter._drawHintHighlight()`). Add `hintPostal` to `shouldRepaint` comparison.

### Pattern 5: First-Launch Tutorial (SESS-04, D-T1/T2/T3)

**What:** `TutorialScreen` is a `StatefulWidget` with a `PageController`. Four slides are static const data (icon, title, body). Skip button and Next/Done button use `context.go('/')` preceded by `setTutorialSeen(true)`.

**Structure:**
```dart
// Source: Flutter PageView API [ASSUMED]
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(icon: Icons.map, title: 'Learn all 50 states!', body: '...'),
    _SlideData(icon: Icons.touch_app, title: 'Drag & Drop', body: '...'),
    _SlideData(icon: Icons.sports_golf, title: 'Golf Scoring', body: '...'),
    _SlideData(icon: Icons.lightbulb, title: 'Use Your Hints', body: '...'),
  ];

  Future<void> _finish() async {
    final repo = await ref.read(userPrefsRepositoryProvider.future);
    await repo.setTutorialSeen(true);
    if (mounted) context.go('/');
  }
  // ...PageView + Skip button + Next/Done button
}
```

**Critical invariant (from CONTEXT.md specifics):** Both the "Skip" button AND the "Done" button on the last slide MUST call `setTutorialSeen(true)` before navigating. A common bug is missing the skip path — test both.

**`WelcomeScreen` routing logic:**
```dart
// After CTA tapped and fade-out initiated:
Future<void> _onStartPressed() async {
  await ref.read(audioServiceProvider).fadeOutAnthem();
  final repo = await ref.read(userPrefsRepositoryProvider.future);
  final seen = await repo.getTutorialSeen();
  if (!mounted) return;
  if (seen) {
    context.go('/');
  } else {
    context.go('/tutorial');
  }
}
```

### Pattern 6: Session Restore Card (HOME-03, D-S1/D-S2)

**What:** `HomeScreen._buildBody()` wraps `GameStateRepository.loadSession()` in a `FutureBuilder`. When the result is non-null, a `SessionRestoreCard` widget is inserted at the top of the Column, above the mode cards ListView.

**Concrete pattern:**
```dart
// In _buildBody():
FutureBuilder<({GameSession session, int hintPenalty})?>( 
  future: ref.read(gameStateRepositoryProvider.future).then((r) => r.loadSession()),
  builder: (context, snapshot) {
    final savedSession = snapshot.data;
    return Column(
      children: [
        if (savedSession != null)
          SessionRestoreCard(
            session: savedSession.session,
            onContinue: () => context.go('/play', extra: savedSession.session.mode),
            onDismiss: () async {
              final repo = await ref.read(gameStateRepositoryProvider.future);
              await repo.clearSession();
              if (mounted) setState(() {});  // rebuild to remove card
            },
          ),
        // ... existing mode cards
      ],
    );
  },
)
```

**Important:** `GameSessionNotifier.restoreGame()` already exists and handles session restoration (Phase 2, D-09: `restoreGame()` lands in `GamePhase.paused`). The "Continue" button should navigate to `/play` with the mode, and `MapScreen` must detect the restore case. Research suggests the simplest path: the "Continue" button calls `ref.read(gameSessionProvider.notifier).restoreGame(session, hintPenalty)` then `context.go('/play', extra: session.mode)`.

**Elapsed time format:** Use the same `_formatElapsed(Duration d)` helper as `GameHud` — `'${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}'`.

### Anti-Patterns to Avoid

- **Calling `fadeOutAnthem()` and then immediately navigating:** The fade is async (~800ms). Either await it (but use a mounted guard) or navigate after the fade completes via a callback. Navigation should happen inside `whenComplete` or after an `await`.
- **Multiple `AnimationController` dispose without null check:** Phase 5 adds `_hintZoomController` alongside `_staggerController` in `WelcomeScreen`. Always dispose in `dispose()` in the same order as creation.
- **`Matrix4Tween` with `Matrix4.inverted` start:** The gladimdim.org article shows `Matrix4.inverted(_controller.value)` as the begin value. This is an alternative coordinate model for map games. For this codebase, which uses the direct `_controller.value = matrix` pattern (established in Phase 3 `_fitMapToScreen()` and `_zoom()`), the begin value should be `_controller.value.clone()` — NOT inverted. Using the wrong model will animate in the wrong direction.
- **Setting `hintPostal` in `UsaMapPainter` after game completion:** If the game completes while a hint glow is active, `_hintGlowTimer` fires after `dispose()`. Always cancel `_hintGlowTimer` in `MapScreen.dispose()`.
- **`setTutorialSeen()` called only on the last slide "Done" tap:** Skip must also set the flag. Unit-testable via `TutorialScreen` widget test with `pumpAndSettle` + tap "Skip".

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Anthem fade-in/out | Custom audio tween class | `Timer.periodic` + `AudioPlayer.setVolume()` | just_audio has no built-in fade; 20ms Timer.periodic is the ecosystem idiom and matches the service's Dart-only nature (no `TickerProvider`) |
| Tutorial "seen" persistence | Custom file-based flag | `UserPrefsRepository.getTutorialSeen()` / `setTutorialSeen()` | Already implemented and tested in Phase 2 |
| Session data on home screen | Custom session model | `GameStateRepository.loadSession()` returns full record | Already implemented and tested in Phase 2 |
| Hint glow rendering | Separate `OverlayEntry` layer | `hintPostal` parameter in `UsaMapPainter` | The painter already controls all state fill colors; a single extra parameter is simpler and avoids z-order issues |
| Accessibility tap-target enforcement | Manual size checks | `meetsGuideline(androidTapTargetGuideline)` in widget tests | Flutter's built-in `AccessibilityGuideline` API automates this |
| MIDI-to-WAV conversion | Python synthesis code | FluidSynth CLI | FluidSynth is the canonical MIDI renderer; `midi2audio` Python wrapper adds no value over the direct CLI |

**Key insight:** Phase 5 is primarily wiring, not building. The risk of over-engineering is higher than the risk of under-delivering — every listed capability has a pre-built hook waiting to be connected.

---

## Common Pitfalls

### Pitfall 1: Matrix4 Entry (2,2) Omitted in Hint Zoom Target

**What goes wrong:** Hint zoom target matrix computed without `..setEntry(2, 2, newScale)`. The `InteractiveViewer` uses the z-scale for internal consistency; without it, the zoom FAB label (`_currentScale`) shows wrong values and the map may jitter on subsequent user pan.

**Why it happens:** Phase 3 and 4 comments call this "Pitfall 1" explicitly (`// Pitfall 1: _zoom() MUST set m.setEntry(2, 2, newScale)`). Easy to forget in new Matrix4 construction in Phase 5.

**How to avoid:** Copy `_fitMapToScreen()` matrix construction as the template for `_computeHintMatrix()`.

### Pitfall 2: FluidSynth Default Gain Is Too Low

**What goes wrong:** Rendering without `-g` flag uses FluidSynth's default gain of 0.2. The output WAV is extremely quiet — `just_audio` plays it at near-inaudible volume even at `setVolume(1.0)`.

**Why it happens:** FluidSynth default is tuned for interactive MIDI playback with a sound card, not for producing normalized WAV for mobile.

**How to avoid:** Use `-g 0.8` in the render command. Verify by playing the output WAV on desktop before bundling.

### Pitfall 3: `setTutorialSeen()` Not Called on Skip

**What goes wrong:** Tutorial shows again on every launch even after the user presses "Skip."

**Why it happens:** Developers add `setTutorialSeen(true)` only to the "Done" completion path.

**How to avoid:** Extract a `_completeTutorial()` method called by both paths. Test both with widget tests.

### Pitfall 4: `_hintGlowTimer` Not Cancelled in `dispose()`

**What goes wrong:** Timer fires after `MapScreen` is disposed; `setState()` call crashes with "setState() called after dispose()."

**Why it happens:** `Timer` is not a `Listenable` — it does not auto-cancel on widget disposal.

**How to avoid:** Add `_hintGlowTimer?.cancel()` to `MapScreen.dispose()` alongside `_hintZoomController.dispose()`.

### Pitfall 5: `fadeOutAnthem()` Awaited Synchronously in CTA Handler

**What goes wrong:** `onPressed: () async { await audioService.fadeOutAnthem(); context.go('/tutorial'); }` freezes the CTA button for 800ms before navigating. Visual feedback appears broken.

**Why it happens:** Fade is 800ms; awaiting it holds the UI thread in the callback.

**How to avoid:** Fire-and-forget the fade, then navigate after a fixed delay, or schedule the navigation inside the Timer callback of the fade:

```dart
onPressed: () {
  audioService.fadeOutAnthem();  // fire and forget
  Future.delayed(const Duration(milliseconds: 850), () async {
    if (!mounted) return;
    final seen = await repo.getTutorialSeen();
    if (!mounted) return;
    context.go(seen ? '/' : '/tutorial');
  });
},
```

### Pitfall 6: WelcomeScreen `CustomPainter` Requests Rebuild on Every Frame

**What goes wrong:** `shouldRepaint` always returns `true` because `animValue` is a `double` compared with `!=` instead of a threshold. The painter repaints 60×/s even when the animation is complete.

**Why it happens:** Flutter calls `shouldRepaint` on every build; naive equality on doubles is unreliable.

**How to avoid:** Use `(old.animValue - animValue).abs() > 0.001`. When the stagger animation completes, all states are visible and `animValue` is pinned at 1.0 — no repaints needed.

### Pitfall 7: Anthem Asset Name in `pubspec.yaml` After Rename

**What goes wrong:** The anthem file is renamed from `anthem_placeholder.wav` to `anthem.wav` but `pubspec.yaml` declares `assets/audio/` (directory-level), so Flutter auto-discovers it. However, `RealAudioService.init()` calls `setAsset('assets/audio/anthem_placeholder.wav')` — the hardcoded string must be updated.

**How to avoid:** When replacing the file, also update the `setAsset()` call. Phase 5 plan must include both file replacement and code update in the same task.

---

## Code Examples

### Stagger Controller Initialization

```dart
// Source: Flags welcome_screen.dart SingleTickerProviderStateMixin pattern
// [CITED: C:\code\Claude\FlagsRoundTheWorld\lib\features\home\welcome_screen.dart]
// Welcome screen uses ConsumerStatefulWidget + TickerProviderStateMixin (not Single-)
// because it also needs the audio fade Timer and potentially a second controller.
class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  final _random = math.Random();
  late final List<int> _staggerOrder;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();  // run once, no repeat
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }
}
```

### Hint Glow in `UsaMapPainter.paint()`

```dart
// Source: HighlightPainter._drawHintHighlight() — direct port
// [CITED: C:\code\Claude\FlagsRoundTheWorld\lib\features\map\highlight_painter.dart]
// Added at end of paint() after matched-state rendering:
if (hintPostal != null) {
  final hintState = states.firstWhereOrNull((s) => s.postal == hintPostal);
  if (hintState != null) {
    final hintPaint = Paint()
      ..color = const Color(0xFFBBFF44)  // D-H3 locked color
      ..style = PaintingStyle.fill;
    canvas.drawPath(hintState.path, hintPaint);
  }
}
```

### Accessibility Guideline Test

```dart
// Source: Flutter accessibility-testing docs
// [CITED: https://docs.flutter.dev/ui/accessibility/accessibility-testing]
testWidgets('A11Y-01: all tap targets meet 48dp Android guideline', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: HomeScreen())));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
});
```

### COPPA Re-verification Command

```powershell
# Verify AD_ID permission remains absent from release APK
# [ASSUMED] — aapt path varies by Android SDK installation
& "$env:ANDROID_HOME\build-tools\<version>\aapt.exe" dump badging `
    build\app\outputs\flutter-apk\app-release.apk | Select-String "AD_ID"
# Expected output: nothing (no match)
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| `audioplayers` | `just_audio` | Project decision (CLAUDE.md); `just_audio` is already in use |
| `introduction_screen` package | Hand-rolled `PageView` | CONTEXT.md explicitly rules out third-party onboarding libs; `PageView` is 30 lines |
| Firebase Analytics for onboarding flow tracking | Not tracked | COPPA prohibition; no analytics in v1 |
| Runtime SVG parsing for welcome silhouette | Reuse `usa_states_paths.json` paths | Already proven in Phase 3; no separate asset needed |

**Deprecated/outdated:**
- `audioplayers`: Do not use — CLAUDE.md explicitly prohibits it.
- `introduction_screen` pub.dev package: Not needed — PageView pattern is simpler and adds no dependency.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | FluidSynth `-g 0.8` produces adequate volume without clipping for SSB | §Pattern 2 | Anthem too loud or too quiet; adjust gain and re-render (low cost, offline task) |
| A2 | GeneralUser GS soundfont trumpet/brass patches produce an acceptable orchestral rendering of SSB | §Pattern 2 | Anthem sounds thin or wrong timbre; switch to MuseScore General SF2 (MIT-licensed, requires attribution) |
| A3 | `Matrix4.identity()..setEntry(0,0,s)..setEntry(1,1,s)..setEntry(2,2,s)..setEntry(0,3,tx)..setEntry(1,3,ty)` correctly positions the hint state centroid at screen center | §Pattern 4 | Hint zoom lands off-center; debug by logging centroid vs. screen center post-animation |
| A4 | Tutorial `PageView` slides in horizontal swipe direction by default (not vertical) | §Pattern 5 | Slides scroll vertically instead of horizontally; fix via `scrollDirection: Axis.horizontal` (default) |
| A5 | The Wikimedia Commons MIDI file produces a complete rendition of SSB (not truncated) | §Anthem Rendering Pipeline | Anthem cuts off mid-song; download a different MIDI source |
| A6 | `just_audio` 0.10.5 `setVolume()` calls from a `Timer.periodic` handler do not produce audible stepping artifacts at 20ms intervals | §Pattern 3 | Volume ramp sounds stepped; reduce interval to 10ms (50 ticks) |

---

## Open Questions

1. **Should `playAnthem()` be replaced by `fadeInAnthem()`, or should `playAnthem()` remain and `fadeInAnthem()` be added as a separate interface method?**
   - What we know: `StubAudioService` currently implements `playAnthem()` and `stopAnthem()`. Replacing them breaks the existing interface test.
   - What's unclear: Whether the planner wants a clean rename (two new methods, remove two old) or an additive approach (keep old methods, add new fade variants).
   - Recommendation: Replace `playAnthem()` → `fadeInAnthem()` and `stopAnthem()` → `fadeOutAnthem()` in a single interface update. The existing `audio_service_test.dart` test calls both; update it in the same task. This is cleaner than having duplicate methods.

2. **Should `SessionRestoreCard`'s "Continue" button use `restoreGame()` + navigate, or navigate and let `MapScreen.initState` detect the session?**
   - What we know: `GameSessionNotifier.restoreGame()` exists and puts the session in `GamePhase.paused`. `MapScreen._startSequence()` is called from `_buildMapStack`, not `initState`, so a pre-loaded session would need different initialization logic.
   - What's unclear: Whether the current `MapScreen._startSequence()` can be short-circuited for a restored session.
   - Recommendation: Call `restoreGame(session, hintPenalty)` on the notifier from `HomeScreen` before navigating, then `MapScreen` detects `GamePhase.paused` and skips re-shuffling. This matches how Phase 2 designed the restore flow.

3. **What file name should replace `anthem_placeholder.wav`?**
   - Options: Keep `anthem_placeholder.wav` (no code change needed) vs. rename to `anthem.wav` (cleaner but requires code update).
   - Recommendation: Rename to `anthem.wav` to remove the "placeholder" ambiguity. Update `RealAudioService.init()` `setAsset()` call in the same task.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All Flutter work | Yes | 3.44.0 | — |
| Python 3 | (None — anthem pipeline is CLI only) | Yes | 3.13.13 | — |
| FluidSynth | Anthem rendering (D-A1) | No | — | Install via GitHub release binary or chocolatey |
| winget | Package installation | Yes | v1.28.240 | — |
| chocolatey | FluidSynth install (Option A) | No | — | Use GitHub release binary (Option B) |
| Star-Spangled Banner MIDI | Anthem rendering | No (download required) | — | Download from Wikimedia Commons |
| GeneralUser GS SF2 | Anthem rendering | No (download required) | — | MuseScore General SF2 (MIT, attribution required) |
| `aapt` (Android build tools) | COPPA re-audit | Not verified | — | Available after `flutter build apk` via $ANDROID_HOME/build-tools/ |

**Missing dependencies with no fallback:**
- FluidSynth must be installed before the anthem rendering task can run. Plan must include an install step.

**Missing dependencies with fallback:**
- GeneralUser GS SF2: if unavailable or license concern, MuseScore General SF2 is MIT-licensed (requires attribution note in LICENSES file, which is already required).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + `mocktail` 1.0.5 |
| Config file | None — standard `flutter test` |
| Quick run command | `flutter test test/features/welcome/ test/features/tutorial/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WEL-01 | Welcome screen renders without error; stagger painter smoke test | Widget | `flutter test test/features/welcome/welcome_screen_test.dart` | Wave 0 |
| WEL-02 | Anthem asset exists and is non-empty at correct path | File check (test) | `flutter test test/features/welcome/welcome_screen_test.dart` | Wave 0 |
| WEL-03 | `RealAudioService.fadeOutAnthem()` completes without throwing; `StubAudioService` no-op | Unit | `flutter test test/core/audio/audio_service_test.dart` | Extend existing |
| HINT-01 | `MapScreen` hint zoom triggers animation and sets `hintPostal`; glow clears after 3s | Widget (manual) | Manual test only — Timer-based glow is hard to automated-test without fake async | Manual |
| HINT-02 | `useHint()` already tested in Phase 2 | Unit | `flutter test test/features/game/game_session_notifier_test.dart` | Exists |
| SESS-04 | Tutorial shown on first launch; not shown on second launch; both Skip and Done set seen flag | Widget | `flutter test test/features/tutorial/tutorial_screen_test.dart` | Wave 0 |
| HOME-03 | Home screen shows restore card when `loadSession()` returns non-null; card hidden when null | Widget | `flutter test test/features/home/home_screen_test.dart` | Extend existing |
| A11Y-01 | All interactive controls ≥48dp, all labeled | Widget (guideline) | `flutter test test/features/welcome/welcome_screen_test.dart` (includes `meetsGuideline`) | Wave 0 |
| A11Y-02 | Multimodal feedback already in Phase 4; confirm no color-only states | Manual audit | Manual review of `_handleDrop` | Manual |

### Sampling Rate

- **Per task commit:** `flutter test test/features/welcome/ test/features/tutorial/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/features/welcome/welcome_screen_test.dart` — covers WEL-01, A11Y-01
- [ ] `test/features/tutorial/tutorial_screen_test.dart` — covers SESS-04 (skip path + done path)
- [ ] Extend `test/features/home/home_screen_test.dart` — cover HOME-03 (restore card shown/hidden)
- [ ] Extend `test/core/audio/audio_service_test.dart` — add `fadeInAnthem()` and `fadeOutAnthem()` interface-parity assertions

---

## Security Domain

> `security_enforcement` is not explicitly set to `false` in config.json — treating as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No accounts, no login |
| V3 Session Management | No | Local game session only; no server sessions |
| V4 Access Control | No | No user roles |
| V5 Input Validation | No | No user text input in Phase 5 (tutorial is read-only, welcome is read-only) |
| V6 Cryptography | No | No new cryptographic operations |
| V2/V3 COPPA | Yes | No persistent identifiers; `AD_ID` blocked; re-verified via `aapt dump badging` in Phase 5 exit criteria |

### Known Threat Patterns for Phase 5

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `anthem.wav` bundled asset probing (user extracts APK to access MIDI IP) | Info Disclosure | Composition is public domain; only rendering matters — no secret content |
| Tutorial "seen" flag tampering (user deletes SharedPreferences) | Spoofing | Non-issue — showing the tutorial again is the failure mode, not a security risk |
| `fadeOutAnthem()` Timer not cancelled → plays in background after navigation | Denial of Service | Cancel `_fadeTimer` in `dispose()` of `RealAudioService` and on second fade call entry |

---

## Sources

### Primary (HIGH confidence)
- `C:\code\Claude\StateTheStates\lib\core\audio\real_audio_service.dart` — `_anthemPlayer` setup, current `playAnthem()`/`stopAnthem()` contract confirmed by direct read
- `C:\code\Claude\StateTheStates\lib\core\audio\audio_service.dart` — interface confirmed by direct read
- `C:\code\Claude\StateTheStates\lib\core\data\user_prefs_repository.dart` — `getTutorialSeen()`/`setTutorialSeen()` confirmed implemented
- `C:\code\Claude\StateTheStates\lib\core\data\game_state_repository.dart` — `loadSession()` return type confirmed
- `C:\code\Claude\StateTheStates\lib\features\map\map_screen.dart` — `_controller`, `_ivKey`, hint no-op, `_fitMapToScreen()` Matrix4 pattern confirmed
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\highlight_painter.dart` — `_drawHintHighlight()` color `0xFFBBFF44` and fill pattern confirmed
- `C:\code\Claude\FlagsRoundTheWorld\lib\features\home\welcome_screen.dart` — gradient colors, structure to port confirmed
- https://www.fluidsynth.org/wiki/UserManual/ — `-ni -F -r -g` flag semantics confirmed (VERIFIED)
- https://docs.flutter.dev/ui/accessibility/accessibility-testing — `androidTapTargetGuideline`, `labeledTapTargetGuideline` API confirmed (VERIFIED)
- https://en.wikipedia.org/wiki/File:2_Star_Spangled_Banner.mid — Public domain CC0 license confirmed (VERIFIED)

### Secondary (MEDIUM confidence)
- https://schristiancollins.com/generaluser.php — GeneralUser GS free commercial use, no required attribution on rendered audio (VERIFIED via community license text at https://scancode-licensedb.aboutcode.org/generaluser-gs-2.0.html)
- https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/MuseScore_General_License.md — MuseScore General SF2 MIT license with attribution required (VERIFIED)
- https://community.chocolatey.org/packages/fluidsynth — FluidSynth 2.4.7 available via Chocolatey (winget search found no result on this machine)
- https://github.com/FluidSynth/fluidsynth/releases — FluidSynth 2.5.4 latest release with Windows pre-built binary confirmed (VERIFIED)

### Tertiary (LOW confidence)
- gladimdim.org Flutter InteractiveViewer animation article — Matrix4 translation math for centering a point (caution: uses inverted matrix model, not applicable here); verified to use `Matrix4.identity()..translate()` approach which is compatible with this codebase's coordinate model with sign adjustment

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all existing libraries confirmed in pubspec and test-verified
- Architecture: HIGH — all integration points confirmed by direct codebase reads; patterns match Phase 3/4 established conventions
- Anthem pipeline: MEDIUM — FluidSynth CLI flags verified via official docs; rendering quality assumptions (gain value, SF2 quality) are [ASSUMED]
- Pitfalls: HIGH — derived from Phase 3/4 accumulated context (Pitfall 1, 4 are project-specific, documented in code comments)

**Research date:** 2026-06-01
**Valid until:** 2026-07-01 (Flutter 3.44 stable; just_audio 0.10.5 stable; FluidSynth 2.5.4)
