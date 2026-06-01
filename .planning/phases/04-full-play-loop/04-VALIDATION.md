---
phase: 4
slug: full-play-loop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-01
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + `mocktail` 1.0.5 |
| **Config file** | none — existing infrastructure from Phases 1–3 |
| **Quick run command** | `flutter test test/features/map/hit_detection_test.dart test/features/game/game_session_notifier_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/map/hit_detection_test.dart test/features/game/game_session_notifier_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-routing | 01 | 1 | HOME-01, HOME-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-completion-stub | 01 | 1 | SCORE-06, SCORE-07 | — | N/A | widget | `flutter test test/features/map/completion_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-drag-loop | 02 | 2 | DRAG-01, DRAG-02, DRAG-03 | — | N/A | widget | `flutter test test/features/map/map_screen_test.dart` | ✅ (needs new tests) | ⬜ pending |
| 04-02-countdown | 02 | 2 | SESS-01 | — | N/A | widget | `flutter test test/features/map/map_screen_test.dart` | ✅ (needs new tests) | ⬜ pending |
| 04-03-tray | 03 | 2 | DRAG-04, DRAG-05, MODE-01, MODE-02, MODE-03, MODE-04 | — | N/A | widget | `flutter test test/features/map/state_tray_test.dart` | ❌ W0 | ⬜ pending |
| 04-04-hud | 04 | 3 | SCORE-03, SCORE-04 | — | N/A | widget | `flutter test test/features/map/map_screen_test.dart` | ✅ (needs new tests) | ⬜ pending |
| 04-04-correct-drop | 04 | 3 | DRAG-01, DRAG-02, DRAG-04 | — | N/A | widget | `flutter test test/features/map/map_screen_test.dart` | ✅ (needs new tests) | ⬜ pending |
| 04-04-incorrect-drop | 04 | 3 | DRAG-03, DRAG-05 | — | N/A | widget | `flutter test test/features/map/map_screen_test.dart` | ✅ (needs new tests) | ⬜ pending |
| 04-05-star-formula | 05 | 4 | SCORE-06, SCORE-07 | — | N/A | unit | `flutter test test/features/map/completion_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-05-pb-badge | 05 | 4 | SCORE-07 | — | N/A | widget | `flutter test test/features/map/completion_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-06-home-cards | 06 | 4 | HOME-01, HOME-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 1 (plan 04-01) must create these stubs before Wave 2 execution:

- [ ] `test/features/home/home_screen_test.dart` — stubs for HOME-01 (4 mode cards rendered), HOME-02 (`getBestScore` FutureBuilder mock)
- [ ] `test/features/map/completion_screen_test.dart` — stubs for SCORE-06, SCORE-07 (star formula unit tests, PB badge visibility widget test)
- [ ] `test/features/map/state_tray_test.dart` — stubs for DRAG-03 (bounce on incorrect), MODE-01 through MODE-04 (mode-specific card content and label visibility)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fly-to-centroid animation: token visually moves from tray to state centroid | DRAG-02 | OverlayEntry animation is not easily assertable in flutter_test without golden tests | Run app in debug, play Learn mode, make a correct drop; verify token animates to centroid and fades |
| Light haptic on correct drop, medium haptic on incorrect drop | DRAG-04, DRAG-05 | HapticFeedback is a platform channel call; not testable in flutter_test widget tests | Test on a physical Android device; correct drop = subtle buzz, incorrect = stronger buzz |
| Success and error sound effects play | DRAG-04, DRAG-05 | Audio playback requires platform channel; StubAudioService used in tests | Test on device with sound on; correct = success SFX, incorrect = error SFX |
| Countdown overlay (3-2-1-GO!) displays during countdown phase | SESS-01 | Timing-dependent animation overlay | Start a game; observe full-screen countdown overlay for 5 seconds before tray becomes draggable |
| Confetti overlay fires on personal best | SCORE-07 | AnimationController-driven canvas; golden test would be brittle | Beat a stored best score; verify confetti particles animate for ~2 seconds on completion screen |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (home_screen_test, completion_screen_test, state_tray_test)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
