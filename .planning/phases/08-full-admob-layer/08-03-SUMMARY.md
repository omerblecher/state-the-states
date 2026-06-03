---
phase: 08-full-admob-layer
plan: "03"
status: complete
completed: "2026-06-03"
subsystem: ads
tags: [admob, app-open, app-state-observer, lifecycle, coppa]
requires: [08-02]
provides: [app-state-observer-wired, app-open-lifecycle]
affects:
  - lib/app.dart
tech_stack:
  added: []
  patterns: [consumer-stateful-widget, app-state-stream, app-open-suppression]
key_files:
  created: []
  modified:
    - lib/app.dart
decisions:
  - "AppStateEventNotifier fires AppState.foreground on cold launch as well as resume — no separate initState showAppOpenAd() call needed (avoids double-fire)"
  - "Belt-and-suspenders suppression: _onAppResumed() checks GamePhase.playing/paused at the app.dart layer; RealAdService.showAppOpenAd() applies the same guard independently"
metrics:
  duration: 4min
  completed: "2026-06-03"
  tasks: 1
  files: 1
---

# Phase 08 Plan 03: App ConsumerStatefulWidget with AppStateEventNotifier Summary

## What Was Built

Converted `App` from `StatelessWidget` to `ConsumerStatefulWidget` and wired `AppStateEventNotifier` subscription for App Open ad lifecycle. `_AppState.initState()` calls `AppStateEventNotifier.startListening()` and subscribes to `appStateStream`; on every `AppState.foreground` event, `_onAppResumed()` reads the current game phase and suppresses `showAppOpenAd()` when the player is in `playing` or `paused` state. `dispose()` cancels the subscription (T-08-03-02 mitigated).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Convert App to ConsumerStatefulWidget with AppStateEventNotifier (AD-05) | 111f39e | lib/app.dart |

## Verification Results

```
flutter analyze lib/app.dart — No issues found
lib/app.dart contains "class App extends ConsumerStatefulWidget": confirmed
lib/app.dart contains "class _AppState extends ConsumerState<App>": confirmed
lib/app.dart contains "AppStateEventNotifier.startListening()": confirmed
lib/app.dart contains "_appStateSubscription?.cancel()": confirmed
lib/app.dart contains "GamePhase.playing || phase == GamePhase.paused" suppression: confirmed
All existing routes (/welcome, /tutorial, /, /play, /type, /complete, /spike) preserved: confirmed
flutter test — pre-existing failures in home_screen_test.dart (2 tests) are pre-existing; no new failures introduced by this change (verified by stash + re-run)
```

## Key Decisions

1. **No separate cold-launch `showAppOpenAd()` in `initState()`** — `AppStateEventNotifier` fires `AppState.foreground` on the first foreground transition including cold launch. Adding a separate `initState()` call would double-fire the App Open ad. The stream subscription alone is sufficient.

2. **Belt-and-suspenders suppression** — `_onAppResumed()` reads `gameSessionProvider.value?.phase` and returns early on `playing`/`paused`. This is the app.dart-layer guard. `RealAdService.showAppOpenAd()` also applies the same guard independently. Two independent checks ensure AD-05 compliance even if one layer is bypassed.

## Deviations from Plan

None — plan executed exactly as written. The Flags analog (lines 63–107) was ported verbatim with title change only.

## Known Stubs

None — `AppStateEventNotifier` subscription is fully wired. `_onAppResumed()` calls the real `adServiceProvider.showAppOpenAd()`.

## Threat Flags

No new security surface introduced beyond what was planned.

| Flag | File | Description |
|------|------|-------------|
| None | — | app.dart now reads adServiceProvider and gameSessionProvider; both are inside the lib/core/ads/ walled garden; GameSessionNotifier walled-garden rule (zero ad imports) preserved |

## Self-Check: PASSED

- lib/app.dart exists: confirmed
- `class App extends ConsumerStatefulWidget` in lib/app.dart: confirmed
- `class _AppState extends ConsumerState<App>` in lib/app.dart: confirmed
- `AppStateEventNotifier.startListening()` in lib/app.dart: confirmed
- `_appStateSubscription?.cancel()` in lib/app.dart: confirmed
- Phase suppression guard (playing/paused) in lib/app.dart: confirmed
- Task commit 111f39e exists: confirmed
- No file deletions in commit: confirmed
