---
phase: 08-full-admob-layer
plan: "05"
status: complete
completed: "2026-06-03"
---

# Plan 08-05: Release APK Build + AD_ID Verification (AD-06)

## What Was Built

Wave 4 final gate: built a release APK with all three mediation adapter AARs present and
confirmed COPPA compliance — zero AD_ID, AdServices, or ADVERTISING permissions in the merged manifest.

## Task 1: Release APK Build

`flutter build apk --release` completed successfully.
- **Output:** `build/app/outputs/flutter-apk/app-release.apk` (73.3 MB)
- All three mediation AARs merged: Unity, ironSource, InMobi
- Non-blocking KGP deprecation warnings from third-party plugins — not errors

## Task 2: AD_ID Absent Verification (AD-06, D-05)

**Result: PASS**

```
aapt dump badging app-release.apk | Select-String "AD_ID|AdServices|ADVERTISING"
→ (no output)
```

### Fix Required

First aapt run returned:
```
uses-library-not-required:'android.ext.adservices'
```

The four `<uses-permission tools:node="remove">` blocks blocked the permission nodes but not the
`<uses-library>` hint injected by mediation AARs. Fix: added `<uses-library android:name="android.ext.adservices" tools:node="remove"/>` inside `<application>` in `AndroidManifest.xml`.

After rebuild: aapt returns zero output — PASS confirmed.

### Final Manifest Protection (5 removal blocks total)

| Element | Type | Status |
|---------|------|--------|
| `com.google.android.gms.permission.AD_ID` | uses-permission | removed ✓ |
| `android.permission.ACCESS_ADSERVICES_AD_ID` | uses-permission | removed ✓ |
| `android.permission.ACCESS_ADSERVICES_ATTRIBUTION` | uses-permission | removed ✓ |
| `android.permission.ACCESS_ADSERVICES_TOPICS` | uses-permission | removed ✓ |
| `android.ext.adservices` (library hint) | uses-library | removed ✓ (new) |

## Key Decisions

- `uses-library` hint for `android.ext.adservices` requires its own `tools:node="remove"` entry separate
  from the permission blocks — added inside `<application>` (uses-library is application-scoped, not manifest-scoped)
- KGP deprecation warnings from Unity/IronSource plugins are cosmetic and do not affect APK validity

## Verification Results

```
flutter build apk --release — exits 0, 73.3 MB APK produced
aapt dump badging app-release.apk | Select-String "AD_ID|AdServices|ADVERTISING" — no output (PASS)
All five tools:node="remove" blocks present in AndroidManifest.xml
```

## Self-Check: PASSED

- Release APK builds with all three mediation AARs
- AD_ID permission absent from merged manifest (aapt confirmed)
- AdServices library hint absent from merged manifest (fix applied + confirmed)
- COPPA compliance verified for Phase 8 (AD-06 satisfied)
