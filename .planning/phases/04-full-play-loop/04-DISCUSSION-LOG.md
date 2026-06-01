# Phase 4: Full Play Loop - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-01
**Phase:** 4-Full Play Loop
**Areas discussed:** State token design, Tray structure, Correct drop animation, Home screen layout

---

## State token design

### Token shape/form

| Option | Description | Selected |
|--------|-------------|----------|
| Styled card (port Flags' card shape, text instead of flag) | Same rounded card widget from Flags, ~90×100dp. Proven pattern. | ✓ |
| State outline silhouette | Mini filled polygon of the state shape on the card. Visually distinctive but adds complexity with no Flags baseline. | |
| Abbreviation chip / badge | Compact circular or rounded-rect chip. Small footprint. | |

**User's choice:** Styled card — port Flags' FlagTray card widget with text replacing the flag image.

### Grand Master token face

| Option | Description | Selected |
|--------|-------------|----------|
| Solid color card (palette color, no decoration) | Card fills with one of the 6 map palette colors. No text, no embossed shape. | ✓ |
| State outline embossed / subtle | State border drawn faintly as a low-opacity texture — technically a hint. | |
| You decide | Plain card with question mark or star icon. | |

**User's choice:** Solid color, no decoration. Player gets no geographic cue.

### Learn mode token content layout

| Option | Description | Selected |
|--------|-------------|----------|
| Abbreviation large on card face + name below the card | Two-layer info: content on card, label beneath. Mirrors Flags pattern. | ✓ |
| Name only — large on card face, nothing below | Single text element. Simpler. Map already shows abbreviations. | |
| You decide | Researcher/planner chooses text layout. | |

**User's choice:** Abbreviation on face + full state name below.

---

## Tray structure

### Number of tokens visible

| Option | Description | Selected |
|--------|-------------|----------|
| One at a time, random order (Flags pattern) | Single token. New one after each correct placement. Randomized at game start. | ✓ |
| Scrollable deck of all remaining states | Player picks which state to drag next. More complex, no Flags baseline. | |
| 3–5 tokens visible | Small rotating hand. Middle ground, still new tray design. | |

**User's choice:** One at a time, Flags pattern.

### Tray position

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom strip, full width (Flags pattern) | ~120dp at bottom. HUD top, map middle, tray bottom. Proven layout. | ✓ |
| Floating overlay over the map | More map visible. Risks covering content. | |
| Side panel | Only works in landscape. Awkward portrait. | |

**User's choice:** Bottom strip, full width.

### Progress counter placement

| Option | Description | Selected |
|--------|-------------|----------|
| HUD only (SCORE-04 covers it in the top bar) | Tray stays clean: token + hint button only. No duplication. | ✓ |
| Both HUD and tray counter | Shows '38 left' in tray too. Convenient, slight visual noise. | |

**User's choice:** HUD only.

---

## Correct drop animation / game screen architecture

### Fly-to-centroid animation approach

| Option | Description | Selected |
|--------|-------------|----------|
| Port Flags' OverlayEntry fly animation exactly | OverlayEntry TweenAnimationBuilder from tray to centroid screen position, then fade. State fills grey. | ✓ |
| In-place state highlight (no fly) | State polygon pulses/glows. Simpler. No overlay widget needed. | |
| You decide | Lightest approach that satisfies DRAG-02. | |

**User's choice:** Port Flags' overlay fly animation exactly.

### Incorrect drop snackbar duration

| Option | Description | Selected |
|--------|-------------|----------|
| Short (1.5–2s) — child-friendly, doesn't block the map | Kids want to try again immediately. | ✓ |
| Standard (3–4s) — Flutter default SnackBar duration | More readable, may feel slow. | |
| You decide | Sensible default. | |

**User's choice:** Short (1.5–2s).

### Game screen architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Extend MapScreen into the full game screen (Flags pattern) | MapScreen gains DragTargets, tray, HUD, pause overlay — all in one ConsumerStatefulWidget. | ✓ |
| New GameScreen wraps MapScreen as a child | Cleaner separation but more interface seams to manage. | |

**User's choice:** Extend MapScreen — direct port of the Flags monolith approach.

---

## Home screen layout

### Card arrangement

| Option | Description | Selected |
|--------|-------------|----------|
| Vertical list (Flags pattern) | 4 cards in a ListView. Full-width, scrollable. Works on all sizes. | ✓ |
| 2×2 grid | GridView. Compact on large screens, narrow on phones. No Flags baseline. | |
| You decide | Best fit for 4-mode set. | |

**User's choice:** Vertical list.

### Mode card content

| Option | Description | Selected |
|--------|-------------|----------|
| Mode name + one-line description + star rating + best score | Full context at a glance. | ✓ |
| Mode name + star rating + best score (no description) | Compact. Players learn by playing. | |
| You decide | Content hierarchy. | |

**User's choice:** Name + description + stars + score.

### Mode launch flow

| Option | Description | Selected |
|--------|-------------|----------|
| Tap card → navigate directly to game screen (Flags pattern) | 5-second countdown orients the player. Clean, no friction. | ✓ |
| Tap card → mode detail screen → play button | Extra screen explains rules. More friction. | |
| You decide | Navigation flow. | |

**User's choice:** Direct navigation, Flags pattern.

---

## Claude's Discretion

- Exact palette color assignment for Grand Master token (cycling by shuffle index, fixed per state, or random-per-session).
- `DragTarget` strategy: one large target over the InteractiveViewer child (dispatch via `stateHitTest`) vs. one per state polygon.
- Pause overlay design — port from Flags.
- Countdown animation (3-2-1-GO overlay) — port from Flags.
- `AnimatedSwitcher` transition for new tray token (fade, slide, or scale).
- `shouldRepaint` comparison fields for `UsaMapPainter` as `matchedPostals` grows.

## Deferred Ideas

- "Continue game" dialog (HOME-03) — Phase 5.
- Hint UI zoom-to-centroid / glow animation (HINT-01/02) — Phase 5 (hooks exist in Phase 2).
- Welcome screen + anthem (WEL-01/02/03) — Phase 5.
- A11y audit (A11Y-01/02) — Phase 5; but Phase 4 should add `Semantics` labels as it builds controls.
- AdMob completion interstitial — v2 only.
