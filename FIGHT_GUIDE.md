# Fight controls, endurance and line pressure

All gameplay is server-owned. Human and AI drivers supply the same intents; cameras and HUD remain local. Both network instances must use this revision: fish snapshots now include endurance (23 floats), while fisher snapshots remain 48 floats.

## Launch and controls

Run PowerShell in this directory:

```powershell
.\Launch.ps1 -HostGame -Role fisher -AI fish
.\Launch.ps1 -HostGame -Role fish -AI fisher
# Optional second human instead of AI:
.\Launch.ps1 -HostGame -Role fisher
.\Launch.ps1 -JoinIP 127.0.0.1 -Role fish
```

Argument-free Launch.ps1 opens the sandbox. Your local Godot editor F5 arguments still launch the fisherman/AI-fish test and were preserved in checkpoint `95a3b46`.

| Fisher action | Keyboard/mouse | Controller |
|---|---|---|
| Cast / species | G / X | X / Y |
| Retrieve | Hold W at saved setting | Continuous RT |
| Saved reel speed | Wheel, 5% steps | D-pad up/down |
| Drag | Brackets, 5% steps; Escape unlocks slider cursor | D-pad left/right |
| Rod pressure | Mouse during fight | Right stick |
| Hook-set / jerk | Hold/release Q near 75% meter; Q during fight | RB |
| Power Reel | Hold Shift | LB |
| Fish Vision | Hold V | Left-stick click |
| Bait camera | C | Right-stick click |

Fish retain their usual swim, sprint, dash and vertical controls. Fish HUD shows current stamina / current maximum, plus endurance percentage. It exposes no drag, line condition, boat marker or rod direction. Fisher HUD explicitly groups DRAG, slider and percentage before tension/condition/retrieve. Both hook-meter caption and bar appear only during timing. Procedural drag audio has been removed with no replacement.

## Code map

- `FightLine.gd`: per-encounter Resource for spool accounting, fish-driven payout, reel pressure, wear, exposure and break hazard.
- `FightSession.gd`: authoritative hook phases, rod geometry, heading leverage, fatigue, line forces, jump/jerk/slack outcomes and landing.
- `FishPlayer.gd`: shared human/AI stamina spending, endurance ceiling/floor, exhausted sprint latch, and fight sprint output. Ordinary swim speed/turn limits remain unchanged.
- `FightTestDriver.gd`: legal AI intentions, stamina-aware runs/rests, orientation-based counter rod and cautious retrieve.
- `FisherView.gd`: owner-only camera, rod/line drawings and labeled HUD; no sound generator.
- `Reef.gd`: fish-only stamina/endurance readout on the existing HUD.
- `NetworkSession.gd`: adds server endurance to fish snapshots; retains role, sequence, rate and finite-input validation. Existing bounded smoke includes four seconds of AI fight exertion.
- `FightCoreChecks.gd`: bounded line/input/endurance contracts used by that smoke.

## Drag, retrieve and force

Line out changes only through retrieval and payout. Swimming inward creates slack rather than deleting spool line. Slack removes line contact.

Normal drag threshold is `strength * drag^drag_curve`. Default exponent **1.0** gives 38.5 / 44 / 55 / 77 force at 35% / 40% / 50% / 70% drag.

Fish propulsion load is `max(heading dot outward, 0) * throttle * acceleration * mass * propulsion_load_scale`, multiplied by the current sprint multiplier while boosting. Outward velocity adds a small damping contribution (0.7 per m/s). Directly-away heading has maximum outward leverage; perpendicular heading contributes little propulsion load, without reducing the fish's ordinary swimming speed. Prototype mass starts at 3.2 and increases modestly with fish growth.

Requested tension adds fish load, elastic extension, reel pressure and temporary jerk load. Retrieve contributes up to 20 force units, with 30 during Power. Normal recovery slows from full rate toward 15% as fish load approaches drag. Fish load—not the combined reel/jerk request—determines normal spool slipping. Reeling can therefore reach the drag cap and still recover line when the fish is not overpowering drag. Extra slipping-reel wear requires fish-driven slip, actual payout and retrieve; normal productive reeling is not penalized as slipping.

Normal tension caps near selected drag, with brief retained shock. Power suppresses payout, retrieves at 7 m/s, bypasses the drag cap, spends fisher stamina and increases wear. Its existing opening-run lock and sprint-start timing rules are preserved. Elastic extension can make a fresh opposing run very dangerous under Power.

## Rod leverage and fatigue

The rod remains bounded to ±75 degrees horizontally, +55/-40 vertically. Opposite-side pressure uses fish **heading**, not a lateral-velocity sign. The counter coefficient grows as the fish presents its flank. Correct pressure adds lateral/vertical acceleration through the existing motor; it does not set facing or teleport the fish. Wrong-side pressure contributes little corrective leverage. Vertical heading supplies the dive counter component; existing dive jerks and jump counters remain.

Current stamina pays for sprints and emergency dashes. **Endurance** caps how much current stamina can recover during that fight:

- Sprinting costs 18 current stamina/s and 0.55 endurance/s.
- Paid dashes cost 14 current stamina and 0.8 endurance.
- Sustained outward effort and resisting counter pressure drain additional endurance, scaled by actual tension and contact.
- Correct counter pressure drains current stamina and suppresses regeneration. Yielding/resting permits recovery up to the reduced ceiling.
- Endurance cannot fall below 30% of capacity. Fight sprint multiplier fades from 1.85 at full endurance toward 1.25 as endurance approaches zero (about 1.43 at the default floor). Ordinary swimming remains available.
- Exhausted held sprint cannot pulse indefinitely; release/repress is required. AI uses the same costs and physics.
- Each new encounter restores the endurance ceiling. Ending an encounter restores that ceiling and clears force/regen locks; landing additionally restores current stamina through the existing reset.

AI fish mostly swim outward, sprint with reserves, stop at low stamina, and yield at 20% until recovering above 75%. Occasional side changes, dives, jumps and inward slack charges remain. Shorter endurance budgets shorten later runs. AI fisher counters heading, stops aggressive retrieve while fish load exceeds drag, and occasionally uses Power against tired non-slipping fish. It remains a deliberately simple test pilot.

## Line condition as risk budget

Condition never directly triggers a break. It bottoms at 2%; break decisions remain probabilistic and require dangerous tension.

Wear begins near **60 force** (strength × 0.545), below fresh-line break territory. Sustained load wear is quadratic above that band; Power, shock and aggressive reeling during fish-driven payout add wear.

`threshold = strength * lerp(damaged_threshold, fresh_threshold, condition^risk_curve)`

Defaults give about **85 force** at full condition, **76** at 70%, **72** at 50%, and **67** at 30%. Above threshold:

`hazard = base_rate * normalized_excess² * (1 + damage_multiplier * damage²) * (1 + capped_exposure * exposure_multiplier)`

Exposure builds by elapsed seconds above the current threshold and decays at 1.5 seconds per safe second. Its hazard contribution caps at 12 seconds. The per-tick break chance is **`1 - exp(-hazard * delta)`**; there is no frame-count roll or guaranteed condition/tension cutoff. Brief pushes have less risk than sustained ones, and spending condition lowers the safety margin for the next push. Fresh-line risk just above threshold is tiny; the same force against damaged line is more dangerous.

Slack hook security, lowered-rod jump defense, dive jerks, intentional hook timing and proximity-plus-recovered-line landing are retained. Landing still requires 0.75 seconds within 3 m and line out under rod length + 3 m; stamina is not a landing gate.

## Main tuning values

| File | Values worth testing |
|---|---|
| FightLine | strength 110; drag curve 1; retrieve 4.5; Power 7; reel pressure 20; elasticity 22 |
| FightLine wear | onset .545 of strength; load .035; Power .035; slipping retrieve .022; shock .003 |
| FightLine risk | fresh threshold .773; damaged .55; curve 1.1; base hazard .012; damage multiplier 16; exposure gain 1, decay 1.5, multiplier .6 |
| FightSession | propulsion scale .85; lateral force 30; current resistance fatigue 13; endurance pressure drain .18 and leverage drain .65 |
| FishPlayer | endurance floor .30; sprint endurance .55/s; dash endurance .8; current regen 12 × fight multiplier .3 × pressure suppression |

These are reasonable first-pass defaults, not subjective balance results. Runtime-created actors use script exports' default values unless assigned before entering the tree.

## Exact manual checklist

1. Launch Fisher vs AI Fish. Select squid with X, cast G, wait for the bite, hold Q and release near 75%.
2. Confirm no generated fight noise. Check DRAG label/slider/percentage; hook meter must disappear after timing.
3. Start at 40% drag (44 force). Compare ordinary outward swimming with sprinting: ordinary movement should create working pressure, sprinting should take line.
4. Hold W at moderate then high saved reel settings. When fish output is below drag, requested tension should rise and line out should decrease. During actual payout, aggressive retrieve should cost more condition.
5. During a sideways run, pull the rod opposite the fish's heading, then deliberately the same way. Compare the curved path and resistance. Directly-away heading should be harder to turn.
6. Watch several run/rest exchanges. AI runs should shorten as endurance drops; resting should still permit recovery. Assess whether fights progress rather than stagnate at the arena edge.
7. Briefly use Power against a fresh sprint, then against a tired/yielding fish. Payout should stop; fresh opposition should produce substantially more dangerous load. Back off between high-pressure pushes.
8. Compare aggressive late-fight pushes with conserved versus damaged line across ordinary play. Breaks are random; a single outcome does not establish the odds.
9. Launch Fish vs AI Fisher. Check STAMINA current/max and ENDURANCE, no fisherman data. Sprint away, turn broadside and resist counter pressure, then yield/rest. Confirm stamina recovery respects the lower ceiling and held exhausted sprint does not flicker.
10. Try one dive/jerk exchange, one jump/lowered-rod exchange and one inward slack charge. Reel close and confirm landing/reset/recast.

## Validation and limits

One import check and one short headless Fisher-vs-AI-Fish smoke passed. Fifteen deterministic contracts checked drag, productive retrieve vs slip, Power, risk/condition/exposure, endurance floor, validated input and rod bounds. The live encounter reached the fight, reduced AI endurance from 100 to about 97.8 in its brief exertion interval, then passed the existing forced-proximity landing/reset fixture. That fixture verifies landing logic, not organic full-fight balance. Godot emitted its existing root-certificate-store warning, with no script errors.

No additional gameplay tours or repeated simulations were run. Visible HUD layout, rod feel, full fight duration, AI arena-edge behavior and controller hardware remain manual checks. Bait/environment/Fish Vision/audio replacement work was intentionally excluded. The remote fetch failed due to the session's network routing; this pass used local main matching the recorded origin/main at 516675c and preserved the local editor setting first.
