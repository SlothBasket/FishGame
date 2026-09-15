# Code guide

## Ownership and tick flow

| File | Responsibility |
|---|---|
| FishInput.gd | Fish input intent and movement/steering math |
| FishPlayer.gd | Fish movement, water/air transitions, input/camera and exported tuning |
| FishFeeding.gd | Charge/lunge, swept bite, grace timer, terrain checks and rewards |
| BaitMotion.gd | Shared commands, live player input, AI decisions, artificial retrieve driver |
| BaitActor.gd | Shared species motor, escape execution, terrain constraints, swallowing |
| BaitVisual.gd | Procedural species meshes and locomotion animation |
| BaitSchool.gd | Spawn locations, surface mullet, respawn population |
| LureTestController.gd | Left-mouse input, camera switching/orbit, boat, origin motion, casting |
| Reef.gd | Terrain, water plane, boundaries, HUD and startup |
| FeedingChecks.gd | Headless regression checks |
| RockShelter.gd | One-guest cover reservation, global cap, collision-safe shelter spots |
| SurfaceFeedback.gd | Surface crossing detection, bounded splashes and expanding ripples |
| Shaders/Sand.gdshader | World-space sand ripples, large-scale color variation, distance antialiasing |
| Shaders/WaterSurface.gdshader | Animated surface streaks and view-angle transparency |
| ReadabilityPreview.gd | Automated floor/water/shrimp screenshot capture |

FishPlayer receives FishInput and calls FishFeeding. Underwater swimming steers heading and updates velocity. Airborne swimming keeps momentum and applies gravity. During a strike, FishFeeding advances short collision substeps and sweeps each actual travelled segment. Sloped floor collision redirects the strike; frontal walls end it. The grace timer allows short post-strike sweeps using normal movement. Cancel/reset clears it.

BaitActor samples one driver each physics tick. A command contains direction, effort, action, descend, and optional flee_fraction (-1 means no escape request). It does not identify AI versus human. The actor alone applies species speeds, collisions, escape recovery, and presentation. Live test bait awards food like other live prey; artificial lures emit bite callbacks without food.

## Drivers and escape scheduling

PlayerLiveDriver turns W/A/D/Space/Ctrl into organism commands. Left mouse uses one charge state; A/D selects crab/squid lateral direction. Holding fills charge; release sends a fraction. Squid escape uses a stable boat-relative lateral axis by default; Space/Ctrl select up/down. The motor bounds horizontal travel within `squid_roam_radius`. Artificial lures retain FishingBaitDriver and use the same left-mouse charge gesture for dart/lift.

LiveBaitDriver chooses ordinary phases separately from its escape clock. The clock schedules random charge durations and intensities for every live species. Nearby predators override the ambient wait, subject to the same BaitActor recovery gate. Mullet uses a wider threat distance for chase anticipation. Seeded RNG remains reproducible at a fixed tick rate. Squid chooses lateral/up/down jets. Its ordinary propulsion pulses are applied by the shared actor motor for both drivers.

start_flee is the single physical escape implementation. Shrimp kicks upward/backward with a nose-down pose, then glides forward and sinks; crab selects the lateral axis of its unchanged body heading; squid jets along the requested vector. Minnow escape velocity uses a fixed forward axis with a bounded sinusoidal lateral component. Mullet preserves forward speed, gains vertical impulse, leaves water, falls under gravity and resumes swimming after re-entry. Only fish and mullet ignore surface collision layer 8; ordinary bait still collides with it. Side boundaries extend above the surface.

## Main tuning values

| Owner | Variables / defaults |
|---|---|
| BaitActor | flee_charge_time 0.65 s; flee_cooldown 0.6 s; strength range 0.25–1 |
| BaitActor | dart_speed 11 m/s; minnow_wiggle_speed 2.2 m/s; minnow_wiggle_frequency 12 radians/s |
| BaitActor | shrimp_kick_speed 5 m/s; squid_jet_speed 6 m/s; crab_scuttle_speed 5.5 m/s |
| BaitActor | powered_descent_speed 2.8 m/s |
| BaitActor | breach_impulse 10 m/s; airborne_gravity 6.5 m/s²; surface_depth 0.45 m |
| LiveBaitDriver | escape_interval_min/max 2.5/6 s; ai_charge_min/max 0.12/1; ambient minimum charge 0.3 |
| LiveBaitDriver | flee_trigger_distance 14 m; mullet_threat_distance 20 m |
| FishingBaitDriver | steering_limit_degrees 45; retrieve_speed 1; arrival starts within 6 horizontal metres |
| LureTestController | cast_distance 65 m; cast_entry_speed 4 m/s; origin_move_speed 12 m/s; orbit_distance 10.8 m |
| FishPlayer | bite_grace_duration 0.2 s; water_height from Reef; air_gravity 12 m/s²; max_breach_horizontal_speed/max_breach_vertical_speed 8 m/s |

BaitActor exports can be overridden before adding a bait or through Inspector on saved scenes. Driver fields are set where the driver is constructed. Keep shared movement rates in the actor so AI and player cannot drift apart. Major existing swim/lunge settings remain on FishPlayer. Surface height is passed from Reef into fish/school and the test boat.

## Boat, casts and arrival

Boat.position and anchor_position use the same waterline coordinates. Alt+WASD updates both drivers immediately and cancels pending player charge without firing it. G chooses a center-facing bearing with +/-0.3 radians of variation and +/-22 percent distance variation. BaitActor.launch_cast integrates a ballistic arc from the boat to its destination before handing control back to the shared motor. Squid instead drops directly below the boat. Origin bounds leave room for the cast inside the arena.

Artificial retrieval tracks current boat bearing, fades rod deflection near it, then emits a bounded arrival velocity toward a point 0.65 m below the hull. Live test bait uses this arrival aid when W is held near the boat, but vertical controls override it. The actor interprets arrival without adding a second physics path. F resets to the current deployment point.

C retains the camera preference across Tab. Mouse input is consumed for bait orbit; fish-view mode uses the normal fish camera handler. Pitch is limited and roll stays zero. Squid visual pitch comes from actual velocity and is smoothed; crab translation does not rotate body facing.

## Tests and remaining manual checks

Run Launch.ps1 -Check after script structure edits, and Launch.ps1 -Test after movement changes. Tests measure trajectories and state transitions, including airborne feeding, floor glancing contact, random ambient escapes, dock arrival, strength variation and recovery. Review actual play for charge feel, visual pitch, camera framing and chase anticipation. These tests establish behavior, not whether the final movement feels right.

## Surface population and frame-time controls
Seagull.gd subclasses BaitActor to reuse catch/swallow/rewards, while owning bird flight/swoop/rest/take-off movement. GULL has a procedural BaitVisual mesh and is deliberately excluded from the controllable bait roster.
BaitSchool adds 12 upper-water prey, four surface-entry slots and four gulls. Roam radius defaults to 45 m; upper zones use 55 m. Entry slots recycle only once their prey is below half depth, at 5–9 s intervals. Population stays bounded. Spawning after a multi-catch is spread across frames.
Geometry.sphere shares one 16×8 unit sphere mesh; transforms provide shape variation. Actor collisions remain separate. LiveBaitDriver senses on staggered 0.3 s intervals, instead of scanning predators each physics tick. Peer checks only run on sensing ticks when no predator is present, and use a 1.7 m radius and 9 s peer recovery.
PerformanceProbe.gd records bounded hitch samples in normal play. F9 saves them. With --perf-check it runs a 75-second timed benchmark and exits; add --perf-tour to move the camera.
LureTestController casts inward from its bounded boat position and assigns a short downward entry period. PlayerLiveDriver applies an absolute ±45-degree boat-bearing deflection rather than accumulating turns. Escape/reset/cast/origin-modifier paths clear stale charge.

## Latest tuning points
- `Reef.arena_width` (240), `rock_count` (24), and `build_water` light settings control the simplified, shadow-free arena.
- `BaitSchool.zone_population` (6 per zone) produces 72 actors including upper-water bait and gulls. `individual_spacing` (7) spreads starting groups out.
- `BaitActor.body_size` scales visuals and bite/collision radius together. `dart_speed` (11) and `minnow_wiggle_speed` (2.2) tune the minnow escape. Squid visual yaw and pitch follow velocity, including vertical jets.
- `LiveBaitDriver._turn_clock` introduces small rod-like steering changes. `_mullet_dive_wait` is independently randomized; a 3-5 second descent overrides surface seeking, which resumes naturally afterward.
- `Seagull` scans once per second for surface mullet using a weak reference, leads their motion during approach, and holds a level body during surface rest. It remains ordinary catchable food; gulls do not consume the mullet yet.
- `LureTestController.deployment_position` places squid below the boat. The shared motor limits horizontal displacement to a six-metre disk around the boat. `BaitActor.launch_cast` owns the short flight phase and downward water entry; camera tracking remains in the controller.

## Editing the shrimp sequence
`BaitActor.start_flee` locks the current horizontal body heading for the escape, so predator direction cannot invent a sideways kick that a player cannot copy. Charge maps to `_escape_strength` and a 0.22-0.5 second kick. During that phase the nose pitches down, velocity rises at `shrimp_kick_speed * strength`, and backward speed stays small.

The next `shrimp_glide_duration` seconds (default 1.1) blend velocity into forward travel at `shrimp_glide_speed` (4.5 m/s at full strength), decelerating to 45 percent while vertical velocity transitions into sinking. The body levels out. Recovery lasts at least the kick duration plus 0.12 seconds; another release can interrupt the later glide. Change these exported values to tune feel without editing driver logic.

## Keeping AI reproducible by players
`LiveBaitDriver` chooses retrieve/coast, desired steering, depth intent, cover and escape timing. `player_reproducible_command` translates ordinary decisions through `PlayerLiveDriver`, clamping the requested turn to its 45-degree cone. It no longer uses a separate crab scuttle action or AI-only squid pulse multiplier. Predator escape timing still reacts automatically; the shared actor owns the resulting motion. AI has no boat tether, so long-range roaming remains freer than a deployed lure.

The parity test starts AI and player shrimp with equal charges and checks their relative trajectories during the escape. Other checks verify the kick pose, forward glide, recovery, shelter occupancy and approach, predator interruption, crossing detection, splash cap and cleanup.

## Terrain, shelter and surface tuning
`Reef.build_reef` places 24 rocks around eight cluster centers. Adjust the centers to change swimming lanes. The 650 pebbles use one MultiMesh and have no collision. Sand pattern spacing and colors are shader uniforms, so the visual detail adds no terrain colliders. The water shader keeps the physical crossing plane flat at `water_depth`; its ripples are visual, preserving jump timing.

`BaitSchool` enables shelter seeking for every fifth eligible spawn. `LiveBaitDriver.shelter_intent` searches at spaced intervals within 24 m, allows up to 16 seconds to approach, lingers roughly four seconds and waits 18-30 seconds after leaving. All travel goes through normal player-compatible commands. Predators interrupt cover immediately on the next sensing update. `RockShelter.max_guests` defaults to six globally, with one weak-reference reservation per rock. Candidate spots are outside the rock radius and checked against adjacent terrain; no bait is placed inside cover.

`SurfaceFeedback` tracks actors crossing a 0.12 m band around the waterline. The band prevents repeated splashes while resting at the surface. Effects share mesh resources, return to a preallocated pool after 1.3 seconds, and are capped at 12. Their arrays and actor IDs are cleaned as objects leave. `--readability-preview` captures five render views; `--perf-check` measures the live population with terrain and water rendering enabled.

## Navigation and repeat escapes
Crab normal locomotion now updates `heading` through the same turn limiter as the other bait. Escape scuttles still keep a fixed body heading. AI home/rim corrections are applied after random steering, every tick, so a new ambient turn cannot continually erase the return command.

Squid sample floor height four times per second. Near the floor, the AI explicitly sets its state, action, effort and depth input to rising; changing only the action left the old descend flag active. The motor stops a downward jet at floor clearance for both drivers. Player squid keep free horizontal velocity inside a 6 m disk around the boat; an outward velocity component is removed in the final 0.6 m, with a gentle inward correction. `PlayerLiveDriver.squid_axis` supplies a stable lateral reference, independent of current offset.

`sequence_chance` (0.45) and `minnow_sequence_chance` (0.7) control two-action sequences. `_burst_axis` holds the forward reference across both steps. Minnows use 0.35-0.6 charge and opposite 45-degree deflections; squid and crabs reverse lateral direction. Both drivers can charge during recovery and buffer one released command. The actor remains the authority on cooldown and physics. Reset, casting, leaving bait control and moving the boat cancel pending releases.

`cast_distance_variation` (0.22) and `cast_angle_variation` (0.3 radians) bound randomized inward casts. `BaitActor.cast_windup_duration` (0.28 s) owns the backward arc before ballistic launch; controls pause during windup/flight.

## Performance investigation
`SurfaceFeedback` builds its complete effect pool at startup and returns expired effects to it, avoiding runtime mesh/node/material allocation during splashes. `Geometry.bait_material` caches immutable palettes; environment materials remain independently mutable. `BaitVisual` updates distant appendages at lower rates and hides bodies beyond 100 m without changing simulation.

`PerformanceProbe` is attached in normal play as a bounded hitch recorder. It keeps at most 240 records over 50 ms, at most two per second, with wall-frame, physics, process, node and draw-call measurements. F9 writes a CSV; ordinary sampling performs no file IO. `--perf-check` enables a 75-second wall-clock capture and summary; `--perf-tour` moves a diagnostic camera through floor/surface views. Durations use real clock time so a stalled simulation cannot hide elapsed seconds. These traces narrow the cause; they do not prove the user's multi-second slowdown is fixed.
