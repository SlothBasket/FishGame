# How the prototype works

## Reading order and file map

Start with `FishInput.gd`, then `FishPlayer.gd`, then `FishFeeding.gd`. These explain player intent, physical movement and attacks. Read the bait scripts afterward. Visuals and level construction can be changed independently.

| File | Owns | Typical reason to edit |
|---|---|---|
| `Scenes/FishPlayer.tscn` | CharacterBody3D, sphere collider, Visual, camera pivot and SpringArm | Change scene composition or saved Inspector settings |
| `FishInput.gd` | Intent fields and pure movement/heading math | Change what controls mean or how propulsion works |
| `FishPlayer.gd` | Local input, heading, velocity, camera, exported tuning | Change swimming feel, growth limits or control mapping |
| `FishFeeding.gd` | Charge/dash/recovery, swept hits, rewards | Change strike behavior, eating or cooldown |
| `FishVisual.gd` | Player mesh and cosmetic animation | Change silhouette, colors, jaw or charge tell |
| `BaitMotion.gd` | Command vocabulary and live/controlled drivers | Change behavior durations, choices or driver input |
| `LureTestController.gd` | Tab debug mode and fisherman-style input bridge | Change test keys, lure presets or anchor placement |
| `BaitActor.gd` | Shared bait motor, claim gate and swallow | Change bait speed/turn limits, nutrition or bite response |
| `BaitVisual.gd` | Bait meshes and speed/twitch animation | Change a bait's appearance for both live and controlled versions |
| `BaitSchool.gd` | Zone placement, population and respawn timers | Change where prey live and how spread out they are |
| `Geometry.gd` | Sphere/triangle/static-box helpers and materials | Change shared procedural art building blocks |
| `Reef.gd` + `Scenes/Reef.tscn` | Arena generation, lighting, HUD, startup | Change map dimensions, obstacles, hoop landmarks or text |
| `FeedingHud.gd` / `FeedingBurst.gd` | Charge ring, notices and bubbles | Change feedback without changing gameplay |
| `FeedingChecks.gd` | Headless regression tests | Check behavior after a change |

The GDScript files keep the original system boundaries. GDScript has no C# partial classes, so `FishFeeding` is now a `RefCounted` component created by `FishPlayer`. Access its state through `fish.feeding`. It is not a second moving body and has no independent physics tick.

## One player physics tick

1. `FishPlayer` gets a `FishInput`: local keyboard/mouse input, or `command` when `external_input` is true.
2. `FishFeeding.update_attack()` detects hold/release, advances charge/recovery and starts a strike when appropriate.
3. During a strike, `advance_dash()` moves the player. Otherwise `FishInput.steer_heading()` updates physical heading and `next_velocity()` computes propulsion/drag, then `move_and_slide()` resolves collisions.
4. `Visual.rotation` is set from heading. Its scale comes only from growth. Charge and biting values are passed into its animation script.
5. HUD reads the state; it never awards food or drives the controller.

`_physics_process(delta)` changes gameplay. `_process(delta)` animates visuals. Rates multiply by elapsed seconds so behavior does not depend on rendering FPS. The engine tests compare 30/120 Hz math for speed and turn rate.

### Aim, heading and velocity are different

`FishInput` contains `throttle`, `steering`, `vertical`, `aim_direction`, `boost`, `bite_held` and `cancel_bite`. Aim is a world-space unit direction, not a Camera3D reference. This lets a test, AI or later server submit the same intent.

`fish.heading` is the actual forward unit vector. The camera pivot rotates independently. The CharacterBody3D transform is kept unrotated because its sphere collider is rotationally symmetric and the camera must not inherit fish turns. Heading is the physical orientation state; Visual displays it, with roll zero.

W turns yaw/pitch toward aim at limited rates. A/D adds a yaw contribution, with a reduced rate when not swimming forward. S applies negative propulsion along heading and does not chase camera aim. Space/Ctrl adds world-vertical propulsion. Velocity approaches that target with acceleration; it can lag heading while turning or braking. Nothing orients the fish by reverse velocity.

All directions use Godot's convention: forward is local **-Z**, up is **+Y**. `FishInput.angles()` and `from_angles()` convert heading to/from pitch/yaw. `turn_toward()` handles angular limits, including opposite directions without an undefined rotation axis.

## Movement and strike tuning

These are exports on FishPlayer. Edit values in the Inspector for the scene you want to change. An Inspector override takes precedence over the script default.

| Property | Default | Effect |
|---|---:|---|
| `swim_speed` / `boost_multiplier` | 8 / 1.85 | Forward m/s and boost ratio |
| `acceleration` / `water_drag` | 12 / 4 | Acceleration toward input / braking with no propulsion |
| `reverse_speed_multiplier` / `reverse_acceleration` | 0.4 / 6 | Backpedal speed ratio and acceleration |
| `vertical_speed_multiplier` | 0.7 | Space/Ctrl propulsion relative to forward speed |
| `forward_turn_rate` / `pitch_turn_rate` | 85 / 65 | Camera-follow yaw/pitch limits, degrees/sec |
| `manual_steering_strength` / `idle_pivot_multiplier` | 125 / 0.45 | A/D yaw assistance and reduced stationary/reverse assistance |
| `full_charge_time` / `charge_swim_multiplier` | 1.4 / 0.25 | Charge cap in seconds and propulsion while charging |
| `minimum_lunge_distance` / `maximum_lunge_distance` | 3 / 15 | Travelled path length in metres |
| `lunge_speed` | 26 | Strike speed in m/s |
| `maximum_lunge_turn_angle` | 65 | Target's maximum angle from release heading, degrees |
| `lunge_turn_rate` | 220 | Actual turn rate toward that target, degrees/sec |
| `bite_cooldown` / `bite_radius` | 0.45 / 0.9 | Recovery seconds / sweep radius before size and prey radius |
| `growth_per_food` / `maximum_size` | 0.01 / 1.6 | Growth increment and cap |

To make a heavier fish, first lower yaw/pitch rates and acceleration. To make reverse easier, change the reverse ratio without changing forward speed. These per-instance values can later move into species Resources; a species framework is not needed yet. Alternating A/D tail-beat speed boosts are a future idea, not implemented.

## Feeding and collision safety

On release, `release_heading` records actual forward. `dash_target` is requested aim clamped to the configured cone. Physics starts along the existing heading and turns toward the fixed target over time. Camera changes after release do not retarget the strike.

Dash movement uses at most 1/120-second substeps so curved sweeps remain close to the actual arc. Each step uses `move_and_collide()`, sweeps only the segment actually travelled, and tests a terrain ray between the nearby fish path and the bait. That prevents tunneling past small bait or eating through a wall. Collision ends the attack; an unobstructed finish preserves forward momentum at normal swim speed along the final heading.

`BaitActor.try_bite()` marks the bait claimed before emitting signals or awarding nutrition. A second claim returns false. Live bait calls `fish.feeding.award_food()`. All sources emit `bitten(bait, eater)`; fisherman bait does not give food. Its visual shrinks into `fish.mouth_position()` and is freed after 0.22 seconds.

FishingBaitDriver uses the horizontal anchor bearing only. retrieve_speed controls effort; steer_input bends the course. Vertical speeds are owned by the shared BaitActor motor, so AI and human bait always use the same profile.

Collision layers: **1 = world**, **2 = player**, **4 = bait**. Player and bait movement collide with world geometry. Eating uses the explicit sweep instead of body-contact collision. The camera arm ignores the player and bait. Keep these masks consistent when adding obstacles.

## Visual changes

`FishVisual` builds one main ellipsoid, a back color form, tail/fins, eyes and a small fixed-size mouth opening. Its internal `_body` performs a small yaw wiggle while charging; the physical heading and collision body do not wiggle. `charge_intensity` controls wiggle/tail speed, and `biting` only reveals the mouth and lowers the jaw. The mouth never scales up during charge.

To change the tell, select Visual and edit `charge_wiggle_degrees`, `charge_tail_amplitude` and `charge_frequency`. To replace art, keep a model facing -Z below the visual root and preserve the three inputs: `swim_intensity`, `charge_intensity`, `biting`. Keep body growth on the Visual root rather than using it for charge squash/stretch.

## Bait behavior and future controlled bait

`BaitMotion.gd` contains nested classes to keep the small abstraction together:

- `BaitCommand(direction, effort, twitch, action, idle_action)` is the legal vocabulary. Actions include cruise, burst, glide, hover, sink/rise, dart/jerk, jig/fall, crawl and pause. Idle enums remain for compatibility, but pose rendering and hotkeys are disabled.
- `IBaitDriver` is the base contract with `sample(bait, delta)`; GDScript inheritance replaces the C# interface.
- `LiveBaitDriver` chooses finite behaviors with timers and its own RNG.
- `ControlledBaitDriver` returns its externally supplied `command`.
- `FishingBaitDriver` turns retrieve/jerk/jig inputs and a world-space anchor into the same commands, using the shared swimming() and gliding() helpers.

`choose_behavior()` is the easiest place to change prey. Minnows cruise/glide/burst/dart across broad regions; shrimp hover, settle and kick; squid hover/glide/pulse; crabs rest, crawl and scuttle on the floor. Outside `roam_radius`, the next decision biases inward. Preferred depth and `depth_band` produce different layers. The actor still owns acceleration, turning, sinking and collision, so AI cannot bypass controlled-bait limits.

Example of a future lure, using the existing actor and visual:

```gdscript
var lure = BaitActor.new()
lure.kind = BaitMotion.Kind.SHRIMP
lure.source = BaitMotion.Source.FISHERMAN
var driver = BaitMotion.ControlledBaitDriver.new()
lure.driver = driver
lure.position = Vector3(5, 4, -10)
lure.bitten.connect(on_lure_bitten)
add_child(lure)
driver.command = BaitMotion.BaitCommand.new(Vector3.FORWARD, 0.8, 1.0)
# Later input ticks can change driver.command to coast, steer, or pulse.
```

Connect `on_lure_bitten(bait, eater)` to a future fight session. Retain rod/player state in that session because the swallowed visual is freed. `BaitVisual` never reads source, so live and fake versions have the same silhouette and animation rules. To add a species later, extend Kind, the motor defaults/nutrition, behavior choices and visual construction together.

Pass an explicit seed to `LiveBaitDriver.new(home, seed, radius)` for reproducible tests. Normal play randomizes; future server authority should choose/run behavior. Seeded reproducibility is a debugging aid, not a networking implementation.

## Level and population edits

`Reef` exports `arena_width`, `water_depth`, and `rock_count`. Width/depth drive the water plane, floor, walls, terrain distribution, HUD depth and bait-school dimensions. The terrain seed stays fixed so layout is stable while live bait behavior varies.

`BaitSchool.ZONES` stores eight centers as fractions: x/z multiply arena half-width; y multiplies water depth. `ZONE_KINDS` maps those zones to minnow, shrimp, squid or crab. Move a zone by changing its vector. `zone_population` defaults to four and `individual_spacing` to four metres. Shrimp occupy lower structure, squid and minnows use open midwater, and crabs start near the floor. `roam_radius` varies between individuals. `respawn_delay` controls replenishment. Set generated-school exports in Reef before `add_child(school)`.

Do not increase population just because the map grows. Try changing centers, spacing and roam radius first. New zones can use additional hoop landmarks in `Reef.build_reef()`; landmarks are visual navigation aids, not spawning logic.

## Future authority boundary

Local input creates intent; the camera remains local. A future server can run `FishPlayer` with `external_input = true`, own heading/velocity, call the same feeding/claim logic, and own bait drivers and respawns. Replicate results rather than trusting clients to set food or claim hits. No RPCs, prediction, synchronization, rod controls or fights are implemented in this pass.

## Revised bait motor and tuning
BaitActor separates passive buoyancy from facing: FALL/SINK/RISE use effort as a fraction of sink_speed in m/s, without changing heading. Passive movement and GLIDE have slower velocity response for coasting. Commands are never mutated by the motor.
FishingBaitDriver.anchor_position sets horizontal pull bearing only. LureTestController resets heading and impulses for every species and owns the diagonal tracking camera.
LiveBaitDriver senses fish_predators and forward terrain every quarter-second. Edit choose_behavior for probabilities, durations and heading changes. BaitSchool randomizes spacing/headings and probes terrain before spawning. Floor clearance must be at least collider radius.

## Shared rising stroke and sinking glide
BaitMotion.swimming() and gliding() are used by both live and fishing drivers. BaitActor interprets CRUISE/BURST as forward speed plus 18% upward speed; GLIDE retains 24% forward speed and sinks at 0.65 times sink_speed. Vertical velocity approaches its target independently, so forward deceleration cannot hide sinking. Crab remains bottom-bound.
JERK/DART uses a short lateral target at 1.5 times swim_speed; JIG_UP uses little forward motion and 2.8 m/s upward motion. These are movement impulses, not animation presets. Live AI selects stroke/glide phases and uses depth bands to bias the next phase.
LureTestController creates a Camera3D with a fixed (8,4,6) offset and smoothed position tracking. Tab activates it; leaving restores fish.camera. No rod line or physical casting constraints are simulated yet.

## Species profiles, rod limits and camera controls
The species block in BaitActor._physics_process owns the final velocity profile for both drivers. Squid travel upward at 2 m/s times effort and fall at 1.5 m/s with very little horizontal motion; E rises at 4.5 m/s. Shrimp settle at 1.4 m/s and E kicks upward at 5.5 m/s. Crabs sink at 4.5 m/s and remap vertical jig intent to lateral escape. Edit these values here, not separately in each driver.
LiveBaitDriver.choose_behavior chooses species-specific phase durations. Minnows alternate cruise/coast, shrimp mostly scoot with occasional kicks, squid alternate rise/drop, and crabs crawl/rest/scuttle. Surface-spawn minnows descend until near the bottom. BaitSchool chooses surface starts and places shrimp above sampled terrain.
FishingBaitDriver.cast_direction records the original horizontal bearing; steering_limit_degrees defaults to 40. Each input computes a fresh absolute deflection, including on release. Repeated frames cannot accumulate a U-turn. Reset and species switching clear cast heading and impulses.
LureTestController.orbit_mouse handles yaw/pitch with pitch limits. C toggles use_fish_camera without releasing bait control; the preference persists across Tab. Mouse input is consumed for bait orbit, while fish-view mode keeps the normal fish camera mouse handler. orbit_distance sets zoom distance. Camera switch and orbit math are covered by checks.
