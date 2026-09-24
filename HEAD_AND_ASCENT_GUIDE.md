> Latest interaction pass: [FIGHT_INTERACTIONS_GUIDE.md](FIGHT_INTERACTIONS_GUIDE.md) supersedes prior hook-security, overlapping stroke classification, exclusive AI outputs and unlimited payout reconciliation. Current snapshots: **47 fish / 63 fisherman**.

# Head-led swimming, slack shaking and ascent

This pass changes fish execution/readability, not the core line force/drag/jerk balance. See ROD_GESTURE_GUIDE.md for retained pump and gesture rules. Normal ecosystem remains 88 actors; F9 diagnostics remain intact.

## Editor launch arguments

Use F5 with Main Run Args:

- `-- --ai-vs-ai`
- `-- --ai-vs-ai --fish-skill=1.0 --fisher-skill=0.7`
- `-- --host --role=fish --ai=fisher`
- `-- --host --role=fisher --ai=fish`

No new buttons: aim/mouse or right stick leads the head, A/D adds head steering; forward movement gives the body turning authority. Sprint and upward aim/rise build ascent. Alternate left/right head motion during slack to threaten the hook. Spectator cameras remain 1/2/3, with WASD/QE/RMB in overview.

## Shared movement and measured strokes

`FishSteering.gd` is a per-fish Resource called by `FishPlayer` before the motor and fight-effort update. It converts desired aim/manual steering into bounded local head pitch/yaw, then advances body heading toward the head. `FishInput` still carries intent only. There is no AI-only motor or stroke-credit input in the network protocol.

Tunables in FishSteering:

- `maximum_yaw = 32°`, `maximum_pitch = 25°` bound relative head aim.
- `head_response = 14/s`, `body_response = 3.5/s` give the head a lead and the body a delayed follow.
- `idle_authority = 0.2`; body turn authority rises with measured forward speed, reaching full authority at 6 m/s. Zero speed still permits slow pivoting.
- `stroke_head_degrees = 8°`, `stroke_body_degrees = 1.2°`: a new alternating side must pass the head threshold and accumulate visible body yaw travel before emitting a measured stroke.
- `shake_speed = 1.2 rad/s`: alternating head motion crossing the same head threshold in 0.10–0.65 seconds builds shake pressure. It decays at 1.3/s.

`FishFightMotion.step` receives the measured stroke from FishSteering, not raw steering/mouse flags. Its existing cadence, partial credit and Overdrive rules then apply. Micro-input or toggling input flags without moving the fish earns nothing. Head shakes can qualify as Drive strokes only if they also produce the required body motion.

`FishVisual` has separate head, body and tail nodes. Head follows the physical local offset; body flex and tail follow lag behind it. Drive/Overdrive still increase tail beat/cadence and keep their wakes, but artificial free-running whole-body Drive wiggle was removed. Movement is a real small arc/S-pattern.

The AI produces legal alternating aim offsets of ±24°, instead of a steering flag cancelled by fixed aim. Timing has small error even at high skill, with occasional 1.2–1.4 second missed-stroke intervals; Drive decays/rebuilds through normal rules. It sometimes uses rapid ±30° aim shakes during observed slack, through the exact same head/motor path. Strong runs under little lateral pressure may initiate an away-left/right course to make tracking harder, while retaining existing wall scoring and physical-pressure responses. No new strategy tree or stat buffs.

## Slack and hook escape

`FightSession.shake_effect` multiplies actual shake pressure by slack above 0.5 m, reaching full contribution at 2.5 m. Tight line gives no added shake effect. Exports `shake_security_drain = 0.22/s` and `shake_hook_hazard = 0.18/s` add security degradation and probability hazard only while qualifying. Existing random hook-loss sampling remains authoritative. No deterministic escape count and no artificial slack award.

Breach adds ascent power and qualifying shake pressure to the existing hook hazard. Lowered rod still reduces the opportunity. The old direct airborne condition-wear deduction is removed: Jump attacks hook security; physical tension still governs line wear/risk normally.

Pump math is unchanged. Lowering a physically gained pump without retrieve returns take-up as slack; the fish can consume it outward before spool payout resumes. Reeling reduces real line_out to collect slack. Focused tests verify this sequence and preserve the existing elastic allowance. Toward-boat/upward movement naturally reduces full 3D distance more than away travel; ascent does not grant slack directly.

## Ascent and fatigue

`FishFightMotion.ascent_power` builds with forward effort, sprint, positive upward heading (>0.35) or rise input (>0.5), actual upward speed (>1 m/s), and available stamina. It depends on upward speed up to 5 m/s, current Drive and endurance capacity. Boat direction is absent from eligibility. Exports: `ascent_build_time = 1.2 s`, `ascent_acceleration = 8`, `ascent_stamina_drain = 6/s`. Normal motor, line forces, surface crossing and existing air-speed caps still govern the actual breach. Turning upward ends an existing Dive so its downward acceleration does not fight the ascent forever.

AI can choose ascent from up to 30 m below surface and commits for a depth-scaled 2.2–7 seconds; actual success still requires motion/stamina. Jump cooldown remains 12 seconds. Ascent is an opportunity, not a guaranteed breach.

`FishPlayer.endurance_floor` now defaults to zero. `power_capacity = (endurance / stamina_capacity)^0.8` scales sprint bonus, Overdrive availability, Dive power, ascent and fight propulsion continuously. Base swimming fades to `exhausted_swim_fraction = 0.55` at zero; steering/head motion remain. Stamina is still capped by endurance. A depleted fish therefore keeps basic movement while losing strong fight output. Existing line force constants are unchanged.

## Impacts and information parity

Hook set retains its real impulse and adds `receive_impact`: head snap toward force, visual body recoil and 0.18–0.36 s reduced steering/propulsion response based on severity. Successful jerk interruptions call the same response in addition to existing counter recovery. Head movement caused by recoil does not earn Drive or shake credit. Actual body heading remains continuous; impact does not instantly aim at an optimal escape route. Existing successful-counter banners remain.

Without Vision, FisherPerception returns maneuver cues (upward/downward/airborne/run motion), line observations and delayed resource readings, but no lateral side. Queued directional detail is masked when Vision is off. With Vision the delayed observation resolves direction. The normal fisherman HUD shows RUN/DIVE/JUMP without lateral labels; Vision adds LEFT/RIGHT/AWAY. Fish/rod/line geometry remains physically visible. AI uses the same perception cache and Focus ability.

## Presentation, files and replication

Changed movement: FishSteering, FishPlayer, FishFightMotion, FishVisual, FightSession. Harness/perception: FightTestDriver, FightDecisions, FisherPerception. HUD: Reef, FisherView, FightSpectator. NetworkSession appends head pitch/yaw, recoil time, ascent and shake to **47-float fish snapshots**, and ascent to **61-float fisherman snapshots**. Input packets are unchanged; clients only render replicated head/ascent state. All peers need the same revision.

Spectator displays Dive/ascent power, slack, hook security, head angles, last recognized stroke side, shake pressure and the existing endurance/take-up/recovery/Vision values. The human fish HUD only adds relevant ASCENT and SLACK—SHAKE HEAD prompts. FishReadabilityChecks adds focused movement/slack/exhaustion contracts; isolated legacy cadence checks now explicitly supply measured stroke events.

Manual checks: head/neck appearance, comfortable mouse/controller stroke amplitude, tail/body rhythm, actual deep ascent and breach opportunities, shaking effectiveness under slack, brief impact readability and long-fight exhaustion. No long balance or graphical performance runs are part of this pass.

Validation: import and all 50 focused startup contracts passed. The single 40-second natural observer run reached a fight, recorded a natural breach, Vision use/recovery and a registered jerk, and printed SPECTATOR PASS and HITCH SAVE PASS. No successful interruption occurred in that short encounter. After reporting completion, the headless process did not exit promptly and was stopped with Ctrl+C; clean shutdown remains unverified. The existing nonfatal Windows certificate-store warning also appeared. No long simulations or repeated gameplay runs were performed.
