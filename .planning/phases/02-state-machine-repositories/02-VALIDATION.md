---
phase: 2
slug: state-machine-repositories
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-31
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK bundled) + `mocktail` ^1.0.5 |
| **Config file** | none — `flutter test` uses the `pubspec.yaml` test runner |
| **Quick run command** | `flutter test test/features/game/ test/core/data/ test/core/audio/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds (pure-Dart unit + light widget tests; no integration) |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the touched directory (e.g. `flutter test test/features/game/game_session_notifier_test.dart`)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

> Task IDs are assigned by the planner; this map binds each phase requirement to its proving test file and the deterministic seam. The planner MUST keep `<automated>` verify commands consistent with this map.

| Requirement | Behavior | Wave | Test Type | Automated Command | File Exists | Status |
|-------------|----------|------|-----------|-------------------|-------------|--------|
| SCORE-01 | `+1 per 10 elapsed seconds`; elapsed via Stopwatch, not tick counter | 0/1 | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ W0 | ⬜ pending |
| SCORE-02 | `+5 per wrong drop` and `+5 per hint used` in formula | 1 | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ W0 | ⬜ pending |
| SCORE-05 | Best score written to SharedPreferences; cold re-read returns same; lower-wins guard | 1 | unit | `flutter test test/core/data/high_score_repository_test.dart` | ❌ W0 | ⬜ pending |
| SESS-01 | Auto-pause fires on `.paused`/`.hidden` only; `.inactive` ignored | 1 | widget | `flutter test test/features/game/game_lifecycle_observer_test.dart` | ❌ W0 | ⬜ pending |
| SESS-01 | `pauseGame()` calls `_stopwatch.stop()` (D-12 load-bearing) | 1 | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ W0 | ⬜ pending |
| SESS-02 | Mute preference persists across sessions | 1 | unit | `flutter test test/core/data/user_prefs_repository_test.dart` | ❌ W0 | ⬜ pending |
| SESS-03 | Snapshot round-trips to identical `GameSession` incl. `hintPenalty` | 1 | unit | `flutter test test/core/data/game_state_repository_test.dart` | ❌ W0 | ⬜ pending |
| SESS-03 | Corrupt snapshot → null, key cleared, no exception (D-08) | 1 | unit | `flutter test test/core/data/game_state_repository_test.dart` | ❌ W0 | ⬜ pending |
| SESS-03 | Restored session lands in `GamePhase.paused` (D-09) | 1 | unit | `flutter test test/features/game/game_session_notifier_test.dart` | ❌ W0 | ⬜ pending |
| WEL-04 | `RealAudioService` init/play/dispose — no leaked players | 1 | unit | `flutter test test/core/audio/audio_service_test.dart` | ❌ W0 | ⬜ pending |
| WEL-04 | `StubAudioService` no-op passes same interface assertions | 1 | unit | `flutter test test/core/audio/audio_service_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Criterion → Deterministic Seam

| Criterion | Seam | Mechanism |
|-----------|------|-----------|
| #1 scoring formula | `GameSessionNotifier` + `FakeTicker` | `FakeTicker.tick()` drives one display refresh; assert `state.value!.score` against formula with known `errorCount`/`hintPenalty` |
| #2 30s background = +0s | `pauseGame()` → assert `_stopwatch.isRunning == false` | Stopwatch stopped before any wall-clock advance; elapsed does not jump across pause/resume |
| #3 best score + mute persist | `setMockInitialValues({})` | write → drop container → new read returns same value |
| #4 snapshot round-trip | save → load, compare via `==` | `GameSession` `==`/`hashCode` from port; stress with `errorCount > 0`, `hintsRemaining < 2` |
| #5 audio service | `RealAudioService` + `StubAudioService` | `TestWidgetsFlutterBinding.ensureInitialized()`; dispose does not throw; stub parity assertions |

---

## Wave 0 Requirements

- [ ] `test/features/game/game_session_test.dart` — `GameSession` `==`/`hashCode`/`copyWith` stubs
- [ ] `test/features/game/game_session_notifier_test.dart` — SCORE-01, SCORE-02, SESS-01 (stop), SESS-03 (restore-to-paused)
- [ ] `test/features/game/game_lifecycle_observer_test.dart` — SESS-01 (D-10/D-11)
- [ ] `test/core/data/game_state_repository_test.dart` — SESS-03 (round-trip, corrupt discard)
- [ ] `test/core/data/high_score_repository_test.dart` — SCORE-05
- [ ] `test/core/data/user_prefs_repository_test.dart` — SESS-02
- [ ] `test/core/audio/audio_service_test.dart` — WEL-04

*Framework already installed (flutter_test SDK + mocktail in pubspec.yaml) — Wave 0 creates test files/fixtures only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | All Phase 2 behaviors have automated verification (pure-Dart logic + light widget tests). |

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
