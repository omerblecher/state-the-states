# Pitfalls Research

**Domain:** Flutter USA states drag-and-drop map game, ages 8+, COPPA/Families compliant, offline
**Researched:** 2026-05-30
**Confidence:** HIGH (carried from proven reference codebase) / MEDIUM (USA-specific additions)

---

## Critical Pitfalls

### Pitfall 1: Drop coordinates not converted through toScene() — using globalToLocal() instead

**What goes wrong:**
Drag events from a FlagTray sitting *outside* InteractiveViewer deliver pointer coordinates in global screen space. If the DragTarget's `onAcceptWithDetails.offset` is passed directly to `Path.contains()` or compared against scene-space centroids, every hit test fails or fires on the wrong state. The bug is zoom-dependent: it disappears at 1× and becomes catastrophic at 3× or 4×, which is exactly where players zoom to target micro-states.

**Why it happens:**
Developers conflate two coordinate spaces. `RenderBox.globalToLocal()` converts to the render-box's local frame, which is the *viewport* frame of InteractiveViewer — it does not account for the child's pan/zoom transform. `TransformationController.toScene()` applies the inverse of the current transformation matrix and returns the point in *scene* (child canvas) space, which is the only space where Path coordinates are meaningful.

**How to avoid:**
Gate the entire drag system behind a mandatory coordinate-transform spike (same gate as Flags). Spike: drag a widget over 5 DragTarget rectangles at 1×, 2×, and 4× zoom; assert the correct rectangle is always hit. Do not build the full drag system until the spike passes. Implementation pattern (proven in Flags, carry over directly):

```dart
Offset? _toSceneFromGlobal(Offset globalOffset) {
  final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  // Step 1: global → IV viewport local
  // Step 2: viewport local → scene (child canvas) coords
  return _controller.toScene(box.globalToLocal(globalOffset));
}
```

Then pass `scale: _controller.value.getMaxScaleOnAxis()` to `hitTest()` so the micro-state proximity expansion stays physically correct at all zoom levels.

**Warning signs:**
- Drops register correctly at default zoom but miss at 3× zoom
- Correct state only triggers when dropping exactly on centroid dot
- Hit detection regresses after adding zoom buttons

**Phase to address:** Phase 1 (coordinate-transform spike) — must pass before any game mode work begins.

---

### Pitfall 2: Alaska/Hawaii inset tokens live in a different coordinate subspace — not reflected in hit test

**What goes wrong:**
Alaska and Hawaii are displayed as inset frames positioned below the mainland at build-time offsets and scales. If the Python pipeline bakes these states' paths into the same scene space as the mainland (i.e., Alaska at its true latitude near the top of the canvas), then:
1. A token dropped on the Alaska inset box hits a scene point that corresponds to ocean or Canada, not Alaska's Path.
2. Conversely, a player who pans to Alaska's true geographic position (top-left of the canvas) and drops a token there gets a hit on an invisible non-inset path.

Double-counting risk: if the pipeline outputs both a "geographic" path and an "inset" path for Alaska, a single token drop can satisfy two separate `Path.contains()` checks, returning a false hit for the mainland position when the player is looking at the inset.

**Why it happens:**
The inset is a visual convenience (same as in Flags' world-wrap pattern). The scene paths must match exactly where the canvas paints the state — i.e., the inset transform (scale + translate) must be baked *into* the path coordinates stored in `usa_states_paths.json`, OR the hit-test must apply the inverse inset transform to the drop point before calling `Path.contains()`. Forgetting this means visual position and logical position are decoupled.

**How to avoid:**
In the Python build pipeline, for Alaska and Hawaii: apply the inset `scale × translate` transform to the raw GeoJSON coordinates *before* emitting Path data to JSON. Store only the transformed (inset-positioned) paths. The centroid field must also reflect the inset position. This ensures `Path.contains(scenePoint)` and centroid-snap work with zero special-casing in Dart. Never output two paths for the same state (one geographic, one inset).

**Warning signs:**
- Dropping a token on the visible Alaska inset never triggers a match
- Dropping anywhere near lat 60°N scene position accidentally matches Alaska
- Alaska centroid snap pulls tokens toward an off-screen position

**Phase to address:** Phase 1 (Python pipeline spike) — the transform must be baked in before any Dart hit-test code is written.

---

### Pitfall 3: Alaska Aleutian Islands cross the antimeridian — raw GeoJSON coordinates break the build pipeline

**What goes wrong:**
Natural Earth's `ne_10m_admin_1_states_provinces` represents Alaska as a MultiPolygon. The Aleutian Island chain extends past 180° longitude; some ring vertices have longitude values near +173° E (which GeoJSON encodes as positive values past 180, or as a polygon that "jumps" across the antimeridian). A naive Python coordinate-normalisation step that scales `(-180, 180)` → `(0, scene_width)` will either:
- Collapse Aleutian ring vertices to the far-right edge of the canvas (near 0° E / 360°), producing a visually shattered polygon.
- Cause shapely/fiona winding-order errors that invert the polygon fill.
- Silently produce a valid-looking but incorrectly positioned outline.

**Why it happens:**
GeoJSON RFC 7946 explicitly says geometries crossing the antimeridian should be split, but Natural Earth does not always comply. The Aleutian portion of Alaska wraps. A developer building the pipeline for the first time sees "Alaska" as a single entry and assumes a simple linear coordinate remap works, not knowing it contains antimeridian-crossing rings.

**How to avoid:**
In the Python pipeline, before remapping coordinates:
1. Use the `antimeridian` Python package (or shapely's split on the antimeridian line) to split any polygon rings that cross ±180°.
2. Clip to the inset bounding box *after* splitting — the Aleutians west of 180° can be either included (scaled into the inset) or dropped (most USA map insets omit the westernmost tip).
3. Test visually by rendering the pipeline output to a PNG before wiring it to Flutter.

**Warning signs:**
- Alaska polygon has a thin horizontal line stretching across the full canvas width
- Alaska fill appears inside-out (white interior, coloured exterior)
- `shapely.validation.is_valid()` returns False for Alaska geometry

**Phase to address:** Phase 1 (Python pipeline, immediately after Natural Earth data is sourced).

---

### Pitfall 4: Micro-state hitbox overlap — RI/DE/CT/NJ/MD snap to the wrong state under centroid tiebreaker

**What goes wrong:**
Rhode Island (area ~4,000 km²), Delaware, Connecticut, New Jersey, and Maryland are so small that their scene-space paths are tiny rectangles. After the proximity-expansion logic inflates each to a 48dp-equivalent radius, adjacent expansions overlap. The centroid tiebreaker (closest centroid wins) then silently resolves conflicts — but if the centroids are closer together than the expansion radius (easily true for RI vs. CT, or NJ vs. DE), a drop intended for state A reliably snaps to state B because B's centroid is slightly closer.

Compounding factor: the northeastern seaboard has five micro-states packed into roughly 200×150 scene pixels. At default zoom (states are ~5 screen-pixels wide each), all five expanded hitboxes become one merged blob. Any drop anywhere in this blob resolves to whichever centroid is closest, which is always the same one, making four of the five states essentially unhittable without zooming in first.

**Why it happens:**
Flags' hit-detection logic (carried over from `hit_detection.dart`) was designed for world-scale countries where micro-states like Singapore and Monaco are isolated — no adjacent micro-state within 200 km. USA's northeastern cluster is fundamentally different: five small states with shared borders and similar sizes. The expansion and centroid-tiebreaker logic that works perfectly for Singapore breaks for RI/DE.

**How to avoid:**
1. Enforce a zoom floor for micro-state placement: detect when the drop point's scene neighbourhood contains N expansion zones (N ≥ 3) and show a "zoom in to place" hint instead of accepting the drop. This prevents the ambiguous-blob problem entirely.
2. When exactly two expansions overlap, use path-exact hit first (no expansion), then expansion only if path-exact returns null — the same layered approach as Flags' `_primaryContains`. This already partially exists; verify it handles adjacent same-size states, not just micro-vs-large.
3. Write a golden-test for the NE seaboard cluster: drop at the geometric centre of each micro-state's path at 1×, 2×, 4× zoom and assert the correct ISO code is returned.

**Warning signs:**
- Rhode Island or Connecticut never matches even when dropped directly on the visible outline
- The same state always wins drops anywhere in the NE seaboard area
- Manual testing at 1× zoom: dropping on DE border resolves to NJ

**Phase to address:** Phase 2 (hit detection implementation) — write the golden test suite before wiring to game logic.

---

### Pitfall 5: Abbreviation/label rendering uses scene-space font size, causing illegibility at low zoom or giant text at high zoom

**What goes wrong:**
`WorldMapPainter` (from Flags) uses `fontSize = screenFontSize / viewScale` so labels stay constant-size on screen regardless of zoom. This is the correct pattern. The failure mode happens when the USA map carries state abbreviations (2-letter codes, e.g. "RI", "DE") for Game Modes 1 and 3, and the threshold logic is not recalibrated for USA state sizes.

USA states range from Alaska (~1,700,000 km²) to Rhode Island (~4,000 km²) — a 425× size range. The Flags threshold buckets (diagonal < 20, < 70, < 250, ≥ 250) were calibrated for world countries; US state diagonals in the same scene space will all fall in the "small/medium" bucket, causing all 50 states' labels to fade in at the same zoom level, including Alaska, which should always be visible. Additionally, two-letter abbreviations for NJ/CT/RI stack on top of each other in the NE seaboard at low zoom.

**How to avoid:**
1. Recalibrate the four opacity threshold buckets for US state scene-diagonal distributions. Measure actual diagonals from the pipeline output JSON before hardcoding thresholds.
2. Port the collision-detection logic from Flags (`drawnRects` list) as-is — it already prevents overlap, labels just need correct threshold values.
3. For two-letter abbreviations, use a slightly smaller minimum font size (10px rather than 11px) to leave room in dense regions.
4. Add a `showAbbreviations` boolean to the painter, separate from `showLabels`, to support Mode 1 (abbreviations visible) vs. Mode 3 (abbreviations visible, name hidden) vs. Mode 4 (nothing visible).

**Warning signs:**
- All 50 state abbreviations appear simultaneously at default zoom as an unreadable smear
- Alaska's "AK" is invisible at default zoom (state too "small" by diagonal threshold)
- NE seaboard shows overlapping "RI"/"CT"/"NJ" text at 1× zoom

**Phase to address:** Phase 2 (map painter implementation) — test against all four mode visibility combinations before calling the painter done.

---

### Pitfall 6: Golf scoring timer drifts when app is backgrounded — penalty clock does not pause correctly

**What goes wrong:**
Golf scoring adds +1 point per 10 seconds elapsed. If the timer is implemented as a `Timer.periodic` tick that increments a counter, it will *slow down or stop entirely* when Android/iOS throttles background apps. The result: a player who minimises the app for 60 seconds loses no time points. Conversely, if `didChangeAppLifecycleState(paused)` triggers an auto-pause but the score snapshot is taken one tick late, the final score can be off by ±10 seconds' worth of points.

Separate issue: the game session auto-pauses on `AppLifecycleState.paused` (correct, carried from Flags). But if the player resumes quickly (<1 s), the pause overlay is shown with the timer frozen, and the player must manually dismiss it — which adds a non-zero time penalty to the score. This is a minor fairness issue but noticeable on repeated plays.

**Why it happens:**
Dart `Timer.periodic` is not guaranteed to fire at the specified interval when backgrounded. Elapsed time should be measured with `DateTime.now()` snapshots at pause and resume boundaries, not by counting ticks.

**How to avoid:**
1. Store elapsed time as a `Duration`, not a tick counter. On pause, snapshot `_lastResumeAt = DateTime.now()` and `_accumulatedElapsed`. On resume, compute elapsed as `_accumulatedElapsed + (DateTime.now() - _lastResumeAt)`.
2. Use `Stopwatch` for the running segment; stop it on `AppLifecycleState.paused`, restart it on resume.
3. The golf score computation (`elapsed.inSeconds ~/ 10`) must read from the accumulated duration, not from a mutable int field.
4. Best score persistence: write the score to SharedPreferences *only after `completeGame()` succeeds*, never during intermediate penalty updates. This prevents a partial write from corrupting a stored best score.

**Warning signs:**
- Score does not increase when left idle for 60 seconds in background
- Resuming the app shows a large score jump (timer was not paused)
- Best score field shows `0` or a huge number after a crash-during-play scenario

**Phase to address:** Phase 2 (GameSession state machine) — use Stopwatch + DateTime snapshots from the first line of game session implementation.

---

### Pitfall 7: Best score persistence race — double-write or stale-read corrupts the stored record

**What goes wrong:**
`SharedPreferences` writes are asynchronous with no atomic transaction semantics. If `completeGame()` fires and immediately calls `saveBestScore()`, and a second game completion event arrives (e.g., from a fast tap or a restored session) before the first write resolves, the second read of the current best may see the pre-first-write stale value and overwrite a valid new record.

Additionally, `SharedPreferences` on iOS has a known intermittent issue (flutter/flutter #128368) where writes succeed in cache but are not flushed to disk before the process is killed, silently losing the record.

**Why it happens:**
The pattern `if (newScore < currentBest) saveBestScore(newScore)` is a classic read-modify-write race when both operations are async. In Flags this is mitigated by calling `saveBestScore` exactly once per session completion, but the async gap still exists.

**How to avoid:**
1. Use a `Mutex` or `Lock` pattern (or simply `await` sequentially) in `HighScoreRepository` so that `getBestScore` and `setBestScore` are never interleaved. With Riverpod AsyncNotifiers this is natural — the notifier handles one `completeGame()` at a time.
2. Guard against the iOS flush risk by calling `SharedPreferences.getInstance()` and then `prefs.reload()` before any read at session start, to force a fresh read from disk.
3. Keep the score field's key stable across app versions — changing the SharedPreferences key (e.g., adding a mode suffix) silently resets all stored best scores for existing users.

**Warning signs:**
- Best score field shows `null` / `0` after a cold launch following a completed game
- Two rapid game completions result in the worse score being saved
- Score persists between uninstall/reinstall (Android backup — unexpected)

**Phase to address:** Phase 2 (data layer, HighScoreRepository) and Phase 3 (verify after game completion flow is wired).

---

### Pitfall 8: just_audio fade-out race on screen transition — audio plays after dispose

**What goes wrong:**
The welcome screen fades out the "Star-Spangled Banner" instrumental before routing to the home menu. If the fade-out is implemented as a timed volume ramp followed by `player.stop()`, and the user taps a button before the ramp completes, the route transition disposes the welcome screen widget, `dispose()` calls `player.dispose()`, but the volume-ramp `Future.delayed` still holds a reference to the player. The delayed callback fires on a disposed object, causing either a platform exception (just_audio throws if called after dispose) or a silent continuation of audio playback from a ghost player.

Separate issue on iOS: AVFoundation's audio session is shared across the app. If the welcome screen's player is disposed mid-fade without stopping first, iOS may not release the audio session, causing the next audio player (game sfx) to silently fail to play.

**Why it happens:**
`Future.delayed` callbacks are not cancelled by widget disposal. Developers assume `dispose()` cleans up all pending async work, but it only disposes the `AudioPlayer` object — it does not cancel pending `Future`s that close over it.

**How to avoid:**
1. Use a `CancelableOperation` (from `async` package) or a `mounted` guard for all delayed audio callbacks.
2. Fade-out pattern: use just_audio's `setVolume()` in a loop with a `Timer`, and hold a reference to the `Timer` in the state — cancel it in `dispose()` before calling `player.dispose()`.
3. Always call `player.stop()` before `player.dispose()` to flush the audio session on iOS.
4. The audio service (carried from Flags) should be a singleton Riverpod provider, not a per-screen object, so its lifetime exceeds any individual screen's lifetime. The welcome screen calls `audioService.fadeOut()` and navigates; the service manages the rest asynchronously and is never disposed with the screen.

**Warning signs:**
- Anthem continues playing on the home screen after transition
- "PlatformException: player already disposed" in logs during fade
- Game SFX silent on first play after the welcome screen fade

**Phase to address:** Phase 1 (audio service, welcome screen) — must be proven working before the service is handed off to the game layer.

---

### Pitfall 9: Anthem recording rights — public-domain composition does not mean the recording is free

**What goes wrong:**
"The Star-Spangled Banner" composition (melody + lyrics) is unambiguously in the public domain — the composition dates from 1814 and any copyright has long expired. However, a specific *recording* of the anthem is a separate copyrightable work. Under the Music Modernization Act (US):
- Recordings published before 1923: public domain as of January 1, 2022.
- Recordings published 1923–1946: protected for 100 years from publication.
- Recordings published 1947–1956: protected for 110 years.
- Any recording published after 1972: protected under federal law.

An arranger who produces a new orchestration holds copyright in that arrangement even though the underlying melody is PD. A developer who downloads a "public domain Star-Spangled Banner" from a music site, ships it in a Families-rated app, and later receives a DMCA takedown discovers this distinction the hard way.

**Why it happens:**
Copyright layering (composition vs. sound recording) is non-obvious. The search result "it's in the public domain" refers to the composition; the specific WAV/MP3 file is not covered by that result.

**How to avoid:**
One safe path (mandated in PROJECT.md): render the anthem from a public-domain MIDI score using a software synthesiser (e.g., FluidSynth + a free SF2 soundfont) inside the project's own build pipeline. The output WAV is an original work produced by the project — no third-party recording copyright to infringe. Document this provenance in a `LICENSES` file bundled with the app.

Do NOT use:
- YouTube downloads (performance rights, neighbouring rights)
- Royalty-free music sites (their licence terms almost always exclude app distribution or require attribution)
- Wikimedia Commons recordings without checking the specific CC licence and whether it covers commercial use in an app

**Warning signs:**
- Audio sourced from a third-party website without reviewing the specific file's licence
- `LICENSES` file lists the anthem as "public domain" without specifying which recording
- The audio file has metadata indicating a named performer or studio

**Phase to address:** Phase 1 (asset sourcing) — must be resolved before any audio asset is committed to the repo.

---

### Pitfall 10: COPPA/Families compliance traps even with ads stubbed

**What goes wrong:**
The v1 ad layer is intentionally stubbed. However, these compliance failures are possible without any live ads:

**a) AD_ID permission not blocked:**
`google_mobile_ads` (and several mediation SDKs) declare `AD_ID` in their own `AndroidManifest.xml`. Flutter's manifest merger includes it automatically. Even with ads stubbed, the `AD_ID` permission is present unless explicitly removed with `tools:remove`. Google Play's pre-launch report flags this for Families apps.

**b) tagForChildDirectedTreatment not set before stub init:**
`MobileAds.initialize()` must be called with `RequestConfiguration` set to `tagForChildDirectedTreatment = TagForChildDirectedTreatment.yes` *before* `initialize()`. Calling `initialize()` first then updating the configuration is too late — AdMob has already initialised with default settings. This applies even if every subsequent ad request is stubbed.

**c) Default SDK identifiers in test builds:**
Some mediation SDKs (IronSource, AppLovin) use device-level identifiers in their initialisation even in test/stub mode, unless explicitly told not to. Adding their pub packages triggers their native SDK initialization at app launch regardless of the stub pattern.

**d) Asset licence audit missed:**
Fonts, icons, and map imagery bundled with the app must have licences compatible with a Families app in a commercial context. The Natural Earth map data is public domain (fine). Flutter's bundled Material Icons are Apache 2 (fine). A Google Font that lacks a desktop/mobile app sublicence, or a third-party icon pack with "non-commercial only" terms, would violate Families policy.

**How to avoid:**
1. Add `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:remove="true"/>` to `AndroidManifest.xml` from day one, even in v1 stub phase.
2. In `AdServiceStub.initialize()`, include the real `MobileAds` `RequestConfiguration` call with `tagForChildDirectedTreatment = yes` — the stub initialises the configuration, not the ads.
3. For each mediation SDK added to `pubspec.yaml`, check whether its native init can be suppressed or delayed. Prefer not adding mediation SDKs to pubspec at all until the AdMob phase (v2).
4. Run a licence audit on every asset and font before first Play Store submission. Use `flutter pub licenses` as a starting point.
5. No Firebase, ever — `firebase_core` collects App Instance IDs, which are persistent device identifiers. This is hardcoded in PROJECT.md; treat any PR adding a `firebase_*` dependency as a blocker.

**Warning signs:**
- `tools:remove` is missing from manifest — `aapt dump badging` shows `AD_ID` permission
- `MobileAds.initialize()` appears before `MobileAds.instance.updateRequestConfiguration()`
- Any mediation SDK appears in `pubspec.yaml` before the v2 monetisation phase
- Font or icon licences not verified in writing

**Phase to address:** Phase 1 (project setup, manifest, pubspec baseline) for AD_ID and configuration. Phase 4 (v2 AdMob) for mediation SDKs. Every phase: no new dependencies without licence review.

---

### Pitfall 11: InteractiveViewer Matrix4 entry(2,2) not kept in sync with entry(0,0) — zoom buttons cause wild jumps

**What goes wrong:**
Flutter's `getMaxScaleOnAxis()` inspects all three diagonal entries of the Matrix4. If a programmatic zoom (hint zoom, fit-to-screen) sets entries (0,0) and (1,1) but leaves (2,2) at 1.0 (the identity default), then `getMaxScaleOnAxis()` returns 1.0 even at 4× visual zoom. The next zoom button press multiplies by its factor from a 1.0 base, snapping the map to a wildly wrong scale.

This specific bug was found and fixed in Flags' `_zoom()` method (line 424 of map_screen.dart: `m.setEntry(2, 2, newScale)`). It must be carried over, not reimplemented from scratch.

**How to avoid:**
Copy the `_zoom()` / `_fitMapToScreen()` / `_animateHintZoom()` helper methods from Flags' `map_screen.dart` verbatim. These methods encode the `m.setEntry(2, 2, newScale)` fix. Rewriting them from memory will likely omit the (2,2) sync.

**Warning signs:**
- Zoom-in button produces a massive scale jump after a hint zoom animation
- `_controller.value.getMaxScaleOnAxis()` returns 1.0 when the map is visually at 3×

**Phase to address:** Phase 2 (map canvas implementation) — copy helpers from reference; add a `expect(controller.value.getMaxScaleOnAxis(), closeTo(3.0, 0.01))` assertion in the coordinate-transform spike.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode 48dp expansion radius without a zoom-floor for micro-state clusters | Simpler logic | Five NE seaboard states become one hitbox blob at default zoom; players can never correctly place RI without accidentally placing CT | Never — add the zoom-floor check upfront |
| Use `rawScene.dy % 2000` for world-wrap normalisation even though USA map does not wrap | Copied from Flags with no modification | Silent — no bug in v1 since USA canvas does not double. But dead code and false confidence. | Remove the `% 2000` modulo from the USA port; the USA canvas is a single 2000×1000 scene |
| Skip the Python pipeline spike and write path data by hand or from a generic GeoJSON loader | Saves one day of pipeline work | Alaska antimeridian + Hawaii inset transforms are invisible until a player can't place either state | Never |
| Use `Timer.periodic` for the golf score timer | Simpler state | Timer slows/stops in background; score is gameable by minimising the app | Never — use `Stopwatch` + `DateTime` snapshots from day one |
| Download a "royalty-free" anthem MP3 from a music site | Audio asset ready in minutes | DMCA takedown, Play Store removal, or legal notice after launch | Never — use self-rendered output from PD score |
| Add mediation SDK packages in v1 even though ads are stubbed | "Ready to activate" | Native SDK init at launch collects identifiers, breaks COPPA | Never before v2 AdMob phase |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Natural Earth GeoJSON → Python pipeline | Assume single Polygon per state; iterate `geometry.coordinates` directly | Check `geometry.type`: US states may be MultiPolygon (Alaska, Hawaii, Michigan). Iterate over `geometry.coordinates` for Polygon, `geometry.coordinates[i]` for MultiPolygon. |
| InteractiveViewer + DragTarget | Pass `details.offset` directly to hit test | Two-step transform: `box.globalToLocal(details.offset + pinAnchor)` then `controller.toScene(viewportLocal)` |
| AdMob + Families | Call `MobileAds.initialize()` then set child-directed config | Set `RequestConfiguration(tagForChildDirectedTreatment: ...)` **before** `initialize()` |
| just_audio + route transitions | Dispose player in widget `dispose()` while a delayed fade is in-flight | Hold a `Timer` reference in state; cancel it in `dispose()` before `player.stop()` then `player.dispose()` |
| SharedPreferences best score | Read-modify-write without await chaining | `await repo.getBestScore()` then conditional `await repo.setBestScore()` in a single async function, never interleaved |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| CustomPainter repaints on every `setState()` call in the parent | Janky drag-hover on mid-range devices | Use two `RepaintBoundary`-wrapped painters (static map, dynamic highlight) — already in Flags; carry over | At 50+ drag-hover updates/second on slow devices |
| `drawnRects` label-collision list rebuilt every paint frame | Labels flicker/reorder when dragging | Sort-once outside `paint()` if country list never changes; memoize the sorted list | At 50 paint frames/second with 50 labels |
| Path objects recreated from JSON on every frame | OOM and jank on first gesture | Parse paths once at app init, store in `List<StateData>`, never re-parse | Immediately on first InteractiveViewer gesture |
| `hitTest()` called on `onWillAcceptWithDetails` (every pointer move) with O(n) path scan | Frame drops while dragging | Already mitigated in Flags with bbox pre-filter; verify 50 states (vs. 195 countries) stays fast enough — it will, but confirm | Not a problem at 50 states, but worth verifying |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `AD_ID` permission present in Families app | Play Store rejection, COPPA violation | `tools:remove` in AndroidManifest from project initialisation |
| Firebase dependency added for crash reporting | COPPA violation (persistent App Instance ID) | Hard block: Firebase is excluded in PROJECT.md. Treat as policy violation, not a preference. |
| Third-party analytics SDK added for "just metrics" | Persistent device identifiers, Families policy violation | Use Android Vitals only. No third-party analytics. |
| Anthem recording sourced without verified provenance | DMCA takedown, Play Store removal | Self-render from PD score; document provenance in LICENSES file. |
| Outbound share intent without parental gate | Children can share content without parental awareness (Families policy) | Deferred to v2; implement math-challenge parental gate as specified in PROJECT.md. |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No "zoom in" affordance for micro-state placement | 8-year-olds can't place Rhode Island at default zoom; frustration and abandonment | Show a "Try zooming in" hint after two wrong drops on any NE seaboard state |
| State token snaps to the wrong state with no visible explanation | Child thinks they placed correctly, game silently marks wrong | Play error sound + bounce animation on wrong drop; never silently accept an ambiguous hit as the wrong answer |
| Timer keeps running while the child is distracted mid-game | Golf score inflated by normal interruptions; child feels penalised | Auto-pause on `AppLifecycleState.paused` (already in Flags); also show pause prompt after 60 s of no interaction |
| Abbreviation labels hidden in all game modes | Players in Learn mode can't see state IDs, defeating the learning purpose | `showAbbreviations` is mode-specific; verify Mode 1 and Mode 3 render abbreviations, Mode 2 and 4 do not |
| Anthem plays loudly on first launch in a quiet environment | Startles child (or parent); negative first impression | Start anthem at 0 volume, fade in over 500 ms before reaching full volume |

---

## "Looks Done But Isn't" Checklist

- [ ] **Hit detection spike:** Token drops at 1×, 2×, 4× zoom on 5 known states — not just "it seems to work."
- [ ] **Alaska inset:** Token dropped on the inset frame correctly matches Alaska; token dropped at Alaska's geographic scene position (top-left of canvas) does NOT match Alaska.
- [ ] **Hawaii inset:** Same as Alaska — inset position matches, geographic position does not.
- [ ] **Micro-state golden tests:** Drop on centroid of RI, DE, CT, NJ, MD each returns the correct state, at 1× and 4× zoom.
- [ ] **Timer accuracy:** Pause app for 30 s; resume; verify elapsed time advanced by 0 s (not 30 s).
- [ ] **Best score persistence:** Complete a game, force-kill the app, re-launch — best score is present.
- [ ] **Anthem provenance:** `LICENSES` file documents exact source, rendering tool, and soundfont used. Not just "public domain."
- [ ] **AD_ID blocked:** `aapt dump badging app-release.apk | grep AD_ID` returns nothing.
- [ ] **No Firebase:** `grep -r firebase pubspec.yaml pubspec.lock` returns nothing.
- [ ] **No ads on pause screen:** Pause overlay has zero ad slots — not even a stub banner.
- [ ] **Audio disposed cleanly:** Start welcome screen, trigger fade-out animation, immediately navigate away — no PlatformException in logs.
- [ ] **Matrix4 (2,2) sync:** After hint-zoom animation, pressing zoom-in button applies a predictable 1.5× step, not a jump to an extreme scale.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong coordinate transform discovered after full game modes built | HIGH | Rewrite drag handler in map_screen; all game modes using DragTarget must be retested; likely 2–3 days |
| Alaska/Hawaii paths in wrong coordinate space after pipeline shipped | MEDIUM | Rerun Python pipeline with corrected inset transforms; regenerate JSON; no Dart changes required |
| Antimeridian Alaska polygon corruption in JSON | MEDIUM | Add antimeridian-split step to Python pipeline; regenerate JSON |
| Micro-state hitbox ambiguity found in QA | LOW-MEDIUM | Add zoom-floor hint + adjust expansion logic in hit_detection.dart; targeted fix, no architecture change |
| Anthem DMCA takedown after submission | HIGH | Emergency asset replacement; new app binary submission; 1–3 day review queue |
| AD_ID present found during pre-submission audit | LOW | One-line manifest fix + rebuild; caught before Play Store, not after |
| SharedPreferences best score corrupted | LOW | Repository-level fix to sequentialise read-modify-write; existing scores unrecoverable |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| toScene() coordinate transform | Phase 1 spike | 5-DragTarget spike test at 1×/2×/4× zoom passes |
| Alaska/Hawaii inset coordinate space | Phase 1 Python pipeline | Visual render of pipeline output PNG; inset tokens match |
| Aleutian antimeridian GeoJSON corruption | Phase 1 Python pipeline | `shapely.validation.is_valid()` passes for Alaska |
| Micro-state hitbox overlap (NE seaboard) | Phase 2 hit detection | Golden tests for RI/DE/CT/NJ/MD at all zoom levels |
| Abbreviation/label scaling | Phase 2 map painter | Mode 1 and 3 render readable abbreviations; Mode 4 blank |
| Golf timer drift (backgrounded) | Phase 2 GameSession | Pause 30 s; verify 0 s added to elapsed |
| Best score persistence race | Phase 2 data layer | Double-completion test; cold-launch score persistence test |
| just_audio fade-out race | Phase 1 audio service | Navigate away mid-fade; no PlatformException; no ghost audio |
| Anthem recording rights | Phase 1 asset sourcing | LICENSES file with provenance; no third-party recording |
| COPPA/Families traps (AD_ID, config) | Phase 1 project setup | `aapt dump badging` clean; no Firebase; config before init |
| Matrix4 (2,2) not synced | Phase 2 map canvas | Hint-zoom then zoom-button; scale matches expected 1.5× step |

---

## Sources

- Flags Around the World `CLAUDE.md` — COPPA non-negotiables, coordinate-transform gate, ad walled-garden pattern (HIGH confidence, first-party)
- Flags Around the World `lib/features/map/hit_detection.dart` — micro-state expansion algorithm, centroid tiebreaker, `_kMinScreenArea` (HIGH confidence, first-party)
- Flags Around the World `lib/features/map/map_screen.dart` — `toScene()` pattern, Matrix4 (2,2) sync fix, audio lifecycle in dispose, RepaintBoundary layering (HIGH confidence, first-party)
- Flags Around the World `lib/features/map/world_map_painter.dart` — label scaling thresholds, `viewScale`-aware font size (HIGH confidence, first-party)
- Flutter API: `TransformationController.toScene()` — https://api.flutter.dev/flutter/widgets/TransformationController/toScene.html (HIGH confidence)
- Google AdMob Families compliance: https://support.google.com/admob/answer/6223431 (HIGH confidence)
- AdMob child-directed treatment: https://support.google.com/admob/answer/6219315 (HIGH confidence)
- Music Modernization Act / Star-Spangled Banner sound recording status: https://legalclarity.org/is-the-star-spangled-banner-public-domain/ (MEDIUM confidence — legal summary, not legal advice)
- Antimeridian GeoJSON splitting: https://macwright.com/2016/09/26/the-180th-meridian.html and `antimeridian` Python package (MEDIUM confidence)
- Flutter SharedPreferences iOS concurrency issue: https://github.com/flutter/flutter/issues/128368 (MEDIUM confidence — open issue, not resolved)
- Flutter timer accuracy in background: https://medium.com/geekculture/flutter-case-study-timer-precision-a1154b431e8 (MEDIUM confidence)
- Natural Earth admin1 US states: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/ (HIGH confidence)

---
*Pitfalls research for: Flutter USA states map game (State the States), ages 8+, COPPA/Families compliant*
*Researched: 2026-05-30*
