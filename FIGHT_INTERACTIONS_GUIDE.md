# Fight interactions: strokes, hook risk, jumps and blended control

This supersedes earlier hook-security/Drive-classification descriptions. Core strength, base drag curve, stamina, endurance, line strength and 150 m spool defaults are unchanged. Full exhaustion and recoil remain. Population remains 88; F9 remains available.

## Editor launch

Use Main Run Args and F5:

- `-- --ai-vs-ai`
- `-- --ai-vs-ai --fish-skill=1.0 --fisher-skill=0.7`
- `-- --host --role=fish --ai=fisher`
- `-- --host --role=fisher --ai=fish`

No new gameplay buttons. Small fast aim wiggles shake the head; larger alternating sweeps with body-following build Drive; faster full-body sweeps spend Drive as Overdrive. Observer 1/2/3 and WASD/QE/RMB controls remain.

## Movement classification: FishSteering

Each completed half-stroke is classified once, at the next reversal across a 3-degree dead zone. Body travel and peak head amplitude reset at EVERY reversal, even unclassified ones. Tiny motion cannot accumulate travel across many reversals to earn a propulsion stroke.

- Head Shake: head amplitude 3–12 degrees, body travel below 4 degrees, reversal interval 0.08–0.32 s, angular speed at least 1.2 rad/s. Adds only short-lived shake pressure.
- Body stroke: head amplitude at least 12 degrees AND body travel at least 4 degrees. Sends the measured alternating stroke to FishFightMotion's existing cadence rules, and clears shake pressure.
- A reversal never gets both classifications. Overdrive consumes only body strokes, including during slack and air.

Tune `stroke_head_degrees`, `stroke_body_degrees`, `shake_maximum_degrees`, `reversal_minimum_degrees` and `shake_speed` in FishSteering. The AI uses legal ±24-degree body sweeps and ±9-degree fast head shakes about its current body heading. Fast propulsion cadence is 0.25–0.266 s plus existing small timing errors; ordinary cadence and occasional pauses still vary. No AI-only credits.

The visual head now pivots farther back (-0.43 z), uses a smaller overlapping ellipsoid (0.36/0.41/0.48 radii), and renders physical offsets at exported `visual_head_fraction = 0.78`. Physical steering limits are unchanged. Eyes/mouth/jaw move inward with the head; body/neck overlap and recoil are preserved. Silhouette is a manual visual check.

## HookRisk: probability, never hit points

`HookRisk.gd` replaces hook security with `looseness`, bounded from 1.0 to 1.4. No threshold automatically throws the hook. The session samples the existing time-independent probability `1 - exp(-hazard * delta)`.

Slack contribution per second:

`0.006 * clamp((slack_metres - 0.5)/2, 0, 2) * looseness * (1 + 8 * active_shake)`.

A tight quiet line has zero passive hook-loss hazard. Brief ordinary slack is low risk; current head shaking multiplies it. Shake pressure decays quickly after motion stops rather than leaving a permanent active boost.

Airborne contribution:

`0.008 * clamp(jump_severity, 0, 2) * looseness * (1 + 16 * active_shake)`.

Lowered rod scales that airborne contribution by 0.4. Severity follows actual takeoff ascent/upward speed and measured height, not a JUMP label. High airborne shakes create strong opportunities without a guarantee. Qualifying violent shakes can add 0.02 times shake strength to looseness at most once/second; landing can add at most 0.06 based on jump severity. All remain capped at 1.4. There is no recovery/health bar to deplete.

Tunables are the exported base hazards, shake multipliers and maximum looseness in HookRisk. Spectator shows `HOOK LOOSENESS x` and actual per-second throw probability, not HOOK %. Normal player HUDs show no exact hook numbers.

## Ascent, flight and return

Jump selection no longer rewards being stationary just below the surface. A new ascent normally needs 7–30 m runway; an already strong ascent can continue near the surface with upward speed >4 m/s and Ascent Power >0.35. Energy, Drive and endurance remain relevant. Deep ascent eligibility is independent of horizontal boat direction; full 3D geometry still decides whether slack develops.

FishFightMotion tracks actual airborne duration, peak height and vertical motion. A breach/fall is followed by exported `jump_recovery_duration = 3 s`; landing resets the AI's 12 s jump cooldown and ends its ascent commitment. Recovery blocks immediate renewed ascent power. AI lowers its aim and stops sprinting briefly after landing. A deliberate later jump still uses ordinary movement.

Fisher responses from delayed observations:

- Ascending / rising airborne: hard retrieve; optional legal Power when slack and resources allow; no gesture.
- Falling airborne / brief post-landing descent: lower rod, reduce retrieve, allow drag to absorb the returning load; no gesture.
- Underwater run/Dive: directional pressure and, when appropriate, a directed jerk.

An ongoing AI gesture preparation is aborted when its observation changes to ascent/fall. Player gestures can still create load in air/ascent, but do not count as successful underwater maneuver interruptions.

## Finite payout and rod pressure

`FightLine.step` still pays out only up to `maximum_payout` per second; its unlimited emergency payout has been removed. `sync_distance` now measures geometry/slack and retains excess as elastic tension; it does not add more line after movement. The existing unilateral movement guard prevents additional impossible separation and never teleports an already overextended fish inward.

`FightSession.fall_load` adds contact-dependent transient load:

`0.7 * downward_speed² * clamp(jump_severity, 0, 2) * line_contact`.

A tiny hop has little height/severity; a high fast fall can create a large reconnect load. Rod elevation scales holding and pressure transfer multiplicatively. Neutral remains 1.0, fully lowered uses exported `low_rod_multiplier = 0.65`, fully raised uses `high_rod_multiplier = 1.3`. Existing temporary take-up/holding buffer remains; the multiplier applies to the combined holding response and elastic/transient pressure. Drag still determines slip threshold, finite payout leaves residual stretch, and condition/exposure still govern probabilistic breaks. Lowering softens an impact but cannot make a severe fall safe automatically.

Pump/reel accounting is unchanged: lift changes temporary span; lowering without retrieve returns slack; lowering plus retrieve collects it. There is no fake permanent rod gain.

## Blended legal AI outputs

`FisherControls.plan` computes independent horizontal rod, vertical rod, retrieve, drag, Power, gesture request, Vision request and optional pump outputs from delayed observations. Labels describe these outputs; they no longer lock controls into one exclusive action. A lateral counter can retrieve simultaneously. A fall can use low rod with limited slack collection. Gestures still go through FightTestDriver's ordinary rod motion and RodGesture detection.

Pumping is limited to controlled fish deeper than 10 m, observed speed below 4 m/s and manageable tension. Shallow/dynamic fish get ordinary retrieve and pressure. Skill still affects execution rather than stats.

Fish RUN now has a course offset (up to ±28 degrees, held for 4 s) plus a slight upward component, so run/cadence/Overdrive can coexist with a lateral path. Reactive directional counters and wall avoidance remain. No added lateral strength or wear bonus. The course chooses toward open arena space; straight away retains superior radial efficiency.

Outside Vision, FisherPerception uses delayed, noisy velocity-derived lateral motion quantized to 0.5. This is a visual estimate, never the fish AI's chosen course/action. Vision resolves heading more precisely with its existing shorter delay. Normal HUD still labels only the maneuver, reserving explicit lateral labels for Vision. Observer remains omniscient for debugging.

## Files, telemetry and compatibility

Changed: FishSteering/FishVisual (classification/art), HookRisk/FightSession (hazard and fall load), FishFightMotion/FishPlayer (jump cycle), FightLine (finite payout/elevation), FisherControls/FightTestDriver/FightDecisions/FisherPerception (intent blending), FisherView/FightSpectator/NetworkSession (presentation), and focused checks. Fish snapshots remain 47 floats; fisherman snapshots are now 63 with falling/airborne flags appended. Run matching revisions on peers.

Observer shows movement classification, Drive/Overdrive, Dive/ascent power, vertical velocity and fall/air state, slack, looseness/hazard, actual rod/retrieve/payout, drag/tension/condition. Existing take-up/recovery/skills/Vision remain. Normal UI stays compact.

Manual follow-up: learnable mouse/stick amplitude separation; shorter head silhouette at rest and full turn; Jump/Dive frequency; lateral rod exchanges; return-load readability; and long-fight balance. No long balance simulations or broad performance work in this pass.

Validation recorded: import passed, all 65 focused startup checks passed, and one 40-second natural AI encounter reached a fight and exited with code 0. Vision use/recovery and a rod gesture were observed; no breach or successful interruption occurred in that short window. F9-equivalent CSV/JSON saving passed. Existing nonfatal certificate-store warning remains. No long simulations or graphical balance/performance runs were performed.
