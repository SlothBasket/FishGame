# Fisher presentation and between-fight AI

This pass changes local presentation and AI inputs outside fights. It does not alter combat strength, Drive economy, fatigue/counters, line physics, drag, landing geometry or hook rules. Batch mechanics and telemetry schema are preserved; more natural food interest can change setup time and which bait is eaten.

## Camera and water

`FishingPresentation.edge_camera` is shared by Fisher and spectator Fisher views: **2.05 m above the boat origin, 0.85 m back, 0.75 m to the side** of the direction toward the action. This keeps the rod/reel ahead of the lens without sitting far behind the boat. Fight FOV smoothly approaches **48 degrees**; the look target is biased **0.65 m below** the tracked Fish. Existing smoothed focus/position tracking and hook-impact transition remain. Bait/alternate/overview views remain available.

`WaterSurface.gdshader` keeps the inexpensive procedural surface: two slow vertex waves of 0.07/0.045 m, a slight animated opacity variation and base opacity raised from 0.22 to 0.28, Fresnel from 0.28 to 0.30. Reef's surface plane has 64 subdivisions on each axis so that the deformation has vertices to move. This is presentation only; water collision/height and breach rules do not change.

## Reel and visual line

`FishingPresentation` is a local Node3D shared by FisherView and FightSpectator. Generated spheres/boxes form the reel body, spool, crank and grip. Crank rotation follows actual fight retrieve recovery **max(0, payout - net line_rate)**, at 3 radians per recovered metre. The spool follows net line flow in the opposite winding direction for payout, at 4 radians/metre. In bait mode the crank previews the legal retrieve input at the normal 4.5 m/s scale, because no fight spool yet exists. It does not move the bait or line.

`FishingLine.gdshader` draws alternating light/dark stripes on a thin ribbon with UV length measured in world metres. `travel += line_rate * delta`: positive payout moves stripes from rod toward Fish; negative recovery moves them toward rod; zero holds them still. Spacing is 1.4 m. The close-view rod ribbon is narrower to avoid obstructing the view.

For a hooked Fish, the shared helper uses `FishPlayer.mouth_position()` from the local/interpolated actor. FisherView resolves the hooked peer through the existing snapshot ID; spectator uses the same actor directly. No extra network fields were required. If a replica has not arrived yet, center-position fallback is temporary.

A rough body sphere (0.85 times Fish scale) detects when tip-to-mouth visually crosses the body. Two flank support points route the line around it. The chosen side has a dead band to avoid small heading changes flipping it. The path terminates exactly at the mouth. This is deliberately approximate visual routing, not rope collision: it never writes line_out, tension, hook state, body position or velocity. Sharp turns may still expose small visual imperfections.

## Optional drag-loop audio

No sound asset was supplied or generated. To enable it:

1. Add a loop file at **`res://Audio/drag_loop.ogg`** (preferred) or **`res://Audio/drag_loop.wav`**, and let Godot import it.
2. Alternatively add a custom Project Setting **`pelagic/audio/drag_loop`** containing its `res://...` path. The helper also exposes a `drag_loop: AudioStream` property for future scene/Inspector use.

Each presentation creates one AudioStreamPlayer, duplicates the stream and enables OGG/WAV looping. It starts once when actual payout begins, smooths volume and pitch (0.75 to 1.4 across 0..14 m/s), then fades and stops after payout ends. No asset means silent disabled audio. Human Fisher owns its playback; spectator playback is enabled only in Fisher camera mode. No per-frame restart, downloads or synthesized sound.

## AI reset and food interest

`FightTestDriver` detects the transition out of a fight. Fisher AI waits a seeded **6-9 simulated seconds** before increasing its cast serial. Ordinary stamina recovery continues. Human controls are untouched. The timer is driven by delta, so acceleration scales normally.

`FishFoodInterest` owns each Fish's independent WANDER -> NOTICE -> APPROACH -> COMMIT flow. It only returns FishInput; it never teleports or sets velocity. Wandering chooses a course/throttle every 2-4 seconds, with 0.4-0.7 throttle, gentle vertical changes, boundary/depth steering, legal rhythmic strokes, and occasional existing Drive bursts once sufficiently charged.

Target scans occur every 0.6-1.0 seconds inside a **45 m detection radius**. Registered live ecosystem prey and Fisher bait use the same search, filtered by validity, alive/unclaimed state and eater-size restriction. Lures have a modest 1.15 interest weighting, not global priority. NOTICE lasts **0.7-1.5 seconds** before approach. Approach predicts at most 0.4 s of target motion, adds a 14-degree curved offset and existing legal rhythmic aim strokes. Close/aligned Fish use the existing feeding charge/release and collision/claim code. Invalid/eaten targets or targets escaping 1.5x detection radius return it to wandering.

After a fight, Fish ignores Fisher lures for **6-9 simulated seconds** but can still notice natural prey. Each driver has its own target/timers/RNG seeded from the existing execution RNG; several Fish can independently notice the same target, with normal bite claims deciding the winner.

`FightTestDriver.bait_retrieve(kind, delta)` is the small species-strategy branching point. Minnow remains default, retrieving at 30/40/50% for 2-5 seconds with occasional 0.6-1.3 s pauses. Other species retain a simple fallback; no species AI expansion was attempted.

## Changed files and validation

New: FishingPresentation.gd, FishingLine.gdshader, FishFoodInterest.gd, FisherExperienceChecks.gd. Updated: FisherView, FightSpectator, FightTestDriver, Reef, WaterSurface shader, guides and milestone index. User launch arguments were checkpointed separately in `b4e0b79`.

Import/parse passed. Thirteen focused checks passed: delayed natural-prey notice, legal bite commitment, actual feeding sweep/claim of live prey, multi-target filtering, lure-only reset, delayed lure interest, seeded 6.69 s recast/no early cast, visual mouth/wrap path, bidirectional stripe/spool motion, retrieve-dependent crank, and missing-audio silence. Wrap routing is pure presentation with no access to combat mutation.

One graphical normal Fisher startup used a controlled in-memory hook/nearby-Fish fixture to inspect line/water/camera. Its screenshot revealed the reel behind the lens; camera was moved back/sideways. One **28-second natural AI spectator session** then verified the shared corrected view and ran without script errors; AI ate **three natural prey**. Screenshot showed reel/crank foreground, striped line and visible underwater prey through the moving surface. Recast timing was contract-tested; the short natural session did not finish a whole fight. No large batch, fight-balance simulation or audio-asset playback was performed. Final readability/cleanup narrowed the rod and retained the existing gameplay model.

Godot editor arguments: `-- --host --role=fisher --ai=fish` for human Fisher, `-- --ai-vs-ai` for spectator; press **1** for Fisher camera, **2** for Fish, **3** for overview.
