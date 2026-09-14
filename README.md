# Pelagic — GDScript fish prototype

Open project.godot in Godot 4.7.2 and press F5, or use Play.cmd. Open Editor.cmd launches the editor. Launch.ps1 -Check imports/parses scripts; Launch.ps1 -Test runs the regression checks. Set GODOT_EXE if your engine is installed elsewhere.

## Fish controls

Mouse looks; W swims toward aim, S reverses, A/D assists turning. Space/Ctrl rises/dives; Shift boosts. Hold/release left mouse charges a feeding lunge. R resets; Esc releases/captures the cursor.

Fish can breach the surface and catch airborne mullet during a strike. Gravity takes over in air. Floor contact redirects a glancing strike along the floor; walls still stop it. The strike retains a tunable 0.2-second grab window afterward. Ordinary swimming never eats bait.

## Bait test controls

| Input | Effect |
|---|---|
| Tab | Enter/leave bait control |
| C | Bait orbit camera / fish third-person camera, while keeping bait control |
| Mouse | Orbit bait, or look from fish camera |
| X | Cycle minnow, shrimp, squid, crab, jerkbait, jig, mullet |
| W | Swim/retrieve; release to coast/drop |
| A/D | Live-bait turn; artificial-lure rod deflection |
| Hold/release Q / E | Charge left/right escape for live bait |
| Space / Ctrl | Live-bait rise / faster descent; Space/Ctrl also aims squid escape vertically |
| Q / E on artificial lure | Immediate jerk / jig |
| Alt + WASD | Move the boat/origin horizontally; suppress bait movement inputs |
| G | Cast selected bait a fixed 28 m from boat along camera bearing, at surface |
| F | Reset to current deployment point |

The test bait appears only when entering bait mode. Boat hull marks the surface origin. Reeling near it slows and rises into an arrival beneath the hull. Live bait can leave this arrival by releasing W or using vertical controls; artificial bait remains retrieve-controlled. Casting clears old motion/escape state. No line, fight, or rod simulation is present.

## Shared live-bait abilities

| Species | Normal movement | Charged escape |
|---|---|---|
| Minnow | Rising swims / sinking glides; some descend from surface | Curving horizontal dart |
| Shrimp | Bottom scoot / settle | Upward-backward kick with side bias |
| Squid | Pulsed up/down movement | Sustained side/up/down jet; body pitches from velocity |
| Crab | Bottom crawl / rest / scuttle | Lateral scuttle without turning its body |
| Mullet | Surface cruise/coast | Higher, slower ballistic breach and re-entry |

AI escape scheduling is independent of roaming: randomized 2.5–6 s intervals followed by variable charge time. Close fish trigger an immediate escape when the shared 2 s recovery permits it. Mullet reacts at 12 m; other live bait at 6 m. AI and player use the same escape motor and strength limits.

## Validation and editing

79 headless checks pass, covering movement, bite occlusion, escape strength/recovery, all-species ambient escapes, squid pitch, crab lateral travel, boat arrival/casting, floor skimming and airborne feeding. The restricted environment can report certificate/log-cache warnings unrelated to gameplay.

See CODE_GUIDE.md for file ownership and tuning. Manual feel testing should focus on Q/E charge range, shrimp kick height, squid pulse cadence, mullet chase timing, camera readability and boat arrival.
