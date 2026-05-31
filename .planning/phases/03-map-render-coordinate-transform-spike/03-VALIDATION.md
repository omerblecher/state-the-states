---
phase: 3
slug: map-render-coordinate-transform-spike
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-31
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) |
| **Config file** | None — standard Flutter test runner |
| **Quick run command** | `flutter test test/features/map/hit_detection_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds (full); <5 seconds (quick) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/map/hit_detection_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green; Criteria 1 & 2 verified manually in SpikeMapScreen
- **Max feedback latency:** 5 seconds (hit detection unit tests)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| stateHitTest() impl | 03-XX | 1 | MAP-01, MAP-03, Criterion 2 | — | N/A | unit | `flutter test test/features/map/hit_detection_test.dart` | ❌ W0 | ⬜ pending |
| UsaMapPainter fill/border | 03-XX | 1 | MAP-01, MAP-02 | — | N/A | widget (smoke) | `flutter test test/features/map/usa_map_painter_test.dart` | ❌ W0 | ⬜ pending |
| MapScreen IV+AnimatedBuilder | 03-XX | 2 | MAP-03, MAP-04, Criterion 4 | — | N/A | widget | `flutter test test/features/map/map_screen_test.dart` | ❌ W0 | ⬜ pending |
| SpikeMapScreen | 03-XX | 2 | Criterion 1 (HARD GATE) | — | N/A | widget + manual | `flutter test test/features/map/spike_map_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/map/hit_detection_test.dart` — 10 centroid assertions (RI, DE, CT, NJ, MD × scale 1.0 and 4.0) + ocean-null case + expansion edge cases (Criterion 2 HARD GATE)
- [ ] `test/features/map/usa_map_painter_test.dart` — smoke: painter renders without exception given 51 real StateData objects (MAP-01, MAP-02)
- [ ] `test/features/map/map_screen_test.dart` — zoom button 1.5× assertion + `getMaxScaleOnAxis()` == entry(0,0) after zoom (MAP-03, MAP-04, Criterion 4)
- [ ] `test/features/map/spike_map_screen_test.dart` — coordinate transform accuracy at 1×/2×/4× zoom (Criterion 1 HARD GATE)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AK renders in bottom-left inset frame with frame rect | MAP-02 | CustomPainter visual output not easily asserted in automated tests | Launch app in debug mode; verify AK polygon group appears in lower-left with surrounding frame rectangle |
| HI renders in bottom-center inset frame with frame rect | MAP-02 | Same as above | Launch app; verify HI polygon group appears in lower-center with surrounding frame rectangle |
| All 50 states render with palette colors at launch | MAP-01 | Color rendering is visual | Launch app; visually confirm all states filled (no blank polygons); some states grey only if matchedPostals is non-empty |
| SpikeMapScreen: drop registers correctly at 4× zoom | Criterion 1 | Requires manual drag interaction in running app | Navigate to `/spike` in debug build; zoom to 4×; drag over TX, CA, FL, NY, AK, HI regions; each should log the correct postal code |
| Pinch-to-zoom stays within min/max bounds | MAP-03 | Gesture interaction | Pinch to zoom out past min scale; verify map doesn't zoom out further; same for max |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
