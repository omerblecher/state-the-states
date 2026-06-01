# Phase 5: Polish, Welcome & Accessibility - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-01
**Phase:** 05-polish-welcome-accessibility
**Areas discussed:** Welcome screen visual, Anthem asset + fade, Tutorial format & content, Hint zoom + session restore UX

---

## Welcome Screen Visual

| Option | Description | Selected |
|--------|-------------|----------|
| USA silhouette CustomPainter (static) | Draw continental USA as a filled shape from usa_states_paths.json — static or fade-in entrance | |
| Animated fill-in | States fill in one by one with AnimationController | ✓ |
| Stars + USA icon composite | Material Icons + simplified USA shape | |

**User's choice:** Animated fill-in

| Stagger order | Description | Selected |
|--------|-------------|----------|
| Random order, fast stagger | ~10–30ms per state, organic feel, total ~1–2s | ✓ |
| West-to-east sweep | Fill in Pacific → Atlantic; needs centroid X ordering | |
| Simultaneous fade-in | All states fade in together | |

**User's choice:** Random order, fast stagger

| Color scheme | Description | Selected |
|--------|-------------|----------|
| Solid white on deep blue gradient | Matches Flags' gradient; clean/patriotic | ✓ |
| Red, white & blue alternating state colors | Vibrant for kids; complex color assignment | |
| You decide | Leave to planner | |

**User's choice:** Solid white on deep blue gradient

| AK/HI inclusion | Description | Selected |
|--------|-------------|----------|
| Yes — same inset layout as game map | Reuses existing path/transform data | ✓ |
| Mainland only | Classic 48-state silhouette; simpler composition | |
| You decide | Either is fine aesthetically | |

**User's choice:** Yes — same inset layout as game map

---

## Anthem Asset + Fade

| Anthem readiness | Description | Selected |
|--------|-------------|----------|
| Not ready — needs rendering in Phase 5 | FluidSynth + SF2 or equivalent; placeholder removed | ✓ |
| Already available — just drop it in | File exists on disk; just copy to assets/audio/ | |

**User's choice:** Needs rendering in Phase 5

| Fade style | Description | Selected |
|--------|-------------|----------|
| Volume tween fade (~800ms ramp) | setVolume() ramp to 0, then stop() — "seamless" | ✓ |
| Immediate stop | AudioPlayer.stop() only | |

**User's choice:** Volume tween fade (~800ms ramp)

| Auto-play vs tap-to-play | Description | Selected |
|--------|-------------|----------|
| Auto-play on load with 500ms fade-in | Starts at vol 0, ramps to full — matches roadmap criterion | ✓ |
| Play on first tap only | Gesture gate; relevant for iOS | |

**User's choice:** Auto-play on load with 500ms fade-in

---

## Tutorial Format & Content

| Format | Description | Selected |
|--------|-------------|----------|
| Full-screen onboarding PageView | 4 swipeable slides; skip button; simple to implement | ✓ |
| Overlay coach marks | Spotlight cutouts over real UI; contextual but complex | |
| Bottom-sheet step guide | Persistent sheet; least common for kids' games | |

**User's choice:** Full-screen onboarding PageView

| Content | Description | Selected |
|--------|-------------|----------|
| Welcome → Drag & Drop → Scoring → Hints | Covers all player needs; standard 4-step arc | ✓ |
| Drag & Drop → Modes → Scoring → Hints | Skips intro; starts with mechanics | |
| You decide | Rough themes: mechanics, scoring, hints, modes | |

**User's choice:** Welcome → Drag & Drop → Scoring → Hints

| Navigation flow | Description | Selected |
|--------|-------------|----------|
| After welcome screen, before home (Recommended) | Welcome → Tutorial → Home; second launch skips | ✓ |
| In place of welcome on first launch | Tutorial is the first screen; welcome always shows | |

**User's choice:** After welcome screen, before home screen

---

## Hint Zoom + Session Restore UX

| Hint zoom approach | Description | Selected |
|--------|-------------|----------|
| AnimationController tween on TransformationController matrix | Matrix4Tween from current to target; established pattern | ✓ |
| TransformationController.animateTo() | Built-in if available in Flutter 3.44 | |

**User's choice:** AnimationController tween on TransformationController matrix

| Post-glow behavior | Description | Selected |
|--------|-------------|----------|
| Stay zoomed in | Player is now close to target; can drop precisely | ✓ |
| Animate back to previous zoom/pan | Clean but may frustrate the player | |

**User's choice:** Stay zoomed in

| Glow color | Description | Selected |
|--------|-------------|----------|
| Port Flags' 0xFFBBFF44 yellow-green | Already designed and tested in Flags codebase | ✓ |
| Patriotic gold / amber (0xFFFFD700) | On-brand for State States; different from Flags | |
| You decide | Any high-contrast color works | |

**User's choice:** Port Flags' 0xFFBBFF44 yellow-green

| Session restore UX | Description | Selected |
|--------|-------------|----------|
| Prominent card at top of home screen | Non-blocking; shows mode, score, elapsed, states placed | ✓ |
| Modal AlertDialog | Blocking; matches Flags pattern for similar prompts | |
| You decide | Key req: show mode, score, elapsed, states placed | |

**User's choice:** Prominent card at top of home screen

| Card dismiss behavior | Description | Selected |
|--------|-------------|----------|
| Auto-dismiss when new game starts | Clean state; reads from GameStateRepository each build | ✓ |
| Persists until explicitly dismissed (X button) | More explicit; adds in-memory dismissed flag | |

**User's choice:** Auto-dismiss when new game starts

---

## Claude's Discretion

- Exact timing curve for hint zoom `AnimationController` (e.g., `Curves.easeInOut`).
- `AnimatedSwitcher`/`AnimatedContainer` transition style for tutorial `PageView`.
- Welcome screen title text, subtitle copy, and CTA button label.
- Tutorial slide illustration/icon choices.
- Exact stagger timing distribution (uniform random vs. weighted).
- `shouldRepaint` logic for the welcome screen `CustomPainter`.
- Whether `fadeOutAnthem()` is a new `AudioService` method or replaces `stopAnthem()`.

## Deferred Ideas

- AdMob + mediation — v2 scope only.
- Rewarded-ad hint refill — v2 scope.
- Gated social sharing — v2 scope.
- Mode 5 Speed Typing — v2 scope.
