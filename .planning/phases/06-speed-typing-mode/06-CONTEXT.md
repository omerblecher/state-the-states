# Phase 6: Speed Typing Mode - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 delivers Mode 5 (Speed Typing) end-to-end:

1. **Home screen card** — A 5th mode card for Speed Typing on `HomeScreen`, showing best score + stars.
2. **SpeedTypingScreen** — UPPERCASE text input field (bottom-anchored, keyboard-docked) + scrolling `Wrap` of green chips for found states. Score/timer HUD at the top.
3. **Input validation** — Accepts exact full name (`GEORGIA`) or 2-letter postal code (`GA`). No aliases. Field clears on every Enter press. Space required in multi-word names.
4. **Golf scoring** — +1 per 10 seconds + +5 per wrong submission. Timer auto-pauses on app background.
5. **Game end** — All 50 found → navigates to existing `CompletionScreen` via `/complete`.
6. **Best score** — Stored via `SharedPreferences`; displayed on the Mode 5 home card.
7. **CompletionScreen** — Extended for Mode 5: new `speedTyping` case in `_modeColor()`, Play Again routes to `/type`, `displayName` extension added to `GameMode`.

**What is NOT in Phase 6:** AdMob, gated sharing, hint refill, hint system for typing mode, any map rendering.

</domain>

<decisions>
## Implementation Decisions

### Input Matching

- **D-01: Exact match only — full name + 2-letter postal code.** No abbreviations, no aliases. `GEORGIA` and `GA` match. `MASS` does not match Massachusetts. The UPPERCASE field eliminates case errors; no fuzzy matching needed.
- **D-02: Space required in multi-word names.** `NEW YORK` matches. `NEWYORK` does not. Comparison: `inputText.trim() == stateName.toUpperCase()` or `inputText.trim() == postalCode`. Simple, no edge cases.
- **D-03: Field clears on every Enter press.** Correct match → success SFX + chip + clear. Wrong match → +5 penalty + clear. Consistent UX; player re-types for another attempt. No red-highlight retain.

### Screen Layout

- **D-04: Text field bottom-anchored above the keyboard.** `SpeedTypingScreen` uses `resizeToAvoidBottomInset: true` (default) with the input field pinned at the bottom via a `Column` + `Spacer` or `Expanded` above for the chip grid. The found-states grid fills the space above the field.
- **D-05: Found states — chips in a scrollable Wrap.** Green `Chip` widgets inside a `SingleChildScrollView` + `Wrap`. States fill in left-to-right as found. Organic, visually satisfying, handles 50 chips without a fixed grid.
- **D-06: Chips display full state name.** `CALIFORNIA`, `NEW YORK`, etc. on each chip. Educational reinforcement — player sees the full name they typed.

### CompletionScreen Compatibility

- **D-07: Add `speedTyping` to `_modeColor()` switch in `CompletionScreen`.** Color: `const Color(0xFF00695C)` (teal/dark cyan — distinct from the existing 4 mode colors). Play Again button (`context.go('/play', extra: widget.session.mode)`) must be updated to route to `/type` when `mode == GameMode.speedTyping`.
- **D-08: Add `displayName` extension on `GameMode`.** `extension GameModeDisplay on GameMode { String get displayName => switch (this) { GameMode.learn => 'Learn', GameMode.statesMaster => 'States Master', GameMode.geographicalMaster => 'Geographical Master', GameMode.grandMaster => 'Grand Master', GameMode.speedTyping => 'Speed Typing' } }`. Used by `CompletionScreen`, `HomeScreen` mode cards, and the app bar. Replaces raw `.name` usage.
- **D-09: Mode color for Speed Typing: teal `0xFF00695C`.** Used in `HomeScreen` `_ModeCard.cardColor`, `CompletionScreen._modeColor()`, and the `SpeedTypingScreen` app bar.

### Claude's Discretion

- **State management architecture:** Extend `GameSessionNotifier` by adding `speedTyping` to the `GameMode` enum. Add a `submitTyping(String input)` action that checks the input against unmatched state names/postal codes, updates `matchedPostals`, applies +5 penalty on miss, and returns `bool`. `activePostal` is always `null` in typing mode. `hintsRemaining` is irrelevant (ignore). This reuses the existing timer, lifecycle observer, `CompletionScreen` routing, and `GameStateRepository` session persistence.
- **Route name:** `/type` for `SpeedTypingScreen` in `app.dart`.
- **HUD layout on SpeedTypingScreen:** Score + elapsed time displayed in a compact row at the top (consistent with `GameHud` style). States-found counter (e.g., `23 / 50`) shown alongside.
- **HighScoreRepository key:** Add `GameMode.speedTyping => 'high_score_speed_typing'` to the `_key()` switch.
- **Icon for Mode 5 card:** `Icons.keyboard` or `Icons.abc` — Claude picks whichever is clearer.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 6 Requirements & Goal
- `.planning/ROADMAP.md` §"Phase 6: Speed Typing Mode" — goal, 5 success criteria (verification target), UI hint flag.
- `.planning/REQUIREMENTS.md` §v2 Requirements — TYPING-01 through TYPING-09 (9 requirements for this phase).
- `.planning/PROJECT.md` — core value, COPPA constraints, offline requirement, walled-garden ad rule.
- `CLAUDE.md` — locked stack/versions, "What NOT to Use", app ID.

### Prior Phase Context (locked decisions)
- `.planning/phases/05-polish-welcome-accessibility/05-CONTEXT.md` — architecture decisions carried forward, code patterns established in v1.
- `.planning/phases/04-full-play-loop/04-CONTEXT.md` — D-11 star formula (used by `CompletionScreen` and `HomeScreen._ModeCard`), existing `GameSessionNotifier` scoring contract.

### Existing Code to Extend (do not rewrite)
- `lib/features/game/game_mode.dart` — add `speedTyping` to the enum; add `displayName` extension.
- `lib/features/game/game_session_notifier.dart` — add `submitTyping(String input)` action.
- `lib/features/home/home_screen.dart` — add Mode 5 `_ModeCard` entry.
- `lib/features/map/completion_screen.dart` — add `speedTyping` to `_modeColor()` switch; fix Play Again routing; adopt `displayName` extension.
- `lib/core/data/high_score_repository.dart` — add `speedTyping` case to `_key()` switch.
- `lib/app.dart` — add `/type` route pointing to `SpeedTypingScreen`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`HighScoreRepository.getBestScore(GameMode)`** (`lib/core/data/high_score_repository.dart`): Works for any `GameMode` — just add the `speedTyping` key case. `HomeScreen` and `CompletionScreen` already call this generically.
- **`_ModeCard` widget** (`lib/features/home/home_screen.dart`): Self-contained — accepts `GameMode`, name, description, icon, `cardColor`, `bestScoreFuture`, `onTap`. Adding Mode 5 is a copy-paste + field fill.
- **`computeStarCount(int score, int? previousBest)`** (`lib/features/map/completion_screen.dart`): Pure function, mode-agnostic. Speed Typing uses the same formula.
- **`GameSession.matchedPostals`** (`lib/features/game/game_session.dart`): Already a `List<String>` of found postal codes — exactly what `SpeedTypingScreen` needs to track found states. Reuse directly.
- **`GameLifecycleObserver`** (`lib/features/game/game_lifecycle_observer.dart`): Handles auto-pause on app background. `SpeedTypingScreen` registers it the same way `MapScreen` does.

### Established Patterns
- **`ConsumerStatefulWidget` + `TextEditingController`**: `SpeedTypingScreen` needs a `ConsumerStatefulWidget` for Riverpod access + a `TextEditingController` for the UPPERCASE input field.
- **`go_router` `/complete` navigation**: `MapScreen` calls `context.go('/complete', extra: {'session': session, 'previousBest': prev})` on game end. `SpeedTypingScreen` uses the same call pattern.
- **`GameSessionNotifier` scoring actions**: `incorrectDrop()` adds +5. A new `submitTyping(String)` should follow the same pattern — check input, update `matchedPostals` on hit or call `incorrectDrop()` equivalent on miss.
- **`TextCapitalization.characters`** on `TextField`: Satisfies TYPING-03 (UPPERCASE input) without manual `toUpperCase()` transforms on every keystroke.

### Integration Points
- **`app.dart` routes**: Add `GoRoute(path: '/type', builder: (_, __) => const SpeedTypingScreen())`.
- **`GameMode` enum exhaustiveness**: Adding `speedTyping` will cause Dart exhaustiveness errors in every existing `switch (mode)` — `_modeColor()` in `CompletionScreen`, `_key()` in `HighScoreRepository`, `displayName` extension, any mode-label helpers. All switches must be updated.
- **`HomeScreen._buildBody()`**: Add the Mode 5 `_ModeCard` after Grand Master (or as the 5th entry). `onTap: () => context.go('/type')`.
- **`SpeedTypingScreen` timer/lifecycle**: `GameSessionNotifier` starts a timer when `phase == playing`. Speed Typing calls `startGame(mode: GameMode.speedTyping)` — reuses the same timer infrastructure.

</code_context>

<specifics>
## Specific Ideas

- The `SpeedTypingScreen` body structure: `Scaffold` with `resizeToAvoidBottomInset: true`. Body is a `Column`: top portion is `Expanded(child: SingleChildScrollView(child: Wrap(...chips...)))`, bottom portion is the text field row (TextField + submit button or keyboard action). Score/timer HUD at the very top as a `Container` row.
- `TextField` with `textCapitalization: TextCapitalization.characters`, `textInputAction: TextInputAction.done`, and `onSubmitted: _onSubmit` handler. The `_onSubmit` method calls `ref.read(gameSessionProvider.notifier).submitTyping(value)` and always clears the controller.
- Chip style: `Chip(label: Text(stateName), backgroundColor: Colors.green.shade700, labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))`.
- The `submitTyping()` action compares `input.trim()` against `StateData.name.toUpperCase()` (full name) and `StateData.postal` (postal code, already uppercase). Look up in the `StateData` list from `stateDataProvider`. If matched and not in `matchedPostals`, it's a hit; if already in `matchedPostals`, treat as wrong (duplicate); if no match, it's a miss.
- Game-end condition: `matchedPostals.length == 50` after a hit → transition to `GamePhase.complete` and route to `/complete`.

</specifics>

<deferred>
## Deferred Ideas

- **Hint system for Speed Typing** — not in Phase 6 requirements. Speed Typing has no map, so zoom-to-centroid hints don't apply. If a hint mechanic for typing mode is desired (e.g., reveal the first letter), that's a future phase.
- **Alphabetical sort for found chips** — chips could be sorted alphabetically as they're added. Deferred: adds complexity, requirements say "scrolling found-states grid" without sort order constraint.
- **Timer display on home card** — showing average time or other stats on the Mode 5 card beyond best score. Deferred: not in TYPING-01/09 requirements.

</deferred>

---

*Phase: 6-Speed-Typing-Mode*
*Context gathered: 2026-06-02*
