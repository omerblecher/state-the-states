---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-31
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (Dart)** | `flutter_test` (SDK) |
| **Framework (Python)** | `pytest` (install in Wave 0) / `unittest` std-lib fallback |
| **Config file** | none — Dart uses `pubspec.yaml` dev_dependencies; Python uses std-lib |
| **Quick run command** | `flutter test test/core/` |
| **Full suite command** | `flutter test` + `python -m pytest scripts/` |
| **Estimated runtime** | ~5s (Dart core) · ~10s (Python pipeline) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/core/` (Dart model + service tests only, ~5s)
- **After every plan wave:** Run `flutter test` + `python -m pytest scripts/`
- **Before `/gsd:verify-work`:** Full suite green + `aapt dump badging` shows no AD_ID + `grep firebase pubspec.lock` empty
- **Max feedback latency:** ~5 seconds (per-task Dart core run)

---

## Per-Task Verification Map

| Req ID | Behavior | Test Type | Automated Command | File Exists | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| DATA-01 | `generate_states.py` produces `usa_states_paths.json` with 51 records total, 50 `isPlaceable: true` | unit (Python) | `python scripts/generate_states.py && python -m pytest scripts/test_pipeline.py::test_state_count` | ❌ W0 | ⬜ pending |
| DATA-01 | `stateDataProvider` resolves with 51 `StateData` items, 50 placeable | unit (Dart) | `flutter test test/core/data/state_data_service_test.dart` | ❌ W0 | ⬜ pending |
| DATA-02 | Alaska geometry passes `shapely.validation.is_valid()` after pipeline | unit (Python) | `python -m pytest scripts/test_pipeline.py::test_alaska_validity` | ❌ W0 | ⬜ pending |
| DATA-02 | Alaska `StateData.centroid` is within lower-left inset frame bounds | unit (Dart) | `flutter test test/core/models/state_data_test.dart` | ❌ W0 | ⬜ pending |
| COMP-01 | No Firebase package in `pubspec.lock` | smoke | `grep firebase pubspec.lock` returns empty | ❌ W0 | ⬜ pending |
| COMP-02 | `AD_ID` permission absent from APK | smoke (manual) | `aapt dump badging build/app/outputs/.../app-debug.apk \| grep AD_ID` returns empty | ✅ manual | ⬜ pending |
| COMP-03 | `GameSessionNotifier` has zero reachable ad imports | static analysis | `grep -r "import.*ads" lib/features/game/` returns empty | ✅ manual | ⬜ pending |
| COMP-04 | App builds with package `com.otis.brooke.state.the.state` | smoke | `flutter build apk --debug` succeeds | ✅ manual | ⬜ pending |
| SESS-05 | All assets bundled in APK; no network dependency at runtime | smoke | `flutter build apk` succeeds; no `http` package in `pubspec.lock` | ✅ manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/test_pipeline.py` — pipeline output validation (state count = 51 total / 50 placeable, Alaska `is_valid()`, inset positions in lower-left frame)
- [ ] `test/core/models/state_data_test.dart` — `StateData.fromJson` round-trip, `isPlaceable`, `InsetGroup` parsing, Alaska centroid inset check
- [ ] `test/core/data/state_data_service_test.dart` — provider resolves 51 records, 50 placeable
- [ ] Python: `pip install pytest` (or confirm `unittest` approach in wave instructions)

*All Dart data/service tests require `usa_states_paths.json` to exist — the pipeline must run in Wave 0 setup before those Dart tests run.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `AD_ID` permission absent from built APK | COMP-02 | Requires a built debug APK + `aapt`; not expressible as a unit test | `flutter build apk --debug` then `aapt dump badging <apk> \| grep AD_ID` → expect empty |
| `GameSessionNotifier` walled garden (no reachable ad imports) | COMP-03 | Reachability is a static-import property across files, not a runtime assertion | `grep -r "import.*ads" lib/features/game/` → expect empty |
| App builds with correct App ID | COMP-04 | Requires a full Android build toolchain | `flutter build apk --debug` succeeds; manifest package = `com.otis.brooke.state.the.state` |
| Fully offline / assets bundled | SESS-05 | Network-absence is an integration property | `flutter build apk` succeeds; no `http`/network package in `pubspec.lock` |
| AK/HI inset visual placement (no antimeridian smear) | DATA-02 | Visual correctness; pipeline emits a standalone PNG for eyeball check | Inspect pipeline PNG output — AK bottom-left, HI bottom-center, no horizontal smear |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
