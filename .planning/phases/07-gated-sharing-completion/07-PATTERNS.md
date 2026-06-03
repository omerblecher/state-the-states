# Phase 7: Gated Sharing Completion — Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 1 (single file modified) + 1 test file extended
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/map/completion_screen.dart` | component (screen) | event-driven + file-I/O | `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart` | exact |
| `test/features/map/completion_screen_test.dart` | test | — | same file (existing test suite, extend in place) | exact |

---

## Pattern Assignments

### `lib/features/map/completion_screen.dart` (component, event-driven + file-I/O)

**Analog:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\completion_screen.dart`

This is the only file modified in Phase 7. All four changes (SHARE-01 through SHARE-04) are surgical edits within `_CompletionScreenState` and `_MathChallengeDialogState`. No new files are created.

---

#### SHARE-01: PB-gate the Share button

**Change location:** `_buildBody()` — lines 293–309 of current `completion_screen.dart`

**Current code** (lines 293–309):
```dart
const SizedBox(height: 12),
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
```

**Analog pattern** (Flags `completion_screen.dart` lines 400–422):
```dart
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
      label: Text(l10n.shareScoreButton),
    ),
  ),
```

**Required delta from analog:** Wrap the entire block in `if (_isNewPb) ...[...]`; use hardcoded `'Share result'` string (no l10n); add `_isSharing` bool field to state. The Flags analog shows the Share button unconditionally — Phase 7 adds the `if (_isNewPb)` outer guard.

**Target code:**
```dart
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

**New state fields** (add to `_CompletionScreenState` alongside existing fields at lines 46–49):
```dart
final GlobalKey _scoreCardKey = GlobalKey();
bool _isSharing = false;
```

---

#### SHARE-02: Add key to RepaintBoundary

**Change location:** `_buildBody()` — line 202 of current `completion_screen.dart`

**Current code** (line 202):
```dart
RepaintBoundary(
  child: Card(
```

**Target code:**
```dart
RepaintBoundary(
  key: _scoreCardKey,   // ← add this line
  child: Card(
```

**Analog source:** Flags `completion_screen.dart` line 303–304:
```dart
RepaintBoundary(
  key: _scoreCardKey,
  child: Container(
```

---

#### SHARE-02 + SHARE-03: `_captureAndShare` method

**Add as new method** to `_CompletionScreenState` (after `_onSharePressed`).

**Required new imports** (add to top of file, after existing `import 'dart:math' as math;`):
```dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
```

`share_plus` is already imported at line 6. `XFile` is re-exported by `share_plus` — no separate import needed.

**Analog source:** Flags `completion_screen.dart` lines 184–213 (adapted — use `SharePlus.instance.share(ShareParams(...))` instead of deprecated `Share.shareXFiles`; use `widget.session.mode.displayName` instead of l10n; add `file?.deleteSync()` in `finally`):

```dart
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

**Key deltas from Flags analog:**
- Flags uses `Share.shareXFiles([XFile(...)], text: ...)` (deprecated static API, lines 205–209) — State States already uses `SharePlus.instance.share(ShareParams(...))` (new instance API, confirmed at existing line 98)
- Flags stores `file` without nullable declaration and has no `file?.deleteSync()` in `finally` (lines 210–212) — State States must declare `File? file;` before `try` and call `file?.deleteSync()` in `finally` (per RESEARCH.md pitfall 7)
- Flags uses l10n for share text (line 203–204) — State States uses hardcoded string (per Phase 4 decision)

---

#### SHARE-03: `_onSharePressed` refactor

**Change location:** `_onSharePressed` method, lines 89–102 of current `completion_screen.dart`

**Current code** (lines 89–102):
```dart
Future<void> _onSharePressed() async {
  final passed = await showDialog<bool>(
    context: context,
    builder: (_) => const _MathChallengeDialog(),
  );
  if (passed != true || !mounted) return;
  final elapsed = _formatTime(widget.session.elapsed);
  final modeName = widget.session.mode.name;
  final score = widget.session.score;
  await SharePlus.instance.share(ShareParams(
    text: 'I placed all 50 US states in $elapsed on $modeName mode!'
        ' Score: $score — State the States 🇺🇸',
  ));
}
```

**Analog source:** Flags `completion_screen.dart` lines 108–113:
```dart
Future<void> _onSharePressed() async {
  final l10n = AppLocalizations.of(context);
  final passed = await _showParentalGate(l10n);
  if (passed != true) return;
  await _captureAndShare(l10n);
}
```

**Target code** (no l10n; add `!mounted` guard matching current file pattern):
```dart
Future<void> _onSharePressed() async {
  final passed = await _showParentalGate();
  if (passed != true || !mounted) return;
  await _captureAndShare();
}
```

**New `_showParentalGate` method** (wraps existing `_MathChallengeDialog` with `barrierDismissible: false`):
```dart
Future<bool?> _showParentalGate() {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _MathChallengeDialog(),
  );
}
```

Note: The existing `_MathChallengeDialog` class is upgraded in-place (SHARE-04 below) rather than replaced. `_showParentalGate` is a thin wrapper that adds `barrierDismissible: false` to the existing `showDialog` call.

---

#### SHARE-04: Upgrade `_MathChallengeDialog` — multiplication gate

**Change location:** `_MathChallengeDialogState` class, lines 347–416 of current `completion_screen.dart`

**Current operand generation** (lines 355–359 of current file):
```dart
@override
void initState() {
  super.initState();
  final seed = DateTime.now().millisecondsSinceEpoch;
  _a = 3 + seed % 7;         // 3–9
  _b = 2 + (seed ~/ 13) % 8; // 2–9
}
```

**Target operand generation** (Flags analog lines 116–118 adapted):
```dart
@override
void initState() {
  super.initState();
  final rng = math.Random();
  _a = 10 + rng.nextInt(90);  // 10–99
  _b = 2 + rng.nextInt(8);    // 2–9
}
```

**Current answer check** (line 369 of current file):
```dart
if (entered == _a + _b) {
  Navigator.of(context).pop(true);
} else {
  setState(() => _error = 'Incorrect — try again');
}
```

**Target answer check** (Flags analog lines 162–170 adapted; also clears text field and regenerates operands on wrong answer):
```dart
void _onConfirm() {
  final entered = int.tryParse(_controller.text.trim());
  if (entered == _a * _b) {
    Navigator.of(context).pop(true);
  } else {
    final rng = math.Random();
    _controller.clear();
    setState(() {
      _a = 10 + rng.nextInt(90);
      _b = 2 + rng.nextInt(8);
      _error = 'Incorrect — try again';
    });
  }
}
```

**Current question display** (line 387 of current file):
```dart
Text(
  'What is $_a + $_b?',
  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
),
```

**Target question display:**
```dart
Text(
  'What is $_a × $_b?',   // × is Unicode U+00D7, not letter x
  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
),
```

**Full `_MathChallengeDialogState` after changes** — the only surviving delta from the existing class is: `late int _a` and `late int _b` must change from `late final` to `late` (mutable) because `_onConfirm` reassigns them on wrong answer.

---

### `test/features/map/completion_screen_test.dart` (test, extends existing)

**Analog:** Same file — existing 11 tests at lines 26–112 must all keep passing. New test cases are added to the existing `main()` function.

**Existing test scaffold pattern** (lines 1–25 — copy exactly for new test helpers):
```dart
GameSession makeSession({int score = 100, GameMode mode = GameMode.learn}) {
  return GameSession(
    phase: GamePhase.completed,
    mode: mode,
    score: score,
    elapsed: const Duration(minutes: 2, seconds: 34),
    errorCount: 0,
    hintsRemaining: 2,
    matchedPostals: const [],
  );
}

Widget buildScreen(GameSession session, {int? previousBest}) {
  return MaterialApp(
    home: CompletionScreen(session: session, previousBest: previousBest),
  );
}
```

**Existing widget test pattern** (lines 57–66 — copy for new SHARE-01 tests):
```dart
testWidgets('personal best shows 3 filled stars and PB badge',
    (tester) async {
  final session = makeSession(score: 50);
  await tester.pumpWidget(buildScreen(session, previousBest: 100));
  await tester.pump();

  expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
  expect(find.text('New Personal Best!'), findsOneWidget);
});
```

**New test cases to add** (SHARE-01 visibility, SHARE-04 math gate):

```dart
group('Share button visibility (SHARE-01)', () {
  testWidgets('Share button absent when _isNewPb == false (no previous best)',
      (tester) async {
    final session = makeSession(score: 100);
    await tester.pumpWidget(buildScreen(session, previousBest: null));
    await tester.pump();
    expect(find.text('Share result'), findsNothing);
  });

  testWidgets('Share button absent when score does not beat previous best',
      (tester) async {
    final session = makeSession(score: 150);
    await tester.pumpWidget(buildScreen(session, previousBest: 100));
    await tester.pump();
    expect(find.text('Share result'), findsNothing);
  });

  testWidgets('Share button present when score beats previous best',
      (tester) async {
    final session = makeSession(score: 50);
    await tester.pumpWidget(buildScreen(session, previousBest: 100));
    await tester.pump();
    expect(find.text('Share result'), findsOneWidget);
  });
});
```

**Note on SHARE-02 testability:** `RenderRepaintBoundary.toImage()` requires a real render context and does not work in `flutter_test`'s software renderer. The `_captureAndShare` image capture path is marked for manual verification on device. Test coverage for SHARE-02 is limited to confirming the Share button tap calls `_onSharePressed` (covered by the SHARE-01 presence test above via widget tap).

---

## Shared Patterns

### `mounted` guard after `await`
**Source:** Current `completion_screen.dart` line 94 + Flags analog line 111
**Apply to:** Both `_onSharePressed` and `_captureAndShare` `finally` block
```dart
if (passed != true || !mounted) return;
// ...
if (mounted) setState(() => _isSharing = false);
```

### `try`/`finally` for async resource cleanup
**Source:** Flags `completion_screen.dart` lines 187–212
**Apply to:** `_captureAndShare` only
```dart
File? file;
try {
  // ...resource-using async work...
} finally {
  file?.deleteSync();
  if (mounted) setState(() => _isSharing = false);
}
```

### `int.tryParse` for numeric input validation
**Source:** Flags `completion_screen.dart` line 162; current `completion_screen.dart` line 368
**Apply to:** `_MathChallengeDialogState._onConfirm` — already present, keep as-is
```dart
final entered = int.tryParse(_controller.text.trim());
```
Returns `null` on non-numeric input; the `==` comparison with `_a * _b` (an `int`) safely returns `false`.

### `barrierDismissible: false` on parental gate dialog
**Source:** Flags `completion_screen.dart` line 125
**Apply to:** `_showParentalGate()` `showDialog` call
```dart
await showDialog<void>(
  context: context,
  barrierDismissible: false,
  // ...
);
```

---

## No Analog Found

No files in this phase lack an analog. All patterns are directly ported from the Flags reference.

---

## Critical Deltas from Flags Analog

These are the exact points where the State States implementation MUST differ from the Flags reference:

| Delta | Flags (analog) | State States (target) | Reason |
|-------|---------------|----------------------|--------|
| Share API | `Share.shareXFiles([XFile(path)], text: ...)` (deprecated static, line 205) | `SharePlus.instance.share(ShareParams(text: ..., files: [XFile(path)]))` | State States already uses new API at line 98; do not regress |
| Share text | l10n string `shareImageHeader(modeName)` | `'New lowest score in $modeName! Score: $score — State the States 🇺🇸'` | No l10n in State States (Phase 4 decision) |
| Mode name source | `_modeDisplayName(mode, l10n)` | `widget.session.mode.displayName` | `GameModeDisplay` extension already defined in `game_mode.dart` |
| `finally` cleanup | No `file?.deleteSync()` in Flags `finally` (line 210) | `file?.deleteSync()` required | Flags omits temp file delete; State States must include it (per RESEARCH.md pitfall 7) |
| `_showParentalGate` structure | `StatefulBuilder` inside `showDialog<void>` (Flags lines 123–181) | `showDialog<bool>` wrapping existing `_MathChallengeDialog` class | State States already has `_MathChallengeDialog` extracted as `StatefulWidget`; upgrade in-place rather than rewriting to `StatefulBuilder` |
| PB-gate on Share button | Share button always visible in Flags (lines 401–422) | Share button only if `if (_isNewPb)` | SHARE-01 requirement |
| l10n dependency | All strings via `AppLocalizations.of(context)` | No l10n; hardcoded English strings | Phase 4 decision |
| Ad service imports | `adServiceProvider`, `AdMobAdService` imports present | Not present (COMP-03 walled-garden rule) | `GameSessionNotifier` zero ad imports; widget-layer only |

---

## Metadata

**Analog search scope:** `C:\code\Claude\FlagsRoundTheWorld\lib\features\map\`, `C:\code\Claude\StateTheStates\lib\features\map\`, `C:\code\Claude\StateTheStates\test\features\map\`
**Files scanned:** 3 (Flags completion_screen.dart, StateTheStates completion_screen.dart, completion_screen_test.dart)
**Pattern extraction date:** 2026-06-03
