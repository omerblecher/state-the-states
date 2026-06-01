---
plan: "05-02"
phase: "05-polish-welcome-accessibility"
status: complete
completed: "2026-06-01"
duration: "3min"
tasks_completed: 2
files_modified: 4
subsystem: audio
tags: [audio, fade, interface, riverpod, just_audio]
dependency_graph:
  requires: ["05-01"]
  provides: ["fadeInAnthem", "fadeOutAnthem", "anthem.wav wired"]
  affects: ["lib/core/audio/audio_service.dart", "lib/core/audio/real_audio_service.dart", "lib/core/audio/stub_audio_service.dart"]
tech_stack:
  added: []
  patterns: ["Timer.periodic volume ramp", "mute-flag guard on fade", "timer cancel in dispose"]
key_files:
  modified:
    - lib/core/audio/audio_service.dart
    - lib/core/audio/real_audio_service.dart
    - lib/core/audio/stub_audio_service.dart
    - test/core/audio/audio_service_test.dart
decisions:
  - "Rename playAnthem→fadeInAnthem and stopAnthem→fadeOutAnthem (clean rename per RESEARCH.md Open Question 1 resolution)"
  - "Timer.periodic 20ms interval chosen over AnimationController because RealAudioService has no TickerProvider"
  - "fadeInAnthem guards on _isMuted to skip volume ramp when app is muted"
  - "_fadeTimer?.cancel() placed as first statement in dispose() to prevent T-05-03 DoS"
metrics:
  duration: "3min"
  completed_date: "2026-06-01"
---

# Phase 5 Plan 2: Audio Fade Interface Rename — Summary

## What Was Built

Atomic rename of `playAnthem()`/`stopAnthem()` to `fadeInAnthem()`/`fadeOutAnthem()` across all three audio files, implementing 500ms fade-in (25 ticks × 20ms) and 800ms fade-out (40 ticks × 20ms) volume ramps via `Timer.periodic` in `RealAudioService`. Updated `setAsset()` to load `anthem.wav` (not `anthem_placeholder.wav`).

## Key Files

### Modified
- `lib/core/audio/audio_service.dart` — Interface updated: `playAnthem()` → `fadeInAnthem()` (D-A3 doc comment), `stopAnthem()` → `fadeOutAnthem()` (D-A2 doc comment)
- `lib/core/audio/real_audio_service.dart` — Full fade implementation with `Timer.periodic`, `_fadeTimer` field, `_isMuted` field, `anthem.wav` path, `_fadeTimer?.cancel()` in `dispose()`
- `lib/core/audio/stub_audio_service.dart` — No-op `fadeInAnthem()` and `fadeOutAnthem()` replacing old stubs
- `test/core/audio/audio_service_test.dart` — `stub.playAnthem()` → `stub.fadeInAnthem()`, `stub.stopAnthem()` → `stub.fadeOutAnthem()`

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| Task 1 | Interface + stub + test rename (3-file atomic) | 000a982 |
| Task 2 | RealAudioService Timer.periodic fade implementation | 3ce3e13 |

## Verification

- `flutter test test/core/audio/audio_service_test.dart` — 2/2 tests pass (StubAudioService group + RealAudioService group)
- `flutter analyze lib/core/audio/` — No issues found
- `grep -rn "playAnthem|stopAnthem" lib/` — 0 matches

## Decisions Made

1. **Clean rename (not additive):** `playAnthem()` and `stopAnthem()` removed from interface entirely; `fadeInAnthem()` and `fadeOutAnthem()` added in their place. The plan's RESEARCH.md Open Question 1 resolved this: clean rename is correct.
2. **Timer.periodic over AnimationController:** `RealAudioService` is a pure-Dart service class with no `TickerProvider`. `Timer.periodic` at 20ms is the idiomatic pattern for this use case.
3. **muted guard on fadeInAnthem:** `if (!_initialized || _isMuted) return` — fade-in is a no-op when app is muted, preventing inaudible volume ramp startup.
4. **_fadeTimer cancel at entry of both methods:** Both `fadeInAnthem()` and `fadeOutAnthem()` cancel any running timer first, satisfying T-05-04 (rapid CTA tap DoS mitigation).
5. **_fadeTimer cancel first in dispose():** Placed before all player disposes to satisfy T-05-03 (timer fires after dispose), per RESEARCH.md Pitfall 4.

## Deviations from Plan

None — plan executed exactly as written. Both Task 1 and Task 2 were committed in immediate sequence (as required by the cross-file interface invariant noted in the plan).

## Known Stubs

None — `fadeInAnthem()` and `fadeOutAnthem()` are fully implemented in `RealAudioService`. `StubAudioService` no-ops are intentional (test double, not stub data).

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `lib/core/audio/audio_service.dart` — contains `fadeInAnthem`, `fadeOutAnthem`; does NOT contain `playAnthem`, `stopAnthem`
- `lib/core/audio/real_audio_service.dart` — contains `fadeInAnthem`, `fadeOutAnthem`, `Timer? _fadeTimer`, `bool _isMuted = false`, `anthem.wav`, `_fadeTimer?.cancel()` before player disposes
- `lib/core/audio/stub_audio_service.dart` — contains `fadeInAnthem`, `fadeOutAnthem`; does NOT contain `playAnthem`, `stopAnthem`
- `test/core/audio/audio_service_test.dart` — calls `stub.fadeInAnthem()` and `stub.fadeOutAnthem()`
- Commits 000a982 and 3ce3e13 verified in git log
