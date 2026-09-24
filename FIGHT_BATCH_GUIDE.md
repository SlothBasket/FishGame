> Current Fisher progression pass: [FISHER_PROGRESSION.md](FISHER_PROGRESSION.md) documents 65 m shared casting, physical rod take-up, counter recovery/Drive disruption, nonlinear endurance costs, slower perceived AI decisions and progression telemetry. Fish snapshots now contain **48** values (Drive lockout appended).

> Current drag/burst pass: see [DRAG_AND_BURSTS.md](DRAG_AND_BURSTS.md). Total-load drag also works during Power Reel; base break hazard is now **0.008**. The older baseline results below are historical. The pre-hook extension bug is fixed.

# Batch fights and telemetry

## Godot editor launch arguments

Run the project with F5 and Main Run Args:

```text
-- --fight-batch=100 --sim-speed=20 --batch-seed=12345
```

A short batch:

```text
-- --fight-batch=3 --sim-speed=20 --batch-seed=12345 --batch-timeout=180
```

Replay an individual row's seed (exactly one fresh encounter):

```text
-- --fight-batch=1 --sim-speed=20 --fight-seed=117074
```

Existing `--fish-skill=... --fisher-skill=...` overrides work. Otherwise both skills are sampled normally for each encounter. `--fight-seed` overrides the derived seed and forces count=1 regardless of argument order. For matching results, use the same revision, engine, physics backend, timeout and skill overrides. Seeded randomness is reproducible; cross-platform bit-identical physics is not promised. Use `--sim-speed=1` to investigate timing without acceleration.

Batch defaults: 100 encounters, 10x speed, seed 12345, 600 simulated seconds per fight. Count clamps to 1–10000, speed to 1–20, timeout to 10–3600 seconds. Setup/casting has a separate timeout of min(fight timeout,120 s). TIMEOUT is neither a fish nor fisherman win. A setup timeout has zero fight duration and a nonzero setup duration.

Normal launch and `-- --ai-vs-ai` retain their existing paths. Batch opens no spectator camera/HUD and may show an empty window in the editor; watch Godot Output. External launchers can add Godot's `--headless` engine flag before the standalone `--` to avoid creating a rendered window. The optional normal spectator `--fight-telemetry` mode is not implemented in this pass.

## Actual simulation, fixed simulated timestep

`FightBatch` starts a local authority session without network transport. It creates fresh FishPlayer and FisherActor nodes and fresh ordinary FightTestDriver instances for every encounter. Casting, pursuit, feeding collision, manual-style hook setting, FightSession, FightLine, FishFightMotion, FisherControls and FisherPerception all run through the same legal input/mechanical code as normal AI-vs-AI. No teleport to a hook, fake winner, or reduced mathematical fight model.

At speed S, Engine.time_scale=S and physics_ticks_per_second=60*S. Therefore every physics callback still receives approximately 1/60 simulated second; maximum catch-up steps are raised to accommodate the requested speed. CPU load may reduce achieved wall-clock acceleration, but must not enlarge simulated delta. Each row records maximum observed delta; the runner returns failure if it exceeds 0.017. Terrain and rock collision geometry stay unchanged. Ambient bait, gulls, water/decorative rendering, HUD, spectator cameras, normal network snapshots and fight particles are omitted/disabled. Fish and bait models may be instantiated for their existing node contracts but do not render.

The batch stops/freezes old actors at an outcome, captures data before normal reset, then removes them and creates new actors at a deferred frame boundary. Bait IDs remain monotonic to prevent old exit callbacks from deleting new catalog entries. TIMEOUT tears down the encounter without calling a fake normal winner.

## Seeds

Row N uses `(base_seed + (N-1)*104729) modulo 2147483647`. Seed range is 0–2147483646. Named offsets seed fisherman casting/size (+11), fight skill/hazards (+23), delayed perception (+37), fish execution (+51), and fisher execution (+67); the global RNG is also reset per encounter. Terrain uses its unchanged fixed seed. Telemetry never calls the perception sampler or consumes gameplay random numbers.

## Output files

Files go under `user://fight-batch/`, named with timestamp, base seed and a startup tick suffix to avoid overwrites:

- `fight_batch_...csv`: one summary row per encounter, flushed after each result.
- `fight_batch_..._events.csv`: event rows with `fight_index,fight_seed,simulated_time,event,state_json`; the last field is quoted JSON, not another physics-frame table.
- `fight_batch_..._metadata.json`: engine version, arguments, seed rule, speed/timestep and timeout.

Completion prints absolute summary/event paths, all outcome counts/percentages, mean/median duration, medians for break condition/tension/threshold, average Run/Dive/ascent/lateral counts, and measured delta range. Empty break populations print n=0. Editor runs use ordinary Godot user data; automated development runs may use the workspace APPDATA override.

## CSV columns (91 in the current writer)

Identification/outcome: `fight_index, fight_seed, fish_skill, fisher_skill, result, duration, combat_duration, setup_duration, maximum_physics_delta`. Duration begins at bait-taken/CANDIDATE; combat_duration counts IMPACT/OPENING/FIGHT only. Setup is measured separately. Duration excludes cleanup. Skill columns are zero if no fight was ever created.

Line: `final_condition, minimum_condition, maximum_tension, average_tension, maximum_break_ratio, maximum_line_out, final_line_out, maximum_payout, total_line_recovered, maximum_slack, slack_time`.

Physical fish: `minimum_endurance, final_endurance, minimum_stamina, average_depth, maximum_depth, minimum_depth, final_depth, minimum_horizontal_distance, final_horizontal_distance, final_distance_3d`.

Maneuver counters: `run_starts, overdrive_starts, overdrive_interruptions, dive_starts, dive_cancellations, ascent_attempts, breaches, jump_landings, lateral_course_changes, left_trajectories, right_trajectories, direction_reversals, head_shake_attempts, hook_loosening_events`.

Fisher counters/durations: `jerk_up, jerk_left, jerk_right, run_interruptions, vision_activations, power_activations, pump_cycles, reeling_time, lowering_time, high_rod_time, lateral_rod_time`.

Lateral/ascent/hook: `straight_time, left_time, right_time, average_ascent_start_depth, maximum_ascent_power, maximum_looseness, maximum_hook_hazard, hook_hazard_time, maximum_airborne_hazard, maximum_slack_hazard`.

Exact break fields, blank for other outcomes: `break_condition, break_tension, break_threshold, break_ratio, break_exposure, break_drag, break_rod_vertical, break_rod_horizontal, break_requested_load, break_shock, break_payout, break_depth, break_velocity_x, break_velocity_y, break_velocity_z, break_action, break_following_jerk, break_falling, break_dive_power, break_overdrive`.

Exact throw fields, blank otherwise: `throw_slack, throw_airborne, throw_shake, throw_looseness, throw_hazard, throw_jump_severity`.

Hazards are rates per simulated second, not percentages or guaranteed outcomes. Condition/skills are fractions; distances are metres. Total recovery counts negative net spool change and does not subtract later payout. Maximum airborne/slack hazards are the separate additive HookRisk contributions. `following_jerk` means registration within the existing 0.8-second jerk notice window. Exact terminal values are captured synchronously before FightSession resets stamina/endurance or frees actors.

## Events and definitions

Events: FIGHT_START, RUN_START, OVERDRIVE_START, RUN_STOPPED, OVERDRIVE_STOPPED, DIVE_START, DIVE_STOPPED, ASCENT_START, BREACH, LANDING, COURSE_CHANGE, LATERAL_LEFT, LATERAL_RIGHT, HEAD_SHAKE, HOOK_LOOSENED, VISION_ON, POWER_ON, PUMP_RECOVERY, LINE_DAMAGE_SPIKE, HIGH_BREAK_RISK, DEEP_UNDER_BOAT, JERK_UP/LEFT/RIGHT, LINE_BREAK, HOOK_THROW, SPOOLED, LANDED, TIMEOUT, and other existing terminal outcomes.

Threshold transitions have a short dwell and 0.35 s inactive rearm to reduce flicker counting. Lateral trajectories require at least 20-degree boat-relative side heading sustained 0.5 s. Direction reversals count transitions between meaningful left and right episodes. Under-boat events require horizontal distance <6 m and depth >12 m for 5 seconds. Run requires boost and run_build>0.6 for 0.3 s; ascent requires power>0.15 for 0.2 s. Pump cycles detect high rod followed by lowering while retrieving; this is a physical-pattern count and can include a similar non-pump motion. Gesture/interruption events come directly from the authoritative action sites rather than polling popup frames.

Each event carries line, hook, fish motion/resource, rod and maneuver context. Break events include the full break-state columns plus physical distance, elastic extension, rod take-up and fish load. Telemetry is observational; it does not alter depth, course, Jump scores or AI strategy.

## Minimal durability change

Only FightLine defaults change:

- `fresh_risk_threshold`: 0.773 → **0.85**.
- `damaged_risk_threshold`: 0.55 → **0.60**.

`strength=110`, `base_break_hazard=0.012`, condition wear, exposure, shocks and risk curve remain unchanged. Higher thresholds reduce risk from moderate loads; extreme loads can still break fresh line. No additional balance iteration followed the smoke batch.

## Implementation map and validation

New files: FightBatch (runner/seeds/output/aggregation), FightTelemetry (measurement/events). Integration: Reef (development-only bootstrap), NetworkSession (offline legal drivers and exact result callbacks), FisherActor/FightSession (seed injection and event hooks), FishPlayer (skip batch presentation), HookRisk (expose unchanged component hazards), FightLine (two risk defaults). Normal RPC payloads are unchanged.

One 3-encounter smoke at 20x, seed12345, timeout180 completed three natural LINE_BROKE outcomes, with exact 1/60 delta and exit code0. Export checks verified three rows, seeds12345/117074/221803, 20 transition events, parseable event JSON and complete break fields. The smoke export has 90 columns; afterward the writer added combat_duration and richer context/debouncing/component readouts, followed by a passing final import without another batch. Timeout teardown and replay seed routing were inspected; no timeout occurred and no duplicate replay was run. Normal spectator launch was preserved by branch inspection rather than an extra gameplay run.

All three smoke breaks occurred shortly after hook set: condition approximately0.866–0.923, tension397–412, median threshold90.49. This is diagnostic evidence, not a win-rate estimate. It suggests inspecting hook-transition separation/stretch and requested load before changing global balance. No fix to that behavior was made here. Larger user-run batches should guide the next pass.
