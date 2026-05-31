# Phase 3: Map Render + Coordinate Transform Spike - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-31
**Phase:** 03-map-render-coordinate-transform-spike
**Areas discussed:** State map color design, Spike vs. production screen structure, Zoom range and feel, Painter viewScale architecture

---

## State Map Color Design

### Q1: How should the 50 states be colored?

| Option | Description | Selected |
|--------|-------------|----------|
| Cycling palette (6 colors, port from Flags) | palette[i % 6] by list index — simple, colorful, direct port | ✓ |
| Political 4-color scheme | Proper no-adjacent-same-color; requires graph coloring step in pipeline | |
| Patriotic palette (reds/whites/blues) | Thematically resonant US flag hues | |

**User's choice:** Cycling palette (6 colors, port from Flags)

---

### Q2: What should a correctly-placed state look like?

| Option | Description | Selected |
|--------|-------------|----------|
| Grey fill, matching Flags | matchedPostals → #AAAAAA; zero new design work | ✓ |
| Keep original color + checkmark overlay | State stays its palette color, small checkmark at centroid | |
| Green fill | Universally "correct/done" signal | |

**User's choice:** Grey fill, matching Flags

---

### Q3: What color should D.C. use?

| Option | Description | Selected |
|--------|-------------|----------|
| Same palette color as adjacent states | Treated as normal polygon; simplest | ✓ |
| Light grey (visually distinct, always) | Always renders neutral grey | |
| You decide | Minor visual detail, let planner pick | |

**User's choice:** Same palette color as adjacent states

---

### Q4: Should inset frames be visually marked?

| Option | Description | Selected |
|--------|-------------|----------|
| Thin border rectangle around each inset group | Classic US atlas convention; mandated by Criterion 3 | ✓ |
| No border, just the state fills | Ocean-blue background defines inset boundaries | |
| You decide | Roadmap mandates rectangle so this was the obvious choice | |

**User's choice:** Thin border rectangle (mandated by Criterion 3)

---

## Spike vs. Production Screen Structure

### Q1: How should SpikeMapScreen and MapScreen relate?

| Option | Description | Selected |
|--------|-------------|----------|
| Two separate screens; spike removed after tests pass | Dev-only spike, production MapScreen; clean separation | ✓ |
| Single screen — MapScreen starts as spike, evolves | Avoids throwaway file; risk of tangled test harness | |
| You decide | Let planner pick structure | |

**User's choice:** Two separate screens; spike removed after tests pass

---

### Q2: What state geometry for the spike DragTarget regions?

| Option | Description | Selected |
|--------|-------------|----------|
| Real state bounding boxes from the JSON | Tests real map geometry immediately | ✓ |
| Abstract regions + simulated inset rects | Simpler; Flags approach with fake geometry | |
| You decide | Let planner pick | |

**User's choice:** Real state bounding boxes from the JSON

---

### Q3: What does "golden test" mean for Criterion 2?

| Option | Description | Selected |
|--------|-------------|----------|
| Unit tests of stateHitTest() with known centroid inputs | Parametric assertions, hermetic, fast CI | ✓ |
| Flutter golden (screenshot comparison) tests | Image comparison; brittle, requires --update-goldens | |
| Widget tests with programmatic DragTarget drops | Integration-style, runs in test harness | |

**User's choice:** Unit tests of stateHitTest() with known centroid inputs

---

### Q4: What parameters does MapScreen expose for Phase 4?

| Option | Description | Selected |
|--------|-------------|----------|
| MapScreen(matchedPostals, showLabels, mode) | Clean interface; Phase 4 passes live session state | ✓ |
| Pure display widget; Phase 4 wraps it | Two separate widgets; MapScreen never changes after Phase 3 | |
| You decide | Let planner determine cleanest handoff | |

**User's choice:** MapScreen(matchedPostals: Set<String>, showLabels: bool, mode: GameMode?)

---

## Zoom Range and Feel

### Q1: Minimum zoom level?

| Option | Description | Selected |
|--------|-------------|----------|
| Fit-to-width (computed, ~0.8–1.0×) | Map fills viewport at min zoom; clean UX | ✓ |
| Fixed 0.5× | Can zoom out to half scene size | |
| Fixed 1.0× | Map is larger than viewport at min zoom on phones | |

**User's choice:** Fit-to-width (computed)

---

### Q2: Maximum zoom level?

| Option | Description | Selected |
|--------|-------------|----------|
| 4× relative to fit-to-width | Matches Criterion 2 test scale; NE states clearly visible | ✓ |
| 8× relative to fit-to-width | More than necessary for state-level geography | |
| You decide | Let planner pick | |

**User's choice:** 4× relative to fit-to-width

---

### Q3: Zoom button step size?

| Option | Description | Selected |
|--------|-------------|----------|
| 1.5× per press (Flags spike default) | Three taps ≈ 3.4×; responsive feel | ✓ |
| 2× per press | Two taps reaches exactly 4×; clean powers-of-two | |
| You decide | Let planner decide for child UX | |

**User's choice:** 1.5× per press

---

### Q4: Pinch-to-zoom enabled?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — pinch zoom enabled | InteractiveViewer default; children expect this | ✓ |
| No — buttons only, pinch disabled | Avoids accidental zoom while dragging token | |
| You decide | Let planner decide for drag-token UX | |

**User's choice:** Yes — pinch zoom enabled

---

## Painter viewScale Architecture

### Q1: How does viewScale get into the painter?

| Option | Description | Selected |
|--------|-------------|----------|
| AnimatedBuilder on TransformationController | Only painter subtree rebuilds; direct Flags port | ✓ |
| onInteractionUpdate callback on InteractiveViewer | Gesture callback; less pure but functional | |
| You decide | Let planner choose lightest approach | |

**User's choice:** AnimatedBuilder on TransformationController

---

### Q2: Border width formula?

| Option | Description | Selected |
|--------|-------------|----------|
| 1–2 screen-pixels always (1.0/viewScale clamped 0.15–1.2) | Flags formula; borders never swamp micro-states | ✓ |
| Fixed 1.0 scene-unit border | Thick at high zoom; swamps RI/DE | |
| You decide | Let planner choose formula | |

**User's choice:** (1.0 / viewScale).clamp(0.15, 1.2) — Flags formula

---

### Q3: Background/border/matched colors?

| Option | Description | Selected |
|--------|-------------|----------|
| Flags defaults: ocean #A8D5E8, borders #555555, matched #AAAAAA | Proven in Flags; light blue ocean, dark borders | ✓ |
| Patriotic: navy #003366, white borders | More dramatic; more design work | |
| You decide | Let UI phase or researcher decide exact hex values | |

**User's choice:** Flags defaults (ocean #A8D5E8, borders #555555, matched #AAAAAA)

---

## Claude's Discretion

- `shouldRepaint` logic for `UsaMapPainter` — minimal field comparison set
- Exact inset frame rect geometry (tight bbox + padding constant)
- Routing/registration of `SpikeMapScreen` (debug route or `--dart-define`)
- Exact `stateHitTest()` function signature

## Deferred Ideas

- Label rendering (on-map abbreviations + viewScale font scaling) — Phase 4
  concern (MODE-01, MODE-03). `showLabels` param declared in Phase 3 but draws
  nothing until Phase 4 adds the label pass.
