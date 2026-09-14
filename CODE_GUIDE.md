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
| LureTestController.gd | Q/E input, camera switching/orbit, boat, origin motion, casting |
| Reef.gd | Terrain, water plane, boundaries, HUD and startup |
| FeedingChecks.gd | Headless regression checks |

FishPlayer receives FishInput and calls FishFeeding. Underwater swimming steers heading and updates velocity. Airborne swimming keeps momentum and applies gravity. During a strike, FishFeeding advances short collision substeps and sweeps each actual travelled segment. Sloped floor collision redirects the strike; frontal walls end it. The grace timer allows short post-strike sweeps using normal movement. Cancel/reset clears it.

BaitActor samples one driver each physics tick. A command contains direction, effort, action, descend, and optional flee_fraction (-1 means no escape request). It does not identify AI versus human. The actor alone applies species speeds, collisions, escape recovery, and presentation. Live test bait awards food like other live prey; artificial lures emit bite callbacks without food.

## Drivers and escape scheduling

PlayerLiveDriver turns W/A/D/Space/Ctrl into organism commands. Q/E use one charge state and a retained left/right choice. Holding fills charge; release sends a fraction. Directional squid escape uses Space/Ctrl for up/down, otherwise left/right. Artificial lures retain FishingBaitDriver and immediate Q/E jerk/jig.

LiveBaitDriver chooses ordinary phases separately from its escape clock. The clock schedules random charge durations and intensities for every live species. Nearby predators override the ambient wait, subject to the same BaitActor recovery gate. Mullet uses a wider threat distance for chase anticipation. Seeded RNG remains reproducible at a fixed tick rate. Squid chooses side/up/down jets and pulses its ordinary propulsion.

start_flee is the single physical escape implementation. Shrimp kicks upward/backward; crab selects the lateral axis of its unchanged body heading; squid jets along the requested vector. Minnow escape velocity curves each frame and updates facing. Mullet preserves forward speed, gains vertical impulse, leaves water, falls under gravity and resumes swimming after re-entry. Only fish and mullet ignore surface collision layer 8; ordinary bait still collides with it. Side boundaries extend above the surface.

## Main tuning values

| Owner | Variables / defaults |
|---|---|
| BaitActor | flee_charge_time 1 s; flee_cooldown 2 s; strength range 0.25–1 |
| BaitActor | dart_speed 7 m/s; minnow_escape_curve 100 degrees/s |
| BaitActor | shrimp_kick_speed 5 m/s; squid_jet_speed 6 m/s; crab_scuttle_speed 5.5 m/s |
| BaitActor | powered_descent_speed 2.8 m/s |
| BaitActor | breach_impulse 8.5 m/s; airborne_gravity 6.5 m/s²; surface_depth 0.45 m |
| LiveBaitDriver | escape_interval_min/max 2.5/6 s; ai_charge_min/max 0.12/1; ambient minimum charge 0.3 |
| LiveBaitDriver | flee_trigger_distance 6 m; mullet_threat_distance 12 m |
| FishingBaitDriver | steering_limit_degrees 40; retrieve_speed 1; arrival starts within 6 horizontal metres |
| LureTestController | cast_distance 28 m; origin_move_speed 12 m/s; orbit_distance 10.8 m |
| FishPlayer | bite_grace_duration 0.2 s; water_height from Reef; air_gravity 9.8 m/s² |

BaitActor exports can be overridden before adding a bait or through Inspector on saved scenes. Driver fields are set where the driver is constructed. Keep shared movement rates in the actor so AI and player cannot drift apart. Major existing swim/lunge settings remain on FishPlayer. Surface height is passed from Reef into fish/school and the test boat.

## Boat, casts and arrival

Boat.position and anchor_position use the same waterline coordinates. Alt+WASD updates both drivers immediately and cancels pending player charge without firing it. G uses horizontal camera bearing and fixed distance; selected bait is recreated below the surface with clean state. Origin bounds leave room for the cast inside the arena.

Artificial retrieval tracks current boat bearing, fades rod deflection near it, then emits a bounded arrival velocity toward a point 0.65 m below the hull. Live test bait uses this arrival aid when W is held near the boat, but vertical controls override it. The actor interprets arrival without adding a second physics path. F resets to the current deployment point.

C retains the camera preference across Tab. Mouse input is consumed for bait orbit; fish-view mode uses the normal fish camera handler. Pitch is limited and roll stays zero. Squid visual pitch comes from actual velocity and is smoothed; crab translation does not rotate body facing.

## Tests and remaining manual checks

Run Launch.ps1 -Check after script structure edits, and Launch.ps1 -Test after movement changes. Tests measure trajectories and state transitions, including airborne feeding, floor glancing contact, random ambient escapes, dock arrival, strength variation and recovery. Review actual play for charge feel, visual pitch, camera framing and chase anticipation. These tests establish behavior, not whether the final movement feels right.
