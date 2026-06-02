# Phase 6: Speed Typing Mode - Research

**Researched:** 2026-06-02
**Domain:** Flutter/Dart — extending an existing Riverpod game state machine with a new input mode; no new external dependencies
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Exact match only — full name + 2-letter postal code. No abbreviations, no aliases. `GEORGIA` and `GA` match. `MASS` does not match. Space required in multi-word names (`NEW YORK` yes, `NEWYORK` no). Comparison: `inputText.trim() == stateName.toUpperCase()` or `inputText.trim() == postalCode`.

**D-02:** Space required in multi-word names.

**D-03:** Field clears on every Enter press. Correct match → success SFX + chip + clear. Wrong match → +5 penalty + clear. No red-highlight retain.

**D-04:** Text field bottom-anchored above the keyboard. `resizeToAvoidBottomInset: true` (default). Found-states grid in `Expanded` above; input field pinned at bottom.

**D-05:** Found states in a `SingleChildScrollView` + `Wrap` of green `Chip` widgets. Fill left-to-right as found.

**D-06:** Chips display full state name (`CALIFORNIA`, `NEW YORK`).

**D-07:** `_modeColor()` in `CompletionScreen` gets `GameMode.speedTyping => const Color(0xFF00695C)`. Play Again routes to `/type` when `mode == GameMode.speedTyping`.

**D-08:** `displayName` extension on `GameMode` added: `GameMode.speedTyping => 'Speed Typing'`. Used by `CompletionScreen`, `HomeScreen`, and app bar.

**D-09:** Mode color for Speed Typing: teal `0xFF00695C`.

### Claude's Discretion

- State management: extend `GameSessionNotifier` with `submitTyping(String input)`. `activePostal` is always `null` in typing mode. `hintsRemaining` is irrelevant (ignore).
- Route name: `/type` for `SpeedTypingScreen` in `app.dart`.
- HUD layout: score + elapsed time in compact row at top. States-found counter `23 / 50`.
- `HighScoreRepository` key: `GameMode.speedTyping => 'high_score_speed_typing'`.
- Icon for Mode 5 card: `Icons.keyboard` or `Icons.abc` — Claude picks.

### Deferred Ideas (OUT OF SCOPE)

- Hint system for Speed Typing mode
- Alphabetical sort for found chips
- Timer display / stats beyond best score on the Mode 5 home card
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TYPING-01 | Mode 5 card on HomeScreen, shows best score or blank | `_ModeCard` pattern + `getBestScore(GameMode.speedTyping)` |
| TYPING-02 | Tapping Mode 5 card navigates to `SpeedTypingScreen` | `context.go('/type')` + new GoRoute in `app.dart` |
| TYPING-03 | Text field auto-capitalizes to UPPERCASE | `textCapitalization: TextCapitalization.characters` on `TextField` |
| TYPING-04 | Valid unseen state/postal on Enter → success SFX + green chip + field cleared | `submitTyping()` returns `true` path; `audioService.playCorrect()` |
| TYPING-05 | Non-matching string on Enter → +5 golf penalty | `submitTyping()` returns `false` path; mirrors `recordDrop(isCorrect: false)` |
| TYPING-06 | Found-states grid scrolls; shows chips for matched states | `SingleChildScrollView` + `Wrap` of `Chip` widgets |
| TYPING-07 | Game ends when all 50 states found | `matchedPostals.length == 50` check in `submitTyping()` after hit → `completeGame()` |
| TYPING-08 | Golf scoring: +1/10s + +5/wrong; timer auto-pauses on background | Reuses existing `Stopwatch`/`_ticker` + `GameLifecycleObserver` |
| TYPING-09 | Best score stored via `SharedPreferences`; displayed on Mode 5 card | `HighScoreRepository.saveBestScore(GameMode.speedTyping, ...)` |
</phase_requirements>

---

## Summary

Phase 6 is a pure-Dart extension of the existing game loop. No new packages are required: the entire typing mode is built by adding one enum value (`speedTyping`), one notifier action (`submitTyping`), one new screen (`SpeedTypingScreen`), and updating five existing files to handle the new enum value. All infrastructure — timer, lifecycle observer, high score repository, completion screen, session serialization — already exists and handles `GameMode` generically via `mode.name` or explicit `switch` statements.

The central complexity is ensuring every exhaustive `switch (mode)` in the codebase is updated simultaneously when `speedTyping` is added. Dart's exhaustive switch will produce compile errors at every missing case, which is both a safety net and a checklist. This phase involves no novel architecture: the planner should model it as a surgical multi-file edit with a new screen bolted onto existing infrastructure.

The only genuine design decision left to Claude is whether `SpeedTypingScreen` should run through the existing 5-second countdown phase or skip it and go straight to `GamePhase.playing`. The recommendation (see Pitfall 1 below) is to **bypass the countdown entirely** using a direct `startGame()` call that internally skips to `playing` for typing mode, or more practically by using the existing countdown but making it visually appropriate (e.g., "Ready?" rather than a timer overlay). The simplest correct approach: keep the countdown as-is (it is brief and harmless for a typing game) but do not render the numeric countdown overlay on `SpeedTypingScreen` since there is no map to prepare.

**Primary recommendation:** Add `speedTyping` to the enum, update all five switch sites, add `submitTyping()` to the notifier, build `SpeedTypingScreen` as a `ConsumerStatefulWidget` following the `MapScreen` lifecycle pattern exactly, and mount `GameLifecycleObserver` the same way.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Input matching (name/postal) | `GameSessionNotifier` (business logic) | — | Match logic is stateful (tracks matched set); belongs in notifier alongside scoring |
| Golf scoring | `GameSessionNotifier` | — | Already implemented; `submitTyping()` calls same scoring path as `recordDrop()` |
| UPPERCASE keyboard input | Widget layer (`SpeedTypingScreen`) | — | `TextCapitalization.characters` is a widget-layer concern |
| Found-states chip grid | Widget layer (`SpeedTypingScreen`) | — | Derives from `session.matchedPostals`; pure display from notifier state |
| Timer + auto-pause | `GameSessionNotifier` + `GameLifecycleObserver` | `SpeedTypingScreen` (mounts observer) | Existing infrastructure; screen must register the observer |
| Session persistence | `GameStateRepository` | — | `saveSession()` is already called on `pauseGame()` and correct match; works generically |
| High score persistence | `HighScoreRepository` | — | Needs one new `_key()` case; rest is generic |
| Navigation to `/complete` | Widget layer (`SpeedTypingScreen`) | — | Same `context.go('/complete', extra: {...})` call as `MapScreen` |
| Mode card display | Widget layer (`HomeScreen`) | — | Needs 5th `_ModeCard` entry |

---

## Standard Stack

No new packages. All dependencies are already in `pubspec.yaml`.

### Core (all already locked in pubspec.yaml)

| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| `flutter_riverpod` | `^3.3.1` | State management | `GameSessionNotifier` extends with `submitTyping()` |
| `go_router` | `^17.2.3` | Navigation | New `/type` route |
| `just_audio` | `^0.10.5` | Audio SFX | `playCorrect()` / `playError()` calls in `SpeedTypingScreen` |
| `shared_preferences` | `^2.5.5` | High score persistence | Already used; one new key |

**No new packages to install for Phase 6.** [VERIFIED: codebase read]

---

## Package Legitimacy Audit

> Not applicable — Phase 6 installs zero new packages.

---

## Architecture Patterns

### System Architecture Diagram

```
Player types in TextField
         |
  [SpeedTypingScreen]  ← GameLifecycleObserver (auto-pause on background)
         | onSubmitted(_onSubmit)
         |
  ref.read(gameSessionProvider.notifier).submitTyping(input)
         |
  [GameSessionNotifier.submitTyping()]
         |
         ├── lookup input vs StateData.name.toUpperCase() / StateData.postal
         │         (using stateDataProvider states list passed as parameter or via ref.read)
         |
         ├── HIT (not in matchedPostals):
         │     copyWith(matchedPostals: [..., postal])
         │     saveSession() → SharedPreferences
         │     check matchedPostals.length == 50 → completeGame() if done
         │     return true
         │
         ├── DUPLICATE (already in matchedPostals):
         │     treat as miss → recordError() path
         │     return false
         │
         └── MISS (no match):
               errorCount += 1, score recalculated
               return false
         |
  SpeedTypingScreen reads return value:
    true  → audioService.playCorrect(), chip added (via session rebuild), clear field
    false → audioService.playError(), clear field (no chip)
         |
  matchedPostals.length == 50
         |
  SpeedTypingScreen watches session.phase == GamePhase.completed
         |
  context.go('/complete', extra: {'session': session, 'previousBest': prev})
```

### Recommended Project Structure

```
lib/
├── features/
│   ├── game/
│   │   ├── game_mode.dart          ← ADD speedTyping + displayName extension
│   │   └── game_session_notifier.dart ← ADD submitTyping(String input)
│   ├── home/
│   │   ├── home_screen.dart        ← ADD Mode 5 _ModeCard
│   │   └── session_restore_card.dart ← ADD speedTyping case to _modeLabel()
│   ├── map/
│   │   └── completion_screen.dart  ← ADD speedTyping to _modeColor() + Play Again route
│   └── typing/                     ← NEW directory
│       └── speed_typing_screen.dart ← NEW SpeedTypingScreen
├── core/
│   └── data/
│       └── high_score_repository.dart ← ADD speedTyping key
└── app.dart                        ← ADD /type GoRoute
```

### Pattern 1: submitTyping() Action

**What:** A `GameSessionNotifier` action that accepts a raw string input, matches it against the state data list, updates `matchedPostals` or `errorCount`, and returns `bool` indicating hit or miss.

**Design choice — state data access:** `submitTyping()` needs the list of 50 `StateData` records to perform matching. Two options:

Option A (recommended): Pass the `List<StateData>` as a parameter from the widget, which already has access via `ref.watch(stateDataProvider)`.
Option B: Call `ref.read(stateDataProvider)` inside the notifier.

Option A is cleaner: the notifier does not take a new provider dependency and the widget already handles the loading/error state of `stateDataProvider`. The method signature becomes `bool submitTyping(String input, List<StateData> states)`.

**When to use:** Only called from `SpeedTypingScreen._onSubmit()`.

**Example implementation:**
```dart
// Source: direct analysis of existing recordDrop() pattern
bool submitTyping(String input, List<StateData> states) {
  final current = state.value;
  if (current == null || current.phase != GamePhase.playing) return false;

  final normalized = input.trim();
  if (normalized.isEmpty) return false;

  // Look up by full name (UPPERCASE) or postal code
  final StateData? match = states.firstWhereOrNull(
    (s) => s.isPlaceable &&
           (s.name.toUpperCase() == normalized || s.postal == normalized),
  );

  // Miss: no matching state
  if (match == null) {
    final newErrorCount = current.errorCount + 1;
    final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
    final newScore = (elapsedSecs ~/ 10) + (newErrorCount * 5) + _hintPenalty;
    state = AsyncData(current.copyWith(
      errorCount: newErrorCount,
      score: newScore,
    ));
    return false;
  }

  // Duplicate: already matched
  if (current.matchedPostals.contains(match.postal)) {
    // Treat duplicate as a miss (D-01: "no match" for already-found state)
    final newErrorCount = current.errorCount + 1;
    final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
    final newScore = (elapsedSecs ~/ 10) + (newErrorCount * 5) + _hintPenalty;
    state = AsyncData(current.copyWith(
      errorCount: newErrorCount,
      score: newScore,
    ));
    return false;
  }

  // Hit: new state matched
  final updated = current.copyWith(
    matchedPostals: [...current.matchedPostals, match.postal],
  );
  state = AsyncData(updated);
  _gameStateRepository?.saveSession(updated, hintPenalty: _hintPenalty);

  // Check game-end condition
  if (updated.matchedPostals.length == 50) {
    completeGame(); // async — fire and forget (same as MapScreen pattern)
  }

  return true;
}
```

Note: `firstWhereOrNull` requires `package:collection` OR can be replaced with an explicit `for` loop. The codebase does not currently import `package:collection`. Use a local helper or explicit loop to avoid adding a new dependency.

### Pattern 2: SpeedTypingScreen Structure

**What:** `ConsumerStatefulWidget` with `TextEditingController`, `GameLifecycleObserver`, and a `Column`-based layout.

**Example:**
```dart
// Source: pattern derived from MapScreen (lib/features/map/map_screen.dart)
class SpeedTypingScreen extends ConsumerStatefulWidget {
  const SpeedTypingScreen({super.key});

  @override
  ConsumerState<SpeedTypingScreen> createState() => _SpeedTypingScreenState();
}

class _SpeedTypingScreenState extends ConsumerState<SpeedTypingScreen> {
  final _controller = TextEditingController();
  late final GameLifecycleObserver _lifecycleObserver;
  bool _gameStartRequested = false;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = GameLifecycleObserver(
      ref.read(gameSessionProvider.notifier),
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    // Always clear first (D-03: field clears on every Enter press)
    _controller.clear();
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final mapData = ref.read(stateDataProvider).value;
    if (mapData == null) return; // data not yet loaded — ignore submit

    final isHit = ref
        .read(gameSessionProvider.notifier)
        .submitTyping(trimmed, mapData.states);

    final audio = ref.read(audioServiceProvider);
    if (isHit) {
      audio.playCorrect();
    } else {
      audio.playError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(gameSessionProvider);
    final mapDataAsync = ref.watch(stateDataProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (session) {
        // Start game once data is ready
        _maybeStartGame(session);

        // Navigate to /complete when game finishes
        if (session.phase == GamePhase.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final repo = await ref.read(highScoreRepositoryProvider.future);
            final prev = await repo.getBestScore(GameMode.speedTyping);
            if (mounted) {
              context.go('/complete', extra: {
                'session': session,
                'previousBest': prev,
              });
            }
          });
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white,
            title: const Text('Speed Typing'),
            // ... HUD info or leading home button
          ),
          body: Column(
            children: [
              // HUD row: score + elapsed + N/50
              _buildHud(session),
              // Found-states chip grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: session.matchedPostals.map((postal) {
                      final name = mapDataAsync.value?.states
                          .firstWhere((s) => s.postal == postal)
                          .name ?? postal;
                      return Chip(
                        label: Text(name),
                        backgroundColor: Colors.green.shade700,
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Bottom input field (D-04)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _onSubmit,
                  decoration: const InputDecoration(
                    hintText: 'Type a state name or postal code...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### Pattern 3: CompletionScreen — Play Again routing for speedTyping

The existing Play Again button uses:
```dart
// lib/features/map/completion_screen.dart line 276
onPressed: () => context.go('/play', extra: widget.session.mode),
```

This must become mode-aware:
```dart
onPressed: () {
  final destination = widget.session.mode == GameMode.speedTyping
      ? '/type'
      : '/play';
  context.go(destination, extra: widget.session.mode);
},
```

Or equivalently use the `displayName` extension approach: add a `playRoute` getter on `GameMode`.

### Pattern 4: displayName Extension

**What:** A Dart extension on `GameMode` providing human-readable names. Replaces `.name` (which gives `speedTyping` not `Speed Typing`) throughout CompletionScreen and HomeScreen.

**Placement:** In `lib/features/game/game_mode.dart` immediately after the enum.

```dart
// game_mode.dart — full file after Phase 6
enum GameMode { learn, statesMaster, geographicalMaster, grandMaster, speedTyping }

extension GameModeDisplay on GameMode {
  String get displayName => switch (this) {
    GameMode.learn              => 'Learn',
    GameMode.statesMaster       => 'States Master',
    GameMode.geographicalMaster => 'Geographical Master',
    GameMode.grandMaster        => 'Grand Master',
    GameMode.speedTyping        => 'Speed Typing',
  };
}
```

`CompletionScreen` currently uses `widget.session.mode.name` in the app bar title and the `_StatRow` for Mode. Both should switch to `.displayName` as part of this phase.

### Anti-Patterns to Avoid

- **Reading `stateDataProvider` inside `GameSessionNotifier`:** The notifier should not take a `FutureProvider` dependency inside an action method. Pass the already-resolved `List<StateData>` as a method parameter from the widget.
- **Using `collection` package for `firstWhereOrNull`:** Avoid adding `package:collection` just for one helper. Use an explicit `for` loop or local extension.
- **Calling `completeGame()` from inside `submitTyping()` and also watching `session.phase == completed` in the widget:** This is the correct pattern (mirroring `MapScreen`'s `_advanceToNextPostal`), but the widget must use `addPostFrameCallback` to navigate — never navigate synchronously during `build()`.
- **Starting a new game from `initState()` directly:** `initState()` runs before the first frame. Use the `_maybeStartGame()` guard pattern from `MapScreen` — call it from `build()` after `stateDataProvider` data resolves.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timer + elapsed scoring | Custom `Timer.periodic` elapsed counter | Existing `Stopwatch` + `_ticker` in `GameSessionNotifier` | Stopwatch-as-truth pattern already tested; custom counter drifts and double-counts |
| Auto-pause on background | `AppLifecycleState` in `SpeedTypingScreen` | `GameLifecycleObserver` (already exists) | `pauseGame()` stops Stopwatch as first action — custom observer would miss this |
| High score "lower wins" comparison | Custom comparison in `SpeedTypingScreen` | `HighScoreRepository.saveBestScore()` (already lower-wins) | The "lower wins" logic is inside the repository; double-implementing it creates drift |
| State lookup from postal | Custom `Map<String, StateData>` in screen | `stateDataProvider` states list (already loaded) | The provider already loaded and parsed all 50 states; don't duplicate |
| Completion navigation | Custom route push | `context.go('/complete', extra: {'session': session, 'previousBest': prev})` | Matches existing `MapScreen` pattern; `CompletionScreen` already handles all modes |

**Key insight:** Every infrastructure concern for Speed Typing — timer, scoring, persistence, navigation, audio — already exists. The only new code is the input matching logic in `submitTyping()` and the `SpeedTypingScreen` widget layout.

---

## Exhaustiveness Analysis — Every Switch on GameMode

Adding `speedTyping` to the enum triggers Dart exhaustiveness errors at every `switch (mode)` that does not include a default/wildcard arm. The following sites have been confirmed by reading the codebase:

### Sites That WILL Produce Compile Errors (exhaustive switch expressions)

| File | Line | Form | Compile Error? |
|------|------|------|----------------|
| `lib/core/data/high_score_repository.dart` | 15 | `switch (mode) { ... }` expression | YES — missing `speedTyping` arm |
| `lib/features/map/completion_screen.dart` | 104 | `switch (mode) { ... }` expression | YES — missing `speedTyping` arm |

### Sites That WILL Produce Compile Errors (exhaustive switch statements — no default)

| File | Line | Form | Compile Error? |
|------|------|------|----------------|
| `lib/features/home/session_restore_card.dart` | 32 | `switch (mode) { case ... }` statement (no default) | YES — non-exhaustive in Dart 3 |
| `lib/features/map/map_screen.dart` | 653 | `switch (widget.mode) { case ... }` statement (no default) | YES — non-exhaustive in Dart 3 |

### Sites That Require Manual Update (no compile error, but semantically wrong)

| File | Location | Issue |
|------|----------|-------|
| `lib/features/map/completion_screen.dart` | App bar title: `widget.session.mode.name` | Emits `speedTyping` not `Speed Typing` — visual bug, not compile error |
| `lib/features/map/completion_screen.dart` | `_StatRow` Mode value: `widget.session.mode.name` | Same visual bug |
| `lib/features/map/completion_screen.dart` | Play Again button `onPressed` | Routes all modes to `/play` — will send Speed Typing to `MapScreen` (wrong screen) |
| `lib/features/game/game_session_notifier.dart` | `endGame()` hardcodes `mode: GameMode.learn` | Not a bug for phase 6 (endGame resets to idle/learn always) — no action needed |
| `lib/app.dart` | `/play` route | `MapScreen` will receive `GameMode.speedTyping` if `/play` is hit with that extra — no hard crash but wrong screen |

### Summary of Files That Must Be Edited

1. `lib/features/game/game_mode.dart` — add `speedTyping`; add `displayName` extension (D-08)
2. `lib/core/data/high_score_repository.dart` — add `speedTyping` key case
3. `lib/features/map/completion_screen.dart` — add `speedTyping` color case; fix Play Again routing; use `.displayName` on mode.name usages
4. `lib/features/home/session_restore_card.dart` — add `speedTyping` case to `_modeLabel()`
5. `lib/features/map/map_screen.dart` — add `speedTyping` case to `switch (widget.mode)` labels/name matrix (can use `showLabels: false, showName: false` — typing mode never reaches MapScreen in practice, but must compile)
6. `lib/features/home/home_screen.dart` — add Mode 5 `_ModeCard`
7. `lib/app.dart` — add `/type` GoRoute
8. `lib/features/game/game_session_notifier.dart` — add `submitTyping()` action
9. `lib/features/typing/speed_typing_screen.dart` — NEW file

---

## Common Pitfalls

### Pitfall 1: The 5-second Countdown Makes No Sense for a Typing Game

**What goes wrong:** `startGame()` unconditionally enters `GamePhase.countdown` for 5 ticks (~5 seconds) before reaching `GamePhase.playing`. On `MapScreen` this countdown shows "3-2-1-GO!" overlaid on the map while the player orients themselves. On `SpeedTypingScreen` there is no map to orient — the countdown is dead time where the keyboard is visible but nothing is happening.

**Why it happens:** `startGame()` is mode-agnostic and always runs the countdown phase.

**Options:**
- Option A (simplest): Keep countdown, but in `SpeedTypingScreen` do NOT show the numeric overlay. The player sees the empty chip grid and text field for ~5 seconds, then the field becomes interactive once `phase == playing`. This is acceptable but slightly awkward.
- Option B (cleanest): Add a `skipCountdown: bool` parameter to `startGame()`. If `true`, the notifier skips directly to `GamePhase.playing` on the first tick (or immediately). This keeps the notifier clean and the countdown remains for map modes.
- Option C (pragmatic): Call `startGame()` then immediately call the internal ticker 5 times via `addPostFrameCallback`. Not advisable — depends on private ticker internals.

**Recommendation:** Option B. The `startGame()` signature change is small, backward-compatible (default `false`), and the typing screen calls `startGame(GameMode.speedTyping, skipCountdown: true)`. The notifier checks: `if (skipCountdown) { _stopwatch.start(); state = AsyncData(current.copyWith(phase: GamePhase.playing)); _ticker.start(_onTick); return; }`.

**Warning sign:** If `SpeedTypingScreen` cannot type for 5 seconds after navigation, the countdown was not skipped.

### Pitfall 2: Navigating to /complete During build()

**What goes wrong:** Calling `context.go('/complete', ...)` synchronously inside `build()` when `session.phase == GamePhase.completed` causes a "Navigator operation requested during build" assertion failure.

**Why it happens:** GoRouter navigation is not safe during the build phase.

**How to avoid:** Use the `addPostFrameCallback` pattern from `MapScreen._advanceToNextPostal()`:
```dart
if (session.phase == GamePhase.completed && !_navigationPending) {
  _navigationPending = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    // fetch previousBest, then navigate
  });
}
```
The `_navigationPending` flag prevents repeated callbacks on subsequent rebuilds while the navigation is in-flight.

**Warning sign:** `FlutterError: Navigator operation requested during build.`

### Pitfall 3: submitTyping() Called Before stateDataProvider Resolves

**What goes wrong:** `_onSubmit()` is called and `ref.read(stateDataProvider).value` is null (still loading). The method returns early silently — the player types a correct answer that registers as nothing.

**Why it happens:** `stateDataProvider` is a `FutureProvider` that takes time to load the JSON asset. If the user somehow submits before the data resolves (unlikely but possible on slow devices), the match is lost.

**How to avoid:** In `_onSubmit()`, guard on `mapData == null` with an early return (already shown in Pattern 2 above). Additionally, disable the `TextField` (or set `enabled: false`) while `stateDataProvider` is in loading state. The `build()` method already receives `mapDataAsync` — use `enabled: mapDataAsync.hasValue` on the `TextField`.

**Warning sign:** Valid state name typed but no chip appears and no error sound plays.

### Pitfall 4: Duplicate Submission Penalty on Re-type

**What goes wrong:** A player types `CALIFORNIA` again after already finding it. Per D-01, there are no aliases and exact match is required. If duplicates are treated as a no-op rather than a miss, the player learns they can spam known states with no penalty. The decisions lock says to treat duplicates as a wrong submission (+5 penalty).

**How to avoid:** In `submitTyping()`, after finding a match, check `current.matchedPostals.contains(match.postal)` before adding. If already matched, fall through to the miss path.

**Warning sign:** Player types already-found state repeatedly with no penalty effect.

### Pitfall 5: Session Restore for Speed Typing Mode

**What goes wrong:** A player pauses a Speed Typing game, kills the app, and relaunches. `HomeScreen` shows the `SessionRestoreCard`. Tapping Continue calls `restoreGame()` then `context.go('/play', extra: saved.session.mode)`. With `session.mode == GameMode.speedTyping`, this navigates to `MapScreen` not `SpeedTypingScreen` — catastrophically wrong.

**Why it happens:** `HomeScreen`'s `onContinue` callback hardcodes `context.go('/play', ...)` for all modes.

**How to avoid:** The `onContinue` callback in `HomeScreen._buildBody()` must route based on mode:
```dart
onContinue: () {
  ref.read(gameSessionProvider.notifier)
      .restoreGame(saved.session, hintPenalty: saved.hintPenalty);
  final route = saved.session.mode == GameMode.speedTyping ? '/type' : '/play';
  context.go(route, extra: saved.session.mode);
},
```

**Warning sign:** Restoring a Speed Typing session opens the map with no tokens.

### Pitfall 6: `_modeLabel()` in SessionRestoreCard Uses Old-Style switch Without Default

**What goes wrong:** `session_restore_card.dart` `_modeLabel()` uses a `switch` statement with four explicit cases and no `default`. In Dart 3, a non-exhaustive switch on a sealed type or enum without `default` is a compile error.

**How to avoid:** Add `case GameMode.speedTyping: return 'Speed Typing';` — or adopt the `displayName` extension to eliminate the duplication entirely.

**Warning sign:** `The type 'GameMode' is not exhaustively matched` at compile.

### Pitfall 7: MapScreen showLabels/showName Switch

**What goes wrong:** `map_screen.dart` line 653 switches on `widget.mode` with four cases and no default. Adding `speedTyping` without updating this switch causes a compile error.

**How to avoid:** Add a `speedTyping` case (e.g., `showLabels = false; showName = false;` — Grand Master settings). `MapScreen` will never be navigated to with `speedTyping` mode in production, but the code must compile.

**Warning sign:** `Non-exhaustive switch` compile error in `map_screen.dart`.

### Pitfall 8: `completeGame()` is async — SpeedTypingScreen Must Watch for phase.completed

**What goes wrong:** `completeGame()` is `async` and calls `_highScoreRepository.saveBestScore()`. If `SpeedTypingScreen` calls `completeGame()` and immediately tries to read the high score for the navigation extra, the score may not be saved yet.

**Why it happens:** `completeGame()` is fire-and-forget in the current call pattern from `MapScreen`. The navigation in `MapScreen` happens via `_advanceToNextPostal`, which awaits `completeGame()` before navigating.

**How to avoid:** In `SpeedTypingScreen`, use the `session.phase == GamePhase.completed` watch to trigger navigation. This fires after `completeGame()` sets `phase: GamePhase.completed`, which happens BEFORE the `await _highScoreRepository.saveBestScore()` call completes. Two options:

1. Navigate immediately when `phase == completed`, fetching `previousBest` from `highScoreRepository` (before the new score is saved — which means `previousBest` will be the old best, not the just-completed score). This is the correct behavior for "previous best" — the score before this run.
2. Have `submitTyping()` return a `Future<bool>` and `await completeGame()` before the screen navigates.

Option 1 is correct by design: `previousBest` means "what was the best before this game". The existing `MapScreen` pattern uses it correctly:
```dart
// MapScreen._advanceToNextPostal() — the previous best is fetched BEFORE completeGame()
final prev = await _highScoreRepository.getBestScore(current.mode);
await notifier.completeGame();
context.go('/complete', extra: {'session': session, 'previousBest': prev});
```

`SpeedTypingScreen` must replicate this exact pattern: fetch `previousBest` first, THEN trigger the navigation after `completeGame()`.

**Warning sign:** `CompletionScreen` always shows "New Personal Best!" even on a worse run.

---

## Code Examples

### Resolving StateData Without package:collection

```dart
// Source: explicit loop pattern (no external dependency)
StateData? _findMatch(String normalized, List<StateData> states) {
  for (final s in states) {
    if (!s.isPlaceable) continue;
    if (s.name.toUpperCase() == normalized || s.postal == normalized) {
      return s;
    }
  }
  return null;
}
```

### _maybeStartGame pattern for SpeedTypingScreen

```dart
// Source: pattern ported from MapScreen._maybeStartGame()
void _maybeStartGame(GameSession session) {
  if (_gameStartRequested) return;
  final phase = session.phase;
  if (phase != GamePhase.idle && phase != GamePhase.completed) return;
  _gameStartRequested = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      ref.read(gameSessionProvider.notifier)
          .startGame(GameMode.speedTyping, skipCountdown: true);
    }
  });
}
```

### GoRoute registration in app.dart

```dart
// Source: existing app.dart pattern
GoRoute(
  path: '/type',
  builder: (context, state) => const SpeedTypingScreen(),
),
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `mode.name` for display strings | `mode.displayName` (extension) | Phase 6 | `speedTyping` → `Speed Typing` — human readable |
| Hardcoded `/play` in Play Again | Mode-aware routing | Phase 6 | `speedTyping` routes to `/type`, others to `/play` |
| Session restore routes all to `/play` | Mode-aware restore routing | Phase 6 | `speedTyping` restored sessions route to `/type` |

---

## Runtime State Inventory

> Phase 6 is a new-feature addition, not a rename or refactor. No existing stored data has keys to migrate.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `shared_preferences` keys `high_score_learn`, `high_score_states_master`, `high_score_geographical_master`, `high_score_grand_master` — unaffected | None — new key `high_score_speed_typing` is additive |
| Live service config | None — no external services | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

---

## Open Questions

1. **Should `startGame()` accept a `skipCountdown` parameter?**
   - What we know: The 5-second countdown exists in `GameSessionNotifier.startGame()` and is hard to bypass without modifying the notifier.
   - What's unclear: Whether the product owner considers the 5-second countdown desirable for Speed Typing (it is harmless but slightly odd).
   - Recommendation: Add `skipCountdown: bool = false` to `startGame()`. The planner should implement this in the same plan that adds `speedTyping` to the enum (Wave 1 of Phase 6).

2. **Does session restore need updating for the typing screen?**
   - What we know: `HomeScreen.onContinue` hardcodes `context.go('/play', extra: saved.session.mode)`. A Speed Typing session in `SharedPreferences` would route incorrectly.
   - Recommendation: Yes, must be fixed. Add to the plan as a required edit to `home_screen.dart`.

3. **Should `completeGame()` in submitTyping use async/await?**
   - What we know: `MapScreen` fetches `previousBest` before calling `completeGame()`, then navigates. `SpeedTypingScreen` must do the same.
   - Recommendation: Follow MapScreen's exact pattern. The planner should document this ordering explicitly in the plan tasks.

---

## Environment Availability

> Step 2.6: No new external tools or services. Phase 6 is pure Dart/Flutter code. All dependencies are already in pubspec.yaml and installed.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) |
| Config file | `pubspec.yaml` (standard Flutter test runner) |
| Quick run command | `flutter test test/features/game/game_session_notifier_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TYPING-01 | Mode 5 card renders on HomeScreen | Widget | `flutter test test/features/home/home_screen_test.dart` | ✅ (extend existing) |
| TYPING-02 | Tapping Mode 5 card navigates to `/type` | Widget | `flutter test test/features/home/home_screen_test.dart` | ✅ (extend existing) |
| TYPING-03 | TextField has `TextCapitalization.characters` | Widget | `flutter test test/features/typing/speed_typing_screen_test.dart` | ❌ Wave 0 |
| TYPING-04 | Valid state name/postal → hit=true, SFX | Unit + Widget | `flutter test test/features/game/game_session_notifier_test.dart` | ✅ (extend existing) |
| TYPING-05 | Non-matching string → hit=false, +5 penalty | Unit | `flutter test test/features/game/game_session_notifier_test.dart` | ✅ (extend existing) |
| TYPING-06 | Found-states Wrap shows chips | Widget | `flutter test test/features/typing/speed_typing_screen_test.dart` | ❌ Wave 0 |
| TYPING-07 | Game ends when 50 states found | Unit | `flutter test test/features/game/game_session_notifier_test.dart` | ✅ (extend existing) |
| TYPING-08 | Timer pauses on background | Unit | `flutter test test/features/game/game_lifecycle_observer_test.dart` | ✅ (already tested; typing mode reuses same path) |
| TYPING-09 | Best score stored after completion | Unit | `flutter test test/features/game/game_session_notifier_test.dart` | ✅ (extend existing) |

### Key Unit Test Cases for `submitTyping()`

These should be added to `test/features/game/game_session_notifier_test.dart`:

1. **Hit — full name match:** `submitTyping('GEORGIA', states)` returns `true`, `matchedPostals` contains `'GA'`, `errorCount` unchanged.
2. **Hit — postal match:** `submitTyping('GA', states)` returns `true`, same result as full name hit.
3. **Miss — invalid string:** `submitTyping('NOTASTATE', states)` returns `false`, `errorCount` incremented by 1, score recalculated.
4. **Duplicate — already matched:** `submitTyping('GEORGIA', states)` after Georgia already in `matchedPostals` returns `false`, `errorCount` incremented.
5. **Miss — partial name:** `submitTyping('MASS', states)` returns `false` (D-01: no aliases).
6. **Miss — missing space:** `submitTyping('NEWYORK', states)` returns `false` (D-02: space required).
7. **Game end at 50 states:** Submitting the 50th state triggers `completeGame()`, `session.phase == GamePhase.completed`.
8. **Not playing:** `submitTyping()` when `phase != playing` returns `false`, state unchanged.

### Key Widget Test Cases for `SpeedTypingScreen`

These go in `test/features/typing/speed_typing_screen_test.dart` (new file):

1. **Renders with empty chip grid initially.**
2. **TextField has `textCapitalization: TextCapitalization.characters`.**
3. **After a hit, a chip appears in the Wrap.**
4. **Field is cleared after every Enter press** (hit and miss alike).

### Sampling Rate

- **Per task commit:** `flutter test test/features/game/game_session_notifier_test.dart test/features/typing/speed_typing_screen_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/features/typing/speed_typing_screen_test.dart` — covers TYPING-03, TYPING-06; directory `test/features/typing/` needs creating
- [ ] Test fixture: a minimal `List<StateData>` with 3–5 states for `submitTyping()` unit tests (add as a helper in the existing notifier test file or as a shared fixture)

*(No new test framework install needed — `flutter_test` and `mocktail` are already in `pubspec.yaml`.)*

---

## Security Domain

> COPPA compliance is the primary security concern for this app. Phase 6 adds no new data collection, no new network calls, no new permissions, and no new identifiers.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No accounts in this app |
| V3 Session Management | No | Session is local `SharedPreferences` only |
| V4 Access Control | No | No roles or permissions |
| V5 Input Validation | Yes | `submitTyping()` trims input; no SQL/HTML injection surface (pure string comparison) |
| V6 Cryptography | No | No secrets stored |

### COPPA Checklist for Phase 6

| Concern | Status | Notes |
|---------|--------|-------|
| New persistent identifier | No | Speed Typing best score stored under a string key in `SharedPreferences` — identical to existing 4 mode keys; no device ID |
| New network call | No | All data is bundled |
| `AD_ID` permission | No change | Not affected by Phase 6 |
| New `import` from ads module in `GameSessionNotifier` | No | `submitTyping()` has zero ad imports (walled-garden rule preserved) |

---

## Sources

### Primary (HIGH confidence — direct codebase reads)

- `lib/features/game/game_mode.dart` — current enum (4 values); confirms `speedTyping` does not yet exist
- `lib/features/game/game_session_notifier.dart` — `recordDrop()` and `completeGame()` patterns; `startGame()` countdown flow
- `lib/features/game/game_session.dart` — `matchedPostals: List<String>` field confirmed
- `lib/features/game/game_lifecycle_observer.dart` — observer registration pattern
- `lib/features/map/completion_screen.dart` — `_modeColor()` switch; Play Again routing; `.name` usage
- `lib/features/home/home_screen.dart` — `_ModeCard` widget signature and call pattern
- `lib/features/home/session_restore_card.dart` — `_modeLabel()` switch; `onContinue` routing
- `lib/features/map/map_screen.dart` — `_maybeStartGame()` guard; `switch (widget.mode)` for showLabels; `initState/dispose` observer pattern; `_advanceToNextPostal()` async complete+navigate sequence
- `lib/core/data/high_score_repository.dart` — `_key()` switch; `saveBestScore()` lower-wins logic
- `lib/core/data/state_data_service.dart` — `stateDataProvider`; `MapData.states: List<StateData>`
- `lib/core/models/state_data.dart` — `StateData.name`, `StateData.postal`, `StateData.isPlaceable` fields
- `lib/core/audio/audio_service.dart` — `playCorrect()` / `playError()` interface
- `lib/app.dart` — existing GoRouter routes; `/complete` extra pattern
- `.planning/phases/06-speed-typing-mode/06-CONTEXT.md` — locked decisions D-01 through D-09

### Secondary (MEDIUM confidence — planning artifacts)

- `.planning/REQUIREMENTS.md` — TYPING-01 through TYPING-09 requirements text
- `.planning/ROADMAP.md` — Phase 6 success criteria
- `.planning/STATE.md` — accumulated decisions log

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new packages; all existing
- Architecture: HIGH — direct codebase read; all patterns verified in existing files
- Pitfalls: HIGH — derived from existing code behavior (session restore routing, countdown, navigation timing)
- Exhaustiveness analysis: HIGH — all switch sites found via grep and file read

**Research date:** 2026-06-02
**Valid until:** 2026-07-02 (stable codebase; no fast-moving external APIs)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dart 3's non-exhaustive switch statement (without `default`) produces a compile error | Exhaustiveness Analysis | If this is a warning rather than error, the planner may not prioritize fixing `map_screen.dart` and `session_restore_card.dart` — but it must still be fixed |
| A2 | `firstWhereOrNull` is not available without `package:collection` in this project | Pattern 1 | If `collection` is already transitively available, an explicit loop is still safe and preferred |

**If this table had only 2 items:** Both are low-risk — the codebase uses Dart 3 exclusively (confirmed by pubspec.yaml `sdk: '>=3.10.0'`), which enforces exhaustive switch expressions and warns on non-exhaustive switch statements.
