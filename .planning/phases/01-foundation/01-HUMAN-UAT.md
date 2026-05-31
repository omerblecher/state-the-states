---
status: partial
phase: 01-foundation
source: [01-VERIFICATION.md]
started: "2026-05-31"
updated: "2026-05-31"
---

## Current Test

[awaiting human testing]

## Tests

### 1. App runtime startup
expected: Installing and launching the debug APK (`build/app/outputs/flutter-apk/app-debug.apk`) brings up the HomeScreen ("State the States" + Play button) without crashing; COPPA init and the ProviderScope RealAudioService override run without error.
result: [pending]

### 2. MapScreen blank-canvas navigation
expected: Tapping "Play" navigates to `/play`; a brief CircularProgressIndicator (data loading in the compute isolate) resolves to a blank canvas with no errors or red screens — confirming JSON → isolate → provider → painter wiring at runtime.
result: [pending]

### 3. AK/HI visual inset check (optional per plan)
expected: When the real map renders (Phase 3, or via a pipeline PNG), Alaska appears in the bottom-left inset and Hawaii in the bottom-center inset, with no antimeridian smear across Alaska. Currently verified programmatically (centroids inside insetFrames + shapely validity); a standalone PNG render was not produced.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
