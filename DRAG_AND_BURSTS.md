# Total-load drag and readable side bursts

This pass uses the user's partial 90-fight report (65 breaks, 54 near jerks) as its diagnostic basis. The pre-hook synchronization fix remains intact. It does not retune Jump/Dive frequency, stamina, endurance, hook risk or fish strength.

## Spool calculation: Scripts/FightLine.gd

`requested_load` includes fish propulsion/outward motion, elastic extension, retrieve pressure and jerk/fall/slack-to-taut transients, scaled by rod elevation and contact. The drag clutch now compares that total with `holding_threshold`, rather than checking fish load/stretch alone. High/low rod still scales both load and holding capacity consistently; temporary rod take-up and buffering remain.

Overload is converted to an equivalent elastic relief span using `elasticity * pressure_multiplier`. Target payout combines outward speed, recovery and this overload span, capped at **14 m/s**. `payout_acceleration_response=24` gives a fast exponential response (about a 42 ms time constant); `payout_response=6` still controls overload-to-rate demand. Actual release is limited by the finite rate, available spool capacity and demanded stretch/load. A transient can unload line/rod elasticity before visible separation grows, so a taut line can pay out even without existing stretch.

Retrieve first takes line; drag can return it in the same step. Power keeps its 7 m/s retrieve and existing stamina/wear costs, but uses exactly the same clutch and payout calculation. Remaining tension is total requested load minus the elastic load relieved by actual release. It is not capped at drag: fast loads, finite response and separation beyond payout capacity still leave dangerous tension. The obsolete `shock_retention` parameter was removed; shock still drives sharp response and existing wear.

Only the requested probability default changed: **base_break_hazard 0.012 -> 0.008**. Strength 110, risk thresholds 0.85/0.60, condition wear and exposure rules remain.

## Fisher controls and presentation

`FisherPerception` supplies delayed observed break threshold and shock alongside existing motion/line observations. `FisherControls.plan` chooses 30/35% for danger/degraded line/dive, 45% for safe healthy runs and occasionally 50% near spool danger; otherwise 40%, with a middle risk band retaining the current setting. Fall retains its 30% target. `FightTestDriver` approaches the target in **5% steps every 0.9-1.4 s**, independent of reel/rod/Power channels. No fish strategy or hidden burst-side flag is exposed to the fisherman.

Spectator HUD already reads authoritative `FisherActor.drag_setting`. FisherView's drag readout now uses authoritative snapshot index 32 while its human input preference remains separate.

`FightSession` drives actual rod direction/tip presentation for spectator and replicated views. A successful hook sets a **0.18 s rise, 0.12 s hold, 0.25 s return** to a 60-degree high rod. Fish impulse aims toward the elevated hook-set tip with the existing impulse magnitude; the downward/horizontal clamp is gone. Geometry is synchronized BEFORE impulse and again at IMPACT. This visual event adds no mid-fight jerk stamina/cooldown cost and no artificial pre-hook stretch. Directional lateral jerks add a short 32-degree sweep over 0.32 s to make the physical rod readable; their counter mechanics remain unchanged.

## Shared side-burst rules

`FishFightMotion.steer_burst`, called before ordinary `FishSteering` in FishPlayer, requires forward sprint, Swim Drive >= **0.55**, run build >= **0.6**, and deliberate steering (A/D magnitude > 0.8 or mouse aim yaw > 40 degrees) for **0.12 s**. It commits aim 55 degrees from the starting heading for **0.75 s**, with a **2.5 s** cooldown. The body still turns through normal head/body response and the existing motor supplies all propulsion: no velocity injection or free acceleration. Releasing sprint, impact/counter recovery, airborne motion or an active dive/ascent cancels the overlay.

`FightTestDriver` occasionally supplies a committed 60-degree aim through the same input path during Run/Drive. It chooses left/right with equal seeded probability and can choose the other side near a boundary. The old location-dot-right 28-degree course offset is removed. Directional counters still read physical heading; Fisher AI still reacts through delayed perceived motion (Vision resolves it faster).

## Telemetry and checks

Added events: `DRAG_CHANGE` (old/new drag plus the normal tension, condition, payout and line-out snapshot), `SIDE_BURST_LEFT`, `SIDE_BURST_RIGHT`, `HOOK_SET_UP`. Side-burst events require an actual body turn of at least 40 degrees during the commitment, not a requested turn or ordinary course drift. Added summary counters for drag changes and each side. Exact break columns/events now include `power_active`, `holding_threshold` and `drag_threshold`. Existing batch harness and seed routing are preserved.

`Scripts/DragBurstChecks.gd` is a standalone headless SceneTree check: total-load payout at 40%, Power payout, catastrophic finite-cap overload, pre-hook span, actual upward rod geometry, both sides through the AI input path, and perceived danger lowering drag. Existing FightCoreChecks expectations that explicitly assumed locked Power/fish-only slip were updated; the broad suite was not run.

Validation: import passed. The focused check initially had a missing feeding fixture; after fixing the fixture all seven checks passed. Immediate transient payout was 4.62 m/s in both normal/Power cases. At 30 m/s separation the capped spool left dangerous tension. Rod geometry reached its upward pose within 0.2 s. Visual readability still needs the user's normal playtest; no screenshots or rendering tour were run.

Exactly one three-fight smoke ran with seed 12345, 20x, 90 s timeout per encounter. All completed: **2 SPOOLED, 1 THROWN, 0 LINE_BROKE**; mean duration 59.55 s. Impact extension was 0.000 m each time. Events contained 3 left bursts, 3 right bursts, 3 hook sets and 98 deliberate drag changes. Peak tensions were 187.72, 235.18 and 181.47; payout never exceeded 14 m/s. This tiny sample verifies operation, not balance. No further batch or tuning was performed.

Godot editor Main Run Args for the same bounded smoke:
`-- --fight-batch=3 --sim-speed=20 --batch-seed=12345 --batch-timeout=90`

For ordinary manual spectator play: `-- --ai-vs-ai`.
