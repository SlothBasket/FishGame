# Fisher progression: rod pull, counters and endurance

This pass follows the user's 50-fight report (38 spool-outs, 7 breaks, 5 thrown hooks, no landings). It preserves total-load drag, 14 m/s maximum payout, Power allowing drag slip, strength 110, hazard 0.008, and the synchronized upward hook set. No baseline fish speed or reel strength increase was made.

## Shared casting and physical rod gain

`FisherActor.cast_distance` remains 65 m for humans and AI. The hidden `ai_cast_distance=95` export and AI assignment were removed; AI now uses the normal configured setting and the same cast variation. Spool capacity remains 150 m.

`FightLine.rod_pull_velocity` supplies physical inward velocity when the rod has take-up, the line is taut and holding pressure exceeds Fish load. Available authority is `(holding_threshold - fish_load) / holding_threshold`, clamped 0..1. Target inward speed follows distance beyond `line_out - rod_take_up`, using `rod_pull_response=4`, capped by FightSession's existing `maximum_pull_speed=7`. It approaches that target with `rod_pull_acceleration=8` scaled by available authority. It never directly alters position or spool length.

FightSession applies this before normal line motion constraints. `constrain_motion` now computes the actual working radius (`line_out - rod_take_up + maximum_extension`). If already outside it, inward correction cannot exceed inward physical displacement available that tick. This permits progressive contraction without teleporting the fish. Existing tension/force and drag remain active; strong Fish resistance can defeat a lift.

A lift temporarily moves the Fish closer. Lowering releases take-up into slack; it does not award permanent line. Reeling that slack while lowering makes the gain permanent. AI pumping is also allowed for a manageable, slow-outward Fish at any depth, rather than requiring deep water.

## Costs and fatigue curve

Tunables are in FishPlayer. Raw endurance costs before the curve:

| Effort | Cost |
|---|---:|
| Sustained paid sprint | 1.2 / s |
| Overdrive | up to 1.8 / s, proportional to Overdrive |
| Dive | 2.0 / s times Dive Power |
| Ascent / significant Jump build | 1.6 / s times Ascent Power |
| Actual committed side burst | 1.5 once per counted body carve |

Costs stack for concurrent exertion. Ordinary swimming has no new endurance cost. Existing opening-run free sprint semantics remain. Existing ordinary pressure fatigue also passes through the shared curve.

`fatigue_multiplier = lerp(low, high, endurance_fraction ^ exponent)` with **low=0.12, high=1.4, exponent=1.0**. Thus a nominal damage budget costs 1.40x near full, 0.888x at 60%, and 0.44x at 25%. The resulting endurance trajectory slows smoothly as reserves decline. All fight fatigue and counter endurance loss use `FishPlayer.fatigue`; current stamina is clamped to the reduced capacity.

Existing `power_capacity` continues reducing sprint, Overdrive, Dive and ascent output. Side-burst angle now also scales from 60% to 100% with capacity. Ordinary swim/steering remains available.

## Counters, recovery and human feedback

`FightSession.apply_counter_recovery` separates current stamina from endurance damage. Base endurance damage is **Run/side 3.5, Overdrive 7, Dive 9**, scaled by counter effectiveness and then the fatigue curve. Current stamina damage remains 15 for Run/Overdrive and is **24 for Dive**, scaled by effectiveness.

`counter_lateness` uses physical maneuver age. The early Run window is **1.3 s**; Dive has **0.8 s** of early development. After the window, lateness rises smoothly over 1.5 s: control falls toward 15% while line shock rises. Correct early input is strongest; late correct input gives partial relief/damage; wrong input supplies line risk without Fish damage. The existing force-versus-resistance contest still affects effectiveness.

At effectiveness >= 0.5, a counter fully interrupts the run and gives recovery of **0.85 s Run/side, 1.4 s Overdrive, 1.5 s Dive**. Dive also cancels Dive Power, blocks immediate continued dive, and recoils upward/inward. Smaller correct counters partially reduce powered output and give proportionally short recovery. Steering is never disabled.

Full Overdrive and Dive counters clear Swim Drive/Overdrive/run build and apply **2.25 s Drive lockout**. During lockout measured strokes may animate but cannot generate Drive or restart Overdrive. Recovery also blocks major powered run/dive/ascent buildup. `DRIVE DISRUPTED` appears in Fish HUD and spectator text. The append-only Fish snapshot is now 48 floats; index 47 carries lockout to remote Fish HUDs. All peers must use the same build.

Side preparation is now **0.35 s**. The initial course is saved at preparation start, so the extra visible carving time does not increase the eventual angle. Burst cadence and symmetric AI side selection are unchanged.

## Human-reproducible AI

`FisherPerception` normal reaction delay maps skill 0.6..1 to **0.75..0.45 s**, with +/-0.06 s jitter and the existing occasional additional late response. Vision delay is **0.25 s**. Rod preparation follows observation.

Perceived maneuver IDs use only delayed coarse motion: run, lateral direction, dive, air, and quiet. A new key must remain stable for 0.35 s; a quiet reset needs 0.9 s. Returning a lateral run to centre does not rearm it. A new commitment, dive/air transition or meaningful direction reversal can rearm the AI. FightTestDriver spends one preparation attempt per ID, even if interrupted. Ordinary pressure/pump movement still passes through the shared physical gesture recognizer; telemetry counts every real jerk, not only planned attempts.

Vision requires an important running situation plus ambiguous perceived direction; depth, generic tension/payout and random timers no longer trigger it. Duration is **0.7-1.0 s**, cooldown **12-18 s**, according to skill. Existing smooth camera-position/focus interpolation is retained. Drag's deliberate 5% steps and update interval are unchanged.

## Progression telemetry

Added row fields: `starting_line_out`, `starting_spool_reserve`, `total_line_paid_out`, `net_line_change`, `rod_lift_distance_gain`, `permanent_pump_recovery`, `successful_run_counters`, `successful_overdrive_counters`, `successful_dive_counters`, `counter_endurance_damage`, `drive_lockout_time`, `vision_total_time`, `average_vision_interval`, `jerk_attempts_per_maneuver`.

Starting values are measured on the first CANDIDATE sample, not at IMPACT. Payout integrates gross spool release (retrieve may happen simultaneously). Net line change includes pre-hook free-span changes. Rod gain is an observational estimate of inward motion while loaded, subtracting simultaneous permanent recovery; pump recovery is line captured during lowering, capped by that cycle's observed gain. These are attribution estimates, not additional forces or exact causal separation from Fish swimming/recoil. Jerk ratio divides actual jerks by distinct perceived maneuver IDs against which jerks occurred. Average Vision interval is zero when fewer than two activations occur.

Every correct counter (including partial relief) records `COUNTER_PROGRESS`: maneuver, lateness 0..1, effectiveness, endurance/stamina before and after, distance/line before, and distance/line around one second later. Side counters count in the Run column but retain `SIDE_BURST` in the event. Follow-up fields remain null if the encounter ends before the second elapses. Events are amended in memory before the encounter's normal event-file flush. No batch harness rewrite.

## Bounded validation

Import/parse passed. `Scripts/ProgressionChecks.gd` passed 12 focused contracts: shared 65 m casting; physical lift (40 -> 36.52 m in the controlled fixture, line still 40); lower-to-slack; retrieve preservation; Overdrive clear/lockout; expiry; stronger Dive fatigue; fatigue curve; one attempt against unchanged perceived maneuver; normal/Vision delays; Vision cooldown. The lift fixture verifies physical state, not graphical polish. No camera/screenshot tour was run.

Exactly one three-fight smoke used seed 12345, 20x, 90 s timeout. **All three timed out; no landing, spool-out, break or throw.** No further win-rate tuning or batch was run. Impact extensions stayed 0.000 m; IMPACT spans were 66.35, 59.47 and 64.50 m. Minimum endurance was 47.19%, 44.30%, 54.22%; final line-out was 94.57, 47.20, 93.98 m. One correct Run counter reduced distance by 2.84 m and line-out by 2.47 m after about one second. Mean Vision intervals within each fight were 25.57, 18.39, 37.02 s. Jerk attempts per perceived maneuver were 1.14, 1.06, 1.05 (the shared gesture recognizer can also recognize ordinary rod transitions).

This demonstrates the requested mechanisms, not a proven landing rate. Longer user-run fights and manual lift/counter play remain the next balance evidence.

Godot editor Main Run Args: `-- --ai-vs-ai` for manual spectator play. Bounded reproduction: `-- --fight-batch=3 --sim-speed=20 --batch-seed=12345 --batch-timeout=90`.
