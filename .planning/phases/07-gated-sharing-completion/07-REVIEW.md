---
phase: 07-gated-sharing-completion
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - lib/features/map/completion_screen.dart
  - test/features/map/completion_screen_test.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-06-03
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Two files reviewed: `completion_screen.dart` (549 lines) and its companion test file (292 lines). The implementation correctly gates the Share button behind `_isNewPb`, uses multiplication in the math challenge, and cleans up temp files in a `finally` block. The overall approach is sound.

Four warnings and three info findings were identified. The most significant issues are: (1) `_isSharing = true` is set *after* the expensive I/O operations rather than at the start of `_captureAndShare`, leaving the UI unresponsive with no feedback during the longest part of the operation and opening a double-tap window; (2) the star-count / PB logic in `initState` is a verbatim duplicate of `computeStarCount`, so a future formula change must be made in two places and is likely to diverge; (3) the fixed temp-file name `score_card.png` is unsafe under concurrent share attempts. No critical (data-loss or security-class) bugs were found.

---

## Warnings

### WR-01: `_isSharing` spinner activated after slow I/O, not before — double-tap window

**File:** `lib/features/map/completion_screen.dart:108-136`

**Issue:** `_isSharing = true` (line 128) is set only after `boundary.toImage()`, `toByteData()`, and `file.writeAsBytes()` have all completed. These operations can take 200–500ms on a slow device. During that entire window the Share button remains visible and tappable, so a user can trigger a second concurrent `_captureAndShare` call. The spinner (which replaces the button) never appears for most of the operation; it flickers on just before the share sheet opens, then off.

The research document (07-RESEARCH.md Pattern 1 and Open Question 1) explicitly called out `setState(_isSharing = true)` as the *first* line inside `_captureAndShare`, before any I/O.

**Fix:**

```dart
Future<void> _captureAndShare() async {
  if (!mounted) return;
  // Set spinner BEFORE any I/O so the button is replaced immediately.
  setState(() => _isSharing = true);
  File? file;
  try {
    final boundary = _scoreCardKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    // ... rest of capture unchanged ...
  } finally {
    file?.deleteSync();
    if (mounted) setState(() => _isSharing = false);
  }
}
```

Remove the `if (mounted) setState(() => _isSharing = true);` call at line 128 (inside the `try` block, after the I/O).

---

### WR-02: Fixed temp-file name `score_card.png` is unsafe under concurrent calls

**File:** `lib/features/map/completion_screen.dart:122`

**Issue:** The temp file is always written to the same path: `'${Directory.systemTemp.path}/score_card.png'`. If two share operations overlap (which WR-01's double-tap window makes possible), the second call's `writeAsBytes` will overwrite the first's bytes while the first's `SharePlus.instance.share()` is still using the file. The `deleteSync()` in the first call's `finally` block then deletes the file while the second call is sharing it.

Once WR-01 is fixed the button is disabled during sharing, eliminating the practical overlap — but the fix to WR-01 reduces the window to near-zero rather than zero (there is a gap between the user tap and the `setState` executing). A unique name is the correct defence.

**Fix:**

```dart
file = File(
  '${Directory.systemTemp.path}/score_card_${DateTime.now().millisecondsSinceEpoch}.png',
);
```

Or use a `const` prefix with a UUID if `uuid` is already a transitive dep — the timestamp suffix is sufficient for this single-user app.

---

### WR-03: Duplicate star-count / `_isNewPb` logic — `initState` reimplements `computeStarCount` verbatim

**File:** `lib/features/map/completion_screen.dart:59-73`

**Issue:** `_CompletionScreenState.initState` contains a hand-rolled branch tree (lines 59-73) that exactly replicates the `computeStarCount` top-level function (lines 21-26), adding only the `_isNewPb` assignment. Any future change to the D-11 formula (e.g. widening the 20% window, adding a 4-star tier) must be applied in both places and will silently diverge.

```dart
// initState (lines 62-72) — duplicate of computeStarCount:
if (prev == null)          { _isNewPb = false; _starCount = 3; }
else if (score < prev)     { _isNewPb = true;  _starCount = 3; }
else if (score <= (prev * 1.20).ceil()) { _isNewPb = false; _starCount = 2; }
else                       { _isNewPb = false; _starCount = 1; }
```

**Fix:** Delegate to `computeStarCount` and derive `_isNewPb` separately:

```dart
_starCount = computeStarCount(score, prev);
_isNewPb = prev != null && score < prev;
```

This eliminates the duplicate and keeps `computeStarCount` as the single source of truth for the formula.

---

### WR-04: Stale "Wave 0 FAILS" comments in test file — incorrect after implementation is complete

**File:** `test/features/map/completion_screen_test.dart:123-124, 148-149, 173-177, 183-184, 239-240, 268-270`

**Issue:** Multiple test cases are annotated with comments asserting they are RED / failing at "Wave 0":

> "Wave 0 status: FAILS — current code shows Share button unconditionally so `findsNothing` assertion fails."
> "SHARE-04: RED until Plan 02 upgrades MathChallengeDialog from addition to multiplication."

The implementation in `completion_screen.dart` already has the correct behaviour: the Share button is gated by `if (_isNewPb)` (line 330) and the math gate already uses multiplication with `rng.nextInt` (lines 402-404, 415). These tests should all be GREEN now, but any reader of the test file will assume they are failing and may skip them or suppress failures. Misleading comments in a test suite are a maintenance hazard.

**Fix:** Remove or update all "Wave 0 status: FAILS" and "RED until Plan 02" comments to reflect the current passing state. For example:

```dart
// SHARE-01: Share button is absent on non-PB completions (gated by _isNewPb).
testWidgets('SHARE-01: Share button absent when score > previousBest (non-PB)',
    (tester) async {
  // score=125 > previousBest=100 → _isNewPb == false
  ...
```

---

## Info

### IN-01: Early-return paths in `_captureAndShare` provide no user feedback

**File:** `lib/features/map/completion_screen.dart:113-119`

**Issue:** Three silent `return` paths exist before any loading indicator: `if (boundary == null) return` (line 114), and `if (byteData == null) return` (line 119). After fixing WR-01 the spinner is set before these guards, so at least the user sees the spinner appear and disappear. However, the user has no indication that sharing silently failed — no error SnackBar, no toast, no message. On a device that cannot render the boundary (e.g. during a hot reload, or a rare GPU compositing issue) the share button will appear to do nothing.

**Fix:** Add a SnackBar or brief error message on the null-boundary path. At minimum, assert in debug mode:

```dart
if (boundary == null) {
  assert(false, '_captureAndShare: RepaintBoundary not found — GlobalKey not attached?');
  return;
}
```

---

### IN-02: `_pbController.forward()` started during `initState` via `setState`

**File:** `lib/features/map/completion_screen.dart:79-83`

**Issue:** `setState(() => _showPbOverlay = true)` is called in `initState` (line 80), before the first `build` call. Flutter permits `setState` during `initState` (it schedules a build), but the idiomatic approach is to set `_showPbOverlay = true` as a field initializer or directly in `initState` without wrapping in `setState`, since no build has occurred yet and there is nothing to diff. The `setState` call is unnecessary here.

**Fix:**

```dart
// In initState, replace:
setState(() => _showPbOverlay = true);
// With:
_showPbOverlay = true;
```

The `whenComplete` callback correctly wraps in `if (mounted) setState(...)` — no change needed there.

---

### IN-03: `computeStarCount` is called from `home_screen.dart` with `previousBest: null` unconditionally — always returns 3 stars

**File:** `lib/features/home/home_screen.dart:246` (context: `completion_screen.dart` function signature)

**Issue:** `_starsForScore(int? score)` in `home_screen.dart` calls `computeStarCount(score, null)`. Because `previousBest == null` is the first branch in `computeStarCount` and returns 3, every mode's stored best score renders as 3 filled stars on the home screen, regardless of how poor the score was. This was noted as an existing issue in the Phase 4 review (04-REVIEW.md) and is carried forward unresolved into Phase 7 — no change was made to either site in this phase, but shipping a Phase 7 completion screen that awards 1-3 stars while the home screen always shows 3 will confuse players who earn 1 star on completion and then see 3 stars on the home card.

**Fix:** Either pass the mode's stored personal-best as `previousBest` in the home screen call (so the formula has meaning), or replace the home screen star display with a fixed 3-star "achieved" icon that does not imply a rating. Do not let this carry into a public release.

---

_Reviewed: 2026-06-03_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
