---
phase: 6
slug: speed-typing-mode
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-02
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK — already installed) |
| **Config file** | `pubspec.yaml` (standard Flutter test runner) |
| **Quick run command** | `flutter test test/features/game/game_session_notifier_test.dart test/features/typing/speed_typing_screen_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 1 | TYPING-04, TYPING-05, TYPING-07, TYPING-08 | — | No ad imports in notifier (walled-garden) | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ✅ extend existing | ⬜ pending |
| 6-01-02 | 01 | 1 | TYPING-01, TYPING-09 | — | N/A | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ✅ extend existing | ⬜ pending |
| 6-02-01 | 02 | 2 | TYPING-03, TYPING-06 | — | N/A | widget | `flutter test test/features/typing/speed_typing_screen_test.dart` | ❌ Wave 0 | ⬜ pending |
| 6-02-02 | 02 | 2 | TYPING-02 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart` | ✅ extend existing | ⬜ pending |
| 6-03-01 | 03 | 3 | TYPING-01 | — | N/A | widget | `flutter test test/features/home/home_screen_test.dart` | ✅ extend existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/typing/speed_typing_screen_test.dart` — stub covering TYPING-03 (TextCapitalization.characters), TYPING-06 (chip grid renders)
- [ ] `test/features/typing/` — create directory
- [ ] State fixture: minimal `List<StateData>` (3–5 states) for `submitTyping()` unit tests — add as helper in `test/features/game/game_session_notifier_test.dart`

*Existing test infrastructure (flutter_test + mocktail) already installed — no new packages required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Keyboard docks below found-states grid | TYPING-03, TYPING-06 | Device keyboard behavior not emulatable in headless tests | Launch app on device/emulator; navigate to `/type`; verify TextField sits above keyboard with grid scrollable above |
| Audio plays on hit/miss | TYPING-04, TYPING-05 | `just_audio` platform audio not testable in flutter_test | Play a round; verify success SFX on correct state, error SFX on wrong state |
| Field clears on every Enter press | TYPING-04 (hit) + TYPING-05 (miss) | TextInputAction behavior varies by platform | Submit a correct state name; submit a wrong string; verify field clears both times |
| Session restore navigates to `/type` | TYPING-02 | Multi-step lifecycle requiring real device kill | Start speed typing session, background app, kill process, relaunch, verify "Continue" returns to SpeedTypingScreen |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
