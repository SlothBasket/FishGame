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
| Hold/release left mouse | Charge escape; A/D picks crab/squid side; Space/Ctrl aims squid vertically |
| Space / Ctrl | Live-bait rise / faster descent; Space/Ctrl also aims squid escape vertically |
| Left mouse on artificial lure | Charged dart / lift |
| Alt + WASD | Move the boat/origin horizontally; suppress bait movement inputs |
| G | Backswing then cast 51-79 m generally toward center; squid drops near boat |
| F | Reset to current deployment point |

The test bait appears only when entering bait mode. Boat hull marks the surface origin. Reeling near it slows and rises into an arrival beneath the hull. Live bait can leave this arrival by releasing W or using vertical controls; artificial bait remains retrieve-controlled. Casting clears old motion/escape state. No line, fight, or rod simulation is present.

## Shared live-bait abilities

| Species | Normal movement | Charged escape |
|---|---|---|
| Minnow | Rising swims / sinking glides; some descend from surface | Forward dart with bounded path wiggle |
| Shrimp | Bottom scoot / settle | Nose-down upward kick, then a forward glide and gentle sinking |
| Squid | Pulsed up/down movement | Side/up/down jet; player stays inside a 6 m boat radius |
| Crab | Bottom crawl / rest / scuttle | Lateral scuttle without turning its body |
| Mullet | Surface cruise/coast | Higher, slower ballistic breach and re-entry |

AI escape scheduling is independent of roaming: randomized 2.5–6 s intervals followed by variable charge time. Close fish trigger an immediate escape when the shared 0.6 s recovery (up to 0.62 s for a full shrimp kick) permits it. Mullet reacts at 20 m; other live bait at 14 m. AI and player use the same escape motor and strength limits.

## Validation and editing

116 headless checks pass, covering movement, bite occlusion, escape strength/recovery, all-species ambient escapes, squid pitch, crab lateral travel, boat arrival/casting, floor skimming and airborne feeding. The restricted environment can report certificate/log-cache warnings unrelated to gameplay.

See CODE_GUIDE.md for file ownership and tuning. Manual feel testing should focus on left-mouse charge range, shrimp kick height, squid pulse cadence, mullet chase timing, camera readability and boat arrival.

## Upper-water and performance pass
The boat begins near the arena edge. Casts enter with 4 m/s downward velocity. Twelve additional upper-water bait, four recurring surface entrants and four seagulls bring the population to 72. Gull behavior cycles flight, swoop, surface rest and take-off; catches use the existing feeding system and award 5 food. Deep surface entrants are recycled to new surface entry points at bounded intervals.
Live test bait now has absolute +/-45-degree steering relative to boat bearing. Left mouse is the only escape charge input. Use A/D for sideways crab/squid direction, and Space/Ctrl for squid vertical aim. Minnow escape preserves forward tracking with a small wiggle.
Mullet launch impulse is 10 m/s. Fish breaches cap upward and horizontal speed at 8 m/s, with 12 m/s² gravity. This preserves aerial feeding without map-spanning launches.
Predator sensing is staggered at 0.3 s intervals. Peer reactions only detect escaping bait within 1.7 m, with a separate 9 s cooldown. Shared lower-resolution sphere meshes and one respawn per frame reduce allocation bursts.
Two 23-second graphical probes of the readability/shelter pass measured median frame times of 16.66/16.69 ms, p95 of 17.72/19.12 ms, and maxima of 574.66/141.69 ms. Most frames were near 60 fps, but isolated hitches remain; their cause has not been isolated. Run Godot with -- --perf-check for another bounded measurement.

### Arena and movement tuning
The arena is 240 m wide, with 24 rocks in eight clusters and shadows disabled. Bait bodies and bite radii use `BaitActor.body_size` (0.8). G launches a visible ballistic cast from the boat toward the center; the bait camera follows the flight. Squid deploy below the boat and can dash horizontally inside a six-metre radius.

Wild bait select small steering changes every 0.6-1.8 seconds. Mullet occasionally dive for 3-5 seconds, then resume their usual surface-seeking movement. Gulls scan for near-surface mullet before swooping and level their bodies while resting. Squid face their actual travel direction; wider initial spacing and more horizontal drift reduce clustering. Minnow escapes use a faster forward burst with body wiggle.

## Readability and shelter
Sand now has world-space ripples and color variation, with 650 small instanced pebbles. Animated surface streaks show the waterline from above and below. Crossing it creates a small splash and expanding ripple, capped at 12 effects at once. Shadows remain disabled.

One in five eligible minnows, shrimp and crabs may seek rock shelter. No more than six can reserve cover at once, with one guest per rock. They swim to an exposed skirt beside the rock, linger briefly, and abandon it when a predator approaches. Other bait continue roaming normally.

Shrimp use the same kick/glide animation and physics whether controlled by AI or a player. Charge LMB and release: the nose dips during the upward kick, then the body levels and glides forward before sinking. Recovery protects the kick but allows the next kick to interrupt the glide. AI decisions pass through the player steering/input driver; squid propulsion pulses also live in the shared motor.

For visual checks, launch Godot with `-- --readability-preview`. It saves floor, above/below-water and shrimp kick/glide screenshots beside the project folder, then exits.

## Navigation, escape chains and diagnostics
Crabs now update their heading while crawling, with home and boundary steering taking priority over ambient turns. Squid cancel their descend state near the ground and choose a powered rise; the shared motor also blocks downward jets at ground clearance.

Full escape charge takes 0.65 seconds. A release during recovery is buffered once and fires when ready. AI sometimes chooses two kicks/dashes with varied charge: shrimp kick twice; squid/crab reverse sides; minnows alternate roughly half-charge darts at 45 degrees either side of a stable bearing. Players can reproduce these using consecutive LMB holds/releases and A/D. Squid uses a fixed boat-relative side axis so left then right remains opposite after moving.

G adds a 0.28-second backswing, then varies cast distance by 22 percent and direction by 0.3 radians around the inward bearing. No camera teleport is added.

Splash nodes are allocated once and reused; bait share immutable materials, and distant appendage animation runs less often. Physics stays at the normal rate. F9 saves the last session's bounded hitch samples to `user://performance-hitches.csv` (the full path prints in the Godot output). Capture this after a slowdown to help distinguish physics cost from rendering/other stalls. `-- --perf-check` now runs 75 seconds of wall time; add `--perf-tour` for a moving camera, or `--perf-duration=120` for a longer run. Two 75-second runs (stationary and moving camera) measured medians of 16.66/16.67 ms, p95 of 17.20/17.10 ms, and worst frames of 54.37/49.65 ms. The reported multi-second stalls were not reproduced; their cause is not yet established.
