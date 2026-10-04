# Cinematic capture

Use Godot Movie Maker with the existing AI-vs-AI spectator. The project viewport and window remain 1920x1080. Capture hides HUD/help, debug statistics, result/counter notices, test-bait markers, and spectator gesture labels. World visuals, particles, stun stars, boat, rod, line and audio remain. Automatic cuts are opt-in with `--director`; gameplay is unchanged.

From Windows Command Prompt (create the output folder first):

```bat
"C:\Users\Sloth\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "C:\Users\Sloth\Documents\Codex\2026-09-13\make\outputs\FishGame" --resolution 1920x1080 --write-movie "C:\Users\Sloth\Documents\Codex\capture.avi" --fixed-fps 60 --quit-after 3600 -- --ai-vs-ai --capture --seed=12345 --shot=fisher
```

This records 3600 frames (60 seconds at 60 fps). Remove `--quit-after 3600` for manual duration; close the game normally to finish writing. Movie Maker writes AVI directly; no custom encoder is used. Do not use headless mode for filming. Use distinct output names for each take.

For an editor-launched clean preview, use these Main Run Args (no movie is written):

```text
-- --ai-vs-ai --capture --seed=12345 --shot=fish-side
```

## Shots and filming controls

| Key | Shot | View |
| --- | --- | --- |
| 1 | fisher | Existing boat/rod view |
| 2 | fish | Existing following fish view |
| 3 | free | Existing free camera; WASD move, Q/E down/up, hold RMB and move mouse to look |
| 4 | wide | Tracks the midpoint and separation of Fish and boat |
| 5 | fish-side | Broadside tracking view |
| 6 | fish-rear | Wider, higher rear tracking view |
| 7 | fish-front | Front three-quarter tracking view |

Capture defaults to fisher; normal spectator defaults to free. Shots are also available without capture. `FightSpectator.set_shot(name, instant=true)` selects presets programmatically and returns false for an unknown name. `instant=false` eases the camera position toward the new shot. Free preserves its current position on selection. No preset sends actor input or consumes simulation randomness.

Use the same seed, game revision, 60 fps and launch options for another angle of the same seeded session; change only shot/output filename. `--fight-seed=N` is accepted as an alias in spectator sessions, but the ambient spectator setup is different from an isolated batch encounter, so a batch seed alone does not reproduce that batch's opening state. Seeding covers encounter RNG, both AI drivers and bait population; cross-version/platform bit-exact physics is not promised. Without a seed, normal randomized play is preserved.

The old screenshot-and-exit option is now `--preview-capture`; feeding/charge preview flags retain their existing behavior. `--capture` itself no longer saves a PNG or quits after two seconds.

Validation for this first pass is import/parse only; no movie or fight was run.

## Automatic director (first pass)

Add `--director` to capture, for example editor Main Run Args:

```text
-- --ai-vs-ai --capture --director --seed=12345
```

The same flags work after `--` in the Movie Maker command above. Manual keys remain unchanged when Director is off; when enabled it owns shot selection. It uses the existing presets plus fish-front. No movie editing, replay buffer or encoder is involved.

Ordinary shots hold 5-10 seconds; explicit API holds clamp to the same range. Major high-interest events may interrupt after 2.5 seconds. Compatible event changes keep the existing composition. Feeding and side dashes lock the current shot; a successful bite adds a 2-second hold, counters hold for 2.5 seconds, and jump framing holds through flight plus 1.5 seconds after water entry. Lower-priority requests expire rather than piling up. Free swimming mixes rear, side, front, follow and environmental wide views; nearby prey biases framing to include the intercept. Terrain is sampled with one short ray every 0.75 seconds. Substantial course changes can request a new angle after 3 seconds.

Hookset, breach, counter and landing outrank feeding/powered/side dashes, dives and ascent. Hookset prefers the boat view; opening/run prefers rear/side; side/dive prefers side; ascent prefers side; breach chooses medium side/front or a Fish-centered wide; counter holds an existing fish angle when useful; landing prefers boat/wide. These read authoritative encounter phase, motion state, last_counter and outcome without altering them.

Position/aim lag smooth tracking inside each shot. A separate seeded RNG varies distance (0.85-1.20x), height (-1.3 to +2.0 m), side, FOV (+/-3 degrees) and hold duration, without affecting gameplay RNG. Physics-mask-1 sphere sweeps and sight rays check seabed/rocks; boat hull clearance is conservative geometry because the boat is visual. Surface shots stay above water, while underwater fish-follow shots are intentional. Unsafe shots fall back to a collision-constrained rear view with a 3-second safety cooldown; off-frame subjects are recentered. This is a first-pass geometric safety check, not rendered-image visibility analysis.

Programmatic seam on `FightSpectator.director`:
- `request_shot(shot, duration=5, interest=4, subject="fish")`: subjects fish/prey/boat; bounded short-lived request.
- `watch_event(event, shot, duration=5)`: override a future event's shot preference.
- Events: swim, approach, feeding-charge, feeding-dash, terrain, course-change, hookset, opening, powered-run, side-dash, dive, ascent, breach, counter, landing, fight.

Validation: import/parse only. No game launch, fight batch, or test movie. Subjective composition remains for manual filming.

## Smoother shot selection and event timestamps (2026-10-04)

Ordinary changes use existing non-instant camera tracking. Only hookset, breach, counter and landing requests can hard-cut; staying on the same preset does not reset its composition. Safety recovery can still reposition immediately to avoid geometry. Recent shot families (rear/follow, side, front, wide, boat) discourage back-to-back similar views unless the event needs that family.

Seeded variants include left/right and low/elevated side/front, close/high rear with modest lateral three-quarter offsets, and near/far environmental wides. Opening favors rear/follow, approaches favor side/front including prey, and lateral dashes favor broadside. Ascent keeps a close low tracking view; a jump wide follows Fish/waterline rather than using the entire Fish-to-boat separation. Existing collision/framing checks remain. No changes to gameplay, simulation RNG or AI.

Each capture session (with or without Director) creates `user://capture-events/capture_<date>_<unique-id>.csv`. Godot prints the resolved path as `CAPTURE EVENTS:`. With Launch.ps1 this is beneath the workspace's `work/app-data/Godot/app_userdata/PELAGIC — Fish Controller/capture-events`; editor launches use the editor's normal Godot user-data folder (Project > Open User Data Folder).

Columns: `timestamp` (simulation seconds since session start), `event`, `encounter_seed`, `metadata_json`. Events include feeding-charge/dash, bite-success, fight-start/opening/hookset, Drive/Overdrive, left/right dash, dive, ascent/breach, counter-success/miss, Power Reel and fight outcomes (line break, thrown hook, landing). State edges are sampled in the session physics tick; counters and outcomes reuse existing authoritative notification paths. Only events are written/flushed, never frame-by-frame actor state. Timestamps identify simulation moments for future editing; no movie editing or frame-offset calibration is performed here.

Implementation: `CaptureEventLog` owns the CSV writer; `NetworkSession` samples it and forwards existing notices/results; `CinematicDirector` handles families, holds and composition. Parse/import checked only; no movie, batch or preview rendered for this pass.


## Dev Launcher
F5 with empty Main Run Args now opens a developer launcher. Director Preview is realtime only; Record Director Fight starts Movie Maker in a separate Godot process and writes duplicate-safe AVI names under user://captures/. Optional seed and AI skills are remembered. See DEV_LAUNCHER.md. Existing explicit capture/movie command lines bypass the menu.


## Unattended one-fight recording

The launcher's Record button now adds `--capture-one-fight` and `--capture-max-seconds=300` (adjustable 30–3600 seconds). After a 3-second lead-in, it enables the existing AI test-bait priority, without teleporting bait or changing combat. A missed hook set may retry. Landing, thrown hook, line break, spool-out or disconnect schedules a normal Godot shutdown 3 seconds later so Movie Maker finishes its file. The total simulation-time cap stops a take even if no hook-up or fight outcome occurs. Timeout is logged without inventing a gameplay result. Movie Maker may take longer in wall-clock time than the footage duration.

A blank recording seed is generated, displayed and saved as the launcher's last seed; clear it for another random take. Ordinary Director Preview remains unlimited and keeps normal targeting. For a bounded preview or manual Movie Maker invocation use these user arguments:

```text
-- --ai-vs-ai --capture --director --seed=12345 --capture-one-fight --capture-max-seconds=300
```

The recording launcher additionally supplies an engine `--quit-after` frame cap at (limit + 5) * 60 as a startup safeguard. Capture CSVs include `test-bait-priority`, the normal outcome, and `capture-complete` or `capture-timeout`. Movies and event logs retain their existing folders. No fight mechanics or normal AI modes are changed.


## Recording fixes, event text and landing gag (2026-10-04)
This supersedes the earlier natural-targeting and clean-HUD notes. The test-bait delay is now an eligibility gate, not merely a delayed priority boost: AI feeding ignores fisherman-owned bait until the delay expires, and take_bait rejects incidental early contact. Targeting OFF blocks those lures for the whole configured take. Live bait remains available. Launcher Director Preview now also receives the targeting options, without automatic shutdown.

Movie Maker + Capture enables bounded recording even without the explicit one-fight flag. A non-MISSED fight outcome schedules shutdown independently of the targeting checkbox. The 3-second tail is extended while the short landing gag is active, then closes after another second; the total duration cap remains authoritative. Right-side event/counter text is now visible in capture. Large central result banners and other debug panels remain hidden; results also appear on the right.

Returning to the boat first orients to the planned Fish-facing angle for 0.65 seconds, then retreats along the line over the rest of a 3.6-second transition. Jump framing is selected at jump commitment; counter preparation retains an existing perspective (or selects Fish-side immediately if caught transitioning to the boat). These holds avoid moving across the line during the actual moment.

LandingShow is a short server-owned post-fight sequence (excluded from batches): hold upright beside the rod for 1.5 seconds, then fling at 55-85 m/s with a 50% chance of gravity (28 m/s squared). Flight is bounded to 4 seconds. Crossing the water inside the arena resets the existing network Fish actor as a fresh life at that splash position. Missing the water resets it at its normal spawn. Food/size and effort resources reset for that next life. Actor transforms use existing replication; gameplay resumes after the sequence. Camera framing follows the gag; CSV events include landing-launch (gravity metadata), landing-splash or landing-new-fish.

Import/parse and small direct checks passed for the delay gate, completion scheduling with targeting off, held pose, water reentry and missed-water reset. No movie or fight batch was run. Camera feel and comedy timing need manual viewing.

### MP4
Godot Movie Maker does not include a built-in MP4 writer. Keep recording AVI, then convert with FFmpeg if installed:

```text
ffmpeg -i "fight_capture.avi" -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -movflags +faststart "fight_capture.mp4"
```

FFmpeg was not found on PATH in this environment; no encoder was installed and no video conversion was run. See https://docs.godotengine.org/en/4.5/tutorials/animation/creating_movies.html for Godot's conversion guidance.
