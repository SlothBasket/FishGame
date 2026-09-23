# Directional gestures, pump/reel and lower-load baseline

## Launch from the Godot editor

Use these exact strings in the editor's Main Run Args / Run Arguments field, then run the project (F6 runs a scene; use F5 for the project):

- Watch AI vs AI: `-- --ai-vs-ai`
- Fixed skills: `-- --ai-vs-ai --fish-skill=1.0 --fisher-skill=0.7`
- Play fish against AI fisherman: `-- --host --role=fish --ai=fisher`
- Play fisherman against AI fish: `-- --host --role=fisher --ai=fish`
- Host for another player: `-- --host --role=fish`
- Join as fisherman: `-- --join=127.0.0.1 --role=fisher` (replace the address for a different computer).
- Normal sandbox: clear the arguments.

The standalone `--` separates engine arguments from game arguments. Use hyphens in `--ai-vs-ai` and equals signs in role/skill options. Roles require a host or join mode. The editor settings are not changed by this pass.

## Human gestures and feedback

During OPENING/FIGHT, use mouse/right-stick rod motion: **flick up, left or right**. Q/RB remains hook-set timing before the fight and does not jerk during the fight. Small/slow movement is ordinary pressure. Stick response now has a squared magnitude curve: partial travel permits slow pumping; a full flick reaches jerk velocity.

`RodGesture.gd` reads the actual server-smoothed rod pose. Within 0.24 s, a gesture must travel at least 0.55 normalized rod units, average at least 2.4 units/s, and end at least 0.6 toward its direction. Downward motion alone does not jerk. `FightSession.gesture` exposes these thresholds. Session cooldown remains 1.2 s, stamina cost 14; Vision freezes rod control and disables gestures. Disabled samples reset history so releasing Vision/cooldown cannot release a stale gesture. Mouse and AI use the same server detector as the right stick.

Near the rod, `JERK LEFT/RIGHT/UP!` lasts 0.8 s after a usable gesture. It means registration, not guaranteed success. Only actual successful counters generate the reliable `RUN STOPPED!`, `OVERDRIVE BROKEN!` or `DIVE STOPPED!` announcement to the fish, fisherman and observer. Natural exhaustion/release produces none.

## Counter contest and tuning

`FightSession.jerk_contest` uses actual heading in the boat-relative frame, line contact, propulsion, Drive, Overdrive, run build and age. A lateral component beyond 0.25 requires the opposite lateral jerk. A nearly straight outward run requires UP; Dive also requires UP. Slow held UP no longer automatically cancels Dive.

- `jerk_counter_force = 65`: counter force budget, scaled by actual rod displacement.
- `early_run_window = 0.9 s`: later runs gradually resist more; a fresh Overdrive onset opens a fresh window, but repeated fast strokes sustaining it do not reset the timer.
- `jerk_spike = 35`, `late_jerk_spike = 65`: transient load increases to 100 as a run/Dive commits. Wrong directions also produce this load while giving zero control.
- Resistance = 25 + 15 × propulsion + 12 × Drive + 30 × Overdrive + 20 × Dive Power. Late resistance rises up to 65%.
- Control fraction = counter force / resistance, clamped and multiplied by contact. At least 0.65 stops the maneuver; weaker matches partially reduce it. Slack defeats both load and control.
- `counter_impulse = 4 m/s`: bounded counter impulse, scaled by control; applied through velocity without teleporting the fish.
- `FishFightMotion.counter_recovery_duration = 1.1 s`: successful run counters remove current Overdrive/run build, briefly inhibit rebuilding and reduce propulsion. They do not erase stored Drive or grant the AI different stats.

Late strong maneuvers can survive, while weaker late maneuvers can still be stopped. Additional tension feeds existing wear, exposure and probabilistic breaks. There is no guaranteed win or scripted line break.

## Pump audit and readouts

Existing `FightLine` mechanics are preserved. Rod pull adds up to 2 m temporary take-up and 15 holding force, making working span shorter without directly reducing `line_out`. If physical line force makes the fish yield, lowering while retrieving can recover that distance permanently. Lower without reeling simply returns temporary span. Reeling is bounded by actual distance plus existing 2.5 m elastic allowance; overpowering payout cancels recovery.

Focused checks exercise slow gestures, pump-only spool invariance, lower-only invariance, a short yielding-body force integration plus reel recovery greater than 1 m, and no free recovery under overpowering payout. These verify accounting, not multiplayer win balance.

Fisher/spectator show remaining spool, current TAKE-UP, and cumulative REEL RECOVERY. Recovery counts actual negative net spool change each tick (including normal retrieve), not hypothetical rod movement or permanent net progress over the whole fight; compare line-out to see net gains after subsequent payout.

## Simple legal AI harness

`FisherPerception` adds observed spool length/capacity to its delayed cache. No hidden fish resources/actions are exposed. `FightDecisions` increases risk tolerance as spool use moves from 50% to 90%; extreme tension still allows LET RUN. A threatened straight run selects UP and lateral motion selects the opposing side.

`FightTestDriver` prepares the rod slightly opposite a counter, then drives normal bounded rod input toward the chosen side. It never presses the active-fight jerk button. Healthy line plus dangerous remaining spool permits legal drag up to 70%, returning to ordinary settings afterwards. Skill affects preparation, cooldown spacing, drag reaction and pump retrieve efficiency, never physical force.

When delayed observations show no major descending/outward motion, dangerous payout or high tension, the AI performs a simple 3.8 s rhythm: 1.6 s slow lift, 0.4 s hold, then lower/reel. Visible power-run cues abort pumping. Perception delay can still cause understandable mistakes. Vision does not interrupt an in-progress gesture. Existing randomized skills and launch overrides remain.

## Population and diagnostics

Normal live target is **88**: 32 school minnows, 12 school mullet, 4 midwater squid, 8 upper-water bait, 2 gulls plus 2 surface minnows, 4 additional mullet, and 24 animals across eight habitat zones. Staged spawning, replenishment, corpse limits and species distribution remain; actual instantaneous count can differ through turnover/player lure.

F9 retains rolling frame history and bait snapshots. Successful CSV and JSON writes produce a high-layer `HITCH REPORT SAVED` notice even in spectator mode, and print both full absolute paths in Godot Output. Editor launches use the editor's ordinary `user://hitch-reports`; the local automated runner's APPDATA override is separate. File failures do not claim success. No broad performance rewrite was made.

## Files and network compatibility

Gesture/counter mechanics: RodGesture, FightSession, FishFightMotion. Harness: FightDecisions, FightTestDriver, FisherPerception. Presentation: FisherView, FightSpectator, FightOutcomeBanner. NetworkSession appends take-up, cumulative recovery, registered jerk direction and popup time: **60-float fisherman snapshots**, unchanged **42-float fish snapshots**. Reliable authority-only counter events route to participants/observer. Peers must run matching revisions. BaitSchool changes only counts; PerformanceProbe changes save feedback/error handling. FightReadabilityChecks covers the small contracts; FeedingChecks expects the new population.

Manual checks remain mouse/right-stick flick thresholds, visual interruption clarity, meaningful human pump gains, long-fight win balance, and whether 88 actors improves frame chugs on your PC. No repeated balance simulations or rendering benchmarks are required for this pass.

Validation recorded: Godot import passed, all 35 focused startup checks passed, and one 40-second natural AI-vs-AI smoke run passed. It observed a registered rod-motion jerk and successful interruption, Vision use/recovery, and successful CSV/JSON hitch-report saving. Existing nonfatal Windows certificate-store warning remains. No win-rate or graphical performance claims were inferred from this bounded run.
