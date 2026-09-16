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

The arena is 240 m wide and 32 m deep, with textured sand, rocks, water highlights and crossing splashes. It contains 194 catchable actors at default settings. Eight loose pods of ten smaller minnows occupy bottom, middle and upper water; nearby fish scatter them through normal escape behavior, then they slowly regroup after a calm interval. Two eight-mullet schools gather near the surface; shrimp, crabs, squid and birds do not school. More dispersed squid occupy middle depths and steer upward well before reaching the floor. Mullet still dive and breach; gulls fly higher and faster, provoke mullet jumps/dives, pursue diving prey and occasionally catch one.

Shrimp move tail-first, kicking upward and horizontally away from danger. Bait escape recovery is 0.95 s, with occasional paired escapes. AI and player use the same species motor. Shrimp/crabs spawn at the surface and sink to their bottom homes, worth 4/5 food. AI occasionally releases controls for 0.5-1.5 seconds. All spawned bait has modest size variation. No rock-hugging or cover-seeking implementation remains.

Fish start at 0.58 scale and grow toward 2.1. Early food has a large visible effect, while each later meal adds less size. Scale reaches about 1.22 at 10 food and 1.93 at 40 food; collision and bite reach grow with the model. Swimming alone never eats; the feeding dash and short post-dash catch window do.

## Editing

Read [CODE_GUIDE.md](CODE_GUIDE.md) for the complete movement path, current formulas, variable tables, internal timer purposes and where to make each change. The guide describes the implementation rather than retaining old experimental instructions.

`-- --readability-preview` captures visual inspection images. `-- --perf-check --perf-tour` runs a 75-second moving-camera benchmark; `--perf-duration=120` changes its duration. F9 writes `user://performance-hitches.csv` during normal play; its absolute path appears in Godot's output. Performance traces help investigate stalls without assuming they are resolved.

Local Git commits are independent save points. Pushing copies them to the remote for backup; uncommitted edits are not a new commit.
