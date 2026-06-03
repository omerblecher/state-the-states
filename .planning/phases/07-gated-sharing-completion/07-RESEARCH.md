# Phase 7: Gated Sharing Completion — Research

**Researched:** 2026-06-03
**Domain:** Flutter widget screenshot capture + share_plus file sharing + parental gate dialog
**Confidence:** HIGH

---

## Summary

Phase 7 completes the stub share flow in `CompletionScreen`. Three surgical changes are required:

1. **PB-gate the Share button** — the button is already rendered unconditionally; add `if (_isNewPb)` guard so it only appears when `_isNewPb == true`.
2. **Upgrade the math gate** — the existing `_MathChallengeDialog` uses single-digit addition (`_a + _b`, where both operands are 3–9). SHARE-04 requires 2-digit × 1-digit multiplication (Flags reference: `a = 10 + rng.nextInt(90)`, `b = 2 + rng.nextInt(8)`, correct answer `a * b`).
3. **Screenshot capture + file share** — wrap the score card in a `RepaintBoundary` with a `GlobalKey`, capture via `RenderRepaintBoundary.toImage(pixelRatio: 3.0)`, write PNG bytes to `Directory.systemTemp`, share as `XFile` via `SharePlus.instance.share(ShareParams(...))` with the required message, delete temp file in `finally`.

The authoritative reference implementation exists in `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart` and can be ported nearly verbatim. The primary deltas from Flags: (a) use `SharePlus.instance.share(ShareParams(...))` instead of the deprecated `Share.shareXFiles`, (b) use `widget.session.mode.displayName` for the mode name (already implemented in Phase 6), (c) no l10n dependency (State States uses hardcoded strings per Phase 4 decision).

**Primary recommendation:** Port `_captureAndShare` and `_showParentalGate` directly from Flags, with the three deltas noted above. No new packages required — `share_plus ^13.1.0` and `dart:io` (`Directory.systemTemp`) are sufficient. `path_provider` is a transitive dependency in the lockfile but does not need to be added to `pubspec.yaml` because `Directory.systemTemp` is used instead of `getTemporaryDirectory()`.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHARE-01 | Share button visible only when `_isNewPb == true`; absent on non-PB completions | `_isNewPb` field already exists in `_CompletionScreenState`; wrap button with `if (_isNewPb)` conditional |
| SHARE-02 | Capture score card via `RenderRepaintBoundary.toImage()`, attach PNG as `XFile` to share sheet | GlobalKey + RepaintBoundary already wraps the score card `Card` widget; needs key reference and `_captureAndShare` method |
| SHARE-03 | Share message: "New lowest score in [Mode Name]! Score: [N] — State the States 🇺🇸" | `widget.session.mode.displayName` + `widget.session.score`; `SharePlus.instance.share(ShareParams(text: ..., files: [...]))` |
| SHARE-04 | Math gate upgraded from single-digit addition to 2-digit × 1-digit multiplication | Existing `_MathChallengeDialog` uses `_a + _b`; change generator and comparison to `a * b` per Flags pattern |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PB-gate Share button visibility | Widget / UI | — | Pure widget-layer conditional render; `_isNewPb` already computed in `initState` |
| Math gate dialog | Widget / UI | — | Stateful dialog in widget layer; no game logic involved |
| Screenshot capture (RenderRepaintBoundary) | Widget / UI | Flutter rendering layer | Must run in widget context; GlobalKey requires widget tree access |
| Temp file write | Widget / UI (dart:io) | — | dart:io `File` write; no platform channel needed for `Directory.systemTemp` |
| Share sheet invocation | Widget / UI (share_plus) | Native OS share sheet | share_plus bridges to platform share intent |
| Temp file cleanup | Widget / UI (dart:io) | — | `finally` block in `_captureAndShare`; widget-layer responsibility |

**Key constraint:** `GameSessionNotifier` must have zero ad imports (COMP-03 walled-garden rule). The share flow lives entirely in `CompletionScreen` widget layer — this constraint is automatically satisfied because no notifier changes are required for Phase 7.

---

## Standard Stack

### Core (already in pubspec.yaml — no new dependencies required)

| Library | Version in Lockfile | Purpose | Why Standard |
|---------|---------------------|---------|--------------|
| `share_plus` | 13.1.0 | Native share sheet with XFile attachment | Already declared in pubspec.yaml; `SharePlus.instance.share(ShareParams(files: [XFile(...)]))` is the v11+ API used in State States |
| `dart:io` | SDK | `Directory.systemTemp` for temp PNG write | Flags reference uses `Directory.systemTemp` directly; no `path_provider` call needed |
| `dart:ui` | SDK | `ui.ImageByteFormat.png` for PNG encoding | Required for `image.toByteData(format: ui.ImageByteFormat.png)` |
| `flutter/rendering.dart` | SDK | `RenderRepaintBoundary` type | Required for the `findRenderObject() as RenderRepaintBoundary` cast |

### Not Required (contrary to STATE.md note)

The STATE.md decision log reads: "path_provider ^2.1.5 added in Phase 7 for screenshot-to-XFile pipeline (temp file write)." This turns out to be unnecessary. The Flags reference implementation (the authoritative baseline) uses `Directory.systemTemp` from `dart:io`, not `path_provider.getTemporaryDirectory()`. `path_provider` 2.1.5 is already a *transitive* dependency (pulled in by another package) and resolves in the lockfile. **Do not add `path_provider` as a direct dependency in pubspec.yaml — it is not needed.**

### Installation

No `flutter pub add` required. All dependencies are already resolved.

---

## Package Legitimacy Audit

No new packages are introduced in this phase. All packages used are existing dependencies.

| Package | Registry | Age | Source Repo | Disposition |
|---------|----------|-----|-------------|-------------|
| `share_plus` | pub.dev | 5+ yrs (flutter community) | github.com/fluttercommunity/plus_plugins | Approved — already in pubspec.yaml |
| `dart:io` | Dart SDK | — | Dart SDK | Approved — SDK package |
| `dart:ui` | Dart SDK | — | Dart SDK | Approved — SDK package |
| `flutter/rendering.dart` | Flutter SDK | — | Flutter SDK | Approved — SDK package |

**Packages removed due to slopcheck:** none
**Packages flagged as suspicious:** none
*slopcheck does not support the `pub` ecosystem; packages verified via `flutter pub deps --json` which confirmed resolved versions: share_plus 13.1.0, path_provider 2.1.5, cross_file 0.3.5+2 — all established Flutter Community packages.* [VERIFIED: pub.dev]

---

## Architecture Patterns

### System Architecture Diagram

```
User taps Share button (visible only if _isNewPb == true)
        |
        v
_showParentalGate() — AlertDialog with StatefulBuilder
  - generates a = 10..99, b = 2..9
  - displays "What is {a} × {b}?"
  - wrong answer: regenerate a,b, show error, stay open
  - correct answer: returns true
        |
   passed == true?
   NO → return (no share)
   YES ↓
_captureAndShare()
  - setState(_isSharing = true)
  - _scoreCardKey.currentContext.findRenderObject() as RenderRepaintBoundary
  - boundary.toImage(pixelRatio: 3.0) → ui.Image
  - image.toByteData(format: ui.ImageByteFormat.png) → ByteData
  - bytes = byteData.buffer.asUint8List()
  - file = File('${Directory.systemTemp.path}/score_card.png')
  - file.writeAsBytes(bytes)
  - SharePlus.instance.share(ShareParams(
      text: "New lowest score in {mode.displayName}! Score: {score} — State the States 🇺🇸",
      files: [XFile(file.path)],
    ))
  - finally: file.deleteSync(recursive: false) + setState(_isSharing = false)
```

### Recommended Widget Structure in CompletionScreen

The score card `Card` widget already has a `RepaintBoundary` wrapper (line 202 of `completion_screen.dart`). It currently has no key. Phase 7 adds `key: _scoreCardKey` to this existing wrapper — no structural change to the widget tree.

```
Column (in SingleChildScrollView)
  ...
  RepaintBoundary(key: _scoreCardKey)   ← add key to existing wrapper
    Card (score card widget)
      Column [Score, Time, Mode, Previous best rows]
  ...
  if (_isNewPb) ... Share button / _isSharing spinner
```

### Pattern 1: RepaintBoundary Screenshot Capture

**What:** Assigns a `GlobalKey` to an existing `RepaintBoundary`, captures it as a PNG image after the widget has painted, and writes to a temp file.
**When to use:** Any time a widget sub-tree must be captured as a shareable image.

```dart
// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart (lines 184–212)
// Adapted: use SharePlus.instance.share(ShareParams(...)) instead of Share.shareXFiles

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';  // XFile re-exported from share_plus

final GlobalKey _scoreCardKey = GlobalKey();
bool _isSharing = false;

Future<void> _captureAndShare() async {
  if (!mounted) return;
  setState(() => _isSharing = true);
  File? file;
  try {
    final boundary = _scoreCardKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    file = File('${Directory.systemTemp.path}/score_card.png');
    await file.writeAsBytes(bytes);

    final modeName = widget.session.mode.displayName;
    final score = widget.session.score;

    await SharePlus.instance.share(ShareParams(
      text: 'New lowest score in $modeName! Score: $score — State the States 🇺🇸',
      files: [XFile(file.path)],
    ));
  } finally {
    file?.deleteSync();
    if (mounted) setState(() => _isSharing = false);
  }
}
```

### Pattern 2: Multiplication Math Gate Dialog

**What:** `AlertDialog` with `StatefulBuilder` that regenerates operands on wrong answer without dismissing. Returns `true`/`false` via `showDialog<bool>`.
**When to use:** COPPA parental gate before any outbound sharing action.

```dart
// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart (lines 115–182)
// Adapted: uses multiplication (a * b) not addition (a + b); no l10n dependency

Future<bool?> _showParentalGate() async {
  final rng = math.Random();
  int a = 10 + rng.nextInt(90);  // 10–99
  int b = 2 + rng.nextInt(8);    // 2–9
  final controller = TextEditingController();
  String errorText = '';
  bool? result;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Grown-up check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('To share, a grown-up needs to answer:'),
            const SizedBox(height: 16),
            Text(
              'What is $a × $b?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Answer',
                errorText: errorText.isEmpty ? null : errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _confirmAnswer(
                controller, a, b, rng, setDialogState, ctx,
                (r) => result = r, (e) => errorText = e,
                (na, nb) { a = na; b = nb; },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { result = false; Navigator.of(ctx).pop(); },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _confirmAnswer(...),
            child: const Text('Share'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}
```

**Implementation note on StatefulBuilder vs extracting to class:** The Flags pattern uses `StatefulBuilder` inside `showDialog` so the dialog can regenerate operands on wrong answer without dismissing. This is simpler than extracting `_MathChallengeDialog` to a separate `StatefulWidget` because the operands are local variables captured by the builder. Either approach is valid; the StatefulBuilder approach avoids creating a new class.

**Alternative (State States existing pattern):** The current `_MathChallengeDialog` in `completion_screen.dart` is already extracted as a `StatefulWidget`. The upgrade can be applied in-place by changing the operand generator from `3 + seed % 7` / `2 + (seed ~/ 13) % 8` to `math.Random()` with `rng.nextInt(90)` / `rng.nextInt(8)`, and the comparison from `_a + _b` to `_a * _b`.

### Pattern 3: PB-Gated Share Button Visibility

**What:** Conditional render of the Share button and a `_isSharing` spinner replacement.

```dart
// Replace the unconditional Share button (lines 296–310 of completion_screen.dart) with:
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.share),
        label: const Text('Share result'),
      ),
    ),
],
```

### Anti-Patterns to Avoid

- **Calling `toImage()` in `initState` or before first paint:** `toImage()` requires `debugNeedsPaint == false`. The capture is triggered by user tap (post-paint), so this is not an issue here — but do not attempt to pre-capture on screen load.
- **Using `WidgetsBinding.instance.addPostFrameCallback` for capture timing:** Not needed here because capture is triggered by a button press, which always occurs after the first frame. The `addPostFrameCallback` pattern is for captures triggered from `initState`.
- **Wrapping the entire `Scaffold` in `RepaintBoundary`:** Captures would include the AppBar, status bar, and all overlays. Wrap only the score card `Card` widget (already done in the existing code).
- **Forgetting the `finally` block on temp file delete:** If `SharePlus.instance.share()` throws, the temp file would persist. Always delete in `finally`.
- **Not checking `mounted` after `await`:** The share sheet is async; the widget may have been disposed. Check `if (mounted)` before `setState`.
- **Using `Directory.systemTemp` on iOS App Store builds without path_provider:** On iOS, `Directory.systemTemp` maps to the OS temp directory and is acceptable for transient files. The temp file is cleaned up immediately after sharing, so it will not bloat storage. [VERIFIED: Flags reference uses this pattern — CITED: FlagsRoundTheWorld/lib/features/map/completion_screen.dart]
- **Forgetting `import 'package:flutter/rendering.dart'`:** `RenderRepaintBoundary` is in `package:flutter/rendering.dart`, not `package:flutter/material.dart`. Without this import, the cast fails at compile time.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Widget-to-PNG capture | Custom render pipeline | `RenderRepaintBoundary.toImage()` | SDK-provided, handles compositing layers, works with `InteractiveViewer` offscreen widgets |
| Native share sheet | Platform channel | `share_plus` | Handles Android `Intent.ACTION_SEND`, iOS `UIActivityViewController`, MIME type negotiation across all platforms |
| Cross-platform temp path | Platform-specific directory logic | `Directory.systemTemp` (`dart:io`) | SDK-provided, works on Android and iOS; Flags reference validates this pattern |
| Random number generation | Seed-based deterministic math | `dart:math` `Random()` | Standard library; no external dependency needed |

**Key insight:** The Flags codebase provides a complete, tested implementation of every technical component required in this phase. This phase is primarily a port, not a net-new build.

---

## Common Pitfalls

### Pitfall 1: RepaintBoundary Missing GlobalKey — `Null` RenderObject

**What goes wrong:** `_scoreCardKey.currentContext?.findRenderObject()` returns `null` because the `RepaintBoundary` wrapper at line 202 of `completion_screen.dart` has no key.
**Why it happens:** The current code has `RepaintBoundary(child: Card(...))` with no key. The capture function has no way to locate the specific boundary.
**How to avoid:** Change the existing `RepaintBoundary` widget declaration to `RepaintBoundary(key: _scoreCardKey, child: Card(...))`. The `_scoreCardKey = GlobalKey()` field must be declared in `_CompletionScreenState`.
**Warning signs:** Null check on `boundary` silently returns without sharing. Add an `assert(boundary != null)` in debug mode.

### Pitfall 2: Wrong Import for `RenderRepaintBoundary`

**What goes wrong:** `RenderRepaintBoundary` is not in scope; cast fails with `undefined class`.
**Why it happens:** `RenderRepaintBoundary` lives in `package:flutter/rendering.dart`, not `package:flutter/material.dart`.
**How to avoid:** Add `import 'package:flutter/rendering.dart';` alongside the existing imports.
**Warning signs:** Compile-time error: `The name 'RenderRepaintBoundary' isn't a type`.

### Pitfall 3: Math Gate Seeds With Low Entropy

**What goes wrong:** Using `DateTime.now().millisecondsSinceEpoch` as a fixed seed (current pattern) means rapid successive taps could produce the same problem. More importantly, `seed % 7` produces operands 0–6, not 3–9 as intended.
**Why it happens:** The current `_MathChallengeDialog` uses `DateTime.now().millisecondsSinceEpoch` as a seed (line 356) and integer division/modulo for both operands — deterministic on the same millisecond.
**How to avoid:** Use `math.Random()` (no seed) so each dialog instantiation gets a fresh random sequence. This matches the Flags reference pattern.
**Warning signs:** Test users report the same math problem appearing repeatedly.

### Pitfall 4: Share Button Visible on Non-PB Completions

**What goes wrong:** SHARE-01 fails because the Share button renders even when `_isNewPb == false`.
**Why it happens:** The current code renders the Share button unconditionally (lines 296–310 of `completion_screen.dart`). It is not inside any `if (_isNewPb)` guard.
**How to avoid:** Wrap the entire `SizedBox` containing the share button inside `if (_isNewPb)`.
**Warning signs:** Regression test: complete a game without beating the personal best and confirm the Share button is absent.

### Pitfall 5: `dart:ui` Import Alias Collision

**What goes wrong:** `import 'dart:ui' as ui;` conflicts with another `ui` alias if one exists.
**Why it happens:** `completion_screen.dart` imports `dart:math as math` but not `dart:ui`. The capture code needs `ui.ImageByteFormat.png` and `ui.Image`.
**How to avoid:** Add `import 'dart:ui' as ui;` to the file (no conflict with existing imports).
**Warning signs:** Compile error: `The name 'ImageByteFormat' isn't defined`.

### Pitfall 6: `barrierDismissible: false` Missing on Math Gate Dialog

**What goes wrong:** Tapping outside the dialog dismisses it without returning a result; `showDialog` returns `null`, which is not `true`, so sharing is silently skipped — but the UX is confusing.
**Why it happens:** Default `barrierDismissible` is `true`.
**How to avoid:** Set `barrierDismissible: false` on the `showDialog` call, matching Flags reference.

### Pitfall 7: Temp File Not Deleted on Share Sheet Dismissal

**What goes wrong:** `Directory.systemTemp` accumulates `score_card.png` files on every share, eventually consuming device storage.
**Why it happens:** If the `finally` block is not present, exceptions or early `return` statements leave the file behind.
**How to avoid:** Declare `File? file;` before the `try`, assign inside, and call `file?.deleteSync()` in the `finally` block.

---

## Code Examples

### Complete `_onSharePressed` Orchestration

```dart
// Source pattern: C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart
Future<void> _onSharePressed() async {
  final passed = await _showParentalGate();
  if (passed != true || !mounted) return;
  await _captureAndShare();
}
```

### Verified `_captureAndShare` (State States variant)

```dart
// Source: FlagsRoundTheWorld completion_screen.dart, adapted for share_plus 13.x API
// [CITED: C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart lines 184–212]
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

Future<void> _captureAndShare() async {
  if (!mounted) return;
  setState(() => _isSharing = true);
  File? file;
  try {
    final boundary = _scoreCardKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    file = File('${Directory.systemTemp.path}/score_card.png');
    await file.writeAsBytes(bytes);

    final modeName = widget.session.mode.displayName;
    final score = widget.session.score;

    await SharePlus.instance.share(ShareParams(
      text: 'New lowest score in $modeName! Score: $score — State the States 🇺🇸',
      files: [XFile(file.path)],
    ));
  } finally {
    file?.deleteSync();
    if (mounted) setState(() => _isSharing = false);
  }
}
```

### Verified Math Gate (Multiplication Upgrade)

```dart
// Source: FlagsRoundTheWorld completion_screen.dart adapted — multiplication not addition
// [CITED: C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart lines 115–182]
// Existing _MathChallengeDialog in State States: change lines 356–369 as follows:

// BEFORE (addition):
//   _a = 3 + seed % 7;         // 3–9
//   _b = 2 + (seed ~/ 13) % 8; // 2–9
//   if (entered == _a + _b) { ... }
//   'What is $_a + $_b?'

// AFTER (2-digit × 1-digit multiplication):
final _rng = math.Random();
// In initState:
//   _a = 10 + _rng.nextInt(90); // 10–99
//   _b = 2 + _rng.nextInt(8);   // 2–9
// In _onConfirm:
//   if (entered == _a * _b) { Navigator.of(context).pop(true); }
// In build:
//   'What is $_a × $_b?'
```

### Sharing `XFile` — Import Clarification

```dart
// XFile is re-exported by share_plus — no separate cross_file import needed
import 'package:share_plus/share_plus.dart';
// XFile is now available directly

// [VERIFIED: pub.dev — share_plus exports XFile from share_plus_platform_interface]
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Share.shareXFiles([XFile(path)])` (deprecated static API) | `SharePlus.instance.share(ShareParams(files: [XFile(path)]))` | share_plus v11.0.0 | Flags uses old API; State States already uses new API (line 98 of completion_screen.dart) |
| `path_provider.getTemporaryDirectory()` for temp path | `Directory.systemTemp` (`dart:io`) | N/A — both valid | Flags uses `Directory.systemTemp`; simpler, no async call needed |
| `pixelRatio: 1.0` (default) | `pixelRatio: 3.0` | N/A — recommendation | Higher pixelRatio produces a sharper PNG on high-DPI screens |

**Deprecated/outdated:**
- `Share.shareXFiles(...)` (static `Share` class): deprecated in share_plus v11.0.0; replaced by `SharePlus.instance.share(ShareParams(...))`. The Flags codebase uses the deprecated form, but State States already uses the new form. Do not regress to the old API.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `XFile` is re-exported by `package:share_plus/share_plus.dart` — no separate `cross_file` import needed | Standard Stack / Code Examples | Import compile error; fix: add `import 'package:cross_file/cross_file.dart'` |
| A2 | `Directory.systemTemp` is a suitable temp directory for the PNG file on both Android and iOS | Code Examples | iOS may sandbox temp differently; fix: use `path_provider.getTemporaryDirectory()` instead |

**Low risk on both:** A1 is confirmed by share_plus source export analysis and web sources. A2 is confirmed by the Flags production codebase using the same pattern.

---

## Open Questions

1. **`_isSharing` spinner — does the existing Share button use it?**
   - What we know: The current `_onSharePressed` in State States does not set `_isSharing`; that field does not exist in the current `_CompletionScreenState`.
   - What's unclear: Does Phase 7 need to add `_isSharing` state to show a loading indicator while capture is in progress?
   - Recommendation: Yes — the capture and file I/O can take ~200–500ms on slow devices. Add `_isSharing` bool field and replace the Share button with a `CircularProgressIndicator` while capturing. Flags reference confirms this pattern.

2. **Score card `RepaintBoundary` — does it capture the PB badge?**
   - What we know: The PB badge (`Container` with "New Personal Best!") renders *above* the `RepaintBoundary(Card(...))` in the widget tree, not inside it.
   - What's unclear: Should the share screenshot include the PB badge?
   - Recommendation: Per SHARE-02 and SHARE-03, the requirement says "score card widget" — the score card is the `Card` with Score/Time/Mode rows. The PB badge is cosmetic context. Scope the `RepaintBoundary` to the `Card` only (current structure), not the badge. If desired, the badge can be incorporated by expanding the `RepaintBoundary` to wrap both, but this is not required by the spec.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All widget code | ✓ | 3.44.0 | — |
| Dart SDK | dart:io, dart:ui, dart:math | ✓ | 3.12.0 | — |
| `share_plus` | SHARE-02, SHARE-03 | ✓ (in pubspec.yaml) | 13.1.0 | — |
| Android device / emulator | Share sheet testing | ✓ (implied by Phase 6 completion) | — | iOS simulator for smoke test |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — uses default test/ discovery |
| Quick run command | `flutter test test/features/map/completion_screen_test.dart --no-pub` |
| Full suite command | `flutter test --no-pub` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHARE-01 | Share button absent when `_isNewPb == false` | Widget test | `flutter test test/features/map/completion_screen_test.dart --no-pub` | ✅ (add test case) |
| SHARE-01 | Share button present when `_isNewPb == true` (score < previousBest) | Widget test | same | ✅ (add test case) |
| SHARE-02 | `_captureAndShare` invoked after gate passes | Widget test (mock share) | same | ✅ (add test case) |
| SHARE-03 | Share message format correct | Unit test | same | ✅ (add test case) |
| SHARE-04 | Math gate uses multiplication not addition | Widget/unit test | same | ✅ (add test case) |

**Testability note on SHARE-02:** `RenderRepaintBoundary.toImage()` requires a real render context and will not work in `flutter_test`'s software renderer without special setup. The recommended test approach is:
- Test that the Share button calls `_onSharePressed` (widget tap test)
- Test that `_onSharePressed` is guarded by `_isNewPb` (SHARE-01)
- Test that `_MathChallengeDialog` returns `true` for correct answer and `false`/`null` for wrong/cancel
- The `_captureAndShare` image capture path is tested manually on a real device — mark as `// Manual verification required` in test comments

**Existing tests that must keep passing:** All 11 passing tests in `completion_screen_test.dart` (confirmed green as of 2026-06-03).

### Sampling Rate

- **Per task commit:** `flutter test test/features/map/completion_screen_test.dart --no-pub`
- **Per wave merge:** `flutter test --no-pub`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] New test cases in `test/features/map/completion_screen_test.dart` — covers SHARE-01 (PB-gate visibility), SHARE-04 (multiplication dialog), and `_MathChallengeDialog` correct/wrong/cancel paths

*(Existing test infrastructure covers the framework — only new test cases need to be authored, not new test files.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — parental gate is UX friction, not cryptographic auth |
| V3 Session Management | no | N/A |
| V4 Access Control | yes (partial) | PB-gate on Share button prevents unwanted sharing by children |
| V5 Input Validation | yes | Math gate: `int.tryParse()` guards against non-numeric input; returns `null` (safe) on parse failure |
| V6 Cryptography | no | No secrets involved |

### Known Threat Patterns for Flutter Share

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Child bypasses math gate by entering random numbers repeatedly | Spoofing | Multiplication gate is harder to brute-force than addition (multiplier space is larger); COPPA requires "reasonable" not "unbreakable" gate |
| Shared image contains unexpected personal data | Information Disclosure | Score card contains only game stats (score, time, mode, previous best) — no PII, no identifiers |
| Temp file persists after crash | Information Disclosure | `finally` block deletes temp file; Android/iOS OS temp cleanup also handles lingering files |

---

## Project Constraints (from CLAUDE.md)

| Directive | Status |
|-----------|--------|
| No Firebase, no persistent identifiers | Not affected by Phase 7 |
| `GameSessionNotifier` zero ad imports (COMP-03 walled-garden) | Enforced — Phase 7 changes are widget-layer only; no notifier imports required |
| COPPA: outbound sharing gated behind adult-verification math challenge | Phase 7 completes this — `_showParentalGate()` is the implementation |
| Standardize audio on `just_audio` — do not introduce `audioplayers` | Not affected by Phase 7 |
| Fully offline — no network dependency for core gameplay | Share sheet is a native OS feature (no network call from app code); compliant |
| Android first, iOS first-class future target | `Directory.systemTemp` + `share_plus` work on both platforms |
| `share_plus` is already declared as `^13.1.0` in pubspec.yaml | Confirmed — no version change needed |

---

## Sources

### Primary (HIGH confidence)

- `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart` — Authoritative reference implementation for `_captureAndShare`, `_showParentalGate` (StatefulBuilder multiplication gate), `_isSharing` spinner, `RepaintBoundary` + `GlobalKey` pattern, `Directory.systemTemp` temp file handling
- `C:\code\Claude\StateTheStates\lib\features\map\completion_screen.dart` — Current State States implementation; confirmed `_isNewPb` field, existing `RepaintBoundary(Card(...))` wrapper, current addition math gate, `SharePlus.instance.share(ShareParams(...))` API already in use
- `https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html` — Official Flutter API: `Future<Image> toImage({double pixelRatio = 1.0})`, requirement that `debugNeedsPaint == false`
- `flutter pub deps --json` — Confirmed package versions: share_plus 13.1.0, path_provider 2.1.5, cross_file 0.3.5+2 [VERIFIED: pub.dev]
- `curl https://pub.dev/api/packages/share_plus` — Confirmed latest stable: 13.1.0 [VERIFIED: pub.dev]

### Secondary (MEDIUM confidence)

- `https://pub.dev/packages/share_plus` — `ShareParams` constructor parameters, XFile re-export from `share_plus_platform_interface` [CITED: pub.dev/packages/share_plus]
- `https://github.com/fluttercommunity/plus_plugins` — SharePlus.instance.share() example, XFile export in share_plus_platform_interface [CITED: github.com/fluttercommunity/plus_plugins]
- `https://www.freecodecamp.org/news/how-to-save-and-share-flutter-widgets-as-images-a-complete-production-ready-guide/` — Production-ready capture pattern with `debugNeedsPaint` guard and `pixelRatio: 3.0` recommendation

### Tertiary (LOW confidence)

- `https://github.com/flutter/flutter/issues/22308` — Root cause of `toImage()` first-call failure: `debugNeedsPaint` assertion; confirmed workaround (call only after paint phase)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages confirmed via `flutter pub deps --json` and pub.dev API
- Architecture: HIGH — Flags reference implementation is complete and directly portable
- Pitfalls: HIGH — derived from Flags codebase analysis + Flutter SDK issue tracker

**Research date:** 2026-06-03
**Valid until:** 2026-09-03 (stable Flutter SDK + share_plus; 90-day window appropriate)
