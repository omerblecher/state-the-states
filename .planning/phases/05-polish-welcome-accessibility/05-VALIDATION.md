---
phase: 5
slug: 05-polish-welcome-accessibility
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-01
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + `mocktail` 1.0.5 |
| **Config file** | None — standard `flutter test` |
| **Quick run command** | `flutter test test/features/welcome/ test/features/tutorial/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/welcome/ test/features/tutorial/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 0 | WEL-02 | — | N/A | Manual (FluidSynth CLI) | Manual: fluidsynth command produces anthem.wav | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 0 | WEL-02 | — | N/A | File check | `test -f assets/audio/anthem.wav && [ $(wc -c < assets/audio/anthem.wav) -gt 100000 ]` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | WEL-03 | T-05-08 | fadeOutAnthem completes without throw | Unit | `flutter test test/core/audio/audio_service_test.dart` | ✅ extend | ⬜ pending |
| 05-02-02 | 02 | 1 | WEL-02, WEL-03 | T-05-09 | Timer.periodic fade does not leak | Unit | `flutter test test/core/audio/audio_service_test.dart` | ✅ extend | ⬜ pending |
| 05-03-01 | 03 | 2 | WEL-01 | T-05-01 | /welcome is initial route | Widget | `flutter test test/features/welcome/welcome_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-03-02 | 03 | 2 | WEL-01, WEL-02, WEL-03 | T-05-02 | USA silhouette renders + anthem plays | Widget | `flutter test test/features/welcome/welcome_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-04-01 | 04 | 2 | SESS-04 | T-05-06 | Tutorial skip/done both set seen flag | Widget | `flutter test test/features/tutorial/tutorial_screen_test.dart` | ❌ W0 | ⬜ pending |
| 05-05-01 | 05 | 2 | HINT-01 | T-05-12 | Glow renders at 0xFFBBFF44 for hintPostal | Unit | `flutter test test/features/map/usa_map_painter_test.dart` | ✅ extend | ⬜ pending |
| 05-05-02 | 05 | 2 | HINT-01, HINT-02 | T-05-10 | _hintGlowTimer cancelled on dispose | Widget | `flutter test test/features/map/map_screen_test.dart` | ✅ extend | ⬜ pending |
| 05-06-01 | 06 | 2 | HOME-03 | — | N/A | Widget | `flutter test test/features/home/home_screen_test.dart` | ✅ extend | ⬜ pending |
| 05-06-02 | 06 | 2 | HOME-03 | — | N/A | Widget | `flutter test test/features/home/home_screen_test.dart` | ✅ extend | ⬜ pending |
| 05-07-01 | 07 | 3 | A11Y-01, A11Y-02 | T-05-14 | All controls ≥48dp with Semantics labels | Widget (guideline) | `flutter test test/features/welcome/welcome_screen_test.dart` | ✅ extend | ⬜ pending |
| 05-07-02 | 07 | 3 | A11Y-01 | — | N/A | Widget (guideline) | `flutter test` | ✅ extend | ⬜ pending |
| 05-07-03 | 07 | 3 | A11Y-02 | — | N/A | Manual audit | Manual: review _handleDrop for multimodal paths | Manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/welcome/welcome_screen_test.dart` — covers WEL-01, WEL-02, A11Y-01 (smoke + meetsGuideline)
- [ ] `test/features/tutorial/tutorial_screen_test.dart` — covers SESS-04 (skip path + done path, both set seen flag)
- [ ] Extend `test/features/home/home_screen_test.dart` — cover HOME-03 (restore card shown/hidden)
- [ ] Extend `test/core/audio/audio_service_test.dart` — add fadeInAnthem() and fadeOutAnthem() interface-parity assertions

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Anthem fade-in (500ms) on welcome screen load | WEL-02, WEL-03 | Timer-based volume ramp not easily testable in FakeAsync without mocking the Timer | Launch app on device/emulator; observe anthem starts quietly and reaches full volume within ~500ms |
| Hint zoom animation and 3s glow window | HINT-01 | Timer-based glow window; Matrix4Tween animation requires real frame scheduling | In a game session, tap hint; observe viewport zooms to target state, yellow-green glow appears, glow disappears after ~3s; viewport remains at hint zoom level |
| A11Y-02 multimodal feedback (haptic + audio + visual) | A11Y-02 | Color-alone prohibition requires human judgment for edge cases | Review _handleDrop: confirm HapticFeedback.lightImpact() and playCorrect() / playError() are both called on correct/incorrect drops respectively; confirm visual state change is not color-only |
| aapt COPPA re-verification (no AD_ID) | COMP-01, COMP-02 | aapt requires a built APK | `flutter build apk --debug` then `$ANDROID_HOME/build-tools/*/aapt dump badging build/app/outputs/flutter-apk/app-debug.apk | grep -i "AD_ID\|permission"` — confirm AD_ID absent |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
