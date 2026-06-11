---
phase: quick-260611-tql
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/map/map_screen.dart
  - test/features/map/map_screen_test.dart
autonomous: true
requirements: [QUICK-260611-TQL]

must_haves:
  truths:
    - "After restoring a paused session, the map shows already-placed states as matched (correctly colored)"
    - "After restore, the GameHud progress count starts at session.matchedPostals.length, not 0"
    - "After restore, already-matched states are excluded from _remainingPostals so they are never re-prompted in the tray"
    - "A fresh game (no matched postals) still shuffles all 50 placeable states with _matchedPostals empty"
  artifacts:
    - path: "lib/features/map/map_screen.dart"
      provides: "_startSequence seeded from restored session.matchedPostals"
      contains: "_matchedPostals = "
  key_links:
    - from: "lib/features/map/map_screen.dart::_buildMapStack"
      to: "_startSequence"
      via: "session threaded as second argument"
      pattern: "_startSequence\\(states, session\\)"
---

<objective>
Fix the session-restore bug in MapScreen. When a user taps "Continue" on the HomeScreen to restore a paused game, MapScreen mounts fresh and `_startSequence` shuffles ALL 50 placeable states into `_remainingPostals` while leaving `_matchedPostals` empty. The restored session's `matchedPostals` (e.g. ["TX","CA"]) is never read, so the map shows nothing placed, the HUD progress shows 0, and already-placed states get re-prompted.

Purpose: Restore must resume from where the player left off — placed states stay placed, progress count is correct, and only unplaced states are prompted.
Output: `_startSequence` accepts the `GameSession?`, seeds `_matchedPostals` from `session.matchedPostals`, and filters already-matched postals out of the playable pool before shuffling. Plus a widget test that proves restore behavior.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@.planning/STATE.md

@lib/features/map/map_screen.dart
@lib/features/game/game_session.dart
@lib/features/game/game_session_notifier.dart

<interfaces>
<!-- Key contracts the executor needs — no codebase exploration required. -->

From lib/features/game/game_session.dart:
- `class GameSession` has `final List<String> matchedPostals;` (defaults to `const []`), `final GamePhase phase;`, `final GameMode mode;`.

From lib/features/game/game_session_notifier.dart:
- `restoreGame(GameSession restoredSession, {required int hintPenalty})` sets state to `restoredSession.copyWith(phase: GamePhase.paused)`. So a restored session arrives in `GamePhase.paused` with `matchedPostals` populated.
- `_maybeStartGame` already guards on phase: it only calls `startGame()` when phase is `idle` or `completed`, so a `paused` restore is NOT overridden. No change needed there.

From lib/features/map/map_screen.dart (current behavior to change):
- `void _startSequence(List<StateData> states)` (line ~326): sets `_sequenceInitialized = true`, assigns `_states`, builds `playable` = all non-DC postals shuffled into `_remainingPostals`, sets `_currentPostal`, builds `_stateIndex`. `_matchedPostals` is left as `{}`.
- Call site `_buildMapStack` (line ~705): `_startSequence(states); _maybeStartGame(session);` — `session` (a `GameSession?`) is already in scope here.
- `GameHud` reads `matchedCount: _matchedPostals.length`; `UsaMapPainter` reads `matchedPostals: _matchedPostals`. Both are driven by the widget-level `_matchedPostals`, so seeding it correctly fixes both progress and map coloring.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Seed _startSequence from restored session</name>
  <files>lib/features/map/map_screen.dart</files>
  <behavior>
    - Fresh game (session null OR session.matchedPostals empty): _remainingPostals contains all 50 placeable postals (DC excluded), _matchedPostals is empty, _currentPostal is the first remaining.
    - Restored game (session.matchedPostals == ["TX","CA"]): _matchedPostals == {"TX","CA"}, _remainingPostals contains exactly 48 postals and excludes "TX" and "CA", _currentPostal is one of the remaining (not TX or CA).
    - Idempotency preserved: a second _startSequence call (rebuild) is a no-op because _sequenceInitialized short-circuits at the top — restore seeding must happen on the first call only.
  </behavior>
  <action>
    Change the signature of `_startSequence` to accept the session: `void _startSequence(List<StateData> states, GameSession? session)`. Keep the existing `if (_sequenceInitialized) return;` guard and `_sequenceInitialized = true;` at the top — restore seeding runs once, on first init.

    After assigning `_states = states`, derive the already-matched set from the restored session: read `session?.matchedPostals` (a `List<String>`), default to empty when null. Assign `_matchedPostals = Set<String>.from(matched)` so the widget-level matched set reflects the restore.

    Build the `playable` list as before (filter `s.postal != 'DC'`, map to postal) BUT also exclude any postal already in the matched set BEFORE shuffling. Then `..shuffle()` and assign to `_remainingPostals`. Set `_currentPostal` to `_remainingPostals.first` only when the list is non-empty (existing guard). Keep `_stateIndex` construction and the post-frame `_fitMapToScreen()` callback unchanged.

    Update the call site in `_buildMapStack` to thread the session: `_startSequence(states, session);` (the local `session` parameter is already in scope). Do NOT touch `_maybeStartGame` — its phase guard (idle/completed only) already prevents overriding a paused restore.

    Do not introduce a "v1/simplified" path — handle the null session and empty-matched cases through the same default-to-empty logic.
  </action>
  <verify>
    <automated>cd C:\code\Claude\StateTheStates; flutter analyze lib/features/map/map_screen.dart</automated>
  </verify>
  <done>_startSequence(states, session) seeds _matchedPostals from session.matchedPostals and excludes those postals from _remainingPostals; call site passes session; flutter analyze is clean.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add restore widget test</name>
  <files>test/features/map/map_screen_test.dart</files>
  <behavior>
    - With a restored paused session (matchedPostals non-empty), MapScreen renders the GameHud reporting matchedCount == the restored count, and UsaMapPainter receives matchedPostals containing the restored postals.
    - The fresh-game existing tests still pass (matchedCount 0 baseline unaffected).
  </behavior>
  <action>
    Add one `testWidgets` case to `test/features/map/map_screen_test.dart` following the existing pattern: resolve real `mapData` via `container.read(stateDataProvider.future)` inside `tester.runAsync`, then `pumpWidget` a `ProviderScope` overriding `stateDataProvider` with the resolved data.

    To put the session into a restored/paused state, override `gameSessionProvider` is not necessary — instead, after the first two `await tester.pump()` calls, drive the notifier directly: read the container's `gameSessionProvider.notifier` and call `restoreGame(...)` with a `GameSession` whose `phase` is `GamePhase.paused` and `matchedPostals` is a known list of two real postals (e.g. `['CA','TX']`), `hintPenalty: 0`. Pump again so MapScreen rebuilds.

    Important sequencing: MapScreen's `_startSequence` runs on the FIRST `_buildMapStack` (first data pump) and is idempotent thereafter, so the restored session must be applied BEFORE the map stack first builds. Achieve this by pre-seeding the session: build a `ProviderContainer`, call `restoreGame` on it before `pumpWidget`, and pass that same container into the `ProviderScope` via `UncontrolledProviderScope` (or use `ProviderScope(overrides: [gameSessionProvider.overrideWith(() => <notifier seeded to paused state>)])`). Prefer the simplest approach that lands a paused session with matchedPostals == ['CA','TX'] visible to MapScreen on its first build.

    Assert: `find.byType(GameHud)` resolves and its `matchedCount` is 2 (use `tester.widget<GameHud>(...)`). Assert a `UsaMapPainter` exists whose `matchedPostals` contains 'CA' and 'TX' (use `find.byWidgetPredicate` matching `CustomPaint` with `painter is UsaMapPainter` and `(painter).matchedPostals.containsAll({'CA','TX'})`, mirroring the existing showLabels predicate tests).

    Import `package:state_states/features/game/game_phase.dart`, `game_session.dart`, and `game_session_notifier.dart` as needed.
  </action>
  <verify>
    <automated>cd C:\code\Claude\StateTheStates; flutter test test/features/map/map_screen_test.dart</automated>
  </verify>
  <done>New restore test passes and asserts matchedCount == 2 and the painter receives CA + TX as matched; all pre-existing map_screen_test.dart cases still pass.</done>
</task>

</tasks>

<verification>
- `flutter analyze lib/features/map/map_screen.dart` is clean.
- `flutter test test/features/map/map_screen_test.dart` passes, including the new restore case.
- Manual reasoning check: on restore with matchedPostals=["CA","TX"], _remainingPostals has 48 entries excluding CA/TX, _matchedPostals == {"CA","TX"}, HUD count == 2, map colors CA/TX as placed.
</verification>

<success_criteria>
- Restored sessions resume with correct matched state: placed states stay placed (map + HUD), and already-matched states are never re-prompted in the tray.
- Fresh games are unaffected (empty matched set, all 50 placeable states shuffled).
- No "simplified/placeholder" path introduced; null and empty-matched cases share one code path.
</success_criteria>

<output>
Create `.planning/quick/260611-tql-fix-session-restore-bug-in-mapscreen-sta/260611-tql-SUMMARY.md` when done.
</output>
