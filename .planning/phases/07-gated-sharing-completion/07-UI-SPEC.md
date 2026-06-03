---
phase: 7
slug: gated-sharing-completion
status: approved
shadcn_initialized: false
preset: none
created: 2026-06-03
---

# Phase 7 — UI Design Contract: Gated Sharing Completion

> Visual and interaction contract for Phase 7. One file is modified: `lib/features/map/completion_screen.dart`. No new screens, no new routes. This contract documents only the delta from the existing implementation plus the full inherited design context the executor needs.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter Material 3, no third-party design system) |
| Preset | not applicable |
| Component library | Flutter Material 3 widgets (AlertDialog, OutlinedButton, CircularProgressIndicator, ElevatedButton, TextButton, TextField) |
| Icon library | Material Icons (`Icons.share`, `Icons.home`, `Icons.replay`, `Icons.star_rounded`, `Icons.star_outline_rounded`) |
| Font | Roboto (Android system default — no custom font declared) |

---

## Spacing Scale

Inherited from prior phases. Values relevant to `CompletionScreen`:

| Token | Value (dp) | Usage on CompletionScreen |
|-------|-----------|--------------------------|
| xs | 4dp | Star icon horizontal padding (`EdgeInsets.symmetric(horizontal: 4)`) |
| sm | 8dp | Gap between star row and "Well done!" title; gap between title and PB badge |
| md | 16dp | Score card internal padding for dialog content vertical gap (`SizedBox(height: 16)`) |
| lg | 24dp | Horizontal screen padding; score card internal `padding: EdgeInsets.all(24)` |
| xl | 32dp | Vertical screen padding; gap above and below score card (`SizedBox(height: 32)`) |
| 2xl | 48dp | Share button height; Play Again button height; spinner container height |
| 56dp | 56dp | Back to Menu button height (primary CTA — not a standard scale token, inherited) |

Exceptions: 12dp gap between consecutive CTA buttons (Play Again → Share) — retained from existing code. 20dp border radius on PB badge container. 14dp border radius on all CTA buttons.

---

## Typography

Inherited from prior phases. All values used on `CompletionScreen`:

| Role | Size | Weight | Line Height | Usage |
|------|------|--------|-------------|-------|
| Display | 28dp | w700 | system default (~1.2) | "Well done!" heading (`Text('Well done!')`) |
| Body / Label | 14dp | w400 | system default (~1.5) | `_StatRow` label column (`Colors.grey.shade600`) |
| Body / Value | 14dp | w700 | system default (~1.5) | `_StatRow` value column |
| Math gate question | 24dp | w700 (bold) | system default (~1.2) | `Text('What is $_a × $_b?')` inside `_MathChallengeDialog` |
| PB badge | 14dp | w700 | system default | "New Personal Best!" badge text (`Colors.white`) |
| CTA button label | 16dp | bold (700) | system default | "Back to Menu" label only; other buttons use default button text size |
| Dialog body | system body2 (~14dp) | w400 | system default | "To share, a grown-up needs to answer:" |

---

## Color

Inherited from prior phases. All values used on `CompletionScreen`:

| Role | Value | Usage |
|------|-------|-------|
| Scaffold background | `#F5F5F5` (`Color(0xFFF5F5F5)`) | Screen background |
| Score card surface | `Colors.white` | Card background; `Container` decoration color |
| Score card shadow | `Colors.black12` | `BoxShadow` on score card; blurRadius 8, offset Offset(0, 4) |
| Share button outline | `Colors.grey.shade400` | `BorderSide` color on Share button |
| Share button foreground | `Colors.grey.shade700` | Icon and label color on Share button |
| Spinner | system default (`ColorScheme.primary`) | `CircularProgressIndicator` — no explicit color override |
| PB badge background | `Colors.amber.shade700` | "New Personal Best!" badge `Container` decoration |
| PB badge text | `Colors.white` | PB badge label |
| Star earned | `Colors.amber` | `Icons.star_rounded` for earned stars |
| Star empty | `Colors.grey.shade400` | `Icons.star_outline_rounded` for unearned stars |

Mode accent colors (used for AppBar, "Well done!" text, Back to Menu button, Play Again border/foreground):

| Mode | Value |
|------|-------|
| learn | `#2E7D32` (`Color(0xFF2E7D32)`) |
| statesMaster | `#1565C0` (`Color(0xFF1565C0)`) |
| geographicalMaster | `#BF360C` (`Color(0xFFBF360C)`) |
| grandMaster | `#4A148C` (`Color(0xFF4A148C)`) |
| speedTyping | `#00695C` (`Color(0xFF00695C)`) |

Accent reserved for: AppBar background, "Well done!" heading text, Back to Menu `ElevatedButton` background, Play Again `OutlinedButton` foreground and border. The Share button deliberately uses grey (not mode accent) to signal secondary/optional status.

---

## Screen Inventory

### Modified Screens in Phase 7

Only `CompletionScreen` (`lib/features/map/completion_screen.dart`) changes. No new screens. No new routes.

#### CompletionScreen — Widget Structure Delta

**New state fields added to `_CompletionScreenState`:**

```dart
final GlobalKey _scoreCardKey = GlobalKey();
bool _isSharing = false;
```

**RepaintBoundary at line 202 — add key:**

```
// BEFORE:
RepaintBoundary(
  child: Card(...)
)

// AFTER:
RepaintBoundary(
  key: _scoreCardKey,   // ← added
  child: Card(...)
)
```

**Share button section (lines 293–309) — conditional wrap + spinner state:**

```
// BEFORE (unconditional):
const SizedBox(height: 12),
SizedBox(
  width: double.infinity,
  height: 48,
  child: OutlinedButton.icon(
    onPressed: _onSharePressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.grey.shade700,
      side: BorderSide(color: Colors.grey.shade400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: const Icon(Icons.share),
    label: const Text('Share result'),
  ),
),

// AFTER (PB-gated + _isSharing spinner):
if (_isNewPb) ...[
  const SizedBox(height: 12),
  if (_isSharing)
    const SizedBox(
      height: 48,
      child: Center(child: CircularProgressIndicator()),
    )
  else
    SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _onSharePressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.share),
        label: const Text('Share result'),
      ),
    ),
],
```

**`_MathChallengeDialog` — operand generator and answer check:**

```
// BEFORE (addition, seed-based):
// In initState:
//   final seed = DateTime.now().millisecondsSinceEpoch;
//   _a = 3 + seed % 7;         // 3–9
//   _b = 2 + (seed ~/ 13) % 8; // 2–9
// In _onConfirm:
//   if (entered == _a + _b) { Navigator.of(context).pop(true); }
// In build:
//   Text('What is $_a + $_b?', ...)

// AFTER (2-digit × 1-digit multiplication, unseeded):
// In initState:
//   final rng = math.Random();  // no seed
//   _a = 10 + rng.nextInt(90);  // 10–99
//   _b = 2 + rng.nextInt(8);    // 2–9
// In _onConfirm:
//   if (entered == _a * _b) { Navigator.of(context).pop(true); }
// In build:
//   Text('What is $_a × $_b?', ...)
```

Wrong-answer path additionally regenerates `_a` and `_b` using a fresh `math.Random()` call inside `_onConfirm` (before `setState(() => _error = 'Incorrect — try again')`).

**`_onSharePressed` — updated orchestration:**

```
// BEFORE:
Future<void> _onSharePressed() async {
  final passed = await showDialog<bool>(context: context, builder: (_) => const _MathChallengeDialog());
  if (passed != true || !mounted) return;
  // simple text-only share
  await SharePlus.instance.share(ShareParams(text: '...'));
}

// AFTER:
Future<void> _onSharePressed() async {
  final passed = await _showParentalGate();
  if (passed != true || !mounted) return;
  await _captureAndShare();
}
```

**New methods added to `_CompletionScreenState`:**

- `Future<bool?> _showParentalGate()` — shows `_MathChallengeDialog` with `barrierDismissible: false`
- `Future<void> _captureAndShare()` — captures `_scoreCardKey` render object, writes PNG to `Directory.systemTemp`, invokes `SharePlus.instance.share(ShareParams(...))`, deletes temp file in `finally`

#### Spinner — visual spec

The `CircularProgressIndicator` inside the `SizedBox(height: 48)` uses:
- No explicit `color` property — inherits `ColorScheme.primary` from the active theme (mode color is not propagated to the spinner; this is intentional)
- No explicit `strokeWidth` — uses Material default (4dp)
- `Center` wrapper ensures the spinner is horizontally and vertically centered within the 48dp container
- The `SizedBox` is declared `const` and has `width` unspecified (expands to full column width via the parent `Column` with `crossAxisAlignment: CrossAxisAlignment.center`)

---

## Copywriting Contract

| Element | Copy | Source |
|---------|------|--------|
| Share button label | "Share result" | Unchanged from current implementation |
| Math gate dialog title | "Grown-up check" | Unchanged from current implementation |
| Math gate prompt (dialog body line 1) | "To share, a grown-up needs to answer:" | Unchanged from current implementation |
| Math gate question | "What is $_a × $_b?" | Changed: `+` replaced with `×` (Unicode multiplication sign U+00D7, not letter x) |
| Math gate answer field hint | "Answer" | Unchanged |
| Math gate wrong answer error | "Incorrect — try again" | Unchanged |
| Math gate Cancel button | "Cancel" | Unchanged |
| Math gate Share button (confirm) | "Share" | Unchanged |
| Share message (text payload) | "New lowest score in $modeName! Score: $score — State the States 🇺🇸" | `modeName` = `widget.session.mode.displayName` (not `.name`); `score` = `widget.session.score` |

**displayName values per mode** (from `GameModeDisplay` extension in `game_mode.dart`):

| Enum value | displayName |
|-----------|-------------|
| `learn` | "Learn" |
| `statesMaster` | "States Master" |
| `geographicalMaster` | "Geographical Master" |
| `grandMaster` | "Grand Master" |
| `speedTyping` | "Name all the states" |

Example rendered share messages:
- "New lowest score in States Master! Score: 142 — State the States 🇺🇸"
- "New lowest score in Name all the states! Score: 38 — State the States 🇺🇸"

Empty state: not applicable — Phase 7 adds no list or data display.

Error state: not applicable — capture failures silently exit `_captureAndShare()` (null-guard returns); no user-visible error toast is specified. The `finally` block always resets `_isSharing = false` so the Share button reappears.

Destructive actions: none in Phase 7.

---

## Interaction Contract

| Trigger | Widget State Before | Action | Widget State After |
|---------|-------------------|--------|-------------------|
| Completion screen loads, `_isNewPb == false` | — | Share button section absent entirely | No Share button, no SizedBox(height:12) spacer above it |
| Completion screen loads, `_isNewPb == true` | — | Share button rendered below Play Again | Share button visible; `_isSharing == false` |
| User taps Share button | `_isSharing == false` | `_onSharePressed()` → `_showParentalGate()` → `showDialog` opens | Dialog open; Share button still visible (dialog is modal overlay) |
| Math gate: user enters wrong answer, taps Share or presses Enter | Dialog open | Error text "Incorrect — try again" shown; `_a` and `_b` regenerated to new values; dialog stays open; text field cleared | Dialog open with new question and error text |
| Math gate: user taps Cancel | Dialog open | `Navigator.pop(false)` | Dialog dismissed; `_onSharePressed` returns without sharing; Share button remains |
| Math gate: user taps outside dialog | Dialog open | No action — `barrierDismissible: false` prevents dismissal | Dialog stays open |
| Math gate: user enters correct answer (`_a * _b`), taps Share or presses Enter | Dialog open | `Navigator.pop(true)` | Dialog dismissed; `_captureAndShare()` begins |
| `_captureAndShare()` starts | `_isSharing == false` | `setState(() => _isSharing = true)` | Share button replaced by `SizedBox(height:48, child: Center(child: CircularProgressIndicator()))` |
| `_captureAndShare()` completes (success or error) | `_isSharing == true` | `finally` block: `file?.deleteSync()` then `setState(() => _isSharing = false)` | Spinner replaced by Share button; temp file deleted |
| Native share sheet shown | `_isSharing == true` | OS share sheet covers the screen | App UI unchanged behind sheet |
| User dismisses share sheet | `_isSharing == true` | `SharePlus.instance.share()` future resolves; `finally` runs | `_isSharing = false`; Share button reappears |

**Keyboard behavior in math gate:** `TextField` has `keyboardType: TextInputType.number` and `autofocus: true`. `onSubmitted` fires on keyboard "Done"/"Enter" key press — same logic as tapping the Share button. Existing behavior is unchanged.

**`barrierDismissible`:** The `showDialog` call for the math gate must set `barrierDismissible: false`. Tapping outside the dialog must not dismiss it.

---

## Touch Target / Accessibility

All existing touch targets are preserved:

| Element | Height | Compliant |
|---------|--------|-----------|
| Share button (`OutlinedButton.icon`) | 48dp | Yes (minimum 48dp) |
| Play Again button (`OutlinedButton.icon`) | 48dp | Yes |
| Back to Menu button (`ElevatedButton.icon`) | 56dp | Yes |
| Spinner container (`SizedBox`) | 48dp | Yes — spinner replaces, not augments; no tap target needed |
| Math gate Cancel (`TextButton`) | system minimum (~48dp) | Yes (Material theme enforces minimum) |
| Math gate Share (`ElevatedButton`) | system minimum (~48dp) | Yes |

The math gate `TextField` uses `TextInputType.number` which opens the numeric keyboard on Android, reducing input friction for the adult completing the challenge.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Flutter SDK (dart:io, dart:ui, flutter/rendering.dart) | `Directory`, `File`, `ui.ImageByteFormat`, `RenderRepaintBoundary` | Not applicable — SDK packages |
| pub.dev — share_plus 13.1.0 (flutter community) | `SharePlus.instance.share`, `ShareParams`, `XFile` | Not applicable — already declared in pubspec.yaml, no version change |

No third-party registries. No new packages added to pubspec.yaml in this phase.

---

## Implementation Notes for Executor

### GlobalKey and RenderRepaintBoundary

Declare `_scoreCardKey` as `final GlobalKey _scoreCardKey = GlobalKey();` in `_CompletionScreenState` (not inside `build` — must be stable across rebuilds). Pass it to the existing `RepaintBoundary` at line 202: `RepaintBoundary(key: _scoreCardKey, child: Card(...))`.

In `_captureAndShare`, retrieve the boundary with:
```dart
final boundary = _scoreCardKey.currentContext
    ?.findRenderObject() as RenderRepaintBoundary?;
if (boundary == null) return;
```
The null-guard is the silent failure path — no error toast. This is intentional per spec.

### dart:ui Import Alias

`completion_screen.dart` already imports `dart:math as math`. Add `import 'dart:ui' as ui;` — the `ui` alias is not currently used in the file, so there is no collision. The alias is required for `ui.ImageByteFormat.png`.

### Required New Imports

```dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
```

`share_plus` is already imported (line 6 of current file). `XFile` is re-exported by `share_plus` — no separate `cross_file` import required.

### `barrierDismissible: false`

The `_showParentalGate()` method wraps `showDialog` with `barrierDismissible: false`. The existing `_onSharePressed` uses `showDialog` directly; the refactored version extracts this call into `_showParentalGate()`. Ensure `barrierDismissible: false` is on the `showDialog` call, not the `AlertDialog`.

### `finally` Block Structure

Declare `File? file;` before the `try` block. Assign inside `try`. In `finally`:
```dart
finally {
  file?.deleteSync();
  if (mounted) setState(() => _isSharing = false);
}
```
The `mounted` guard before `setState` is required because `SharePlus.instance.share()` is `await`-ed and the widget may have been disposed while the share sheet was open.

### Math Gate — Wrong Answer Regeneration

When the user submits an incorrect answer, `_onConfirm` must:
1. Clear `_controller.text`
2. Regenerate `_a` and `_b` with fresh `math.Random()` values
3. Call `setState(() => _error = 'Incorrect — try again')`

The current `_MathChallengeDialog` sets `_error` only. Add steps 1 and 2 before step 3. Use `math.Random()` (no seed) for both regenerations.

### `_onSharePressed` Refactor

Replace the current body of `_onSharePressed` entirely:
```dart
Future<void> _onSharePressed() async {
  final passed = await _showParentalGate();
  if (passed != true || !mounted) return;
  await _captureAndShare();
}
```
The existing `_MathChallengeDialog` class is upgraded in-place (not replaced). `_showParentalGate` is a new method that wraps `showDialog<bool>(builder: (_) => const _MathChallengeDialog(), barrierDismissible: false)`.

### Score Card Capture Scope

The `RepaintBoundary` with `_scoreCardKey` wraps only the score card `Card` widget. The PB badge ("New Personal Best!") is above the `RepaintBoundary` in the widget tree and is NOT included in the captured image. This is intentional — the share image contains only Score, Time, Mode, and Previous best rows.

### pixelRatio

Use `boundary.toImage(pixelRatio: 3.0)` for a sharp PNG on high-DPI screens. Do not use the default (`pixelRatio: 1.0`).

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS (FLAG: "Share" confirm button is single-word — non-blocking, unchanged from existing code)
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved
