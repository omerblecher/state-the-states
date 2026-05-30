# State States

## What This Is

A cross-platform (Flutter), fully-offline, COPPA / Google Play Families-compliant educational mobile game for a general audience including children aged 8+. Players learn U.S. geography by dragging state tokens onto an interactive vector map of the United States (mainland plus Alaska and Hawaii inset projections). It is the spiritual successor to *Flags Around the World* and deliberately baselines that project's directory architecture, Riverpod state-management patterns, CustomPainter map engine, and UI polish.

## Core Value

A child can drag a state onto its correct place on the U.S. map and immediately feel they got it right — the interactive map placement loop must be smooth, forgiving, and rewarding above everything else.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- v1 milestone: the playable core. All are hypotheses until shipped and validated. -->

**Welcome & Audio**
- [ ] Premium patriotic opening screen featuring a stylized vector silhouette of the USA (no spinning globe).
- [ ] Programmatic playback of a self-rendered, rights-clean "Star-Spangled Banner" instrumental on launch, with a seamless fade-out on transition into the menus.
- [ ] Audio service with safe load / lifecycle / termination controls (baselined from the Flags `just_audio` service).

**Map Canvas & Interaction**
- [ ] Vector USA map rendering mainland states plus dedicated inset frame projections for Alaska and Hawaii.
- [ ] High-performance `InteractiveViewer` pan-and-zoom replicating the Flags setup (tray outside, DragTargets inside, `TransformationController.toScene()` for drop coordinates).
- [ ] Invisible 48dp radial proximity-snapping hit-box around the calculated centroid of micro-states (e.g., Rhode Island, Delaware) to prevent finger-target frustration.

**Game Modes 1–4 (map drag-and-drop)**
- [ ] **Learn:** state abbreviations visible on the map; full state name shown beneath the token tray; font scales with the canvas matrix transform.
- [ ] **States Master:** full state name shown only beneath the tray; map entirely blank (no labels/abbreviations).
- [ ] **Geographical Master:** abbreviations rendered on the map, scaling with zoom thresholds; tray tokens show no text clues.
- [ ] **Grand Master:** total blackout — no names in the tray, no labels on the map.

**Scoring & Local Records**
- [ ] Golf-style scoring (lowest wins): +1 point per 10 seconds elapsed; +5 points for placing a token on an incorrect state path.
- [ ] Best scores/times for each mode stored locally via `SharedPreferences` (offline, no accounts).

### Out of Scope

<!-- Explicit boundaries, with reasoning. -->

- **Mode 5 — Speed Typing Challenge** — deferred to v2. Independent of the map engine; lands as its own text-driven phase. (Full production widget code is a v2 execute-phase deliverable.)
- **Gated social sharing** (math parental gate + watermarked screenshot via `share_plus`) — deferred to v2.
- **Full AdMob + mediation monetization** (Banner / Interstitial / Rewarded / App Open with Unity, AppLovin, etc.) — deferred to v2; ad layer is stubbed as a walled garden in v1.
- **Washington D.C. as a placeable/typeable entity** — excluded. Canonical entity set is the **50 states**; matches the "all 50 states" end condition. Micro-state snapping still applies to small states (RI, DE).
- **Firebase (Analytics / Crashlytics) — ever** — collects persistent device identifiers; COPPA-prohibited for this app. Use Android Vitals.
- **Online accounts, cloud sync, leaderboards** — app is fully offline by design.

## Context

- **Reference codebase:** `C:\code\Claude\FlagsRoundTheWorld` (GitHub: `omerblecher/flags-round-the-world`). Architecture, repositories, services, and CustomPainters are to be adapted directly — this is a hard requirement, not a suggestion.
- **Reference architecture (feature-first):** `lib/core/{ads,audio,data,models,l10n}` + `lib/features/{home,game,map,ads}`. Stubs/real split for `ads` and `audio` services. Repositories: `high_score_repository`, `user_prefs_repository`, `game_state_repository`.
- **Reference stack:** Riverpod 3.x + codegen (`riverpod_annotation`/`riverpod_generator`/`build_runner`), `go_router`, `flutter_svg` + `path_drawing`, `shared_preferences`, `just_audio`, `google_mobile_ads` ^8.x with Unity/ironSource/InMobi/AppLovin mediation, `share_plus`, `intl` + `flutter gen-l10n`.
- **Map data approach (locked in Flags, carried over):** pre-processed JSON, NOT runtime SVG parsing. Pipeline: source vector (Natural Earth admin-1 US states) → Python build-time script → bundled `usa_states_paths.json` containing `dart:ui` Path data, centroids, and Alaska/Hawaii inset transforms.
- **Highest technical risk (carried over from Flags):** drag-drop hit detection under `InteractiveViewer` zoom. A coordinate-transform spike should gate the full drag system before it is built out.
- **Audience:** general audience including children 8+. COPPA and Google Play Families Policy compliance is a first-class constraint throughout, not a final-phase add-on.

## Constraints

- **Compliance**: COPPA + Google Play Families Policy — no persistent identifiers, no Firebase, child-directed ad config (`tagForChildDirectedTreatment(true)` on AdMob **and** every mediation SDK), `AD_ID` permission blocked, max content rating G/PG. Outbound device intents (sharing) gated behind an adult-verification math challenge.
- **Tech stack**: Flutter/Dart; baseline directly from *Flags Around the World* (Riverpod + codegen, go_router, CustomPainter + InteractiveViewer map, `just_audio`, `shared_preferences`). Standardize audio on `just_audio` (the spec's `audioplayers` mention is superseded for one-stack consistency).
- **Platforms**: Android first (Google Play Store launch), iOS App Store as a first-class future build target.
- **Offline**: fully offline — no network dependency for core gameplay; all data and assets bundled.
- **Audio rights**: anthem must be a genuinely rights-clean asset (self-rendered from the public-domain composition); a public-domain *composition* does not make an arbitrary *recording* free to ship.
- **App ID**: `com.otis.brooke.state.the.state`.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Baseline architecture/patterns from *Flags Around the World* | Proven, COPPA-audited Flutter codebase with the same genre mechanics; reduces risk and rework | — Pending |
| v1 = playable core (welcome + map + Modes 1–4 + scoring + local records) | Get a real, complete game in hand fastest; defer independent/heavier features | — Pending |
| Mode 5, gated sharing, full AdMob → v2 | Each is separable from the core map loop; keeps v1 focused and shippable | — Pending |
| Canonical entity set = 50 states (no D.C.) | Matches "all 50 states" end condition; simplest data model; micro-state snapping unaffected | — Pending |
| Anthem self-rendered from public-domain score | Clean rights for a Families app; recordings of PD compositions are not automatically free | — Pending |
| Standardize audio on `just_audio` (not `audioplayers`) | One audio stack, reuse Flags' service patterns directly | — Pending |
| Map data = pre-processed bundled JSON (not runtime SVG) | Locked decision inherited from Flags; performance + offline | — Pending |
| Suggested repo name: `state-the-states` | Mirrors Flags' `flags-round-the-world` naming; clean, kebab-case, matches app name | — Pending |
| No Firebase | Persistent identifiers are COPPA-prohibited; use Android Vitals | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-30 after initialization*
