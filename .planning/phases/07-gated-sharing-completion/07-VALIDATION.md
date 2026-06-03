---
phase: 7
slug: gated-sharing-completion
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-03
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | none — uses default test/ discovery |
| **Quick run command** | `flutter test test/features/map/completion_screen_test.dart --no-pub` |
| **Full suite command** | `flutter test --no-pub` |
| **Estimated runtime** | ~30 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/map/completion_screen_test.dart --no-pub`
- **After every plan wave:** Run `flutter test --no-pub`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | W0 | SHARE-01, SHARE-04 | T-07-01 | Math gate uses multiplication; Share button absent on non-PB | widget | `flutter test test/features/map/completion_screen_test.dart --no-pub` | ✅ (add cases) | ⬜ pending |
| 07-02-01 | 02 | 1 | SHARE-01 | — | Share button visible only when `_isNewPb == true` | widget | `flutter test test/features/map/completion_screen_test.dart --no-pub` | ✅ (add cases) | ⬜ pending |
| 07-02-02 | 02 | 1 | SHARE-04 | T-07-01 | `_MathChallengeDialog` uses `_a * _b` multiplication check | widget | `flutter test test/features/map/completion_screen_test.dart --no-pub` | ✅ (add cases) | ⬜ pending |
| 07-02-03 | 02 | 1 | SHARE-02, SHARE-03 | — | `_captureAndShare` + share message format | manual | Manual: tap Share on PB completion, verify message on share sheet | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] New test cases in `test/features/map/completion_screen_test.dart` — covers:
  - SHARE-01: Share button absent when `_isNewPb == false`
  - SHARE-01: Share button present when `_isNewPb == true`
  - SHARE-04: `_MathChallengeDialog` correct answer passes (multiplication check)
  - SHARE-04: `_MathChallengeDialog` wrong answer stays open
  - SHARE-04: `_MathChallengeDialog` cancel returns `false`

*(Existing test infrastructure covers the framework — 11 passing tests in completion_screen_test.dart as of 2026-06-03. Only new test cases are added, not new test files.)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `_captureAndShare` produces a readable PNG and attaches it to the native share sheet | SHARE-02 | `RenderRepaintBoundary.toImage()` requires real render context; flutter_test software renderer cannot exercise it | Run on Android emulator/device: complete a game at lower score than best, tap Share, pass math gate, confirm share sheet appears with score_card.png attached |
| Share message reads "New lowest score in [Mode Name]! Score: [N] — State the States 🇺🇸" | SHARE-03 | Share sheet content is OS-rendered; cannot be asserted in widget tests | Inspect share sheet text in system share dialog after passing math gate |
| Temp file `score_card.png` is deleted after share sheet dismissal | SHARE-02 | File system state change, not assertable in widget tests | Check `Directory.systemTemp` before and after sharing via debug print or adb shell |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
