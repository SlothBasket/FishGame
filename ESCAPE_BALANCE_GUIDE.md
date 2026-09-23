# Powered resistance, escape AI and delayed fisher perception

This pass keeps line strength, condition/break-risk formulas, drag/payout, spool capacity, physical acceleration caps, dive rules, landing and server authority. Your local spectator editor arguments were checkpointed as `d8b3d4f`. No GitHub operations were performed.

## What changed

CHARGE BOAT has been removed from the fish action enum, scoring, driver and coaching. Human swimming toward the boat remains possible. Available AI/coaching actions are RUN, LEFT, RIGHT, DIVE, JUMP and REST.

The fish banks Drive at the legal ideal cadence before committing to sustained sprint. A run begins above 70% current stamina ceiling with Drive above .55, and ends below 28% stamina or when REST is selected. Near the landing zone, an emergency run remains available. When a committed run has Drive above .85, stamina above 55%, and rod pressure or positive line gain offers an opportunity, the pilot uses a 1.5-second fast-cadence burst. This spends the same Overdrive resource as a human; no forces/resources/outcomes are granted directly. Recovery still uses legal swimming and strokes.

Scoring continues to favor following the rod side to reduce counter leverage, dives with energy/Drive and room beneath, near-surface jumps against raised rod pressure, and hard side changes against a centered, loaded rod. Dive/jump opportunity weights have been increased modestly. Decisions remain state-driven rather than random cycling. None reads line condition to manufacture a fish win.

## Additional line load

`FightSession.resistance_load()` is the tunable pure calculation. It returns sustained resistance plus a target transient:

```
powered = built_propulsion * forward_effort * taut_contact
sustained = powered * counter_leverage * mass * fish_acceleration
            * propulsion_load_scale * directional_load_scale
turn_target = min(maximum_turn_shock,
                  max(powered - .9, 0) * counter_leverage
                  * min(heading_change_radians_per_second, 3) * turn_shock_scale)
```

Built propulsion already incorporates actual speed buildup, Drive and sprint/run. Merely aiming sideways or steering without propulsion/contact produces no extra load. Ordinary low-output movement does not qualify for the turn shock. The shock decays exponentially over .18 seconds and is refreshed while the powered hard turn continues.

The sustained component joins radial and dive load before the existing spool calculation. The bounded turn pulse joins existing transient load. Drag/payout and finite elastic stretch still determine how much pressure is retained; line wear and probabilistic break hazard are unchanged. The fish still pays current stamina/endurance for counter resistance. The same struggle now also costs the fisher line margin.

Defaults in `FightSession`:

- `directional_load_scale = 1.1`
- `turn_shock_scale = 18`
- `maximum_turn_shock = 36`
- `turn_shock_decay_time = .18 s`

The small force check used built propulsion 2.2, effort/contact/counter 1, base mass 3.2 and turn rate 1.5 rad/s. It produced about 79 sustained resistance and 35 transient load. Through the actual line model, that hard-turn fixture reached about 131 tension; the exceptional combined turn/dive fixture reached about 198 versus a fresh risk threshold around 85. These are capability checks, not predicted average encounter loads or a guarantee of breaks. Normal swimming stayed below meaningful wear. Physical pull acceleration remains capped separately, so higher risk load does not become a grappling-hook launch.

## Fisher perception and decision delay

`FisherPerception.gd` owns a small queue of timestamped observations. A sample is delivered only after its reaction delay; newer truth is not passed directly into `FightDecisions.fisher_choice()`. That policy now takes a Dictionary, not a FightSession, making its information boundary explicit. Fisher coaching and the AI consume the same held observations/actions.

Normal samples include tension, condition, slack, payout, line distance, own drag, visible airborne state, outward motion and a coarse lateral-motion direction. A developing dive is inferred from downward speed below -3 m/s and elapsed observation time; exact Dive Power is never read. The AI never reads fish stamina, endurance, Drive, Overdrive or fish action. Power decisions use perceived slow outward movement, limited slack/load and the fisher's own stamina instead of hidden fish exhaustion.

Defaults in `FisherPerception`:

| Setting | Default |
|---|---|
| sample_interval | .12 s |
| reaction_delay | .30 s |
| reaction_jitter | ±.10 s |
| late_reaction_chance | .12 per sample |
| late_reaction_extra | .20 s |
| vision_reaction_delay | .08 s |

Older queued samples preserve temporal order. Occasional extra delay makes a competent pilot hold a direction/retrieve briefly too long. The risk policy uses a rough 88% nominal-strength tolerance while condition is above .7, otherwise 72%, through delayed observations. It does not call the exact condition-dependent break threshold. It can therefore accept wear for progress and notice danger late.

Vision is requested using `FisherIntent.vision` when the cached direction reverses or a downward maneuver creates uncertainty, with Focus above 55. A request lasts .9 s and has an 8 s cooldown. Existing Focus drain/recovery, exhaustion and rod-freeze rules apply. While Vision is active, observation delay shortens and coarse movement direction is replaced by visible body heading. Vision does not unlock hidden energy values. The AI does not have permanent Vision.

## Measured damage feedback

`FightSession` records condition before the line step, includes subsequent airborne wear, and computes `line_damage_rate = max(0, before-after)/delta`. This is actual condition loss, not inferred from tension. The display threshold is .00001 condition/s to avoid meaningless floating-point noise.

- Fisher: explicit `LINE CONDITION: nn.n%`, `LINE DAMAGE!` and a flashing condition bar. A .35 s visual hold makes brief real damage readable.
- Spectator: condition percentage, live percent-per-second damage, Vision state, age of perceived information, directional load and turn shock. This remains separate from normal player HUD.
- Fish: only `DAMAGING LINE`, and only with development coaching enabled; no condition percentage or exact damage rate.

Use the existing `-AIVsAI` launch and 1/2/3 camera controls. Watch a powered turn, delayed counter and the actual damage rate together. Disable normal fish coaching through `show_fight_coaching` as before.

## Files and protocol

- New `FisherPerception.gd`: sampled, delayed, limited observations.
- `FightDecisions.gd`: no CHARGE, updated escape scoring, fisher policy accepts only observations.
- `FightTestDriver.gd`: legal Drive banking/Overdrive runs, cached fisher controls and normal Vision requests.
- `FightSession.gd`: powered resistance/turn loads, cache updates and measured condition loss.
- `FishPlayer.gd`, `NetworkSession.gd`, `Reef.gd`, `FisherView.gd`, `FightSpectator.gd`: replicated damage feedback and observer diagnostics.
- `FightReadabilityChecks.gd`: force-range, delay, data-boundary and action checks.

Snapshots are now **41 fish floats** and **56 fisherman floats**, adding only qualitative damage and actual damage rate respectively. Both peers must use this revision. Input validation and authority remain unchanged.

## Validation and limits

Import passed. The initial bounded run stopped immediately at a perception assertion: a timer field made the cache appear populated before delivery. That bookkeeping issue was fixed, and the bounded run was restarted. All 17 startup checks then passed, including powered-vs-passive resistance, mathematical wear/risk capability, delayed delivery and absence of hidden fish resources in the cache. The restarted 40-second spectator run also passed, with a natural bait attack/hook-set reaching a fight and exactly two AI actors. It uses no forced outcomes.

One short encounter cannot establish win rates or prove every escape route. Human-visible damage flashing, Vision timing, the full duration of fights and the practical frequency of line breaks still need manual observation. No line-strength nerf or forced fish victory was added. Avoid treating the peak fixture values as normal continuous tension. Godot retains its existing certificate-store warning.
