# Phase 8: Full AdMob Layer - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 8-Full AdMob Layer
**Areas discussed:** Ad unit IDs, Mediation scope, Banner placement, Rewarded hint refill

---

## Ad unit IDs

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — I have real IDs | Production AdMob account with unit IDs ready | ✓ |
| No — use test IDs for now | Use Google published test IDs with swap TODO | |

**User's choice:** Production IDs available — hard-code in `ad_constants.dart`

---

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcode in ad_constants.dart | Direct constants; IDs appear in APK resources anyway | ✓ |
| Environment variable / Dart define | `--dart-define` at build time; overkill for personal project | |

**User's choice:** Hardcode in `ad_constants.dart`

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — replace with real App ID | Update AndroidManifest meta-data to production App ID | ✓ |
| Leave test App ID for now | Keep test App ID until Play Store submission | |

**User's choice:** Replace test App ID in AndroidManifest in phase 8

---

## Mediation scope

| Option | Description | Selected |
|--------|-------------|----------|
| All three in phase 8 | Unity + ironSource + InMobi; COPPA flags + AD_ID verification | ✓ |
| Google-direct first, mediation in phase 9 | Base AdMob only; adds a phase | |

**User's choice:** All three mediation adapters in phase 8

---

| Option | Description | Selected |
|--------|-------------|----------|
| aapt dump badging on release build | Existing Phase 1 COPPA verification pattern | ✓ |
| You decide | Claude picks verification approach | |

**User's choice:** `aapt dump badging app-release.apk`

---

## Banner placement

| Option | Description | Selected |
|--------|-------------|----------|
| HomeScreen only | Bottom of screen; one call site; matches ROADMAP SC #2 | ✓ |
| HomeScreen + CompletionScreen | Second banner on end-of-game screen | |

**User's choice:** HomeScreen only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom of screen | Standard adaptive banner; non-intrusive | ✓ |
| Above mode cards | Unusual; potentially intrusive on kids' app | |

**User's choice:** Bottom of HomeScreen

---

## Rewarded hint refill

| Option | Description | Selected |
|--------|-------------|----------|
| Reset to exactly 2 | `hintsRemaining = 2`; simple; matches starting value | ✓ |
| Add 2 on top (can stack) | `hintsRemaining += 2`; could exceed 2; complicates economy | |

**User's choice:** Reset to exactly 2

---

| Option | Description | Selected |
|--------|-------------|----------|
| Show 'No ad available' message | Snackbar: "No ad available right now — try again later." | ✓ |
| Silent failure | Hint button stays disabled; no feedback | |
| You decide | Claude picks based on existing UX patterns | |

**User's choice:** Snackbar with "No ad available" message

---

| Option | Description | Selected |
|--------|-------------|----------|
| Only when hintsRemaining == 0 | Rare, meaningful prompt; player uses hints fully first | ✓ |
| Whenever player taps hint | More ad ops; interrupts natural hint-use flow | |

**User's choice:** Trigger rewarded prompt only when `hintsRemaining == 0`

---

## Claude's Discretion

- `RealAdService` architecture (single class, internal per-type fields, preload-on-completion)
- App Open suppression via `WidgetsBindingObserver` in `app.dart` + `gameSessionProvider` phase check
- Rewarded hint dialog implementation (`showDialog` with "Watch Ad" / "Cancel")
- `adServiceProvider` switch point (only file that changes to activate real ads)

## Deferred Ideas

None — discussion stayed within phase scope.
