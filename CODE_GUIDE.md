# FishGame: movement and tuning guide

This is the current implementation, not a history of earlier experiments. All gameplay is GDScript. The sand and water materials use Godot's shader language only for drawing. Distances are metres, speeds are metres/second, timers are seconds, and `delta` is the elapsed time for a simulation or render tick. Y points upward; a model's nose normally points along local -Z. Shrimp deliberately face the other way so their tail leads motion.

## Where to make a change

| Desired change | File and entry point |
|---|---|
| Player fish speed, turning, drag, jump or bite | `Scripts/FishPlayer.gd` exports; math in `FishInput.gd` and `FishFeeding.gd` |
| Fish starting size and growth curve | `FishPlayer.gd`: `starting_size`, `growth_rate`, `maximum_size`, `size_multiplier()` |
| Bait speed, collision, escape strength or shape of a kick | `BaitActor.gd`: exports, `_physics_process()`, `start_flee()` |
| Player bait buttons and charge buffering | `BaitMotion.gd`: `PlayerLiveDriver.sample()` |
| AI decisions, depth preferences, threat response or paired escapes | `BaitMotion.gd`: `LiveBaitDriver.sample()` and `choose_behavior()` |
| Population, spawn depth, pod locations and respawns | `BaitSchool.gd`: exports, `_ready()`, `_spawn()` |
| School spacing and regrouping | `BaitPod.gd` and the pod block in `LiveBaitDriver.sample()` |
| Boat movement, aiming, cast distance and cameras | `LureTestController.gd` |
| Gull hunting and diving | `Seagull.gd` |
| Body geometry and wiggles, without changing movement | `BaitVisual.gd`, `FishVisual.gd`, `Geometry.gd` |
| Floor, water, rocks and arena boundaries | `Reef.gd`, `Shaders/Sand.gdshader`, `Shaders/WaterSurface.gdshader` |

An `@export` appears in Godot's Inspector on a node using that script. Most bait are created at runtime, so change their default exports in `BaitActor.gd`, or set a value in `BaitSchool._spawn()` before `add_child(bait)`. Driver classes inherit RefCounted, not Node; set their fields where they are constructed. A zero `swim_speed`, `acceleration` or `turn_rate` means "use the species default" and is replaced in the actor's `_ready()`.

## Player fish: input to motion

`FishPlayer.read_local_input()` reads the keyboard and camera and constructs `FishInput`. With `external_input` true, tests and bait/boat mode supply `command` instead. The input object contains throttle, yaw steering, vertical intent, boost, camera aim and bite/cancel state; it never moves anything.

`FishPlayer._physics_process()` first updates the attack, then chooses exactly one path: feeding dash, airborne motion, or normal underwater swimming. This prevents several systems from competing to write velocity. `FishInput.steer_heading()` steers forward swimming toward mouse aim and adds A/D yaw assistance. S reverses along the existing facing; it never flips the model. `next_velocity()` computes a target vector, caps combined forward/vertical speed, and approaches it with acceleration or drag. The CharacterBody performs collision movement; the visual follows heading rather than velocity, preserving backward swimming.

| FishPlayer setting | Default | Effect |
|---|---:|---|
| `swim_speed` | 8 | Normal forward speed |
| `boost_multiplier` | 1.85 | Forward boost speed multiplier |
| `acceleration` | 12 | How quickly velocity approaches powered swimming |
| `water_drag` | 4 | How quickly released input stops the fish |
| `reverse_speed_multiplier` | 0.4 | Reverse speed relative to swim speed |
| `reverse_acceleration` | 6 | Response while reversing |
| `vertical_speed_multiplier` | 0.7 | Strength of Space/Ctrl relative to forward propulsion |
| `forward_turn_rate`, `pitch_turn_rate` | 85, 65 | Mouse-follow yaw and pitch, degrees/second |
| `manual_steering_strength` | 125 | Additional A/D yaw, degrees/second |
| `idle_pivot_multiplier` | 0.45 | Reduced A/D turn strength without forward throttle |
| `mouse_sensitivity` | 0.0025 | Mouse pixels to camera rotation |
| `air_gravity` | 12 | Downward acceleration above the surface |
| `max_breach_horizontal_speed`, `max_breach_vertical_speed` | 8, 9.5 | Entry-to-air speed limits; prevent map-spanning jumps |

The pitch clamp of 85 degrees in `FishInput.steer_heading()` keeps ordinary swimming away from a vertical yaw singularity. `turn_toward()` rotates around the cross-product axis; its explicit antiparallel fallback handles exactly opposite directions instead of producing an undefined axis. `approach_angle()` wraps angular differences so turning across -PI/PI takes the short route. These are numerical protections, not extra steering modes.

Fish state: `heading` is the actual facing, `velocity` is the CharacterBody velocity, `_spawn` is the R-reset location, `_camera_yaw/_camera_pitch` hold view orientation, and `airborne` selects gravity. `_body_radius` remembers the original collision size for growth. `suppress_bite_until_release` stops a click used to recapture the cursor from accidentally firing a bite. Reset cancels an attack and restores position, momentum and view; it preserves food and growth.

## Feeding dash, collision and growth

`FishFeeding.update_attack()` detects the start of an LMB hold and its release. Charge chooses a travel distance; it does not directly choose damage or speed. Release clamps aim once to the permitted cone. `advance_dash()` moves in substeps no larger than 1/120 second, turning physically toward that aim. Every travelled subsegment runs `sweep_bite()` so small bait cannot be skipped at high speed. A terrain ray prevents eating through a rock.

| Setting on FishPlayer | Default | Effect |
|---|---:|---|
| `full_charge_time` | 1.4 | Time to maximum feeding distance |
| `minimum_lunge_distance`, `maximum_lunge_distance` | 3, 15 | Tap/full-charge travel distances |
| `lunge_speed` | 26 | Underwater dash speed |
| `maximum_lunge_turn_angle` | 65 degrees | Allowed release aim relative to facing |
| `lunge_turn_rate` | 220 degrees/second | How quickly the dash bends |
| `charge_swim_multiplier` | 0.25 | Swimming speed while charging |
| `bite_radius` | 0.9 | Swept bite radius before growth scaling |
| `bite_cooldown` | 0.45 | Recovery after the fish's feeding dash |
| `bite_grace_duration` | 0.2 | Short catch window after the dash finishes |

A floor contact with upward normal greater than 0.55 redirects the remaining movement along the floor tangent. A frontal wall stops the dash. The tangent must retain at least 15 percent of lunge speed to avoid treating a nearly direct collision as useful movement. Above water, gravity replaces underwater propulsion, while the bite remains active. `closest_point()` supplies the nearest point on each segment, including a safe zero-length case.

`_charge_time`, `_dash_remaining` and `cooldown_remaining` track the three attack stages. `_was_held` detects input edges. `release_heading` and `dash_target` freeze the release cone reference and target. `_trail_time` emits cosmetic bubbles every 0.045 seconds. `grace_remaining` owns the final catch window; `meal_notice_time` and `bite_flash` only drive feedback. Food counters and `last_meal` drive the HUD.

`BaitActor.try_bite()` marks an actor claimed before emitting signals, ensuring one reward even if several strikes touch it. Live food grants nutrition; `Source.FISHERMAN` preserves a tested hook/callback-only path for a future deceptive bait controller. It is not an extra menu species or a second movement system. The current five test species are ordinary live food. Fight mechanics are not implemented.

Growth is an exponential approach to a cap:

```gdscript
starting_size + (maximum_size - starting_size) * (1.0 - exp(-growth_rate * food))
```

| Growth setting | Default | Tuning consequence |
|---|---:|---|
| `starting_size` | 0.58 | Smaller values make early growth more dramatic |
| `maximum_size` | 2.1 | Asymptotic upper size, in model scale units |
| `growth_rate` | 0.055 | Larger values reach the cap with fewer meals |

At 0/10/20/40 food, scale is approximately 0.58/1.22/1.59/1.93. Each equal food increment adds less size than the previous one; size never decreases. Visual size, collision radius, mouth position and bite radius all use the same multiplier. Changing growth does not secretly increase movement speed. `update_growth_collision()` runs at startup and after eating; normal render/physics updates apply the visual scale.

## Shared bait command and motor

There are six rendered kinds: minnow, shrimp, squid, crab, mullet and gull. `LureTestController.ROSTER` contains only the first five. The former two artificial test species and their driver are gone. There is no cover-seeking system.

A `BaitCommand` contains direction, effort (0-1), action, optional descend/arrival intent, and `flee_fraction` (-1 means no escape request). `twitch` is an optional visual intensity used by scripted commands; escape animation also supplies it automatically. The four actions are PAUSE, CRUISE, GLIDE and RISE. `swimming()` and `gliding()` make the common forms. `ControlledBaitDriver` simply returns a supplied command for tests; `PlayerLiveDriver` reads assigned input fields; `LiveBaitDriver` decides those inputs automatically. None of them moves a Node.

`BaitActor._physics_process()` executes in this order:

1. A claimed actor stops simulating. Cast windup/flight, if active, runs before normal controls.
2. Squid refresh a downward floor probe every 0.25 seconds. The driver produces one command and the shared recovery timer ticks down.
3. An accepted escape request initializes a species-specific velocity/sequence.
4. Normal heading steers toward command direction at `turn_rate`, unless escaping or airborne. The motor builds a cruise/glide/rise target, then applies species and descend/arrival overrides.
5. Air gravity, escape velocity or normal acceleration owns this tick's velocity. Entry sinking and the player squid radius limit are applied afterward.
6. `move_and_slide()` handles terrain. Bottom clearance, mullet re-entry and visual facing are updated.

| Species | Swim speed | Acceleration | Turn rate (degrees/s) | Base hit radius | Food |
|---|---:|---:|---:|---:|---:|
| Minnow | 2.9 | 4.5 | 100 | 0.28 | 1 |
| Shrimp | 2.7 | 14 | 250 | 0.28 | 4 |
| Squid | 2.8 | 6 | 105 | 0.42 | 3 |
| Crab | 1.35 | 8 | 180 | 0.38 | 5 |
| Mullet | 3.8 | 6 | 100 | 0.34 | 3 |
| Gull | 6 | 5 | 90 | 0.55 | 5 |

The default arrays in `BaitActor._ready()`, `hit_radius()` and `nutrition()` follow `Kind` order. `body_size` scales both visible bait and its collision/bite radius. `randomize_size(rng)` runs before adding spawned AI or player bait: minnows use base 0.64, other species 0.8, each multiplied by a uniform 0.85-1.15. Food values do not vary with size. Tests may set exact sizes directly. Gull flight uses `Seagull` rather than the generic underwater motor.

Normal cruise adds upward velocity equal to 18 percent of powered swim speed. Glide retains 24 percent forward speed and sinks at `sink_speed * 0.65`; its horizontal response is 1.8 and vertical response 2.5. `sink_speed` defaults to 1. `powered_descent_speed` is 2.8; RISE uses 70 percent of it. Arrival is an explicit bounded velocity toward the rod origin, preventing reeling past the boat.

Species override that baseline: shrimp retain 55 percent horizontal travel and naturally descend at 1.4; crabs descend at 4.5 and stop horizontal movement on release; squid drift horizontally at 0.45 and push vertically in pulses; mullet seek `water_height - surface_depth` using a spring factor of 2, bounded between -1.5 and +2.5 vertical speed. Squid's pulse is `0.2 + 0.8 * max(0, sin(age*4))^2`, multiplied by powered effort and 2.0. Change that expression in the shared motor to alter both AI and player pulse shape.

`_apply_bottom_constraint()` probes up to four metres down. It maintains `bottom_clearance` (0.32) or the hit radius plus 0.02, whichever is larger. Crabs get a 0.3 m settling margin. It never pins an upward kick. Collision layers: world/floor is 1, edible bait is 4, and the ordinary-bait surface barrier is 8. Fish, mullet and gull can cross that surface layer.

## Bait escape tuning and internal state

| BaitActor value | Default | Effect |
|---|---:|---|
| `flee_charge_time` | 0.65 | Time to full bait escape charge |
| `flee_cooldown` | 0.95 | Minimum time between escapes |
| `minimum_flee_strength`, `maximum_flee_strength` | 0.25, 1 | Tap/full charge strength mapping |
| `dart_speed` | 10 | Minnow forward dart speed before strength scaling |
| `minnow_wiggle_speed`, `minnow_wiggle_frequency` | 2.2, 12 | Side velocity and angular frequency of its small dart wiggle |
| `shrimp_kick_speed` | 4.5 | Upward kick speed before strength scaling |
| `shrimp_glide_speed`, `shrimp_glide_duration` | 4, 1.1 | Tail-first glide speed and duration |
| `squid_jet_speed` | 5.5 | Jet speed along the requested 3D vector |
| `crab_scuttle_speed` | 5 | Lateral escape speed |
| `breach_impulse`, `airborne_gravity` | 10, 6.5 | Mullet jump strength and air gravity |
| `surface_depth` | 0.45 | Mullet's preferred depth below water |
| `squid_roam_radius` | 8.4 | Player squid's horizontal boat radius |

`start_flee()` maps charge to strength once and sets the sequence. Minnows lock `_escape_axis`, add a sinusoidal lateral component, and keep tracking forward. Shrimp use the commanded tail axis: kick for 0.22-0.5 seconds at horizontal `3 * strength` plus upward kick speed, then blend into a tail-first glide. Glide speed eases to 45 percent and vertical speed changes from +0.65 to -0.9. The velocity blend rate is 22. Their visible yaw is rotated PI from travel heading and their nose pitches down during the kick. Crabs select the side of their unchanged body heading closest to the escape request. Squid use the requested normalized vector, with no turn cone for jets. Mullet retain forward travel and begin an airborne arc.

`flee_remaining` is escape duration; `flee_recovery` is its independent re-trigger gate. `_escape_age`, `_escape_axis` and `_escape_strength` describe the current sequence. `_shrimp_kick_duration` stores the charge-dependent first phase. `flee_velocity` persists while escaping. `_breaching` starts mullet gravity even before it crosses the waterline; `airborne` records crossing. `_motion_age` drives squid pulses. `_visual_pitch/_visual_yaw` smooth presentation, never alter physical velocity. `_floor_scan` schedules the cached `floor_height` probe.

The player squid radius removes outward velocity in the final 0.6 m and adds a gentle inward correction capped at 3 m/s. Tangential and inward jets remain possible. A floor clearance of 0.65 blocks downward squid velocity at terrain. This physical safety margin is distinct from the AI's much higher preferred cruising band.

## Player bait input, charge and cameras

`PlayerLiveDriver` fields `throttle`, `steering`, `rise`, `descend` and `escape_held` are assigned by the test controller. `use_anchor` enables boat-relative bearing; otherwise ordinary direction is based on the actor's heading. `steering_limit_degrees` (45) limits ordinary rod deflection. Near the origin, retrieve arrival begins within 6 horizontal metres and aims 0.65 below the waterline.

For squid, `aim_direction` is camera forward and bypasses that cone on escape. `squid_axis` is a fallback lateral axis for scripted input without camera aim. `squid_manual_jets` makes Space/Ctrl edge-triggered 0.65-charge jets rather than continuous rise/descend. W uses 30 percent retrieve effort and an arrival cap of 0.9 m/s; release sinks. AI sets `squid_manual_jets` false so its continuous depth decisions are not mistaken for keyboard presses.

`charge` accumulates while LMB is held, including during recovery. `_held` detects release. `_pending_escape` stores one released direction/fraction until the actor is ready; the `fraction` metadata preserves charge without firing the returned ordinary command early. `_vertical_held` detects a new up/down press without repeating a held key. `clear_input()` clears every transient input/queued escape when resetting or changing modes. Crab's `escape_side` selects its lateral direction.

## AI decisions, depth and pods

`pause_clock` schedules hands-off intervals every `pause_interval_min/max` (4-9 s), staggered by each driver seed. `pause_remaining` holds a random 0.5-1.5 s pause. The final command becomes ordinary player GLIDE, so momentum eases and bait sinks normally instead of freezing. Fish threats cancel the pause; mullet dives also override it. Active physical escapes finish normally.

`LiveBaitDriver.choose_behavior()` chooses short cruise/coast/rise/drop/rest phases. `_action`, `_direction`, `_effort` and `state` describe that decision; `_duration` is the chosen span and `_remaining` counts it down. `_turn_clock` requests small direction changes every 0.6-1.8 seconds, within +/-0.65 radians. Boundary/home corrections are applied later, so a random turn cannot keep crabs stuck at a rim. `home` and `roam_radius` define the return region; `preferred_y` and `depth_band` define depth preference.

| AI field | Default | Effect |
|---|---:|---|
| `sense_interval` | 0.3 | Staggered predator/peer/obstacle checks |
| `flee_trigger_distance` | 14 | Fish detection distance for ordinary bait |
| `mullet_threat_distance` | 20 | Earlier mullet escape anticipation |
| `peer_trigger_distance`, `peer_recovery_time` | 1.7, 9 | Small, infrequent responses to escaping neighbors |
| `escape_interval_min/max` | 3 / 7 | Ambient wait between escape requests |
| `ai_charge_min/max` | 0.12 / 1 | Random-charge tuning; ambient charge also has a 0.3 floor |
| `sequence_chance`, `minnow_sequence_chance` | 0.45 / 0.7 | Chance of a paired escape |
| `squid_floor_clearance` | 6 | Minimum AI cruise clearance over terrain |
| `depth_band` | 5 | Distance above/below preferred depth before correction |

`_sense_time` schedules scans. `_threat/_threat_direction` cache the first detected predator response; `_peer_recovery` prevents repeated neighbor chain reactions. `_escape_clock`, `_charging_escape` and `_random_charge` schedule ambient holds/releases separately from swimming phases. Threats override the wait but still obey physical recovery. `_burst_pending`, `_burst_axis`, `_burst_side` and `_burst_strength` hold the second step of a pair; `_use_burst_bearing` preserves a stable reference for that step. Minnows alternate 45-degree darts at 0.35-0.6 charge; squid/crabs reverse sides; shrimp repeat a tail-first kick. Paired spacing adds 0.2-0.45 seconds to physical recovery.

Mullet's `_mullet_dive_wait` starts at 5-15 seconds, then waits 12-22 seconds between dives. `_mullet_dive` holds a 3-5 second descend phase; afterward the shared surface-seeking motion returns them upward. Squid use a floor-aware lower bound `max(floor + 6, preferred_y - depth_band)` and an upper bound `min(water - 2, preferred_y + depth_band)`. Low squid clear their drop state and request powered rise. Downward escapes near the lower bound are redirected upward. No player position is teleported by this AI correction.

`player_reproducible_command()` translates AI decisions through `PlayerLiveDriver`: ordinary turns obey the same 45-degree input cone, depth commands use the same motor, and escape strength/cooldown remains shared. Wild bait have no boat tether. Shrimp panic direction and squid jets may point directly away from danger; their resulting sequence still comes from the same physical implementation.

`BaitPod` is only a gathering point plus weak references to its minnow or mullet members. It never moves an actor. Each minnow has a `pod_slot` about 4.5 m from the pod center, with 1.8 m vertical variation. A nearby fish refreshes `scatter_remaining` to 5-9 seconds; during that time normal escape/swim decisions take over without cohesion. When calm, the command direction blends toward its slot with weight `clamp(distance/14, 0, 0.65)`. Height error greater than 1.8 m requests rise/descent. These values are in the pod block of `LiveBaitDriver.sample()`.

`pod_separation` is cached on sensing ticks, using only that pod's members. `BaitPod.separation_distance` is 2.4 m and its repulsion is capped at 0.8. Increase slot radius or separation for looser schools; reduce cohesion's 0.65 cap for slower reunion. Do not apply this to every bait: only spawned minnow and mullet pod members receive a `pod` reference. Shrimp, crabs, squid and gulls remain independent. Mullet dive/airborne phases bypass cohesion so reunion cannot interrupt an escape; their slots have 5 m radius.

## Population and respawning

`BaitSchool` creates 194 actors by default: eight zones times `zone_population` 8, 12 upper-water bait, four independent mullet, four gulls, four surface entrants, eight minnow pods times `pod_population` 10, two mullet pods of eight, and `midwater_squid_count` 10. The minnow centers in `_ready()` span Y=4, 13-22 and 28 m; mullet pods are at 31.5 m. Edit those centers to move schools, or the population settings to increase density. Additional squid start at 14-24 m and all squid spawn heights are clamped to 14-25 m. Zone coordinates are fractions of arena width/depth; `individual_spacing` is 7 and `roam_radius` is 45.

`seed_value = -1` varies play; set a nonnegative value for repeatable spawning. `_rng` belongs to the school; each driver gets its own seed. `_respawns` stores species, home, radius and any pod/slot assignment. `respawn_delay` is 8 seconds and at most one replacement is built per render frame. Pod membership is preserved, and dead weak references are pruned when replacements join.

`_entry_baits` tracks the four descending surface entrants weakly. Every 5-9 seconds (`_entry_clock`), one that has reached below half depth is reset near the surface with downward velocity. This supplies non-player surface entries without accumulating more actors. `_spawn()` rays down to avoid embedding bottom bait in terrain; shrimp/crabs retain their bottom home but spawn at `water_depth - 0.5`, with downward speed 4 and entry duration 0.5 s. Every replacement follows the same surface entry, then uses the shared natural sinking motor (shrimp 1.4, crab 4.5 m/s). `arena_half_width` and `water_depth` are supplied by Reef.

## Boat setup and ballistic casting

`LureTestController.active` means the fish is frozen and boat/bait input is active. `boat_aiming` distinguishes boat setup from deployed bait. First G enters the boat from either fish or bait mode and removes the old test bait. WASD moves relative to the current boat heading, mouse sets heading and view pitch, X selects among five species. The second G casts along the selected horizontal heading. Pitch changes the view, not the landing distance. While reeling, coming within 1.2 m of `anchor_position - UP*0.65` automatically calls `cast_bait()` to enter boat setup. This check runs only after cast flight finishes; slack bait does not trigger it.

| Controller field | Default | Effect |
|---|---:|---|
| `cast_distance` | 65 | Nominal cast range |
| `cast_distance_variation` | 0.22 | Random range multiplier, about 51-79 m |
| `cast_angle_variation` | 0.12 radians | Small variation around player aim |
| `origin_move_speed` | 12 | Boat movement speed |
| `orbit_distance` | 10.8 | Bait camera distance |

The boat begins near an edge facing inward, but casts are no longer forced toward the center. A cast near a wall is shortened along the chosen ray to stay within +/-110 m. Boat movement is bounded to +/-105 m. `anchor_position` and boat position share one origin. `spawn_position` records the landing/reset point. `deployment_position()` puts squid directly below the boat before it can roam its 8.4 m radius.

`BaitActor.launch_cast()` clears old actions and stores origin/destination. A 0.28 s windup (`cast_windup_duration`) moves backward by a sinusoidal 1.5 m, rising 0.4 m at its peak, then returns to the launch point. The flight uses gravity 14 and an analytically calculated launch velocity to reach the destination in 1.8 s (0.55 for a squid drop). It ignores terrain collision during this controlled flight inside the arena. Landing sets downward velocity 4 and a 0.35 s entry period. `entry_remaining` holds at least 2.5 downward speed briefly before ordinary sinking/retrieve takes over.

`cast_windup`, `cast_remaining`, `cast_origin`, `cast_destination` and `cast_launch_velocity` hold that sequence. `clear_actions()` cancels it, escape and airborne state. Camera focus eases toward the moving bait at rate 5; it does not jump to the landing point. `boat_yaw/boat_pitch` describe boat view, `orbit_yaw/orbit_pitch` describe bait orbit, and `use_fish_camera` preserves C's third-person viewing preference. Squid orbit approaches vertical; other bait keep a shallower view range. Mouse sensitivity for these views is 0.004.

## Birds, visuals and performance

`Seagull` owns four phases: 0 level patrol, 1 prey dive, 2 water rest, 3 climb. `flight_height` is 10 m above the surface, `flight_speed` 11 m/s, and patrol vertical correction is capped at 2 m/s. It scans only for surface-near mullet every 0.8-1.2 s, predicts 0.45 s ahead, and begins diving within 14 horizontal metres. It keeps that target through the dive instead of losing it when it swims down.

`dive_speed` is 14, acceleration 18 (ordinary flight 10). Dive prediction uses 0.2 s and `hunting_depth` caps pursuit at 7 m. `alarm_sent` ensures one response per attack when the bird is within 11 m: a surface mullet has a 50 percent chance of a 0.9-strength jump; otherwise it receives a 3-5 s dive. A jump aborts the bird's attack. A diving mullet remains its target until contact, five-second timeout or depth limit. At contact within 1.1 m, `catch_attempted` allows exactly one `catch_chance` roll (0.35). `caught_by_bird()` removes the prey from collision/edible sets, plays its normal swallow toward `mouth_position()`, and emits the normal respawn signal without player points. Another predator cannot claim the same bait twice.

`climb()` targets 18 m forward and normal flight height for four seconds. After climbing, a 25 percent roll selects a floating rest of 4-8 s; otherwise patrol resumes. `remaining` is the phase timer, `prey` is a weak reference, and `scan_clock` limits searches. `BaitVisual.bird_pose` selects flight (0), swept/tucked dive wings (1), floating folded wings (2), or underwater recovery paddling (3). Wing angles ease at rate 10 rather than snapping. Body pitch follows velocity except while resting, when it stays level.

`BaitVisual` builds species geometry and animates appendages from speed/action/twitch. `_phase` advances by `delta * (4 + speed * 6)`. Animation state does not steer or accelerate bait. Visual updates are spaced at 0.06 seconds beyond 30 m and 0.12 beyond 60 m; bodies hide beyond 100 m. `_animation_wait/_animation_delta` preserve elapsed animation time at those lower rates. Physics always continues. `FishVisual` similarly handles tail/mouth pose from swim/charge/bite state.

`Geometry` shares low-resolution sphere geometry and immutable bait materials. Environment materials remain independent so water/rock changes cannot recolor bait. `FeedingBurst` is a short-lived, non-colliding bubble effect; `SurfaceFeedback` reuses a pool of 12 splash/ripple effects, detects crossings across a 0.12 m waterline band and returns effects to the pool after 1.3 seconds. These affect appearance only.

`Reef` owns a 240 m wide, 32 m deep arena with 24 clustered rocks, 650 instanced pebbles and visual hoops/particles. Shadows are disabled. Sand ripples use world-space shading; water streaks animate without moving the physical crossing plane. Adjust shader uniforms for material colors/pattern spacing, not movement code.

F9 saves bounded hitch records to `user://performance-hitches.csv` and prints the path. `PerformanceProbe` keeps at most 240 records over 50 ms, at most two per second, without file IO until requested. `-- --perf-check` runs a 75-second wall-clock benchmark; `--perf-tour` adds a moving camera. `--readability-preview` renders inspection screenshots beside the project. These diagnostics do not change the normal movement rules.

## How to validate a tuning change

Run `Launch.ps1 -Check` after changing script structure, then `Launch.ps1 -Test` for movement/collision checks. The suite checks physical trajectories, growth, live/fisherman bite routing, cast phases, roster, population, pod separation/reunion, squid floor/radius behavior, shrimp tail-first escape and gull dives. Retired-feature checks were removed together with their implementation. Use visual captures and actual play for feel; a passing test cannot establish whether pacing is enjoyable.

Change one family of variables at a time. For a faster shrimp escape, adjust shared kick/glide exports rather than adding velocity in AI. For schools that regroup sooner, adjust scatter timing rather than teleporting members. For stronger early growth, change starting size or growth rate rather than independently scaling the visual. Keeping each physical effect in its owning motor prevents AI and player behavior from drifting apart.
