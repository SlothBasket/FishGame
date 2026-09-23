> Latest rod-gesture/pump pass: [ROD_GESTURE_GUIDE.md](ROD_GESTURE_GUIDE.md) gives **Godot editor launch arguments**, directional gesture controls, interruption rules, pump audit, 88-actor baseline and current 60-float fisherman snapshots. Supersedes older button-jerk and population descriptions below.

> Current physical-cue/AI pass: [FIGHT_READABILITY_GUIDE.md](FIGHT_READABILITY_GUIDE.md) supersedes historical defaults below: **150 m spool, 42-float fish snapshots**, physical-pressure cues, skill overrides, visible spectator equipment and powered directional wear.

> Latest escape/AI rules: [ESCAPE_BALANCE_GUIDE.md](ESCAPE_BALANCE_GUIDE.md) documents powered resistance load, measured line damage and delayed fisherman perception. CHARGE BOAT is removed; older policy descriptions below are historical. Current snapshots: 41 fish / 56 fisherman floats.

> Current readability/testing pass: [SPECTATOR_GUIDE.md](SPECTATOR_GUIDE.md) supersedes earlier cadence windows/Overdrive cost and BEST MOVE coaching descriptions. It documents shared state-based AI actions, banners, dive bubbles, natural AI-vs-AI mode and the current 40-float fish snapshot.

> Latest fish-side rules: [SWIM_DRIVE_GUIDE.md](SWIM_DRIVE_GUIDE.md) supersedes the earlier fixed propulsion, always-away leverage, snapshot counts and dive-counter descriptions below. It documents Swim Drive, shared coaching, run buildup, committed dives, finite payout overload and current validation. The spatial and line-risk rules below remain in place.

# Fight controls, endurance and line pressure

All gameplay is server-owned. Human and AI drivers supply the same intents; cameras and HUD remain local. Both network instances must use this revision: fish snapshots now include endurance (29 floats), while fisher snapshots now contain 52 floats (capacity, lateral motion, warning ratio and counter pressure appended).

## Launch and controls

Run PowerShell in this directory:

```powershell
.\Launch.ps1 -HostGame -Role fisher -AI fish
.\Launch.ps1 -HostGame -Role fish -AI fisher
# Optional second human instead of AI:
.\Launch.ps1 -HostGame -Role fisher
.\Launch.ps1 -JoinIP 127.0.0.1 -Role fish
```

Argument-free Launch.ps1 opens the sandbox. Your current Godot editor F5 arguments launch the fish/AI-fisher test; this pass preserves that selection.

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

Fish retain their usual swim, sprint, dash and vertical controls. Fish HUD shows stamina/endurance plus qualitative pressure, gaining/losing line, outward leverage and strong counter pressure. Its high-pressure warning starts above 75% of nominal line strength; no drag setting, condition, boat marker or rod direction is shown. The fisherman warning starts at 90% of the current condition-dependent break threshold. Both flash only the exclamation mark. Development bait markers intentionally expose test lure location and can be disabled. Fisher HUD uses an anchored right-side panel with containers and vertical scrolling as a smaller-window fallback. It shows line out / capacity, visible LEFT/AWAY/RIGHT motion, DRAG slider and percentage, tension, condition, retrieve, Power stamina and Focus. The hook-meter caption and bar use a separate centered panel visible only during timing. Network status stays on the left; fish stamina/endurance is anchored at upper right beneath the score. Default viewport and window are 1920 × 1080. Procedural drag audio has been removed with no replacement.

## Code map

- `FightLine.gd`: per-encounter Resource for spool accounting, temporary rod take-up/buffer, load smoothing, capacity, fish-driven payout, reel pressure, wear, exposure and break hazard.
- `FightSession.gd`: authoritative hook phases, rod geometry, heading leverage, fatigue, line forces, jump/jerk/slack outcomes and landing.
- `FishPlayer.gd`: shared human/AI stamina spending, endurance ceiling/floor, exhausted sprint latch, and fight sprint output. Ordinary swim speed/turn limits remain unchanged.
- `FightTestDriver.gd`: legal AI intentions, stamina-aware runs/rests, orientation-based counter rod and cautious retrieve.
- `FisherView.gd`: owner-only camera, rod/line drawings and labeled HUD; no sound generator.
- `Reef.gd`: fish-only stamina/endurance readout on the existing HUD.
- `NetworkSession.gd`: adds server endurance to fish snapshots; retains role, sequence, rate and finite-input validation. Existing bounded smoke includes four seconds of AI fight exertion.
- `FightCoreChecks.gd`: bounded line/input/endurance contracts used by that smoke.

## Drag, retrieve and force

Line out changes only through retrieval and payout. Swimming inward creates slack rather than deleting spool line. Slack removes line contact. Capacity defaults to 250 m; reaching it finishes with the appended `SPOOLED` fish-win outcome and uses the existing cleanup/return-to-setup path.

Normal drag threshold is `strength * drag^drag_curve`. Default exponent **1.0** gives 38.5 / 44 / 55 / 77 force at 35% / 40% / 50% / 70% drag.

Fish propulsion load is `max(heading dot outward, 0) * throttle * acceleration * mass * propulsion_load_scale`, multiplied by the current sprint multiplier while boosting. Outward velocity adds a small damping contribution (0.7 per m/s). Directly-away heading has maximum outward leverage; perpendicular heading contributes little propulsion load, without reducing the fish's ordinary swimming speed. Prototype mass starts at 3.2 and increases modestly with fish growth.

Requested tension adds fish load, elastic extension, reel pressure and temporary jerk load. Retrieve contributes up to 20 force units, with 30 during Power. Normal recovery slows from full rate toward 15% as fish load approaches drag. Fish effort or actual elastic extension can trigger spool slipping against drag plus the rod buffer. The geometry branch prevents perpendicular/stationary fish from remaining far beyond available line just because their estimated outward effort is low. Reeling can therefore reach the drag cap and still recover line when the fish is not overpowering drag. Extra slipping-reel wear requires fish-driven slip, actual payout and retrieve; normal productive reeling is not penalized as slipping.

Normal tension caps near selected drag plus the current rod buffer, with brief retained shock. Power normally suppresses payout, requests recovery at 7 m/s, bypasses the drag cap, spends fisher stamina and increases wear. Its existing opening-run lock and sprint-start timing rules are preserved. Elastic extension can make a fresh opposing run very dangerous under Power.

## Rod take-up and pump/reel rhythm

`rod_pull = min(1, length(Vector2(horizontal, max(0, vertical))))`. Left/right and upward displacement build pressure; down from center releases vertical pressure, while any remaining lateral pull still counts. Diagonal input cannot double the maximum.

`take_up = maximum_rod_take_up * rod_pull` (default 2 m).

`holding_threshold = drag_threshold + maximum_rod_buffer * rod_pull` (default +15 force at full pull).

The working span is neutral-tip-to-fish distance plus temporary take-up. The authoritative neutral anchor is now the fixed boat water-level position. This reference prevents arbitrary animated-tip geometry from double-counting or reversing the intended rod pressure. Curved rod art still uses the existing rod tip; authoritative span and radial force share the fixed boat anchor. The HUD distance is this neutral reference; line slack uses the working span.

Take-up changes elastic extension/contact without changing spool line out. Pulling while taut increases load; lowering gives that temporary length back. If the fish moved closer during the pull, lowering without retrieving leaves slack. Reeling during the lowering stroke recovers that slack permanently. Rod buffer also falls as the rod centers, allowing the fish to take line more easily. It is a position-based mechanical allowance, not a timed power-up; holding it retains pressure, fatigue, wear and break risk. Power still bypasses the normal cap entirely.

Ordinary fish load and tension each use exponential response with a 0.25-second time constant. Existing rod input smoothing remains. Power, active jerk load, slack-to-taut contact and a sudden outward velocity jump use the faster existing tension response (12/s) and unsmoothed fish load. This keeps ordinary surges readable without making genuine impacts sluggish.

## Rod leverage and fatigue

The rod remains bounded to ±75 degrees horizontally, +55/-40 vertically. Opposite-side pressure uses fish **heading**, not a lateral-velocity sign. The counter coefficient grows as the fish presents its flank. Correct pressure adds lateral/vertical acceleration through the existing motor; it does not set facing or teleport the fish. Wrong-side pressure contributes little corrective leverage. Vertical heading supplies the dive counter component; existing dive jerks and jump counters remain.

Current stamina pays for sprints and emergency dashes. **Endurance** caps how much current stamina can recover during that fight:

- Sprinting costs 18 current stamina/s and 0.55 endurance/s.
- Paid dashes cost 14 current stamina and 0.8 endurance.
- Sustained outward effort and resisting counter pressure drain additional endurance, scaled by actual tension and contact.
- Non-sprint swimming always recovers stamina toward the endurance ceiling. Continuous rod fatigue can consume at most half of the 6 stamina/s fight regeneration; discrete jerks/dashes still spend stamina. Strong rod resistance continues reducing endurance. Resting/yielding can recover faster but is not required.
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

Slack hook security, lowered-rod jump defense, dive jerks, intentional hook timing and proximity-plus-recovered-line landing are retained. Landing now checks actual boat-relative position after movement: within 4 m horizontally, between 6 m underwater and 1 m above the surface, line out at most 10 m, and slack at most 2.5 m for 0.75 seconds. Stamina is not a landing gate.

## Main tuning values

| File | Values worth testing |
|---|---|
| FightLine | strength 110; drag curve 1; retrieve 4.5; Power 7; reel pressure 20; elasticity 22 |
| FightLine pumping | maximum_rod_take_up 2 m; maximum_rod_buffer 15 force; maximum_line_out 250 m; ordinary_response_time .25 s |
| FightLine wear | onset .545 of strength; load .035; Power .035; slipping retrieve .022; shock .003 |
| FightLine risk | fresh threshold .773; damaged .55; curve 1.1; base hazard .012; damage multiplier 16; exposure gain 1, decay 1.5, multiplier .6 |
| FightSession | propulsion scale .85; lateral force 30; current resistance fatigue 13; endurance pressure drain .18 and leverage drain .65 |
| FishPlayer | endurance floor .30; sprint endurance .55/s; dash endurance .8; current regen 12 × fight multiplier .5 × continuous pressure drain capped at half regeneration |

These are reasonable first-pass defaults, not subjective balance results. Runtime-created actors use script exports' default values unless assigned before entering the tree.

## Pumping pass: first manual checks

1. Launch Fisher vs AI Fish and hook one. With taut line and steady retrieve, compare centered, half-pulled and fully pulled rod. Tension should increase; full pull at 40% drag can hold roughly 59 force before shocks.
2. Pull, then center without reeling. Compare with pulling then centering while reeling. Only retrieval should permanently reduce spool line; the second sequence should retain more of the gained ground.
3. Let the rod down during a run or jump. Watch lower load/buffer and easier payout. Compare a raised rod on the same kind of run.
4. At low drag, watch LINE approach 100 / 250 m and confirm SPOOLED returns to setup. For a shorter targeted manual test, lower `maximum_line_out` in FightLine temporarily, keeping it greater than the initial cast distance.
5. Check the anchored right-side panel at 1920 × 1080 and a smaller resized window; scroll if necessary. Hook timing should be centered and disappear afterward. Network text stays left, fish energy upper right. LEFT/AWAY/RIGHT reports visible lateral velocity only; it does not reveal AI intent (stationary/inward motion falls into the default AWAY bucket).

## Existing fight checklist

1. Launch Fisher vs AI Fish. Select minnow with X, cast G, wait for the bite, hold Q and release near 75%.
2. Confirm no generated fight noise. Check DRAG label/slider/percentage; hook meter must disappear after timing.
3. Start at 40% drag (44 force). Compare ordinary outward swimming with sprinting: ordinary movement should create working pressure, sprinting should take line.
4. Hold W at moderate then high saved reel settings. When fish output is below drag, requested tension should rise and line out should decrease. During actual payout, aggressive retrieve should cost more condition.
5. During a sideways run, pull the rod opposite the fish's heading, then deliberately the same way. Compare the curved path and resistance. Directly-away heading should be harder to turn.
6. Watch several run/rest exchanges. AI runs should shorten as endurance drops; resting should still permit recovery. Assess whether fights progress rather than stagnate at the arena edge.
7. Briefly use Power against a fresh sprint, then against a tired/yielding fish. Payout should stop; fresh opposition should produce substantially more dangerous load. Back off between high-pressure pushes.
8. Compare aggressive late-fight pushes with conserved versus damaged line across ordinary play. Breaks are random; a single outcome does not establish the odds.
9. Launch Fish vs AI Fisher. Check STAMINA current/max and ENDURANCE, no fisherman data. Sprint away, turn broadside and resist counter pressure, then yield/rest. Confirm stamina recovery respects the lower ceiling and held exhausted sprint does not flicker.
10. Try one dive/jerk exchange, one jump/lowered-rod exchange and one inward slack charge. Reel close and confirm landing/reset/recast.

## Spatial safety and controlled force

The spool cannot recover below actual distance + temporary take-up − `maximum_extension` (2.5 m). If real separation demands more line, normal payout responds to extension immediately; it is no longer dependent only on fish heading/effort. Every swimming/airborne move and dash substep constrains outward displacement at the finite elastic span. Tangential motion remains possible, and the constraint does not create a large inward velocity or assign fish position.

After actual movement, `after_fish_move` synchronizes distance/slack and checks landing/spool-out. An unexpected invalid starting span or moved anchor pays the missing line immediately, even under Power, instead of storing extreme stretch. Power normally blocks payout but cannot preserve an impossible spatial state. Its requested recovery stalls at the physical span floor until the fish moves closer. This means a blocked fish cannot be cranked down to a few numerical metres while still far away.

Line acceleration is capped at 20 m/s². Its vertical component is scaled to 15%, capped at 2 m/s² and upward force fades out during the last 2 m below the surface. Added horizontal pull cannot accelerate an inward-moving fish beyond 7 m/s; faster fish-driven motion is not clamped by that speed cap. Hook-set impulse no longer adds upward speed. Directional leverage and dangerous tension remain distinct from physical acceleration, so Power can damage the line without launching the fish.

FishPlayer records upward fish intent/velocity before adding line force. Surface crossing only arms normal airborne hook-throw risk when this recent fish-driven breach intent exists. Being lifted by line force alone does not qualify. This is a short 0.25 s intent latch, not a new jump mechanic.

The AI fisher and smoke default are now MINNOW. AI fish slow their approach, start a short charge only when aligned and in range, release according to distance/charge duration, and cancel if the target goes behind them or is lost. The test marker is a small local billboard on fisherman bait, hidden on claiming/eating, and replicated as a simple source flag in reliable bait lifecycle events. Set `NetworkSession.show_test_bait_markers = false` to disable creation. No ecosystem/AI bait behavior was retuned.

Additional tunables: `FightLine.maximum_extension = 2.5`, `maximum_line_out = 250`; `FightSession.maximum_line_acceleration = 20`, `maximum_vertical_acceleration = 2`, `vertical_pull_fraction = .15`, `maximum_pull_speed = 7`, `landing_distance = 4`, `landing_depth = 6`, existing confirmation `.75`; `FishPlayer.fight_regen_multiplier = .5`.

## Spatial pass manual checks

1. Launch Fisher vs AI Fish, use minnow, locate the TEST BAIT marker and hook it. Watch visible distance and line out while retrieving continuously. Recovery should stop when blocked, with no delayed snap when moving the rod afterward.
2. Power against a fresh run, then a yielding fish. Check controlled inward movement and minimal upward lifting; lowering still releases rod pressure. Low drag should require a sustained run to spool 250 m.
3. Bring the fish into the boat zone. Confirm stable landing after .75 s, then recast. A fish far away must never land merely because the displayed line is short.
4. Launch Fish vs AI Fisher. Follow the test minnow marker. Swim normally while under pressure: stamina should climb toward its current endurance ceiling. Sprint should drain it. Compare away/broadside/slack moves with the fish feedback.
5. Deliberately breach and compare with a fish merely being pulled near the surface. Only the intentional/natural breach should receive the airborne hook-throw contribution. Check both high-tension warnings during aggressive pressure, not ordinary working load.

## Validation and limits

One import and one short headless Fisher-vs-AI-Fish smoke passed all 30 contracts. New checks cover impossible initial span recovery, the non-teleporting taut guard, blocked Power recovery, acceleration bounds, and physical near/far landing eligibility. The live minnow encounter entered the fight and passed landing/reset using the existing forced-proximity fixture. The smoke deliberately establishes bite contact, so it does not prove organic AI approach reliability. That remains a manual check, as do visible marker/warning readability and breach classification feel.

No repeated gameplay simulations, screenshots or long balance runs were performed. The optional Fish-vs-AI-Fisher session was not run. Godot emitted its existing certificate-store warning without script errors. The hard elastic guard may feel firm at maximum stretch under Power; tune force/extension after manual testing rather than increasing stored error. Multiplayer roles require matching versions (29 fish fields, 52 fisher fields, 19 reliable bait-event fields). The remote fetch failed; this pass started from clean local main matching recorded origin/main at 4e27385.
