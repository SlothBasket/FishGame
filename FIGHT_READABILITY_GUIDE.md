# Physical fight cues and spectator teaching pass

This is the current reference for this pass; older balance guides record earlier defaults. Core pumping, payout, line risk, Drive, run/dive, stamina and authoritative simulation remain in place. Default spool capacity is now **150 m**, measured in full 3D.

## Run and observe

`./Launch.ps1 -AIVsAI` starts the normal cast, retrieve, pursuit and manual-style hook sequence. Optional `-FishSkill 1.0 -FisherSkill 0.7` forwards `--fish-skill=1.0 --fisher-skill=0.7`. Without overrides, each encounter independently samples both skills from 0.60–1.00 on the server. Overrides clamp to that range. Skill alters decisions/execution only, never strength, stamina or line properties.

Spectator controls: **1** fisherman camera, **2** fish follow, **3** overview; overview **WASD**, **Q/E** down/up, **RMB + mouse** look. **F10** disconnects. Boat hull/deck, camera-facing rod ribbon and line are local visual geometry with no collision. The rod uses the session's actual hand, direction and loaded tip, curved through a control point along the shaft. Line sag reads actual slack.

The HUD shows skills, action, Drive, resources, condition, Vision and Focus. `AI PERCEPTION: CURRENT` means an observation younger than 0.18 s, not omniscience; otherwise age is explicitly marked OLD. Orange `LINE DAMAGE` appears only while measured condition is decreasing.

## Shared physical cue

`FightSession` extracts signed lateral counter acceleration in the boat-to-fish horizontal frame, normalized by `lateral_force` and the existing total-force cap. `FishPlayer.directional_pressure` carries this signal. Fish AI uses it instead of rod input. `FeedingHud` projects that same world direction into camera-right, fades chevrons, and hides weak pressure. Following this force reduces opposing-heading counter leverage through the existing contest calculation.

`pressure_dead_zone = 0.12`, full visual bank at another 0.35 pressure, `pressure_bank_degrees = 27`, nonlinear exponent 0.7 and response 7/s set body-bank readability. A sign reversal beyond the threshold adds up to 20% bank for 0.2 s. Gameplay heading is never overwritten by this bank.

Fish snapshots are **42 floats**, with signed pressure appended at index 41; fisherman snapshots remain 56. All peers must run the same revision. Drive, Overdrive and Dive visuals also run on replicas using already-replicated state.

## Local fish animation and effects

`FishVisual` adds 9 degrees of internal body sway at full Drive and 10 more at full Overdrive; tail amplitude and cadence increase independently of authoritative heading. Exports `drive_body_degrees` and `overdrive_body_degrees` control amplitude. Frequencies live in `_process`; the existing charge animation still combines with them.

`FishPlayer` allocates three small reusable CPU particle emitters once: 96 bubbles for Dive, 64 for Overdrive, and a 48-particle one-shot onset burst. Eight-sided, four-ring spheres keep geometry inexpensive. Dive velocity increases from 2–4 to 5–9 m/s with Dive Power, directed backward/upward. Overdrive wake speed follows normalized Overdrive. No particle nodes are spawned every frame. Subjective visibility is a manual check.

## AI execution and habitat awareness

`FightDecisions.fish_choice` scores legal RUN/LEFT/RIGHT/DIVE/JUMP intents using energy, own Drive, physical pressure, depth and projected distance gain/clearance. `heading_for` projects 18 m forward and turns the aim along/away from arena walls. It uses current prototype bounds, no navmesh or teleport; actual motor turn rates still apply. Skill controls clearance margin (5–12 m), decision hold (0.9–0.35 s interpolation), and probability of selecting a close second-best action. This boundary helper is the place to replace square bounds with a future habitat query.

Jump commits upward aim plus rise/sprint for 2.2 seconds with a 12-second cooldown, requires near-surface depth and energy, and competes more strongly under pressure. It never presses feeding attack. Drive cadence error and fast-stroke execution depend on fish skill; Dive/Jump opportunities share the skill-dependent decision hold.

`FightTestDriver` casts through normal `FisherActor.cast` using exported `ai_cast_distance = 95` m, existing random variation and the shared 10 m arena inset. Human default distance stays 65 m. The minnow retrieves at 40% with 0.8 s neutral pauses each 7 s until the bite. No bait teleporting or artificial hook contact.

Fisher skill changes hook release timing, rod accuracy, delayed drag updates/occasional mild overcommitment, observation delay/jitter/late reactions and Vision duration/cooldown. Observation remains a cache of coarse movement and visible line behavior, excluding hidden fish energy, Drive, Overdrive, Dive Power and action. Coarse depth is rounded to 4 m.

Vision uses ordinary `FisherIntent.vision`: uncertainty, deep observed fish, delayed loaded-line information or payout can trigger bursts while Focus exceeds 55. Bursts last approximately 1–1.24 s across supported skills, with 6–8 s cooldown; less-skilled fishers may waste a burst. Normal actor Focus drains at 22/s and recovers at 8/s. Vision improves direction and latency, not access to hidden resources.

## Directional wear tuning

`FightSession.directional_wear_scale = 0.0015` is condition fraction per second at maximum qualifying effort. Extra wear multiplies normalized Drive above 0.6, run build, propulsion above 0.9, opposing directional leverage, and pressure above existing `spool.wear_start` (reaching full contribution 0.35 above onset). Each factor clamps to 0–1. Passive turns and ordinary Drive produce none of this added wear.

At full qualifying resistance this adds 0.15 percentage points/s; intermittently qualifying exchanges could plausibly reach the requested 20–30% over five minutes together with existing wear. That is a tuning hypothesis, not a measured result or scripted outcome. Condition remains a modifier to exposure and probabilistic breaking, never line HP. Inspect `directional_wear_rate` to adjust only this contribution.

## Validation and manual follow-up

Import and the existing bounded natural AI-vs-AI check only. Startup checks exercise physical-direction decisions, 150 m capacity, powered-only wear and delayed limited observations. Visual quality, wall routing over a long fight, jump frequency, and five-minute wear remain manual checks; no performance tour or balance simulation was run.

Recorded result: import passed; all 20 startup contracts passed after correcting the fixture's boat from seabed to water level. One complete 40-second natural observer run reached hook-set/fight and passed. Vision activated, minimum Focus was 73.23%, then Vision stopped and Focus recovered. No natural breach occurred during this short run. Godot also emitted its existing nonfatal Windows certificate-store warning. No long-run balance claims are made.
