---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: milestone
status: executing
stopped_at: Completed 08-02-PLAN.md
last_updated: "2026-06-03T15:55:52.513Z"
last_activity: 2026-06-03
progress:
  total_phases: 8
  completed_phases: 6
  total_plans: 38
  completed_plans: 36
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-02)

**Core value:** A child can drag a state onto its correct place on the U.S. map and immediately feel they got it right — the interactive map placement loop must be smooth, forgiving, and rewarding above everything else.
**Current focus:** Phase 08 — full-admob-layer

## Current Position

Phase: 08 (full-admob-layer) — EXECUTING
Plan: 5 of 6
Status: Ready to execute
Last activity: 2026-06-11 - Completed quick task 260611-tql: Fix session restore bug in MapScreen

Progress: [██████████] 95%

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
| Phase 06-speed-typing-mode P00 | 2min | - tasks | - files |
| Phase 06-speed-typing-mode P01 | 5min | 2 tasks | 7 files |
| Phase 06-speed-typing-mode P02 | 8min | 2 tasks | 2 files |
| Phase 06-speed-typing-mode P03 | 10min | 2 tasks | 4 files |
| Phase 07-gated-sharing-completion P01 | 15min | 1 tasks | 1 files |
| Phase 07-gated-sharing-completion P02 | 16min | 2 tasks | 1 files |
| Phase 08-full-admob-layer P01 | 15min | 3 tasks | 5 files |
| Phase 08-full-admob-layer P02 | 9min | 2 tasks | 4 files |
| Phase 08-full-admob-layer P03 | 4min | 1 tasks | 1 files |
| Phase 08-full-admob-layer P04 | 18min | 2 tasks | 6 files |

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
- Roadmap v2: Mode 5 wrong-submission penalty = +5 (matches golf scoring contract across all modes; RESOLVED)
- Roadmap v2: AppLovin permanently disabled (kAppLovinEnabled = false) — AppLovin SDK 13.0+ refuses child-directed init
- Roadmap v2: Rewarded hint refill must call refillHints() inside onUserEarnedReward only — never onAdDismissedFullScreenContent
- Roadmap v2: path_provider ^2.1.5 added in Phase 7 for screenshot-to-XFile pipeline (temp file write)
- Roadmap v2: GameSessionNotifier walled-garden rule preserved throughout Phase 8 — zero ad imports
- [Phase ?]: 06-00: Wave 0 stub test imports flutter_test only — speed_typing_screen.dart does not exist in Wave 0; import deferred to Wave 2 via TODO comment
- [Phase ?]: 06-00: stateFixture() uses pathStrings/paths as empty const lists — avoids parseSvgPathData() for unit tests that only need postal/name/isPlaceable/insetGroup
- [Phase ?]: 06-01-SUMMARY.md
- [Phase ?]: 06-03
- [Phase ?]: 07-01: Dialog tests open via Share result tap; _MathChallengeDialog private class not accessible from test library
- [Phase ?]: 07-01: ensureVisible() required before tapping Share result — button is below 600px test viewport in scrollable body
- [Phase ?]: 07-01: Test 3 RED because multiplication RegExp (U+00D7) does not match current addition question format
- [Phase ?]: 07-02: _isSharing moved after toImage to prevent pumpAndSettle timeout from CircularProgressIndicator infinite animation
- [Phase ?]: 07-02: MathChallengeDialog renamed public with @visibleForTesting; _a/_b changed from late final to late int for operand regeneration
- [Phase ?]: Ref is sealed in Riverpod 3.x — use ProviderContainer + overrideWith for RealAdService tests (not mocktail mock)
- [Phase ?]: 08-02: unnecessary_underscores lint: onUserEarnedReward (_, __) must name second param

### Pending Todos

None yet.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260603-9px | Refactor SpeedTypingScreen: rename to Name all the states, add TypingResult enum, fix keyboard layout, add progress bar, chip animations, distinct error SnackBars | 2026-06-03 | 0966cb2 | [260603-9px-refactor-speedtypingscreen-rename-to-nam](.planning/quick/260603-9px-refactor-speedtypingscreen-rename-to-nam/) |
| 260611-tql | Fix session restore bug in MapScreen: _startSequence ignores the restored session's matchedPostals | 2026-06-11 | fb44655 | [260611-tql-fix-session-restore-bug-in-mapscreen-sta](.planning/quick/260611-tql-fix-session-restore-bug-in-mapscreen-sta/) |

### Blockers/Concerns

- **Phase 5 (MEDIUM):** 05-07-PLAN.md accessibility audit still pending — Phase 6 can begin in parallel but v1 is not fully complete until 05-07 ships.
- **Phase 8 (HIGH):** Production ad unit IDs required — app must be registered in AdMob console with app ID com.otis.brooke.state.the.state before Phase 8 validation.
- **Phase 8 (MEDIUM):** Mediation SDK COPPA method signatures rated MEDIUM confidence — confirm GmaMediationUnity.setGDPRConsent / GmaMediationIronsource().setDoNotSell signatures from installed package source after flutter pub get.
- **Phase 8 (MEDIUM):** AD_ID manifest merge risk — inspect build/intermediates/merged_manifests after each mediation adapter AAR is added.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v2 | Full AdMob + mediation (Phase 8) | Active — Phase 8 | Roadmap v2 creation |
| v2 | Mode 5 — Speed Typing Challenge | Active — Phase 6 | Roadmap v2 creation |
| v2 | Gated social sharing (parental math gate + share_plus) | Active — Phase 7 | Roadmap v2 creation |
| v2 | Rewarded-ad hint refill | Active — Phase 8 | Roadmap v2 creation |

## Session Continuity

Last session: 2026-06-03T15:55:52.502Z
Stopped at: Completed 08-02-PLAN.md
Resume file: None
