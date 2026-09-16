# Pelagic - Godot fish prototype

Open `project.godot` in Godot 4.7.2 and press F5, or run `Play.cmd`. `Launch.ps1 -Check` imports/parses; `Launch.ps1 -Test` runs the current regression suite. Set `GODOT_EXE` if Godot is installed elsewhere.

## Controls

| Mode | Controls |
|---|---|
| Fish | Mouse look; W/S forward/reverse; A/D turn; Space/Ctrl rise/dive; Shift boost; hold/release LMB feed |
| Boat | G enters boat setup; WASD moves; mouse aims; X chooses species; press G again to cast |
| Bait | Tab enters/leaves bait control; W reel/release glide; A/D steer; hold/release LMB escape; X species; F reset |
| Squid | Mouse aims unrestricted dash; LMB charges/releases it; Space/Ctrl are one-press up/down jets; W slow reel/release sink |
| Camera | C switches bait/fish camera while controlling bait; mouse orbits bait |
| Other | R resets fish position; Esc releases/captures cursor; F9 saves a hitch report |

The test roster is minnow, shrimp, squid, crab and mullet. The two artificial test baits and their obsolete driver are removed. G works directly from fish mode: the first press puts you in the boat, the second casts in your chosen horizontal direction. Casts have a short backswing, a visible flight and varied distance. Reeling fully back to the boat automatically returns to cast setup. Squid drops below the boat and can dash within an 8.4 m radius.

## Current world

The arena is 264 m wide and 32 m deep, with textured sand, rocks, water highlights and crossing splashes. It contains 142 catchable actors at default settings. Eight loose pods of six minnows occupy bottom, middle and upper water; nearby fish scatter them through normal escape behavior, then they slowly regroup after a calm interval. Two eight-mullet schools gather near the surface; shrimp, crabs, squid and birds do not school. More dispersed squid occupy middle depths and steer upward well before reaching the floor. Mullet still dive and breach; gulls fly higher and faster, provoke mullet jumps/dives, pursue diving prey and occasionally catch one.

Shrimp move tail-first, kicking upward while preserving their travel heading. Bait escape recovery is 0.95 s, with occasional paired escapes. AI and player use the same species motor. Initial bait appears gradually over about 15 seconds, with shrimp/crabs spread through the water column; replacement shrimp/crabs enter at the surface and sink to their bottom homes, worth 4/5 food. Mullet must dive after three consecutive jumps. Threat escapes keep the travel heading except for bounded turns around a head-on fish. AI occasionally releases controls for 0.5-1.5 seconds. All spawned bait has modest size variation. No rock-hugging or cover-seeking implementation remains.

Fish start at 0.58 scale and grow toward 2.1. Growth now spans a longer round: scale is about 0.67 at 10 food, 0.97 at 50, 1.27 at 100, and 1.64 at 200. Crabs require 0.72 scale and gulls 1.05; rejected bites show the requirement. Collision and bite reach grow with the model. Swimming alone never eats; the feeding dash and short post-dash catch window do.

## Editing

Read [CODE_GUIDE.md](CODE_GUIDE.md) for the complete movement path, current formulas, variable tables, internal timer purposes and where to make each change. The guide describes the implementation rather than retaining old experimental instructions.

`-- --readability-preview` captures visual inspection images. `-- --perf-check --perf-tour` runs a 75-second moving-camera benchmark; `--perf-duration=120` changes its duration. Press **F9 immediately after a hitch**. A save confirmation appears. It writes a timestamped **CSV + JSON pair** to `user://hitch-reports/`; its full path appears in Godot Output. With `Play.cmd` / `Launch.ps1`, look in `../../work/app-data/Godot/app_userdata/PELAGIC — Fish Controller/hitch-reports/` relative to this project. Send both matching files, plus what you were doing when the hitch happened. The CSV contains the most recent 1800 frames; JSON includes recorded hitches, system details and a bait-state snapshot. Performance traces help investigate stalls without assuming they are resolved.

Local Git commits are independent save points. Pushing copies them to the remote for backup; uncommitted edits are not a new commit.

Development milestones are saved as descriptive local commits after substantial changes. These can later supply a version selector using temporary checkouts/builds; no duplicate project directories are required now. See `MILESTONES.md`.

Performance comparison: `-- --perf-check --perf-tour --perf-duration=60 --profile-bait` uses fixed spawning and reports frames after 30 seconds. Add `--dense-benchmark` to test 226 bait. Normal play uses 142. F9 reports now include a last-ten-seconds summary and physics steps per frame, so startup cannot conceal sustained slowdown.
