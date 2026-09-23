# Fish Swim Drive, directional contest and dives

This pass extends the existing authoritative fight. It keeps the 250 m spool, pump/reel take-up, finite extension safety, landing, line condition/hazard, hook timing, stamina/endurance, minnow test bait and debug marker. No GitHub operations were performed.

## Controls and first manual test

Launch either role from PowerShell:

```powershell
.\Launch.ps1 -HostGame -Role fish -AI fisher
.\Launch.ps1 -HostGame -Role fisher -AI fish
```

While hooked, W still provides ordinary swimming. Alternate A/D, or make small alternating horizontal mouse movements, roughly once every **0.48 seconds per side change**. The SWIM DRIVE bar should fill. Both devices share one stroke tracker; using both provides no separate bonus. Gamepad left-stick steering also reaches that same tracker. Mouse motion still aims the fish, but horizontal sensitivity is multiplied by .45 while hooked to reduce sway. Mouse strokes need 6 accumulated horizontal pixels; they do not require a large absolute camera angle.

Faster changes (less than about .32 seconds) provide temporary OVERDRIVE while consuming the stored bar. Try building the bar first, then spending it through a short fast sequence. Inputs faster than .08 seconds are coalesced into the same bounded stroke timing; strength cannot scale without limit. This is not a reaction-time competition against an unlimited mouse input rate.

Hold Shift for a run. Output builds over .6 seconds; high Drive improves it. Sprint still spends stamina and endurance, and non-sprint swimming still recovers current stamina up to the reduced ceiling. Release Shift to recover and reset an interrupted dive.

To dive, sprint while pointing/swimming more than 35 degrees downward for .4 seconds. DIVE POWER appears and builds over roughly one second. Upward rod pressure above .7 interrupts while power is below .55. After that point it increases dangerous load without cancelling the dive. Release sprint, exhaust stamina or contact bottom to end the dive. An early interruption requires releasing sprint before recommitting.

## Shared directional rule

Left/right are defined in the horizontal **boat-to-fish frame**, not screen space. Faint boat and line references are provided while hooked to make that frame readable.

- Center rod: away is strongest.
- Rod left and fish left: strong propulsion efficiency, little lateral counter force.
- Rod right and fish left: strong lateral counter force and sustained resistance fatigue.
- Rod magnitude still controls take-up and holding buffer independently of directional effectiveness.

`FightContest.evaluate()` returns propulsion efficiency, lateral counter and vertical counter. For a side component `s` and horizontal rod `r`, following uses `max(0,s*r)` and countering uses `max(0,-s*r)`. Full matching side gives .95 efficiency; directly-away efficiency declines modestly from 1 to .7 as the rod commits laterally. Following a lowered vertical rod is also recognized. This avoids penalizing all sideways movement equally.

Fish BEST MOVE evaluates candidate away/left/right/down headings with that same function, balancing efficiency against counter coefficients. Fisher BEST COUNTER evaluates which rod side yields the larger actual counter coefficient, with the explicit early/late dive rule layered on top. Both AI pilots call these same helpers. Coaching does not use hidden AI plans.

Successful lateral counters drive a smoothed body roll up to about **16 degrees**, stronger rod bend, and endurance drain. The same signed rod/counter coefficient powers all three. GOOD COUNTER versus POOR ANGLE indicates directional effectiveness, not simply total tension. A fully pulled rod can still have poor directional control.

## Files and responsibilities

- `FishFightMotion.gd`: per-fish server-owned Resource containing cadence, stored Drive, overdrive cost, run ramp, dive commitment and built propulsion. It accepts FishInput, heading, speed, stamina and bottom contact; it never reads devices or sets transforms.
- `FightContest.gd`: pure shared efficiency/counter calculations and coaching choices. Modify this first when changing directional rules.
- `FishInput.gd`: signed `stroke_axis` intent for mouse sway; A/D retains its usual steering field.
- `FishPlayer.gd`: detects local mouse strokes, reduces hooked horizontal camera sway, runs the shared motion component, applies Drive to speed/acceleration, and applies dive acceleration. Floating-body bottom detection uses collision normals rather than `is_on_floor()`.
- `FishFeeding.gd`: retains the shared line constraint during dash substeps and ends a dive on seabed dash contact.
- `FightSession.gd`: combines built motion with contest efficiency, handles early/late dive counters, and applies existing capped line forces, fatigue and outcomes.
- `FightLine.gd`: finite mechanical payout plus residual elastic load; existing wear/hazard and spatial safeguards remain.
- `FishFightReferences.gd`: local-only faint line and boat glyph, visible only while hooked; no physics.
- `Reef.gd` / `FisherView.gd`: Drive/Dive bars, coaching and directional feedback within existing HUDs.
- `FightTestDriver.gd`: legal .53-second A/D cadence, imperfect runs and occasional dives; fisher follows the shared counter choice. No direct Drive grants or special AI forces.
- `NetworkSession.gd`: validates the added mouse intent and replicates authoritative effort, coaching, roll and anchor position. Test-only host-fish automation supports the second bounded smoke.
- `FightCoreChecks.gd`: small deterministic cadence/contest/dive/payout checks plus existing fight contracts.

## Drive and built force

Drive ranges from 0 to `sustainable_max` (1). Ideal alternating strokes add `drive_gain` (.18) times cadence quality, while continuous decay removes .07 per second. The ideal tolerance is .16 seconds; slower timing fades quality gradually. Faster-than-efficient strokes set a capped overdrive bonus and a consumption rate instead of granting another independent energy source.

Movement multiplier is `1 + .22 * normalized_drive + overdrive * normalized_drive`. With an empty bar there is no overdrive benefit. Fast cadence consumption increases with the ratio of ideal interval to actual interval, capped at three times its base consumption. Overdrive also decays when strokes cease.

Run force no longer jumps directly to the full sprint multiplier. The current run build, Drive and endurance jointly scale the available sprint bonus. Ordinary cruise still works at zero Drive.

Line propulsion uses a smoothed built-effort budget: throttle × (.35 + .65 × normalized actual speed) × Drive multiplier × run contribution. Contest efficiency projects that budget into effective line load. Thus speed buildup and cadence matter; heading times a fixed throttle force is no longer the whole model. The existing small outward-velocity damping term remains, rather than adding a second full momentum force budget. Dive power contributes additional downward acceleration and load.

## Dive and payout mechanics

Dive adds up to 9 m/s² downward acceleration while spending 12 extra stamina/s. Power grows to 1, adding up to 35 load units. Early strong up-counter interrupts and creates a sharp load pulse; late counter maintains a pulse of 35 + 40 × power without cancelling the dive. Rod-up force remains physically capped by the prior spatial pass, so a counter cannot launch the fish into the air.

Payout demand converts force imbalance into an **elastic displacement** through elasticity, then into recovery rate through payout response. It is capped at **14 m/s** (previously 22). Remaining stretch after payout adds tension above nominal drag; a late dive counter also contributes a genuine transient load. Low drag helps but does not erase residual extension or shocks.

The full 3D boat-to-fish distance remains authoritative. Deeper dives consume real line. The pre-move elastic guard and exceptional post-move reconciliation remain: an invalid external/initial span can pay emergency line to prevent a teleport, but ordinary legal movement is constrained before that fallback. Power normally suppresses payout; it cannot retain an impossible spatial state.

## Tuning and debug switches

| Location | Main values |
|---|---|
| FishFightMotion cadence | sustainable_max 1; overdrive_max .35; ideal_stroke_interval .48; timing_tolerance .16; minimum_stroke_interval .08 |
| FishFightMotion energy | drive_gain .18; drive_decay .07/s; fast_cadence_scaling .8; overdrive_consumption .65/s times cadence cost |
| FishFightMotion run/dive | run_build_time .6 s; dive_angle 35 degrees; dive_commit_time .4 s; dive_build_time 1 s; dive_counter_window .55 power; dive_stamina_drain 12/s; dive_acceleration 9 |
| FishPlayer | minimum_mouse_stroke 6 pixels; hooked_sway_camera_scale .45; show_fight_coaching true |
| FightSession | leverage_endurance_drain .95; body-roll target 16 degrees; early counter rod threshold .7 |
| FightLine | maximum_payout 14 m/s; existing elasticity 22 and response 6 |
| Local references | FishFightReferences.enabled; line alpha .13, boat glyph alpha .22 |
| Fisher coaching | FisherView.show_fight_coaching |

Runtime-created Resources use script defaults. Debug coaching/reference switches are independent of authoritative simulation. Turning them off changes no gameplay.

## Networking and validation

Fish intent now has seven validated finite floats, with mouse stroke axis clamped to [-1,1]. The server owns stroke timing, Drive, dive state and outcomes; clients never submit force or Drive totals. Snapshots now have **39 fish fields** and **55 fisherman fields**; reliable bait events remain 19 fields. Matching revisions are required.

One import check, one Fisher-vs-AI-Fish smoke and one Fish-vs-AI-Fisher smoke passed. They checked shared/non-stacking cadence, bounded overdrive spending, run ramp, contest/coaching agreement, early interruption, committed dive coaching, bottom cancellation, payout overload, existing spatial contracts and landing/reset. The first role ran 39 checks; the second ran 38 because it has no local fisherman HUD. Both encounters used the existing deterministic contact/landing fixtures, not a full natural fight. No long simulations, screenshots or automatic balance loops were run.

Manual checks still needed: subtle mouse comfort, AI natural bite approach, practical side interpretation, faint-reference readability, body-roll direction/feel, full dive exchanges and payout tuning during a real run. The .08-second stroke floor intentionally limits extreme shaking. High-end forces and dive duration are first-pass values. Use good rhythm, then a brief overdrive run; compare matching and opposing rod sides; counter one dive early and another late. Check that late pressure is risky without launching either actor. No GitHub fetch/push was attempted.
