# Architecture Research

**Domain:** Flutter educational drag-and-drop map game (USA variant)
**Researched:** 2026-05-30
**Confidence:** HIGH — based on direct line-by-line reading of the Flags Around the World reference codebase

---

## Standard Architecture

### System Overview

```
┌───────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER  (lib/features/)                               │
│  ┌──────────┐  ┌─────────────────────────────────────────────┐    │
│  │  home/   │  │                map/                          │    │
│  │HomeScreen│  │  MapScreen (ConsumerStateful)                │    │
│  │WelcomeScr│  │  ┌──────────┐ ┌────────────┐ ┌──────────┐  │    │
│  └──────────┘  │  │GameHud   │ │StatePainter│ │ StateTray│  │    │
│  ┌──────────┐  │  │          │ │(CustomPaint│ │(Draggable│  │    │
│  │  game/   │  │  └──────────┘ │ + Highlight│ │ outside  │  │    │
│  │GameSession│  │              │ Painter)   │ │ IV)      │  │    │
│  │Notifier  │  │              └────────────┘ └──────────┘  │    │
│  │GameHud   │  │  InteractiveViewer (DragTargets inside)     │    │
│  │StateTray │  └─────────────────────────────────────────────┘    │
│  └──────────┘  ┌──────────┐                                       │
│                │  ads/     │  ← walled garden; no import into     │
│                │(stub only │    GameSessionNotifier                │
│                │ in v1)    │                                       │
│                └──────────┘                                       │
├───────────────────────────────────────────────────────────────────┤
│  STATE LAYER  (Riverpod AsyncNotifier)                             │
│  gameSessionProvider → GameSessionNotifier → GameSession (frozen) │
│  countryDataProvider → FutureProvider<List<StateData>>            │
│  countryNamesProvider → FutureProvider<Map<String,String>>        │
│  adServiceProvider   → Provider<AdService>  (StubAdService in v1) │
│  audioServiceProvider → Provider<AudioService>                    │
├───────────────────────────────────────────────────────────────────┤
│  CORE LAYER  (lib/core/)                                           │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐     │
│  │data/       │ │models/     │ │audio/      │ │ads/        │     │
│  │HighScore   │ │StateData   │ │AudioService│ │AdService   │     │
│  │UserPrefs   │ │BoundingBox │ │RealAudio   │ │StubAdSvc   │     │
│  │GameState   │ │(dart:ui    │ │StubAudio   │ │AdMobAdSvc  │     │
│  │StateData   │ │ Path)      │ │            │ │(Phase 6)   │     │
│  │Service     │ └────────────┘ └────────────┘ └────────────┘     │
│  └────────────┘                                                   │
│  ┌────────────┐                                                   │
│  │l10n/       │  ARB-generated AppLocalizations                   │
│  └────────────┘                                                   │
├───────────────────────────────────────────────────────────────────┤
│  ASSET PIPELINE  (build-time, not runtime)                        │
│  Natural Earth admin-1 US SVG → Python script →                   │
│  assets/map/usa_states_paths.json                                 │
│   { states: [{ abbr, paths:["M…Z"], boundingBox, centroid,        │
│               insetGroup }] }                                      │
└───────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | File path (lib/) | Responsibility | Communicates with |
|-----------|-----------------|----------------|-------------------|
| `MapScreen` | features/map/map_screen.dart | Root stateful widget; owns `TransformationController`, `_currentScale`, sequence list, hover ISO, tutorial/pause overlay state | reads `countryDataProvider`, reads/writes `gameSessionProvider`, calls `audioServiceProvider`, calls `adServiceProvider` (result screen only) |
| `UsaMapPainter` | features/map/usa_map_painter.dart | `CustomPainter`; draws state `dart:ui` Paths from `StateData.paths`; draws inset frame rects for AK/HI; paints abbreviation labels or full-name labels at `fontSize = targetPx / viewScale`; receives `matchedAbbrs`, `showLabels`, `labelMode`, `viewScale` | reads from `MapScreen` via constructor params; no Riverpod dependency |
| `HighlightPainter` | features/map/highlight_painter.dart | Second `CustomPainter` layer (willChange=true); hover gold fill, target-ring outline, hint highlight | receives `hoveredAbbr`, `targetAbbr`, `stateIndex`, `viewScale` as params |
| `hitTest()` | features/map/hit_detection.dart | Pure function; scene-space `Offset` → state abbreviation or null; scale-aware 48dp centroid expansion for micro-states (RI, DE, CT, etc.) | called by `MapScreen._handleDrop` and `onWillAcceptWithDetails` |
| `StateTray` | features/game/state_tray.dart | Single `Draggable<String>` token tray outside `InteractiveViewer`; shows full state name or blank per mode; emits drag data = state abbreviation; `kPinAnchor` offset corrects drop coordinate in `onAcceptWithDetails` | pure widget; receives `currentAbbr`, `stateName`, `showName`, `cardKey` |
| `GameHud` | features/game/game_hud.dart | Stateless HUD strip (48dp); score, elapsed timer MM:SS, progress bar, pause + mute buttons | receives all values as params; no Riverpod |
| `GameSessionNotifier` | features/game/game_session_notifier.dart | `AsyncNotifier<GameSession>`; owns `Ticker`, `_elapsedSeconds`, `_hintPenalty`; drives phase state machine (idle→countdown→playing→paused→completed); golf scoring; persistence on each correct drop | reads `gameStateRepositoryProvider`, `highScoreRepositoryProvider`; **zero imports from features/ads/** |
| `GameSession` | features/game/game_session.dart | Immutable value object; `phase`, `mode`, `score`, `elapsed`, `errorCount`, `hintsRemaining`, `matchedAbbrs` | used by notifier and `MapScreen` |
| `GameMode` | features/game/game_mode.dart | `enum { learn, statesMaster, geographicalMaster, grandMaster }` | drives `showLabels`, `showName`, `showTrayText` booleans in `MapScreen._buildMap` |
| `GamePhase` | features/game/game_phase.dart | `enum { idle, countdown, playing, paused, completed }` | drives timer and back-button guards |
| `StateDataService` | core/data/state_data_service.dart | Async JSON asset loader; `compute()` isolate for JSON decode; main-thread `Path` construction in chunks (yield every 30 states); exposes `stateDataProvider` and `stateNamesProvider` | `rootBundle`; `path_drawing` parseSvgPathData |
| `StateData` | core/models/state_data.dart | `isoCode` → renamed to `abbr` (2-letter); `paths`, `boundingBox`, `centroid`, `isDegenerate`, **`insetGroup` (enum: mainland / alaska / hawaii)** | pure data; no dependencies |
| `HighScoreRepository` | core/data/high_score_repository.dart | `SharedPreferences`-backed best score per `GameMode`; golf convention: lower is better (saves only if `score < current`) | called only from `GameSessionNotifier.completeGame()` and `MapScreen._advanceToNextState()` |
| `UserPrefsRepository` | core/data/user_prefs_repository.dart | Mute pref, tutorial-seen flag | called from `MapScreen._loadMuteState()` |
| `GameStateRepository` | core/data/game_state_repository.dart | JSON snapshot of `GameSession` in `SharedPreferences`; enables mid-game app-kill resume | called from `GameSessionNotifier.recordDrop()`, `useHint()`, `completeGame()` |
| `AudioService` | core/audio/audio_service.dart | Abstract interface; `init / playCorrect / playError / playAnthem / setMuted / dispose`; real impl uses `just_audio`; stub is a no-op | wired via `audioServiceProvider`; called from `MapScreen` and `WelcomeScreen` |
| `AdService` | core/ads/ad_service.dart | Abstract interface; `getBannerWidget / showInterstitialAd / showRewardedAd / showAppOpenAd`; `StubAdService` returns `SizedBox.shrink()` and `false` for all | **`GameSessionNotifier` has zero imports from ads**; only `MapScreen` (result path) and `app.dart` call it |

---

## Recommended Project Structure

```
lib/
├── app.dart                     # GoRouter definition, App ConsumerStatefulWidget
├── main.dart                    # ProviderScope, runApp
│
├── core/
│   ├── ads/
│   │   ├── ad_constants.dart    # Ad unit IDs (empty strings in v1)
│   │   ├── ad_load_state.dart   # enum AdLoadState { loading, loaded, failed }
│   │   ├── ad_service.dart      # abstract interface AdService
│   │   ├── ad_service_provider.dart  # Provider<AdService> → StubAdService in v1
│   │   ├── ads_initializer.dart # MobileAds.initialize() + COPPA flags (v6)
│   │   ├── admob_ad_service.dart # real impl (v6 only)
│   │   ├── app_state_observer.dart  # foreground/background stream
│   │   └── stub_ad_service.dart # no-op impl for v1–v5
│   │
│   ├── audio/
│   │   ├── audio_service.dart   # abstract interface AudioService
│   │   ├── audio_service_provider.dart  # Provider<AudioService>
│   │   ├── real_audio_service.dart  # just_audio impl; adds playAnthem()
│   │   └── stub_audio_service.dart  # test/CI no-op
│   │
│   ├── data/
│   │   ├── game_state_repository.dart   # session snapshot in SharedPreferences
│   │   ├── high_score_repository.dart   # best score per GameMode
│   │   ├── state_data_service.dart      # JSON loader; stateDataProvider + stateNamesProvider
│   │   └── user_prefs_repository.dart   # mute, tutorial_seen
│   │
│   ├── l10n/                    # ARB files + flutter gen-l10n output
│   ├── models/
│   │   └── state_data.dart      # StateData, BoundingBox, InsetGroup enum
│   └── ticker.dart              # Ticker / RealTicker (1-second interval)
│
├── features/
│   ├── ads/                     # (mirrors Flags; currently thin wrappers — real work in Phase 6)
│   │
│   ├── game/
│   │   ├── game_mode.dart       # enum GameMode
│   │   ├── game_phase.dart      # enum GamePhase
│   │   ├── game_session.dart    # immutable GameSession value object
│   │   ├── game_session_notifier.dart  # AsyncNotifier<GameSession>
│   │   ├── game_hud.dart        # HUD strip widget
│   │   └── state_tray.dart      # Draggable token tray (replaces flag_tray.dart)
│   │
│   ├── home/
│   │   ├── home_screen.dart     # mode-select + continue-game detection
│   │   └── welcome_screen.dart  # patriotic splash + anthem playback
│   │
│   └── map/
│       ├── map_screen.dart      # ConsumerStatefulWidget; orchestrates everything
│       ├── usa_map_painter.dart  # CustomPainter; fills + borders + labels
│       ├── highlight_painter.dart  # hover/hint/target-ring layer
│       ├── hit_detection.dart   # pure hitTest() function
│       ├── state_sequence.dart  # buildStateSequence() / buildGrandMasterSequence()
│       └── completion_screen.dart  # result + personal best + interstitial trigger
│
└── generated/
    └── l10n/                    # flutter gen-l10n output
```

### Structure Rationale

- **core/**: Pure logic, no Flutter widgets. Can be unit-tested without a widget tree. Audio and ads have stub/real splits so CI and Phase 1–5 builds run without AdMob or device audio.
- **features/game/**: `GameSessionNotifier` is the single source of truth for session state. It has **zero imports from features/ads/** — the ad walled-garden rule. Widgets that need ad behavior call `adServiceProvider` directly.
- **features/map/**: All map rendering is isolated here. `MapScreen` is the orchestrator widget; `UsaMapPainter` and `HighlightPainter` are pure `CustomPainter` subclasses with no Riverpod dependencies.
- **features/ads/**: Thin shell retained for structural parity with Flags. Real implementation lands in Phase 6.

---

## Architectural Patterns

### Pattern 1: Tray-Outside / DragTargets-Inside

**What:** The `StateTray` Draggable lives in a `Column` child that is a sibling of the `InteractiveViewer`, not a descendant. DragTargets are children of the `InteractiveViewer`'s content. Drop coordinates are recovered via `TransformationController.toScene(box.globalToLocal(details.offset + StateTray.kPinAnchor))`.

**When to use:** Always — this is a locked architectural decision. The alternative (`RenderBox.globalToLocal()` applied at the DragTarget level) produces incorrect coordinates under zoom because it transforms into the widget's local coordinate space, not the scene's coordinate space.

**Trade-offs:** Requires careful `kPinAnchor` bookkeeping. The pin-tip offset (`Offset(45, 70)` in Flags — `card_width/2, card_height + pin_height`) must match the feedback widget's actual geometry exactly. A mismatch produces drops that register slightly off from where the visual pin lands.

**Example:**
```dart
// MapScreen build — Column layout
Column(children: [
  GameHud(...),
  Expanded(
    child: InteractiveViewer(
      key: _ivKey,
      transformationController: _controller,
      constrained: false,
      child: SizedBox(
        width: 2000, height: 1400, // USA canvas dimensions
        child: Stack(children: [
          CustomPaint(painter: UsaMapPainter(...)),
          CustomPaint(painter: HighlightPainter(...)),
          DragTarget<String>(
            onAcceptWithDetails: (details) {
              // Recover scene point from global drop offset
              final scenePoint = _controller.toScene(
                (_ivKey.currentContext!.findRenderObject()! as RenderBox)
                    .globalToLocal(details.offset + StateTray.kPinAnchor),
              );
              final hit = hitTest(scenePoint, _states,
                  scale: _controller.value.getMaxScaleOnAxis());
              _handleDrop(hit, hit == _currentAbbr);
            },
          ),
        ]),
      ),
    ),
  ),
  StateTray(key: _trayKey, currentAbbr: _currentAbbr, ...),
])
```

### Pattern 2: Layered CustomPainter with RepaintBoundary

**What:** Two separate `CustomPainter`s on top of each other inside a `Stack`. The base painter (`UsaMapPainter`) has `isComplex: true` and no `willChange`. The top painter (`HighlightPainter`) has `willChange: true`. Each is wrapped in `RepaintBoundary`.

**When to use:** Always. The base map is expensive to paint (50 paths + labels) but only changes when `matchedAbbrs` changes. The highlight layer changes on every drag frame (`_hoveredAbbr` updates). Separating them prevents the expensive map repaint on every hover update.

**Trade-offs:** Two rasterization caches in GPU memory. On low-end Android devices this is still far preferable to repainting the full map on every pointer event.

**Example:**
```dart
Stack(children: [
  RepaintBoundary(
    child: CustomPaint(
      isComplex: true,
      painter: UsaMapPainter(
        states: states,
        matchedAbbrs: _matchedAbbrs,  // new Set() on each advance
        showLabels: showLabels,
        labelMode: labelMode,
        viewScale: _currentScale,
      ),
      size: const Size(2000, 1400),
    ),
  ),
  RepaintBoundary(
    child: CustomPaint(
      willChange: true,
      painter: HighlightPainter(
        hoveredAbbr: _hoveredAbbr,
        stateIndex: _stateIndex,
        targetAbbr: showTargetRing ? _currentAbbr : null,
        viewScale: _currentScale,
      ),
      size: const Size(2000, 1400),
    ),
  ),
  DragTarget<String>(...),
])
```

### Pattern 3: Ad Walled Garden via Abstract Interface

**What:** `AdService` is an abstract interface. `StubAdService` returns `SizedBox.shrink()` and `false` from all methods. The provider wires `StubAdService` for Phases 1–5. `GameSessionNotifier` has **no import** from `features/ads/` or `core/ads/` — it cannot touch ads at all. Only `MapScreen` (on game completion, triggering interstitial) and `app.dart` (App Open suppression check) reference `adServiceProvider`.

**When to use:** Always throughout v1. Real `AdMobAdService` is wired only in Phase 6.

**Trade-offs:** Small indirection cost. Pay-off is that the entire game is testable and runnable without an AdMob init, and COPPA compliance of the core session logic can be verified in isolation.

### Pattern 4: Scale-Adaptive Scene-Space Rendering

**What:** Labels, border strokes, dot radii, and target rings are expressed in *screen pixels* then divided by `viewScale` to convert to *scene units* before painting. This keeps them visually constant size regardless of zoom.

**When to use:** Any element that must appear at a fixed physical size. The formula is `sceneValue = screenTargetPx / viewScale`, clamped to a min/max scene value to prevent degenerate rendering at extreme zoom.

**Example (from Flags world_map_painter.dart, directly portable):**
```dart
// Border stroke: ~1 screen pixel at any zoom
final borderPaint = Paint()
  ..strokeWidth = (1.0 / viewScale).clamp(0.15, 1.2);

// Abbreviation label: 11 screen-pixel font at any zoom
final fontSize = 11.0 / viewScale;
```

For State States, label rendering needs two modes:
- **Abbreviation mode** (Learn + Geographical Master): render 2-letter `abbr` at centroid, `fontSize = 11 / viewScale`, always visible (no opacity threshold — all 50 states are large enough to show)
- **Full-name mode** (Learn only, on tray not map): name shown in `StateTray`, not on canvas

---

## Data Flow

### Startup / Map Load Flow

```
rootBundle.loadString('assets/map/usa_states_paths.json')
    ↓  compute() isolate
  List<Map<String,dynamic>> raw entries decoded
    ↓  main thread, 30-state chunks
  List<StateData>  (dart:ui Paths constructed)
    ↓
stateDataProvider (FutureProvider) emits AsyncData
    ↓
MapScreen.build() receives data → _buildMap()
    ↓
_initSequence() → buildStateSequence() → _remainingAbbrs list
    ↓
WidgetsBinding.addPostFrameCallback → _fitMapToScreen()
    ↓
gameSessionProvider.notifier.startGame(mode)
    ↓  phase: idle → countdown (5 ticks) → playing
```

### Drag-Drop Drop Flow

```
User drags StateTray token, drops on map
    ↓
DragTarget.onAcceptWithDetails(details)
    ↓
_controller.toScene(box.globalToLocal(details.offset + StateTray.kPinAnchor))
    → scenePoint (scene-space Offset)
    ↓
hitTest(scenePoint, _states, scale: _currentScale)
    → abbr?: exact path contains + expanded-bbox fallback + centroid tiebreaker
    ↓
_handleDrop(hitAbbr, isCorrect: hitAbbr == _currentAbbr)
    ↓ if correct:
  gameSessionProvider.notifier.recordDrop(abbr, isCorrect: true)
      → GameSession.matchedAbbrs += abbr
      → gameStateRepository.saveSession()     ← persistence
  HapticFeedback.lightImpact()
  audioServiceProvider.playCorrect()
  _animateCorrectDrop() → OverlayEntry fly-to-centroid
      → _advanceToNextState()
          → _matchedAbbrs = {..._matchedAbbrs, abbr}  ← new Set triggers repaint
          → if empty: completeGame() → highScoreRepository.saveBestScore()
                                     → context.go('/result')
    ↓ if incorrect:
  gameSessionProvider.notifier.recordDrop(abbr, isCorrect: false)
      → errorCount++, score recalculated
  HapticFeedback.mediumImpact()
  audioServiceProvider.playError()
  _trayKey.currentState?.triggerBounce()
```

### Score Computation (golf — lower is better)

```
score = (elapsedSeconds ~/ 10) + (errorCount * 5) + hintPenalty
                                                     ↑ +5 per hint used
```

The notifier recomputes `score` on every ticker tick (during playing phase) and on every `recordDrop(isCorrect: false)`. `elapsedSeconds` and `errorCount` are owned by the notifier, not stored in `GameSession` directly (only the derived `score` and `elapsed` Duration are in `GameSession`).

### Repository Write Pattern

```
gameStateRepository.saveSession(session)  ← on every correct drop and hint
highScoreRepository.saveBestScore(mode, score)  ← only on completeGame()
userPrefsRepository.setMuted(bool)  ← on every mute toggle
userPrefsRepository.setTutorialSeen(true)  ← once on first tutorial dismiss
```

---

## USA-Specific Deltas vs Flags Around the World

### Delta 1: Alaska and Hawaii Inset Projections

**Problem:** Alaska and Hawaii are geographically non-contiguous with the mainland and at natural scale would render either too small (Hawaii) or dominate the canvas (Alaska).

**Solution:** The Python pipeline produces two separate inset groups. Each state record carries an `insetGroup` field: `mainland | alaska | hawaii`. The painter applies a 2D transform (scale + translate) before drawing each group's paths.

**Implementation in UsaMapPainter:**
```dart
// Inset frame constants — chosen during pipeline calibration
const _alaskaInsetRect = Rect.fromLTWH(0, 900, 400, 300);   // bottom-left
const _hawaiiInsetRect = Rect.fromLTWH(420, 900, 300, 200); // bottom-center

void _drawInsetGroup(Canvas canvas, List<StateData> states,
    Rect insetRect, Rect naturalBounds) {
  final scaleX = insetRect.width / naturalBounds.width;
  final scaleY = insetRect.height / naturalBounds.height;
  final s = min(scaleX, scaleY);
  canvas.save();
  canvas.translate(insetRect.left - naturalBounds.left * s,
                   insetRect.top  - naturalBounds.top  * s);
  canvas.scale(s, s);
  _drawStates(canvas, states);  // reuses same fill/border logic
  canvas.restore();
}
```

Inset frame borders (thin rectangle drawn around each inset area) use the same scale-adaptive stroke width pattern: `strokeWidth = (1.0 / viewScale).clamp(0.15, 1.0)`.

**Hit detection for inset states:** The `hitTest()` function must apply the *inverse* of the inset transform before testing Paths. The simplest approach: store pre-transformed (inset-space) paths in `StateData` alongside their original paths, or transform the `scenePoint` into inset-natural space before calling `path.contains()`. The Python pipeline should output path data already in the inset-translated coordinate space so hit detection requires no special-casing.

Recommended pipeline output: all path coordinates (including AK and HI) are pre-transformed into the final canvas coordinate space. `StateData.paths` and `StateData.centroid` are already in canvas scene coordinates. `insetGroup` is metadata only (used for drawing the inset frame rect, not for coordinate transforms).

### Delta 2: Centroid-Based 48dp Proximity Snapping for Micro-States

**Problem:** Rhode Island, Delaware, Connecticut, New Jersey, Maryland, Massachusetts, New Hampshire, Vermont, and Hawaii (as inset) present small tap targets. At default zoom (map fits screen), their paths are only a few screen pixels wide.

**Solution:** Identical to the Flags hit_detection.dart implementation. The `_kMinScreenArea = 2304.0` (48×48 dp) threshold and `_kMinScreenDiagonal = 40.0` logic ports directly. The only change is the identifier field: `StateData.abbr` replaces `CountryData.isoCode`.

Key constants (carried verbatim from Flags):
- `_kMinScreenDiagonal = 40.0` — expand state bbox so on-screen diagonal reaches 40dp
- `_kMinScreenArea = 2304.0` — if on-screen bbox area < 48×48dp, use circular centroid expansion

No new logic needed. The `hitTest()` function signature changes only the import and the field name.

### Delta 3: Abbreviation Labels vs Country Name Labels

**Flags behavior:** Labels are country full names (`countryNames[isoCode]`), visibility controlled by size-based opacity thresholds (micro-states invisible until zoomed in enough).

**State States behavior:** Labels are 2-letter abbreviations (`state.abbr`, e.g. "CA", "TX"). All 50 states are large enough that the opacity thresholds from Flags are not needed — even Rhode Island at default zoom should show its abbreviation (the label is only 2 characters wide). The `diagonal < 20` micro-state dot rendering path from Flags does not apply to USA states (no US state is that geometrically degenerate on a USA-only canvas).

**Mode-driven label visibility:**

| `GameMode` | `showLabels` (map) | `showName` (tray) | `labelMode` |
|---|---|---|---|
| `learn` | true | true | abbreviation |
| `statesMaster` | false | true | — |
| `geographicalMaster` | true | false | abbreviation |
| `grandMaster` | false | false | — |

`UsaMapPainter` receives `showLabels: bool` and `labelMode: LabelMode` (enum with one value: `abbreviation`; extensible for future full-name-on-map mode).

**Font scaling with zoom (same pattern as Flags):**
```dart
// Fixed screen-pixel size regardless of zoom
final fontSize = 11.0 / viewScale;  // ~11dp always
```

No size-based opacity fade needed for US states. All states should show their abbreviation whenever `showLabels == true`.

### Delta 4: Canvas Dimensions and World-Copy Logic

**Flags canvas:** 4000×1000 (doubled width for date-line wrap; painted twice with a `canvas.translate(2000, 0)` copy).

**State States canvas:** No date-line. Single copy. Recommended canvas: `2000×1400` (landscape USA shape fits naturally; wider than tall; inset region adds ~400px of height at bottom). The world-copy translation and `% 2000` modulo in hit detection are dropped entirely.

**`_fitMapToScreen()` adjustment:**
```dart
// Flags used mapW=2000, mapH=1000
// State States: adjust to actual USA canvas dimensions
const mapW = 2000.0;
const mapH = 1400.0;  // includes inset rows
final scale = min(box.size.width / mapW, box.size.height / mapH).clamp(0.1, 1.0);
```

### Delta 5: Entity Identifier — `abbr` replaces `isoCode`

Every reference to `isoCode` in Flags maps to `abbr` (2-letter USPS abbreviation) in State States. The `StateData` model, `GameSession.matchedAbbrs`, `HighScoreRepository._key(mode)`, `GameStateRepository` JSON serialization, and all drag data strings use `abbr`.

### Delta 6: State Name Localization

Flags loads `countries_en.json` (197 entries) and overlays locale-specific JSON at runtime. State States can use a simpler approach: hardcode 50 state names directly in ARB `app_en.arb` (no runtime JSON overlay needed; names do not change). This eliminates `stateNamesProvider` as a separate `FutureProvider` — names can be inlined in the ARB or in a Dart constant map in `state_data_service.dart`.

Alternatively, keep the JSON pattern for structural parity with Flags and to allow future i18n of state names. Decision: keep the JSON pattern (low cost, structural consistency).

### Delta 7: Anthem Audio

Flags `AudioService` interface: `init / playCorrect / playError / setMuted / dispose`.

State States adds: `playAnthem() / stopAnthem()`. The `WelcomeScreen` calls `playAnthem()` on load and `stopAnthem()` (with fade-out) on navigation to `HomeScreen`. The anthem asset must be self-rendered from the public-domain composition (not an arbitrary recording).

The `just_audio` `AudioPlayer` supports volume fade via `setVolume()` animated over a `Timer`. Add one player instance to `RealAudioService` for the anthem, separate from `_correctPlayer` / `_errorPlayer`.

---

## Build Order

Dependencies flow strictly top-to-bottom. Each phase's output is a prerequisite for the next.

### Phase 1: Foundation — Pipeline + Models + i18n

**Deliverables:**
1. Python SVG pipeline: Natural Earth admin-1 US states → `usa_states_paths.json` with `abbr`, `paths`, `boundingBox`, `centroid`, `insetGroup`
2. `StateData` model (`core/models/state_data.dart`)
3. `StateDataService` + `stateDataProvider` + `stateNamesProvider` (`core/data/state_data_service.dart`)
4. `GameMode` enum (4 modes)
5. `GamePhase` enum
6. `GameSession` value object
7. ARB baseline with 50 state names
8. `AudioService` interface + `StubAudioService` + `RealAudioService` (skeleton; anthem method stubbed)
9. `AdService` interface + `StubAdService` (full; never changes until Phase 6)

**Why first:** Everything else depends on having `StateData` with valid `dart:ui` Paths and the correct entity identifier.

### Phase 2: State Machine + Repositories

**Deliverables:**
1. `Ticker` / `RealTicker` (port verbatim)
2. `GameSessionNotifier` (port from Flags; rename iso→abbr; add `statesMaster` mode)
3. `HighScoreRepository` (port verbatim; update mode key strings)
4. `UserPrefsRepository` (port verbatim)
5. `GameStateRepository` (port verbatim; rename iso→abbr in JSON keys)
6. Unit tests for notifier state machine transitions and golf scoring

**Why second:** The notifier is pure Dart logic with no Flutter dependency. Testing it before any widget exists catches scoring bugs early.

### Phase 3: Map Render + Coordinate Transform Spike (GATE)

**GATE: Coordinate-Transform Spike must pass before full drag system.**

The spike (`SpikeMapScreen`, already implemented in Flags) proves that `TransformationController.toScene(box.globalToLocal(rawOffset))` produces correct scene coordinates at 1×, 2×, and 4× zoom. For State States the spike should additionally test the inset-group coordinate space: drag a token over a simulated AK inset rect at 1×, 2×, 4× zoom and confirm the hit-test returns the correct region.

**Deliverables:**
1. `SpikeMapScreen` variant with inset regions (AK, HI simulated as Rects)
2. Manual QA: verify correct region hit at 1×/2×/4× zoom
3. `UsaMapPainter` — mainland fills, borders, AK/HI inset frames, abbreviation labels (scale-adaptive)
4. `HighlightPainter` (port verbatim; rename iso→abbr)
5. `hitTest()` (port verbatim; rename iso→abbr; remove world-copy modulo logic)
6. `MapScreen` skeleton with `InteractiveViewer` + `TransformationController` + `_fitMapToScreen()`

**Why gated:** The entire drag-drop system's correctness depends on the coordinate transform. Building `StateTray` and drop logic on top of an unverified transform means any bug infects all downstream features and is expensive to root-cause later.

### Phase 4: Game Modes + Full Play Loop

**Deliverables:**
1. `StateTray` (port `FlagTray`; replace SVG flag with state name token; `showName` and `showAbbr` props)
2. `GameHud` (port verbatim; rename flags→states in copy)
3. Full `MapScreen._buildMap()` with mode-driven `showLabels`/`showName` booleans
4. `_handleDrop()`, `_advanceToNextState()`, `_animateCorrectDrop()` (port; rename iso→abbr)
5. `buildStateSequence()` / `buildGrandMasterSequence()` (port `flag_sequence.dart`)
6. Pause overlay, back-button guard, `WidgetsBindingObserver` lifecycle pause
7. `CompletionScreen` (port `completion_screen.dart`)
8. All 4 game modes end-to-end playable

**Why fourth:** Requires Phase 3's painters and Phase 2's notifier. This is the largest phase.

### Phase 5: Polish + Welcome + Anthem

**Deliverables:**
1. `WelcomeScreen` with USA silhouette vector art
2. `RealAudioService.playAnthem()` / `stopAnthem()` with fade-out
3. Tutorial overlay (port from Flags; update copy for states)
4. Hint system (port verbatim; hint zooms to state centroid)
5. Session restore (port verbatim; rename iso→abbr)
6. Accessibility: Semantics labels, 48dp tap targets audit
7. COPPA audit: `AD_ID` blocked, no persistent identifiers, child-directed flag

### Phase 6: Ad Layer (walled garden lifted)

**Deliverables:**
1. `AdMobAdService` real implementation
2. `ads_initializer.dart` with `tagForChildDirectedTreatment(true)` on AdMob and all mediation SDKs
3. `ad_service_provider.dart` switched from `StubAdService` to `AdMobAdService`
4. Banner on `HomeScreen` and `CompletionScreen`
5. Interstitial on game completion only (not mid-round, not pause)
6. Rewarded ad for hint refill
7. App Open ad with gameplay suppression in `app.dart`

---

## Anti-Patterns

### Anti-Pattern 1: Using `RenderBox.globalToLocal()` at the DragTarget Level

**What people do:** Call `context.findRenderObject().globalToLocal(details.offset)` inside `DragTarget.onAcceptWithDetails` to get a local coordinate.

**Why it's wrong:** `globalToLocal()` on the DragTarget's RenderBox converts to the DragTarget's local coordinate space, which is the InteractiveViewer's transformed space. At zoom != 1.0, this returns the wrong scene coordinate.

**Do this instead:** Use `TransformationController.toScene(ivBox.globalToLocal(rawGlobal + kPinAnchor))` where `ivBox` is the `RenderBox` of the `InteractiveViewer`'s key. Proven in the Flags spike and production code.

### Anti-Pattern 2: Painting Inset State Paths Without Pre-Transforming Coordinates

**What people do:** Apply a `canvas.scale/translate` transform in the painter for AK/HI groups, but keep `StateData.paths` and `StateData.centroid` in their original geographic coordinate space.

**Why it's wrong:** `hitTest()` receives a drop point in *canvas scene coordinates*, not in the original geographic coordinate space. If the paths are in original coords but the drop point is in canvas coords, hit detection fails for AK and HI.

**Do this instead:** Pre-transform AK and HI path coordinates in the Python pipeline so `StateData.paths` for every state is already in the final canvas coordinate space. `hitTest()` then needs no special-casing. The painter draws the inset frame rect as a decorative border, but all path data is already in final canvas space.

### Anti-Pattern 3: Importing `ads/` from `GameSessionNotifier`

**What people do:** Call `adServiceProvider` from inside `GameSessionNotifier` (e.g., to trigger an interstitial when the game completes).

**Why it's wrong:** Violates the walled-garden rule. It couples the core game loop to the ad SDK, making unit tests require AdMob mocks and making COPPA compliance harder to verify.

**Do this instead:** `GameSessionNotifier.completeGame()` only transitions `phase` to `completed`. `MapScreen._advanceToNextState()` detects the empty queue and calls `context.go('/result')`. `CompletionScreen.initState()` calls `adServiceProvider.showInterstitialAd()` once. The notifier never knows about ads.

### Anti-Pattern 4: Triggering `setState` on Every Pointer Move Event for Scale

**What people do:** Subscribe to the `TransformationController` and call `setState()` on every listener call (potentially 60+ times per second during a pinch gesture).

**Why it's wrong:** Triggers full widget rebuild subtree on every scale delta, even sub-pixel changes. Causes jank during pinch-to-zoom.

**Do this instead (Flags pattern):**
```dart
void _onScaleChanged() {
  final s = _controller.value.entry(0, 0);
  if ((s - _currentScale).abs() > 0.005) {  // threshold gate
    setState(() => _currentScale = s);
  }
}
```
This limits painter repaints to scale changes larger than 0.5%, which is imperceptible visually but eliminates the bulk of redundant rebuilds.

### Anti-Pattern 5: Sharing a GlobalKey Between Draggable `child` and `feedback`

**What people do:** Pass `widget.cardKey` to both the `child` and `feedback` constructors of `Draggable`.

**Why it's wrong:** Flutter mounts the feedback widget in the Overlay and the child in the tree simultaneously during a drag. A GlobalKey must be unique in the tree at any time. This throws a `"Duplicate GlobalKey"` error the moment the user starts dragging.

**Do this instead (Flags FlagTray pattern):** Apply `cardKey` only to `_cardShell(key: widget.cardKey)` on the `child`. The `feedback` and `childWhenDragging` use `_cardShell()` (no key). This is the exact pattern in `flag_tray.dart` and must be replicated in `state_tray.dart`.

---

## Integration Points

### External Services

| Service | Integration | Notes |
|---------|-------------|-------|
| `google_mobile_ads` | `AdMobAdService implements AdService` in `core/ads/`; wired at provider level | v1: `StubAdService`. v6: real impl. `GameSessionNotifier` never imports this. |
| `just_audio` | `RealAudioService implements AudioService` in `core/audio/` | Anthem needs its own `AudioPlayer` instance; correct/error players share the existing pattern |
| `shared_preferences` | All three repositories (`HighScore`, `UserPrefs`, `GameState`) | Each creates its own `SharedPreferences.getInstance()` call via `FutureProvider`; no cross-repo shared instance |
| `path_drawing` | `StateDataService` during JSON → `dart:ui Path` conversion | `parseSvgPathData(pathString)` on main thread, chunked |

### Internal Boundaries

| Boundary | Communication | Rule |
|----------|---------------|------|
| `GameSessionNotifier` ↔ `features/ads/` | **None** — walled garden | Notifier must never import from ads layer |
| `MapScreen` ↔ `UsaMapPainter` | Constructor params only | Painter receives `List<StateData>`, `Set<String> matchedAbbrs`, `bool showLabels`, `double viewScale`; no Riverpod inside painter |
| `MapScreen` ↔ `GameSessionNotifier` | `ref.watch/read(gameSessionProvider)` | MapScreen reads session for HUD data; writes via notifier methods |
| `core/data/` ↔ `features/` | `FutureProvider` injection | Features never instantiate repositories directly; always via Riverpod provider |
| `AdService` ↔ all callers | `adServiceProvider` only; callers import `core/ads/ad_service.dart` abstract interface | Real vs. stub swap is a single provider change |

---

## Sources

- Reference codebase: `C:\code\Claude\FlagsRoundTheWorld\lib\` — all files read directly (HIGH confidence, same codebase being ported)
- `CLAUDE.md` in Flags repo — locked architectural decisions carried forward
- `PROJECT.md` in State States — confirmed carry-over decisions and USA-specific requirements

---
*Architecture research for: State States — Flutter USA states drag-and-drop map game*
*Researched: 2026-05-30*

---

## v2 Architecture Changes

*Added: 2026-06-02 — v2.0 milestone (Speed Typing, AdMob activation, rewarded hint refill, screenshot share)*

### 1. SpeedTypingScreen — Location and Reuse

**File:** `lib/features/typing/speed_typing_screen.dart`

Create `lib/features/typing/` as a new feature directory. The screen is a new mode with no map, no `InteractiveViewer`, and no `StateTray` — it is structurally closer to `HomeScreen` than to `MapScreen`.

**What it reuses from existing code:**

| Reused component | How |
|-----------------|-----|
| `gameSessionProvider` / `GameSessionNotifier` | Reads `session.phase`, `session.score`, `session.hintsRemaining`, `session.elapsed`. Calls `startGame(GameMode.speedTyping)`, `recordTypingGuess()`, `completeGame()`, `pauseGame()`, `resumeGame()`. |
| `GameHud` | Identical widget, same props. Score, elapsed, progress bar, pause + mute buttons all apply unchanged. |
| `audioServiceProvider` | `playCorrect()` / `playError()` on each guess. Same call site pattern as `MapScreen`. |
| `adServiceProvider` | `showInterstitialAd()` in `initState` after game completes (same pattern as `CompletionScreen`). `showRewardedAd()` for hint refill (see section 6). |
| `HighScoreRepository` | No change. `completeGame()` already writes to it. |
| `GameStateRepository` | No change. `recordTypingGuess()` calls `saveSession()` on correct guess; same pattern as `recordDrop()`. |

**What it adds (net-new):**

- `TextField` with `textCapitalization: TextCapitalization.characters` for UPPERCASE input
- Auto-submit on exact match (no Submit button; compare on every `onChanged`)
- Scrolling `GridView` or `Wrap` of found-states chips (renders matched postals)
- `_inputController = TextEditingController()` — clears on each correct guess
- No map, no `InteractiveViewer`, no `TransformationController`, no `hitTest()`

**Route:** Add `/typing` to `app.dart` GoRouter, parallel to `/play`. Both accept `GameMode` as `extra`. `HomeScreen` gains a Mode 5 card that pushes `/typing` with `GameMode.speedTyping`.

---

### 2. GameMode Enum Extension

`lib/features/game/game_mode.dart` — single-line change:

```dart
// Before
enum GameMode { learn, statesMaster, geographicalMaster, grandMaster }

// After
enum GameMode { learn, statesMaster, geographicalMaster, grandMaster, speedTyping }
```

**Downstream impact is narrow.** The existing code has exactly two switch/if-chain sites that need updating:

1. `CompletionScreen._modeColor()` — add a case for `speedTyping` (pick a color; suggest `Color(0xFF00695C)` teal).
2. `HomeScreen` mode-card builder — add the Mode 5 card. All other mode-card logic is driven off the enum value passed as `extra`, not an exhaustive switch.

`GameSessionNotifier` has no mode-specific branching; it is mode-agnostic by design. `HighScoreRepository` keys are `mode.name` strings (`"speedTyping"` is a valid new key, no collision). `GameStateRepository` serializes `mode.name`; restoring a `speedTyping` session works without any repository changes provided the enum value exists before any save is made.

**Label/tray logic in `MapScreen._buildMap()`:** The existing mode → `showLabels`/`showName` dispatch is only called for map modes. `SpeedTypingScreen` never calls `_buildMap()`, so no change needed there.

---

### 3. GameSessionNotifier: `recordTypingGuess()`

Add one method. No existing method changes. No state machine changes.

```dart
// In game_session_notifier.dart — add after recordDrop()

/// Records a typed state name guess.
///
/// [postal] is the 2-letter abbreviation that the UI resolved from the
/// typed name. Returns true if the guess was correct and not already matched;
/// false otherwise (wrong or duplicate — caller plays error SFX).
///
/// Correct: appends to matchedPostals, flushes snapshot, returns true.
/// Incorrect: increments errorCount, recomputes score, returns false.
/// Duplicate (already matched): no-op, returns false.
bool recordTypingGuess(String postal) {
  final current = state.value;
  if (current == null || current.phase != GamePhase.playing) return false;
  if (current.matchedPostals.contains(postal)) return false;

  final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;

  // Correct guess
  final updated = current.copyWith(
    matchedPostals: [...current.matchedPostals, postal],
  );
  state = AsyncData(updated);
  _gameStateRepository?.saveSession(updated, hintPenalty: _hintPenalty);
  return true;
  // NOTE: incorrect branch omitted — SpeedTypingScreen ignores wrong guesses
  // (user just keeps typing; there is no error penalty for misspellings).
  // Add errorCount increment here if the product spec changes.
}
```

**Why no existing method changes:** `recordDrop()` is map-only; it is never called by `SpeedTypingScreen`. The notifier's phase state machine (`idle → countdown → playing → paused → completed`) applies identically to both modes. `completeGame()`, `pauseGame()`, `resumeGame()`, `useHint()` are all mode-agnostic and work unchanged.

**Zero imports from ads preserved.** `recordTypingGuess()` has no ad-layer dependency.

---

### 4. AdMobAdService Provider Swap

The swap is a single-line change in `lib/core/ads/ad_service_provider.dart`:

```dart
// Before (v1)
final adServiceProvider = Provider<AdService>((ref) => const StubAdService());

// After (v2)
final adServiceProvider = Provider<AdService>((ref) => AdMobAdService());
```

No callers change. All screens that call `ref.read(adServiceProvider)` continue to import only `core/ads/ad_service.dart` (the abstract interface). The concrete type is invisible to them.

**`AdMobAdService` must be implemented in `core/ads/admob_ad_service.dart`** (the file is already scaffolded in the v1 structure as a placeholder). It implements the existing four-method `AdService` interface:

| Method | v2 behavior |
|--------|------------|
| `getBannerWidget()` | Returns a loaded `AdWidget` sized to `AdSize.banner`; returns `SizedBox.shrink()` while loading |
| `showInterstitialAd()` | Shows preloaded `InterstitialAd`; preloads next ad after show |
| `showRewardedAd()` | Shows preloaded `RewardedAd`; completes with `true` if `onUserEarnedReward` fires before dismiss |
| `showAppOpenAd()` | Shows preloaded `AppOpenAd` if not expired (4-hour window) and gameplay is not suppressed |

**COPPA configuration** happens in `ads_initializer.dart` (called once from `main.dart` before `runApp`), not inside `AdMobAdService`. The initializer calls `MobileAds.instance.updateRequestConfiguration(RequestConfiguration(tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes))` and `MobileAds.instance.initialize()`. Each mediation SDK (Unity, ironSource, InMobi, AppLovin) requires its own child-directed flag call in the initializer; `AdMobAdService` itself is unaware of these per-SDK calls.

**Ad unit IDs** live in `core/ads/ad_constants.dart` (already scaffolded). v1 has empty strings; v2 fills in the real IDs. The constants file is the only place IDs appear.

---

### 5. CompletionScreen Screenshot Capture

The existing `RepaintBoundary` at line 201 of `completion_screen.dart` wraps the score `Card`. It is anonymous. Promoting it to a keyed boundary requires a `GlobalKey<RenderObjectState>` (specifically `GlobalKey`) held as `_scoreCardKey`.

**Minimal surgical change to `_CompletionScreenState`:**

```dart
// Add to _CompletionScreenState fields
final GlobalKey _scoreCardKey = GlobalKey();

// Change the RepaintBoundary at line 201 from:
RepaintBoundary(
  child: Card(...),
)

// To:
RepaintBoundary(
  key: _scoreCardKey,
  child: Card(...),
)
```

**Screenshot capture method (add to `_CompletionScreenState`):**

```dart
Future<Uint8List?> _captureScoreCard() async {
  final boundary = _scoreCardKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
```

**No structural refactor required.** The `RepaintBoundary` already exists; it only needs a key. The `toImage()` / `toByteData()` call is standard Flutter; no new packages needed. `share_plus` `ShareParams` accepts `XFile` for image sharing — convert `Uint8List` to `XFile` via `XFile.fromData(bytes, mimeType: 'image/png')`.

**Updated `_onSharePressed()` for v2:**

```dart
Future<void> _onSharePressed() async {
  // Gate: PB only (v2 spec: "New lowest score" gating)
  if (!_isNewPb) return;  // button is hidden unless PB; guard here too

  final passed = await showDialog<bool>(
    context: context,
    builder: (_) => const _MathChallengeDialog(),
  );
  if (passed != true || !mounted) return;

  final imageBytes = await _captureScoreCard();
  final elapsed = _formatTime(widget.session.elapsed);
  final modeName = widget.session.mode.name;
  final score = widget.session.score;

  if (imageBytes != null) {
    final file = XFile.fromData(imageBytes,
        name: 'state_the_states_result.png', mimeType: 'image/png');
    await SharePlus.instance.share(ShareParams(
      text: 'New lowest score in $modeName mode! '
            '$score points in $elapsed — State the States',
      files: [file],
    ));
  } else {
    // Fallback: text-only if capture fails
    await SharePlus.instance.share(ShareParams(
      text: 'New lowest score in $modeName mode! '
            '$score points in $elapsed — State the States',
    ));
  }
}
```

**Math gate upgrade (v2 spec: 2-digit × 1-digit):** The existing `_MathChallengeDialog` uses addition (`_a + _b`). Change to multiplication: `_a` = random 2-digit (12–49), `_b` = random 1-digit (3–9), expected answer = `_a * _b`. No structural change to the dialog — just the number ranges, operator display string, and answer check.

---

### 6. Rewarded Hint Refill Flow

The walled-garden rule is preserved: `GameSessionNotifier` never sees the ad service. The flow is owned entirely by the widget layer.

**Flow:**

```
User taps hint button in GameHud with hintsRemaining == 0
    ↓
MapScreen (or SpeedTypingScreen) detects hintsRemaining == 0
    → does NOT call notifier.useHint()
    → instead: calls _offerRewardedHint()
        ↓
  ref.read(adServiceProvider).showRewardedAd()
    → awaits Future<bool>
        ↓ true (user watched to completion):
      ref.read(gameSessionProvider.notifier).refillHints()
      audioServiceProvider.playCorrect()  // satisfying confirmation SFX
        ↓ false (dismissed or unavailable):
      show SnackBar: "Watch an ad to refill hints"
      (no hint granted)
```

**New `refillHints()` method on `GameSessionNotifier`:**

```dart
// Add to game_session_notifier.dart

/// Refills hints to 2 after a completed rewarded ad watch.
///
/// Must only be called by the widget layer after [AdService.showRewardedAd]
/// returns true. The notifier is unaware of the ad that preceded this call.
/// No penalty is added — the reward is the refill itself.
void refillHints() {
  final current = state.value;
  if (current == null || current.phase != GamePhase.playing) return;
  state = AsyncData(current.copyWith(hintsRemaining: 2));
  _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
}
```

**Which component calls `adServiceProvider`:** The calling widget is whichever screen is active — `MapScreen` for map modes, `SpeedTypingScreen` for speed typing mode. Neither delegates to `GameSessionNotifier`. The pattern is:

```dart
// In MapScreen._onHintPressed() (or SpeedTypingScreen equivalent)
Future<void> _onHintPressed() async {
  final session = ref.read(gameSessionProvider).value;
  if (session == null) return;

  if (session.hintsRemaining > 0) {
    // Normal hint path — unchanged from v1
    final consumed = ref.read(gameSessionProvider.notifier).useHint();
    if (consumed) _executeHint();
    return;
  }

  // hintsRemaining == 0: offer rewarded ad
  final earned = await ref.read(adServiceProvider).showRewardedAd();
  if (!mounted) return;
  if (earned) {
    ref.read(gameSessionProvider.notifier).refillHints();
    // Now call useHint() immediately to consume one of the refilled hints
    final consumed = ref.read(gameSessionProvider.notifier).useHint();
    if (consumed) _executeHint();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Watch an ad to refill hints')),
    );
  }
}
```

**Why `adServiceProvider` is called in the widget, not the notifier:** This is the same discipline as interstitial triggering (`CompletionScreen.initState()` calls the ad; the notifier only transitions `phase`). Keeping it in the widget preserves unit testability of the notifier and means no AdMob mock is needed to test `refillHints()`.

**`StubAdService.showRewardedAd()` returns `false`** (current implementation). For development testing of the refill flow without a real ad, temporarily return `true` from the stub — or use a `ProviderScope` override in tests. The production code path is unchanged.

---

### v2 New File Summary

| File | Status | Notes |
|------|--------|-------|
| `lib/features/typing/speed_typing_screen.dart` | New | Mode 5 screen |
| `lib/core/ads/admob_ad_service.dart` | Promoted from scaffold to real impl | Was placeholder in v1 |
| `lib/core/ads/ads_initializer.dart` | Promoted from scaffold to real impl | COPPA + MobileAds.initialize() |
| `lib/core/ads/ad_constants.dart` | Updated | Fill in real ad unit IDs |
| `lib/core/ads/ad_service_provider.dart` | Single-line change | Swap StubAdService → AdMobAdService |
| `lib/features/game/game_mode.dart` | One-word addition | Append `speedTyping` to enum |
| `lib/features/game/game_session_notifier.dart` | Additive | Add `recordTypingGuess()` + `refillHints()` |
| `lib/features/map/completion_screen.dart` | Additive | Add `_scoreCardKey`, `_captureScoreCard()`, update `_onSharePressed()`, upgrade math gate to multiplication |

### v2 Invariants Preserved

- `GameSessionNotifier` imports from ads: **zero** (unchanged)
- `AdService` interface: **unchanged** (four methods; no new methods needed)
- `GameSession` value object: **unchanged** (no new fields)
- `HighScoreRepository` / `GameStateRepository` / `UserPrefsRepository`: **unchanged**
- `MapScreen`, `UsaMapPainter`, `HighlightPainter`, `hitTest()`: **unchanged**
- COPPA rule: `refillHints()` is triggered by widget after ad completes; notifier remains ad-unaware
