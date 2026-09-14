# Pelagic — GDScript fish prototype

This project is entirely **GDScript**, for **Godot 4.7.2**. No C#, .NET SDK, NuGet packages, or external art assets are required. Both standard Godot and the .NET edition can run GDScript, but the included launcher selects the installed standard editor.

Open `project.godot` in Godot and press **F5**. On this computer, **Play.cmd** starts the game and **Open Editor.cmd** opens the editor. On another computer, import the project directly or set `GODOT_EXE` to that computer's Godot executable before using the launchers. `Launch.ps1` keeps editor data in the enclosing workspace's `work/` folder.

## Controls

| Input | What it does |
|---|---|
| Mouse | Look/aim independently of fish heading |
| W | Forward throttle; gradually steer toward where you look |
| S | Slow reverse along the fish's current axis, without turning it around |
| A / D | Assist left/right yaw; pivot slowly without W; never strafe |
| Space / Ctrl | Rise/dive along world up/down |
| Shift + W | Boost forward swimming; no reverse boost |
| Hold LMB | Slow propulsion and charge; tail/body anticipation becomes stronger |
| Release LMB | Curved feeding lunge; eat bait touched during the dash |
| R | Reset position, heading and attack; retain earned food |
| Esc | Release/capture cursor and cancel attack |
| Click with cursor free | Capture cursor; that click does not attack |
| Tab | Toggle fisherman-lure test mode |

Forward motion has acceleration and coasting. Pointing the camera behind the fish does not reverse its velocity instantly: hold W to curve around. A/D can tighten that curve. S leaves facing unchanged unless you also steer manually. Looking up/down while holding W changes pitch, while Space/Ctrl adds vertical propulsion. Gameplay roll remains zero.

A tap lunges about 3 metres; 1.4 seconds of charge reaches 15 metres of travelled path. On release, the requested target is limited to 65° from actual fish heading, then the fish turns toward that target at 220°/second during the dash. A curved dash's endpoint is closer than its travelled distance. Aim is fixed on release. The fish carries momentum along the final direction afterward, but only eats during the dash. Recovery is 0.45 seconds; begin a fresh press after recovery.

## Start changing the game

Open **Scenes/FishPlayer.tscn**, select **FishPlayer**, and edit the grouped Inspector properties. Start with `forward_turn_rate`, `manual_steering_strength`, `reverse_speed_multiplier`, and `maximum_lunge_turn_angle`. Select its **Visual** child to tune charge wiggle without changing physics. Open **Scenes/Reef.tscn** and select **Reef** to change arena size/depth.

[CODE_GUIDE.md](CODE_GUIDE.md) explains the tick-by-tick flow, each script's responsibility, tuning defaults, and how to alter bait, visuals, feeding and zones. All gameplay scripts are in `Scripts/`; there are no hidden C# implementations.

## Current playground

- 180×180 metre arena, 32 metre water column, procedural rocks and swim-through hoops.
- 32 prey across eight sparse zones: open-water minnows, lower shrimp, midwater squid and bottom crabs.
- Minnows cruise/glide/burst/dart (+1); shrimp hover/settle/kick (+2); squid glide/hover/pulse (+3); crabs rest/crawl/scuttle (+2).
- Bait respawn after eight seconds. Each food increases size by 1%, capped at 1.6×; the body collision radius grows too.
- Fish and bait collide with terrain. Decorative grass/coral do not collide. Solid objects stop lunges and occlude bites.

The intended game is fish players competing to eat and grow, with human fishermen imitating live prey. This pass preserves that direction but does not implement multiplayer, rods, or fights. Live bait and future controlled bait use identical commands, movement limits and visuals. A fisherman bait's `bitten` signal provides the future fight entry point, without food rewards.

## Fisherman-lure test mode

Press **Tab** to control a minnow from a dedicated diagonal tracking camera. Each reset and species switch starts on the same forward cast bearing. Rod height does not affect the retrieve slope. This is a development tool for judging whether human input can reproduce convincing bait behavior.

| Input in lure mode | Action |
|---|---|
| W | Retrieve toward anchor; release to sink |
| A / D | Bias the next jerk vertically |
| Q | Short jerk; consecutive jerks alternate left/right |
| E | Jig sharply upward and toward the anchor |
| F | Reset lure near the fish |
| X | Switch between jerkbait and sinking jig |
| Tab | Return to fish control |

The test lure is line-constrained by a configurable maximum distance and moves through `BaitActor`; it cannot teleport. `FishingBaitDriver` supports floating, sinking or suspending on pause, retrieve-driven rise/dive, alternating jerk angle, jig strength and maximum line length. `ControlledBaitDriver` remains separate for possible direct control of live bait later.

## Check your changes

From this project folder:

```powershell
.\Launch.ps1 -Check   # Godot imports/registers GDScript classes and checks parsing
.\Launch.ps1 -Test    # Headless physics tests; nonzero exit on failure
```

The standard Godot parser check and all **52 self-tests** pass. Tests cover heading steering, reverse, collisions, curved lunges, sweep/occlusion, rewards, controlled-bait parity, respawning, retrieve direction, alternating jerk, jig, rise/glide trajectories and camera switching and crab bottom crawling. Godot emits a nonfatal certificate-store diagnostic in the restricted tool environment; no game network requests are involved.

For this revision, no repeated visual capture workflow was run. Manually play-test two things: whether W+A/D and the 65° strike cone feel right, and whether the more separated bait zones give the right amount of searching versus feeding.

Optional existing capture flags remain available: `-- --capture`, `-- --charge-preview`, and `-- --feeding-preview`. The latter two drive a demonstration attack and add stationary test bait; normal play does neither.

### Revised bait controls
Tab enters bait control. W retrieves toward a distant surface anchor; A/D steers continuously. Q darts sideways, E kicks upward, and releasing W coasts before settling without pitching nose-down. X cycles all six species and F resets. Animation hotkeys have been removed. Shrimp and crabs also spawn near the start. Prey now react to nearby fish and probe ahead for terrain. Validation: 52 checks pass.

Reeling and live swimming now use the same shallow rising stroke. Both coast forward and descend on a glide. Q is a lateral dart; E is a short upward hop. A/D steers during reeling and gliding. The camera maintains a fixed world angle so motion remains readable.


## Species and camera update
Mouse movement orbits the bait camera. C switches between bait orbit and fish third-person camera while retaining bait controls; C also selects the preferred camera before entering with Tab. A/D deflects the rod heading up to 40 degrees either side of the original cast direction, including while gliding, without accumulating a turn.
Minnows alternate gentle rising swims and falling glides; some start near the surface and descend toward the bottom. Shrimp scoot near the floor and E triggers a fast upward escape. Squid W rises predominantly vertically, release drops, and E gives a stronger upward pulse. Crabs sink fast, crawl along terrain, and E performs a sideways escape with no upward hop. Live AI uses the same species motor as player bait. X cycles species; F resets. 60 regression checks pass.

Brief lure references: Rapala's X-Rap guidance uses jerk/pause/reel-slack sequences (https://blog.rapala.com/news/go-all-day-crappie-fishing-with-the-x-rap-4/); Berkley's shrimp guidance includes bottom pauses, drops and darting retrieves (https://berkley-fishing.com.au/product/shrimp/). These inform the interaction rhythm; the squid/crab profiles are gameplay choices.
