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

Ordinary shots hold 3.5-7 seconds; explicit API holds clamp to 3-8. High-interest events may interrupt after 1.5 seconds. Feeding dashes lock the current shot; a successful bite adds a 2-second hold. Lower-priority requests expire rather than piling up. Free swimming mixes rear, side, front, follow and environmental wide views; nearby prey biases framing to include the intercept. Terrain is sampled with one short ray every 0.75 seconds. Substantial course changes can request a new angle after 3 seconds.

Hookset, breach, counter and landing outrank feeding/powered/side dashes, dives and ascent. Hookset prefers the boat view; opening/run prefers rear/side; side/dive prefers side; ascent prefers side; breach prefers wide; counter holds an existing fish angle when useful; landing prefers boat/wide. These read authoritative encounter phase, motion state, last_counter and outcome without altering them.

Position/aim lag smooth tracking inside each shot. A separate seeded RNG varies distance (0.92-1.12x), height (-0.3 to +0.7 m), side, FOV (+/-3 degrees) and hold duration, without affecting gameplay RNG. Physics-mask-1 sphere sweeps and sight rays check seabed/rocks; boat hull clearance is conservative geometry because the boat is visual. Surface shots stay above water, while underwater fish-follow shots are intentional. Unsafe shots fall back to a collision-constrained rear view with a 3-second safety cooldown; off-frame subjects are recentered. This is a first-pass geometric safety check, not rendered-image visibility analysis.

Programmatic seam on `FightSpectator.director`:
- `request_shot(shot, duration=5, interest=4, subject="fish")`: subjects fish/prey/boat; bounded short-lived request.
- `watch_event(event, shot, duration=5)`: override a future event's shot preference.
- Events: swim, approach, feeding-charge, feeding-dash, terrain, course-change, hookset, opening, powered-run, side-dash, dive, ascent, breach, counter, landing, fight.

Validation: import/parse only. No game launch, fight batch, or test movie. Subjective composition remains for manual filming.
