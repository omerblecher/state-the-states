---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Monetization & Speed Mode
status: planning
last_updated: "2026-06-02T00:00:00.000Z"
last_activity: 2026-06-02
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-30)

**Core value:** A child can drag a state onto its correct place on the U.S. map and immediately feel they got it right — the interactive map placement loop must be smooth, forgiving, and rewarding above everything else.
**Current focus:** v2.0 — Monetization & Speed Mode

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-06-02 — Milestone v2.0 started

Progress: [          ] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 8
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 4 | - | - |
| 03 | 2/5 | ~35min | ~17min |

**Recent Trend:**

- Last 5 plans: none yet
- Trend: —

*Updated after each plan completion*
| Phase 03 P03 | 5min | 1 tasks | 1 files |
| Phase 03 P04 | 25min | 2 tasks | 2 files |
| Phase 03 P05 | 15min | 2 tasks | 3 files |
| Phase 04 P01 | 15min | 2 tasks | 6 files |
| Phase 04 P02 | 25min | 2 tasks | 2 files |
| Phase 04 P03 | 3min | 2 tasks | 2 files |
| Phase 04 P04 | 7min | 2 tasks | 4 files |
| Phase 04 P05 | 3min | 2 tasks | 2 files |
| Phase 04 P06 | 2 | 2 tasks | 2 files |
| Phase 05-polish-welcome-accessibility P02 | 3min | 2 tasks | 4 files |
| Phase 05-polish-welcome-accessibility P03 | 15min | 2 tasks | 5 files |
| Phase 05-polish-welcome-accessibility P05 | 10min | 2 tasks | 3 files |
| Phase 05-polish-welcome-accessibility P04 | 7min | 1 tasks | 2 files |
| Phase 05-polish-welcome-accessibility P06 | 3min | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Python pipeline (DATA-01/02) gates all rendering work — Phase 1 must complete before Phase 3 begins.
- Roadmap: Coordinate-transform spike in Phase 3 is a hard gate — Phase 4 must not begin until spike passes at 1×/2×/4× zoom including AK/HI inset regions.
- Roadmap: COPPA baseline (COMP-01/02/03/04) placed in Phase 1 — AD_ID blocked and StubAdService wired from first commit.
- Roadmap: Ad layer (Phase 6 in research) is v2 scope only; v1 stubs it entirely and no mediation SDKs enter pubspec until v2.
- 03-01: Drop max() from hit_detection.dart imports — only used in removed isDegenerate branch
- 03-01: MapData wraps stateDataProvider; insetFrameRects order guaranteed by JSON Map.values insertion order
- 03-02: tester.runAsync() required when testWidgets awaits compute()-backed FutureProvider — FakeAsync blocks isolate completion
- 03-02: findsAtLeastNWidgets(1) for CustomPaint assertions — MaterialApp adds its own CustomPaint to the tree
- 03-02: UsaMapPainter showLabels/mode declared for Phase 4 but draw nothing in Phase 3 — single TODO comment marks extension point
- [Phase ?]: Required for dart:ui Path creation even without widget tests
- [Phase ?]: 03-04-SUMMARY.md
- [Phase ?]: 03-05: if (kDebugMode) GoRoute single-element collection-if (no spread) avoids List<GoRoute> type error in routes list
- [Phase ?]: 03-05: Fixture-backed spike tests need no tester.runAsync() — overrideWith(async => fixture) resolves synchronously unlike compute()-backed provider
- 04-01: MapScreen.mode changed to non-nullable GameMode with default GameMode.learn — preserves const MapScreen() backward-compat (Risk 7)
- 04-01: state_tray_test.dart skip param is bool? in Flutter 3.44/Dart 3.12 — string skip causes compile error; use skip:true
- 04-01: state_tray_test.dart omits state_tray.dart import — Dart compile failure on missing file even with skip:true; import deferred to Plan 03
- 04-02: find.byType(PopScope) finds PopScope<dynamic> not PopScope<Object?> — use find.byWidgetPredicate((w) => w is PopScope) for reliable generic-type matching in widget tests
- 04-02: _startSequence called from _buildMapStack (inside stateDataProvider.when data callback) so it runs after MapData resolves, not from initState
- 04-03: StateTray is a direct port of FlagTray — SvgPicture replaced by mode-driven _cardFace() switch; no other structural changes
- 04-03: triggerBounce() exposed as public on StateTrayState so MapScreen can call _trayKey.currentState?.triggerBounce() on incorrect drop
- 04-04: GameHud uses hardcoded string literals — no l10n dependency in Phase 4
- 04-04: _buildMapStack receives GameSession? as parameter from build() to avoid double ref.watch on same provider
- 04-04: UsaMapPainter predicate cast: use 'is UsaMapPainter' guard before 'as UsaMapPainter' — avoids TypeError from _ShapeBorderPainter in StateTray's button painter
- 04-05: SizedBox.expand replaces Positioned.fill inside Opacity/IgnorePointer — Positioned must be a direct Stack child
- 04-05: geographicalMaster mode color is BF360C not E65100 — UI-SPEC locked value
- 04-05: CompletionScreen widget tests use MaterialApp(home: ...) — no ProviderScope needed (reads only widget fields)
- [Phase ?]: 05-02: playAnthem/stopAnthem renamed to fadeInAnthem/fadeOutAnthem; Timer.periodic 20ms chosen over AnimationController for service-layer fade
- [Phase ?]: TutorialScreen stub uses ConsumerStatefulWidget for forward-compatibility with Plan 04 PageView onboarding
- [Phase ?]: 05-03: staggerOrder initialized lazily in stateDataProvider data callback to avoid crash before MapData resolves
- [Phase ?]: 05-03: fire-and-forget fadeOutAnthem() + Future.delayed 850ms for smooth navigation (RESEARCH.md Pitfall 5)
- [Phase ?]: .planning/phases/05-polish-welcome-accessibility/05-05-SUMMARY.md
- [Phase ?]: 05-04: GoRouter wrapper in widget tests required when testing context.go('/') — use MaterialApp.router(routerConfig: GoRouter(...))
- [Phase ?]: 05-06: SessionRestoreCard StatelessWidget — Riverpod reads in HomeScreen; card receives callbacks

### Pending Todos

None yet.

### Blockers/Concerns

- **Phase 3 (MEDIUM):** Coordinate-transform spike is highest technical risk; do not parallelize Phase 4 until spike passes.
- **Phase 5 (MEDIUM):** FluidSynth + SF2 anthem rendering toolchain not in Flags reference; verify before committing Phase 5 timing.
- **General:** Natural Earth shapefile field names (adm0_a3, postal) are MEDIUM confidence — verify against actual shapefile on first download before writing pipeline filter logic.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v2 | Full AdMob + mediation (Phase 6) | Deferred | Roadmap creation |
| v2 | Mode 5 — Speed Typing Challenge | Deferred | Roadmap creation |
| v2 | Gated social sharing (parental math gate + share_plus) | Deferred | Roadmap creation |
| v2 | Rewarded-ad hint refill | Deferred | Roadmap creation |

## Session Continuity

Last session: 2026-06-01T19:12:58.353Z
Stopped at: context exhaustion at 81% (2026-06-01)
Resume file: None
