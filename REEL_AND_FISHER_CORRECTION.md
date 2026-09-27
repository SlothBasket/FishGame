# Reel, Fisher and fight-readability correction

This is the current specification. It supersedes older descriptions of total-load payout, fish-tracking cameras, angular/straight-only mouth lines, fixed Drive purchases and the 64-float Fisher snapshot. Continuous Drive was checkpointed separately in 10f48e0 before this pass. No win-percentage tuning was performed.

## Reel accounting (FightLine / FightSession)

Units are explicit prototype force-equivalent units and metres/second, not pounds. Defaults:

- `max_drag_force = 120`; drag resistance D = 120 * selected drag (linear).
- Outward force accommodation C = `base_outward_capacity` (330) + `capacity_per_released_drag` (2) * (120 - D).
- Finite payout speed = min(`maximum_payout` 14, C / `force_per_payout_speed` 40). Full drag permits 8.25 m/s, half drag 11.25 m/s, free spool 14 m/s (absolute cap).
- Raw load R = max(Fish movement force, elastic extension * 22) + transient jerk/fall/turn load.
- Connected tension = min(R, D) + max(0, R - D - C), with a separate lower bound for stretch beyond the 2.5 m safety allowance. Slack removes contact. Fish force and drag are opposing, never simply added.

With max drag 10/base capacity 30, force 50 produces tension 20/10/0 at 100/50/0% drag. Force 60 still produces tension 10 at zero drag. The focused checks exercise these exact examples. Existing line-strength, wear/hazard parameters and physical acceleration caps remain; drag force now has its own tuning value rather than being implicitly tied to line strength.

Before Fish movement, `step` records starting path distance and deployed line, computes force, and attempts recovery. Requested retrieve is 4.5 m/s times the input tier (7 m/s for Power). Useful motor speed is maximum speed times clamp(1 - Fish load / holding authority, 0, 1). Holding authority retains the existing rod lift/elevation contribution; Power multiplies that authority by 1.5. Slack can be reeled at requested speed. Actual recovery is the lesser of request/useful speed, bounded by available line and the existing 2.5 m elastic allowance.

After Fish movement, `sync_distance` pays out only min(actual positive path-distance change, finite speed * dt, remaining spool capacity, geometric need). Failed recovery is never added to this value. The movement constraint permits only the upcoming finite payout allowance beyond the working radius; it still preserves tangential movement and avoids teleports. Repeated calls cannot spend payout twice.

`line_out_after = line_out_before - actual_recovery * dt + payout * dt`. `line_rate` is that net change per second. `retrieve_efficiency = actual_recovery / requested_retrieve`, or 1 when no retrieve was requested. Reel slip is 1 - efficiency while retrieving. Rod take-up remains temporary, distinct from permanent deployed line. Total recovery now counts actual recovered line, not merely negative net movement.

## Audio and human feedback

ReelDragAudio preserves the original drag assets and opening/loop/ending. Drag plays only when both measured payout and net line movement are positive; net recovery immediately mutes its voices. Stopping with no recovery can play the natural tail.

A separate deterministic generated mono PCM loop contains four muted ratchet clicks per 0.4 seconds. Its smoothed volume follows lost retrieve efficiency, so successful recovery is quiet. It never uses the drag recording. Successful entry into IMPACT triggers a separate 0.3-second one-shot from the existing recording at 2.2x pitch, with a short ending fade. No downloads. The Fisher HUD and spectator show requested/actual recovery and efficiency; sound timing/volume still needs listening feedback.

## Fisher decisions

FisherPerception delays efficiency, recovery and net line-rate observations just like other line/motion data. No Fish energy reads were added. If efficiency falls below 80%, FisherControls caps retrieve near measured useful recovery + 0.05 input. If efficient, it probes up by at most 0.10 input over the observed previous request. During actual hard outward runs (outward >3 m/s or payout >2 m/s with positive net rate), retrieve caps at 15%, pumping/Power stop, and rod/drag/counters take priority. When load weakens, the next delayed observations allow renewed retrieve.

Distance stages remain FAR >=70 m, MID 40-70, CLOSE 20-40, LANDING PUSH <20. Safe close-out targets 55% drag, briefly 65% inside 20 m with low danger; dangerous line, Dive/fall and poor condition retain 30-35% relief. Retrieve ceilings apply even during a close-out opportunity. Safe distant pumps retain a real lift/lower capture cycle. A successful visible counter or run ending can open a 2.5 s progress window and a 0.9 s Power push. Existing reaction timing and Power/Overdrive ordering remain.

## Continuous Drive

See CONTINUOUS_DRIVE_POLISH.md: 0.10 per good reversal (about ten), 0.30/s ordinary power, 0.48/s Overdrive. No fixed activation costs or active-spend refill. At 5-10 stamina, recovery scales to 0.04 per good reversal. Depleted Drive hands spending to the existing 18 stamina/s sprint plus 8/s Overdrive, with existing radial cost and endurance rules. AI desired budgets vary 40-60%, 65-85%, 90-100%; seeded intent mean was 72.9%. No new Drive tuning in this second checkpoint.

## Hookset, camera and rod

Pre-hook rod is centered with vertical -0.15, oriented from boat yaw rather than auto-aiming at Fish. Successful hook timing keeps the existing single physical yank. Its authoritative rod animation adds 0.06 s anticipation, 0.18 s upward snap, 0.12 s hold and 0.25 s settling; snapshots present the same geometry to humans. The hook sound is local and causes no extra impulse.

Main Fisher/spectator camera is 3.5 m up, 3.8 m behind boat heading and 1.1 m to the side, FOV 60. Look direction combines boat heading with only 25% horizontal rod direction; Fish framing adjustment is capped at 0.96 m. The base target is 12 m forward and 3 m below the boat, preventing a Fish under the boat from turning this camera vertically down. Intentional Fish Vision/bait camera modes retain underwater views. A presentation-only 0.7 m forward/0.5 m sideways hand-and-tip offset exposes the rod without moving its physics anchor.

Mouse response 0.008 (was 0.0035), stick 7.5 (was 5), authoritative rod smoothing rate 14 (was 5). RodGesture requires displacement 0.30, speed 2.0 control-units/s, ending deflection 0.25, inside 0.24 s. Compact UP/LEFT/RIGHT flicks pass; slow pumping does not. Adjust these values in FisherView, FightSession and RodGesture, respectively.

## Side maneuvers and counters

The existing legal boat-relative side geometry remains. AI maintains a selected side aim for 1.2 s with small physical rhythm strokes, and does not cancel because stored Drive drops below the initial side threshold. A budget-complete run waits for its already committed side arc to finish. Side cooldown remains randomized 3-5 s, symmetric, with existing boundaries and maneuver exclusions. Actual heading/velocity/displacement still determine telemetry, never the intent alone.

`FightSession.required_jerk` is the single physics/coaching rule: committed straight-away run -> UP; actual left/right movement -> opposite horizontal jerk; Dive -> UP. Air/fall/ascent protection remains. Overdrive is intensity, not a direction. Counter telemetry stores DIVE/RUN/SIDE_BURST plus `overdrive_powered`. Powered Dive calculates one Dive penalty and one event, then interrupts Dive and underlying Drive/Overdrive together. Existing counter magnitude tables remain; strong non-Dive recoil now includes the visible oblique reaction for powered runs too.

Strong counters (effectiveness >=0.5) publish a local 0.85 s halo of five generated star meshes near the mouth. The existing reliable counter event carries effectiveness; weak/wrong jerks do not spawn stars. The effect scales modestly, orbits, shrinks and frees itself. Human Fisher and spectator coaching use the authoritative required jerk in the snapshot/direct state, not a separate directional interpretation.

## Jump effort and mouth line

Ascent starts with upward powered intent and >0.5 m/s upward velocity. Once started, committed upward intent builds toward available endurance capacity even if instantaneous upward velocity falls. Abandoning intent decays it at 0.4/s; interruption clears it. Breach snapshots `jump_launch_power`; airborne reset cannot erase that value. Initial severity uses the launch snapshot, and height-based severity retains its contribution. Gravity and breach velocity caps were not increased.

FishingPresentation uses one sampled cubic Bezier: exact mouth endpoint, short forward/approach-side lead, then smooth connection to rod tip. No body collision or sphere wrapping, no angular support corners. Lead length scales with Fish and is capped for very close tips. Occasional body overlap is an accepted visual limitation. Solid base plus sparse line-rate markers remains; crank/spool direction is unchanged.

## Network and diagnostics

Fisher snapshots now contain 69 floats (append requested retrieve, actual recovery, efficiency, authoritative jerk hint, jump launch power). Fish snapshots remain 51. Both peers must use this build. The reliable counter event additionally carries effectiveness. No authority is transferred to presentation.

Telemetry events append requested/actual recovery, efficiency/slip, physical outward distance, finite payout capacity and jump launch power; existing deployed line, extension, force, direction and counter measurements remain. Summary adds Drive-funded/stamina-funded powered time and maximum jump launch power. Counter detail includes whether it was Overdrive-powered.

## Bounded validation

Import passed. ReelCorrectionChecks passed 29 focused checks: force examples, no phantom payout, actual separation, useful recovery, AI efficiency response, gestures, retained ascent/launch, under-boat framing, directional counter hierarchy, single powered-Dive recovery, low rod/snap, mouth lead and separate audio triggers. Headless cleanup reported four leaked ObjectDB instances; no script errors. The preceding checkpoint passed 40 Drive/feeding checks.

One normal 28-second AI-vs-AI graphical session ate five natural prey without script errors; its screenshot shows the whole rod. One seven-second controlled human-Fisher hook fixture entered FIGHT with zero initial extension and a readable full rod. One two-encounter batch, seed913, timeout45 seconds at 20x, produced one THROWN and one setup TIMEOUT; no line breaks or script errors. This sample does not establish win rate, long-fight close-out, or multiple lateral opportunities. No large batch. Full subjective rod, audio, counter-star and jump feel remains for manual playtesting; network payload compatibility was updated but no two-client play session was run.

## Follow-up: steady Fisher pressure and stalled close recovery

Manual testing exposed two control-loop problems: the more sensitive gesture detector could interpret abrupt ordinary AI rod-pressure changes (or counter preparation/return) as jerks, and close-range/low-efficiency decisions disabled useful pumping. FightTestDriver now limits normal rod motion to `pressure_rod_rate = 0.85` control-units/s, below the gesture's 2.0 threshold. Only the deliberate counter stroke uses `flick_rod_rate = 8.0`; preparation and return remain slow. Deliberate attempts retain maneuver gating and are at least 4 seconds apart. Human input responsiveness is unchanged.

FisherControls permits safe pumps from 8 m outward when recovery is below 0.8 m/s, including the former 20 m stall. Poor retrieve efficiency still reduces cranking but no longer forbids improving leverage. An ongoing 3.8 s pump completes its lift/lower capture while safe; actual runs, dives, air/fall, dangerous tension and Vision can abort. Lift retrieve respects the useful-speed plan, and lowering probes just 0.15 input higher rather than blindly forcing full retrieve.

Maximum reel drag increased 110 -> 120 (about 9%); line strength and break rules are unchanged. Shared `FightLine.rod_pull_acceleration` increased 8 -> 20. Actual assistance is still multiplied by clamp((holding threshold - Fish load) / holding threshold, 0, 1), requires loaded rod take-up/contact/positional error, and retains the 7 m/s target pull-speed cap. Thus correct rod pressure can overcome ordinary swimming, including the existing strongly moderated vertical line force, while an overpowering Fish gets no free inward movement. No hidden Fish stamina checks or deployed-line awards were added.

Import passed and seven focused FisherSteadyChecks passed. Alternating pressure caused zero accidental jerks; one intentional counter produced one accepted jerk with the existing cooldown. In an eight-second controlled motor/spool fixture starting at 22 m, ordinary swimming ended at 3.81 m horizontally and 18.56 m on a steep downward line while pumping. Strong powered resistance still took line. These isolated results verify useful physical recovery, not a live-fight landing guarantee. No batch or long simulation was run for this follow-up. The user's AI-vs-AI editor launch setting was preserved.
