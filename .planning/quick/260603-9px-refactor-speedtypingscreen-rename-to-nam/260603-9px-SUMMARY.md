---
quick_id: 260603-9px
slug: refactor-speedtypingscreen-rename-to-nam
description: "Refactor SpeedTypingScreen: rename to Name all the states, add TypingResult enum, fix keyboard layout, add progress bar, chip animations, distinct error SnackBars"
date: 2026-06-03
status: complete
commits:
  - f1457fc
  - db7566d
---

# Quick Task 260603-9px — Summary

## What Was Delivered

**Task 1 — TypingResult enum + submitTyping return type + mode rename** (`f1457fc`)

- `lib/features/game/typing_result.dart` (new) — `enum TypingResult { hit, invalid, duplicate }`
- `lib/features/game/game_mode.dart` — `speedTyping.displayName` is now `'Name all the states'`
- `lib/features/game/game_session_notifier.dart` — `submitTyping()` returns `TypingResult` with distinct `invalid` / `duplicate` / `hit` values; scoring behavior unchanged (both invalid and duplicate still increment `errorCount`)

**Task 2 — SpeedTypingScreen layout, animations, SnackBars + test update** (`db7566d`)

- `lib/features/typing/speed_typing_screen.dart` — Full refactor:
  - AppBar title: `'Name all the states'`
  - TextField moved to top of body Column with `autofocus: true` (keyboard no longer crushes chip grid)
  - HUD redesigned: two-row container — Row 1 has `_StatColumn` widgets (SCORE, FOUND X/50) + timer/mute/pause; Row 2 has `LinearProgressIndicator(value: matched/50.0, minHeight: 6, Colors.greenAccent)`
  - `_onSubmit` switches exhaustively on `TypingResult`:
    - `hit` → play correct SFX (existing)
    - `invalid` → play error SFX + red floating SnackBar "Invalid state — +5 penalty"
    - `duplicate` → play error SFX + amber floating SnackBar "Already found! — +5 penalty"
  - Chips replaced with `_AnimatedChip` (350ms `Curves.elasticOut` scale + `Curves.easeIn` fade, `ValueKey(postal)`)
  - New private widgets: `_StatColumn`, `_AnimatedChip`
- `test/features/typing/speed_typing_screen_test.dart` — Updated `'Speed Typing'` → `'Name all the states'`; all 4 tests pass
