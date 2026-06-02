# Phase 6: Speed Typing Mode - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-02
**Phase:** 06-speed-typing-mode
**Areas discussed:** Input Matching Rules, Screen Layout, CompletionScreen Compatibility

---

## Input Matching Rules

### Q1: What inputs count as valid beyond exact name + postal code?

| Option | Description | Selected |
|--------|-------------|----------|
| Exact name + postal code only | "GEORGIA" and "GA" match. "MASS" does not. Clean, unambiguous. | ✓ |
| Name + postal + common abbreviations | Also accept well-known short forms like "MASS", "PENN", "MINN". More forgiving. | |
| You decide | Claude picks simplest implementation satisfying TYPING-04. | |

**User's choice:** Exact name + postal code only.

### Q2: How should multi-word state names work?

| Option | Description | Selected |
|--------|-------------|----------|
| Space required — "NEW YORK" matches, "NEWYORK" does not | Compare trimmed uppercase input against state's uppercase full name. | ✓ |
| Space optional — "NEWYORK" also matches "NEW YORK" | Strip all spaces before comparing. More forgiving but potential collisions. | |
| You decide | Claude picks simpler implementation. | |

**User's choice:** Space required.

### Q3: Does the field clear on a wrong submission?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — clear on every Enter press (hit or miss) | Consistent UX. REQUIREMENTS imply clear on both outcomes. | ✓ |
| No — only clear on correct match | Player sees wrong input, can backspace-correct. Lower friction for typos. | |
| You decide | Claude picks most natural typing-game behavior. | |

**User's choice:** Clear on every Enter press.

---

## Screen Layout

### Q1: Where does the text field sit?

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom-anchored above keyboard | Input docks at bottom above keyboard. Grid fills space above. Natural for mobile typing. | ✓ |
| Top of screen, grid below | Score/timer HUD → input field → grid. Traditional form layout. | |
| You decide | Claude picks most natural layout. | |

**User's choice:** Bottom-anchored above keyboard.

### Q2: How are found states displayed?

| Option | Description | Selected |
|--------|-------------|----------|
| Chips in a scrollable Wrap | Green chips fill in left-to-right. Visually satisfying. Scrolls on overflow. | ✓ |
| Scrollable ListView of rows | Each state is a row (name + checkmark). Easier to read but less dynamic. | |
| Grid of 50 fixed-size tiles | Empty outlines + green fills. Built-in progress bar. | |

**User's choice:** Chips in a scrollable Wrap.

### Q3: What text appears on found chips?

| Option | Description | Selected |
|--------|-------------|----------|
| Full state name | "CALIFORNIA", "NEW YORK". Reinforces learning. Wider chips. | ✓ |
| Postal code only (compact) | "CA". Very compact — 50 chips fit easily. Loses educational reinforcement. | |
| Both: name + code | "California (CA)". Most informative but widest chips. | |

**User's choice:** Full state name.

---

## CompletionScreen Compatibility

### Q1: How to handle mode color + Play Again routing for speedTyping?

| Option | Description | Selected |
|--------|-------------|----------|
| Add speedTyping to _modeColor() + fix Play Again route | Add teal case; update Play Again to route to /type when mode == speedTyping. | ✓ |
| Pass playAgain callback from navigating screen | Mode-agnostic CompletionScreen. More flexible but adds param to all call sites. | |
| You decide | Claude picks cleaner approach. | |

**User's choice:** Add to switch + fix route.

### Q2: What color for Speed Typing mode?

| Option | Description | Selected |
|--------|-------------|----------|
| Teal / dark cyan — 0xFF00695C | Strong contrast vs. existing 4 mode colors. Distinct and modern. | ✓ |
| Amber / gold — 0xFFF57F17 | Energetic, stands out. "Speed challenge" feel. | |
| You decide | Claude picks color that fits palette. | |

**User's choice:** Teal 0xFF00695C.

### Q3: How to handle mode display names (mode.name = "speedTyping" is ugly)?

| Option | Description | Selected |
|--------|-------------|----------|
| Add displayName extension on GameMode | Single extension used by all screens. One place to update. | ✓ |
| Hardcode in each widget separately | Less code now, 3+ places to update per new mode. | |
| You decide | Claude picks cleaner approach. | |

**User's choice:** displayName extension on GameMode.

---

## Claude's Discretion

- **Session state architecture:** Extend `GameSessionNotifier` (add `speedTyping` to `GameMode` enum, add `submitTyping(String)` action). User did not select this gray area for discussion — Claude resolves it by reusing existing infrastructure.
- **Route name:** `/type` for `SpeedTypingScreen`.
- **HUD layout on SpeedTypingScreen:** Score + elapsed + states-found counter at top.
- **HighScoreRepository key:** `'high_score_speed_typing'`.
- **Mode 5 card icon:** `Icons.keyboard` or `Icons.abc`.

## Deferred Ideas

- Hint system for Speed Typing mode (no map, so zoom-to-centroid doesn't apply; future phase if desired).
- Alphabetical sort for found chips.
- Additional stats on the Mode 5 home card beyond best score.
