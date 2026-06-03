---
phase: 07-gated-sharing-completion
plan: 01
subsystem: testing
tags: [flutter_test, tdd, completion_screen, share, math_gate]

# Dependency graph
requires:
  - phase: 05-polish-welcome-accessibility
    provides: CompletionScreen widget with Share result button and _MathChallengeDialog
provides:
  - Wave 0 RED test suite for SHARE-01 (PB-visibility gating) and SHARE-04 (multiplication math gate)
affects:
  - 07-02-PLAN.md (Plan 02 must turn all RED tests GREEN)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TDD Wave 0: write RED tests first against current behaviour, turn GREEN in next plan"
    - "Use ensureVisible() before tapping off-screen widgets in scrollable CompletionScreen"
    - "Parse dialog question text via tester.widget<Text>() to handle randomly-generated operands"
    - "Trigger dialog indirectly through Share result button rather than instantiating private class"

key-files:
  created: []
  modified:
    - test/features/map/completion_screen_test.dart

key-decisions:
  - "07-01: Dialog tests (SHARE-04) open via tapping Share result on CompletionScreen rather than directly instantiating _MathChallengeDialog — avoids Dart private-class compile error; Plan 02 renames class to public MathChallengeDialog"
  - "07-01: Tests 3-5 use ensureVisible() before tap() because Share result button is below the 600px test viewport in the scrollable body"
  - "07-01: Test 3 (multiplication correct answer) is RED at Wave 0 because the RegExp 'What is (\\d+) × (\\d+)' (U+00D7) does not match the current addition question format 'What is N + M?'"

patterns-established:
  - "Wave 0 TDD: append new group at end of main(); do not modify existing tests"
  - "Dialog operand extraction: use find.textContaining('What is') → widget<Text>().data → RegExp match"

requirements-completed:
  - SHARE-01
  - SHARE-04

# Metrics
duration: 15min
completed: 2026-06-03
---

# Phase 7 Plan 01: Gated Sharing — Wave 0 Test Cases Summary

**6 new RED/GREEN test cases for PB-visibility gating (SHARE-01) and multiplication math gate (SHARE-04) appended to completion_screen_test.dart; all 11 pre-existing tests continue to pass**

## Performance

- **Duration:** 15 min
- **Started:** 2026-06-03T06:35:23Z
- **Completed:** 2026-06-03T06:50:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added group 'Phase 7 gated sharing' with 6 testWidgets cases to completion_screen_test.dart
- Tests 1 and 6 (SHARE-01 non-PB / first-game): RED at Wave 0 — Share button shows unconditionally in current code
- Test 2 (SHARE-01 PB): GREEN at Wave 0 — regression guard ensuring Share button is never removed entirely
- Test 3 (SHARE-04 multiplication): RED at Wave 0 — dialog question uses '+' not '×'; U+00D7 RegExp finds no match
- Tests 4 and 5 (SHARE-04 wrong answer / cancel): GREEN at Wave 0 — dialog error message and Cancel dismiss work correctly
- All 11 pre-existing tests continue to pass; total test count is 17

## Task Commits

1. **Task 1: Add Phase 7 widget test cases (SHARE-01 + SHARE-04)** - `d23f356` (test)

**Plan metadata:** (included in state update commit)

## Files Created/Modified

- `test/features/map/completion_screen_test.dart` - New group 'Phase 7 gated sharing' with 6 testWidgets cases appended at end of main()

## Decisions Made

- **Dialog tests via Share result tap, not direct class instantiation:** `_MathChallengeDialog` is a private class (library-scoped underscore prefix) inaccessible from the test library. Plan 02 renames it to `MathChallengeDialog` (public, @visibleForTesting). To avoid a compile error at Wave 0, tests 3–5 trigger the dialog through the existing `Share result` button on a PB CompletionScreen rather than directly instantiating the class.

- **ensureVisible() before tapping Share result:** The CompletionScreen body is a scrollable column. In the 800×600 test viewport, the Share result button is rendered at y≈660, outside the visible area. Without `ensureVisible()`, the tap produces a warning and the dialog never opens.

- **Multiplication RegExp uses U+00D7 (×), not letter x:** Test 3 uses `RegExp(r'What is (\d+) × (\d+)')` where `×` is Unicode U+00D7. At Wave 0 the dialog renders `What is N + M?` (addition), so the RegExp match is null and the test fails with the explicit message "Dialog question must use multiplication (×) format — RED until Plan 02". This is the expected RED failure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced direct MathChallengeDialog instantiation with Share result button tap**
- **Found during:** Task 1 (adding test group)
- **Issue:** Plan instructs `showDialog(builder: (_) => const MathChallengeDialog())` but `MathChallengeDialog` doesn't exist yet (current class is `_MathChallengeDialog`, private). Using the private name from a different library causes a compile error; using the public name causes a "undefined name" compile error. Either path breaks the 11 pre-existing tests.
- **Fix:** Tests 3–5 open the dialog by calling `ensureVisible` + `tap(find.text('Share result'))` on a PB CompletionScreen instead of directly instantiating the dialog class. The dialog itself is the same widget; only the invocation path differs.
- **Files modified:** test/features/map/completion_screen_test.dart
- **Verification:** `flutter test test/features/map/completion_screen_test.dart --no-pub` — 11 pre-existing tests pass; 3 new tests RED (tests 1, 3, 6); 3 new tests GREEN (tests 2, 4, 5)
- **Committed in:** d23f356 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — compile-blocking class visibility issue)
**Impact on plan:** Necessary to keep pre-existing tests green while writing Wave 0 RED tests. No scope creep; dialog behavior coverage is identical.

## Issues Encountered

- Share result button off-screen at test viewport height (800×600). Resolved with `tester.ensureVisible()` before tap.
- _MathChallengeDialog private-class accessibility. Resolved by triggering dialog via existing button rather than direct instantiation (documented above as deviation).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Wave 0 test gate is in place: 3 RED tests will turn GREEN when Plan 02 implements the production changes
- Plan 02 must: (1) rename `_MathChallengeDialog` → `MathChallengeDialog` (public, @visibleForTesting), (2) change question from addition to multiplication, (3) gate Share button visibility on `_isNewPb`
- After Plan 02, all 17 tests should pass

---
*Phase: 07-gated-sharing-completion*
*Completed: 2026-06-03*
