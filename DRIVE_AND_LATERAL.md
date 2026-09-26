# Renewable Drive and real lateral movement

This pass uses the user's 500-fight report (381 landings, 106 throws, 12 breaks, 1 spool-out) and manual observations. It does not target an AI win percentage. Line strength/hazard, drag, capacity, landing geometry, Jump decision frequency, rod lift and pump accounting are preserved.

## Player resource rules

Keep building Swim Drive with the existing alternating physical strokes. Building a full bar alone spends no stamina. Press the existing sprint control while moving forward with at least **0.80 Drive**: a **1.0 s normal Drive burst** spends **0.75 Drive** immediately (a full bar leaves 0.25). Hold sprint through that second to use its propulsion. Continuing sprint afterward is deliberate stamina-funded extension. Release/repress after rebuilding to start another normal burst; holding the button does not repeatedly auto-spend full bars.

For Overdrive, hold sprint and perform a fast measured stroke reversal (existing fast cadence window), with at least **0.65 Drive and 13 stamina**. It spends **0.65 Drive + 12 stamina** at activation, lasts **1.4 s**, and adds **8 stamina/s** alongside ordinary paid sprint. This is stronger/longer than the normal Drive burst. Fast strokes while not sprinting build Drive rather than forcing escalation. No Drive builds while a burst/Overdrive is active. Passive Drive decay and counter disruption remain.

All tunables and resource clocks are in `FishFightMotion`; actual energy deductions are in `FishPlayer`. Normal Drive propulsion has zero direct sprint/Overdrive stamina cost; rod resistance, a Dive/ascent or an enemy counter can still affect stamina. Existing free opening-run rules remain. Stamina exhaustion does not prevent using sufficient stored Drive. Normal swimming and steering remain available.

Drive now builds outside fights using the same measured head/body stroke path. Motion stepping is shared; fight-only Dive/ascent logic remains gated. The fight no longer resets Swim Drive on the bite. Fish carry only the Drive they legitimately built. The optional AI pre-bait naturalism expansion was left out.

## Resistance-dependent energy cost

`FishFightMotion.opposition_cost = 1 + contact * max(0, heading dot outward)^2`.

This multiplies paid sprint/Overdrive stamina and maneuver endurance exertion. Against a taut line, equal duration/effort costs **2.0x directly outward**, **1.25x at 60 degrees**, and **1.0x purely lateral/inward**. Slack removes this extra resistance cost. There is no extra lateral damage or force bonus. The shared nonlinear endurance curve still applies afterward. AI course scoring now considers this same radial resistance tradeoff instead of only metres gained; no extra side-burst scheduling frequency was added.

## True side bursts

The shared steering overlay uses horizontal **outward = Fish - Fisher**, **right = outward cross UP**. Sustained A/D or a strong boat-relative look direction for **0.35 s**, adequate Drive (or an active paid-for Drive burst) and run build commit the target **55 degrees outward toward the chosen side**. AI supplies legal 60-degree boat-relative aim, with the same symmetric selection and boundary fallback.

The target is anchored during preparation. Normal head/body steering supplies the visible carve; no position, heading or velocity snap is applied. The **0.75 s commitment** survives releasing side/sprint intent, while retaining forward throttle. Collision/impact, interrupted powered control, air/dive/ascent exclusions can cancel it. It uses the ordinary motor and energy rules.

`measure_side` runs AFTER movement. A burst event requires heading's selected-side component > **0.6**, selected-side velocity > **2 m/s**, both sustained for **0.1 s** during the committed maneuver. Measurements use the current boat-relative frame; ordinary lateral swimming outside a commitment never counts. Events include radial/lateral velocity, signed boat-relative angle, and integrated outward/lateral displacement, updated until commitment ends. The snapshot at burst recognition is distinct from its eventual total displacement.

## Power ordering and counter gradient

Power Reel remains subject to the normal drag clutch. After **0.25 s** of active Power, a newly starting sufficiently strong Overdrive (>=60% of its nominal maximum) interrupts it for **1.5 s**. Retrieve and aggressive rod gestures are blocked during recovery, the rod is visibly pulled down, and normal drag keeps running. Camera and basic controls stay available. An Overdrive that started before Power does not retroactively interrupt it. This is server-owned FightSession logic for humans and AI. The old automatic Power-to-Fish sprint lock was removed so Fish can legally answer the commitment.

Counter lateness now rises continuously across `maneuver_age / (early_window + 1 s)`. There is no long flat perfect plateau. Existing directional correctness and force/resistance still apply; effectiveness decreases toward 15%, while jerk shock increases. A strong correct straight-Run counter clears Drive/run output, applies the existing stamina/endurance damage and disruption, and adds bounded lateral recoil plus a short physical head deflection. It never scripts a 180-degree rotation or line-length award. No additional hook-risk change was made.

## Procedural player/world cues

Fish: Drive meter remains visible outside fights, with READY, BURST, DISRUPTED and OVERDRIVE labels; existing stamina/endurance HUD adds reduced-power feedback. Tail amplitude/rate follows Drive. Normal bursts use a lighter bubble stream, Overdrive uses the stronger stream, and committed side bursts add a **28-degree body bank** and faster wake. Preparatory head/body carve remains visible before commitment.

Fisher: a prominent compact status label shows REEL READY, DRAG PAYING OUT, POWER REEL or POWER INTERRUPTED alongside existing stamina, drag, condition and tension bars. The rod physically bends/loads using the existing line presentation; the Overdrive punishment visibly drags it downward. Development HUD remains available. No art assets or presentation-heavy test tour was added.

Network snapshots append presentation state: **51 Fish floats** (normal burst timer, side timer/sign appended) and **64 Fisher floats** (Power recovery appended). Senders, readers and local smoke guards use the updated sizes; all peers need the same build.

## Telemetry

Adds average/max Drive, total Drive gained/spent, normal Drive burst count, direct stamina spending during normal Drive and Overdrive, powered straight/lateral time, radial/lateral energy totals, actual lateral burst displacement/angle/velocities, Overdrive-Power punish count/event, and counter effectiveness bins (>=0.7, >=0.35, below0.35). Energy totals track direct propulsion spending; separate counter/rod stamina loss is not mislabeled as Drive spending. Lifetime resource counters are baselined at encounter entry. Straight powered time means heading within 30 degrees of radial outward. Existing progression and exact break fields remain.

Side events are amended in memory as the commitment travels. Only true detected bursts contribute displacement totals. `OVERDRIVE_PUNISH_POWER` reports the order-sensitive interaction. Counter effectiveness continues to be recorded per counter as well as binned. No batch harness rewrite.

## Files and validation

Gameplay: FishFightMotion, FishPlayer, FightSession, FightDecisions, FightTestDriver. Presentation/replication: FishVisual, Reef, FisherView, FightSpectator, NetworkSession. Measurement: FightTelemetry. Checks: new DriveBurstChecks plus updated existing FightCoreChecks/DragBurstChecks expectations. Guides and milestone index updated.

Import/parse passed. Ten focused DriveBurstChecks passed: free-swim build; normal burst leaves 25% with no direct stamina cost; Overdrive spends both; Power ordering in both directions; equal-duration radial cost comparison; one-frame rejection; physical left and right motor runs; ordinary turn rejected by telemetry. The mirrored motor fixture measured **-8.75/+8.75 m lateral displacement** and **10.38 m/s peak selected-side speed**. These are controlled motor results, not a claim of identical displacement in a live contested fight.

Exactly one 3-fight smoke used seed12345, 20x, timeout90: **2 THROWN, 1 TIMEOUT**, no landings/breaks/spool-outs. All IMPACT extensions were 0.000 m. It recorded 19 normal Drive bursts, with zero direct normal-Drive stamina cost, and 3 left/4 right true bursts. No natural Overdrive or Power-punish occurred in this small sample; those were verified by the focused ordered-interaction contract. No win-rate adjustment or second batch followed. Final integration cleanup corrected remaining UI snapshot guards, moved the existing side endurance charge to the post-movement event, and made frame measurements follow the current boat axis; import was rechecked for integration edits. Graphical readability and longer-run AI resource choices remain for manual testing.

Godot editor Main Run Args: `-- --ai-vs-ai`. To reproduce the bounded smoke: `-- --fight-batch=3 --sim-speed=20 --batch-seed=12345 --batch-timeout=90`.
