# Local development milestones

- Core fight milestone (subject: `Make rod pressure, spool drag, slack and landing coherent`) — explicit spool accounting, continuous retrieve, bounded rod, fish-centered camera, distinct rod/line and standard HUD, drag/Power wear, slack hook security, outward-biased AI and full-stamina landing. See FIGHT_GUIDE.md for scoped validation and deferred bait work. Prior local editor settings preserved in `d6fa7e7`; argument-free F5 restored to sandbox.

- Multiplayer foundation milestone (subject: `Add authoritative ENet fish sessions and interpolated ecosystem replicas`) — Fish + Fish ownership, validated intent-only RPC, reliable lifecycle/catalog events, 20 Hz fish and 10 Hz bait snapshots, local cameras, host/join launch options and F10 disconnect. Import passed; one approximately four-second two-process localhost check confirmed both fish movement, matching 26-bait staged population, and host survival after client departure. No performance tours or fight implementation. Fish + Fisher remains deferred.

Each milestone is a Git commit, not a duplicate copy of the project. Remote pushing is optional for switching locally, but provides a separate backup. A future devlog launcher can list these commits and build a selected revision in a temporary checkout. Preserve this repository and its .git directory.

- `5f30907` - Schools, boat setup/casting, denser ecosystem, gull hunting, size variation and movement documentation. Last version before the longer-round pacing pass.
- Milestone identified by subject: `Tune round growth, heading-preserving escapes and staged population` - 264 m arena, 226 gradually introduced bait, three-jump mullet limit, slower growth, size gates and timestamped F9 reports.

Changes are committed after validation at substantial milestones. Uncommitted edits remain editable working files, not additional version entries. Do not rewrite milestone history when adding new versions.

Validation for the pacing milestone: 97 checks passed. Standalone 75-second graphical tour on GTX 1660 Ti: median 16.65 ms, p95 26.55 ms, maximum 82.83 ms, peak physics 24.46 ms. The 226-bait population is the current performance baseline; pause population increases pending profiling. No multi-second hitch reproduced.

- Optimization milestone (subject: `Reduce prey crowding and profile sustained physics slowdown`) - 142 default bait, cached rigid meshes, shared neighbor lookup, 15 Hz AI decisions with 60 Hz motion, stronger recent-window diagnostics. 101 checks pass. Default benchmark is smooth; 226-bait stress case remains an explicitly documented investigation target in PERFORMANCE_NOTES.md.

- Pre-multiplayer polish milestone (subject: `Polish shared bait controls, migrating ecosystem and local presentation`) — shared reel tiers/gamepad actions, momentum-preserving charge, minnow preparation, lateral crab escapes, soft squid tether, moving habitats, bounded mortality/replenishment, terrain camera clearance and readable gull hunting. No multiplayer/fights. Validation scoped to import plus short deterministic polish checks.

- **Make fights tire fish through rod leverage and compounding line risk** — linear drag, distinct reel/fish load, endurance and fish HUD, heading-aware AI, condition/exposure break hazard, clearer silent fisherman HUD. Local editor setting preserved in `95a3b46`.

- **Add rod pumping, finite spool and anchored fight HUD** — temporary take-up/buffer layered on existing drag, 100 m spool-out, ordinary load smoothing, subtle direction feedback, centered hook timing and separate fish/network status.

- **Keep fight span consistent and cap pull forces** — 250 m spool, span-limited recovery and movement, post-move landing, controlled horizontal acceleration, breach-intent filtering, non-sprint recovery, fight feedback and minnow test markers/attack timing.

- **Add fish Swim Drive and shared directional dive counterplay** — unified mouse/A-D rhythm, bounded overdrive, run ramp, shared contest/coaching/AI, body bank and rod feedback, optional spatial aids, committed dives and finite payout overload. Local-only milestone.

- **Improve Drive readability and add natural AI spectator mode** — forgiving stored cadence, sustained Overdrive, shared state-based action coaching, dive bubbles, reliable outcome banners and a true two-AI observer with three camera views.

- **Give powered fish resistance line risk and delayed fisher perception** — removes charge-boat AI, banks/spends legal Drive, adds powered resistance/turn load, measured damage feedback and delayed visible-state fisher decisions with normal Focus use.

- Milestone subject: `Make fight pressure and AI execution readable to players and spectators` — shared physical cues, Drive/Overdrive/Dive animation, visible boat/rod/line, strategic Vision, 150 m spool, skill settings, wall-aware movement jumps and separate directional wear. See FIGHT_READABILITY_GUIDE.md for tuning and scoped validation.

- Milestone subject: `Add physical directional jerks and readable pump recovery` — shared server rod gestures, timed directional counters, simple legal AI counter/pump rhythm and spool urgency, 88-actor baseline, visible F9 save confirmation and editor launch documentation.

- Milestone subject: `Make fish steering, Drive and hook escape physically readable` — head-led body arcs, measured Drive strokes, active slack shakes, directional-information Vision gate, ascent power, zero-endurance fatigue and impact recoil. See HEAD_AND_ASCENT_GUIDE.md.

- Milestone subject: `Separate fish stroke intent and blend jump counterplay` — exclusive head/body stroke classification, bounded hook looseness/hazard, committed jump return, finite payout/elevation response, blended fisher controls and shorter overlapping head geometry.

- Milestone subject: `Add seeded real-fight batch telemetry and modest risk thresholds` — fixed-step accelerated batches, fresh legal AI encounters, exact outcome CSV/event capture, diagnostics for lateral/deep/jump behavior, and risk thresholds 0.85/0.60.

- Milestone subject: `Synchronize pre-hook line span before hook impact` — follows free-moving fish through CANDIDATE/METER and initializes IMPACT geometry including rod take-up, without pre-hook fight forces or risk. Preserves yank and post-hook mechanics. Import plus one 30-second seeded encounter passed; impact extension 0.000 m. Local editor batch arguments separately preserved in `4ee2fb7`.

- Milestone subject: `Make drag respond to total load and add readable shared side bursts` — finite payout during Power/transients, hazard 0.008, perceived AI drag management, shared committed body turns, upward hook snap and jerk sweeps, focused telemetry. Import, targeted contracts and one three-fight smoke; no broad balance iteration. Editor launch settings preserved in `3a1912a`.

- Milestone subject: `Give rod lifts and counters lasting fight progression` — shared normal cast range, bounded rod contraction, maneuver fatigue and nonlinear counter endurance loss, Drive lockout feedback, perceptual maneuver gating and restrained Vision, progression telemetry. Import, focused contracts and one three-fight/90 s smoke; no win-rate tuning. Editor settings preserved in `066f2e3`.

- Milestone subject: `Separate renewable Drive and add true lateral burst counterplay` — Drive-first bursts, deliberate stamina escalation, ordered Overdrive/Power punishment, radial effort costs, measured boat-relative sides, procedural cues and free-swim Drive. Scoped contracts and one three-fight smoke, no win-rate tuning. User batch settings checkpointed in `2f45eaf`.

- Milestone subject: `Fix CPU particle intensity control` — replace unsupported particle amount ratio with guarded 32/64 counts while retaining emitting control and existing CPU effect settings. Import and one 1,200-frame normal graphical AI spectator launch passed without particle/script errors; no combat changes.

- Milestone subject: `Improve Fisher presentation and between-fight AI behavior` — shared reel/striped mouth-attached visual line, flank routing, close camera, subtle moving water and optional drag audio; seeded AI recast pauses, live/lure food interest and minnow retrieve seam. Import, focused checks, controlled Fisher view and one short natural spectator session. No fight balance changes.

- Milestone identified by subject: `Add recorded reel drag with natural start loop and stop` — supplied ReelDrag.mp3 preserved, derived opening/middle loop and ending, payout-driven smoothed pitch, short crossfades, and local camera muting. Import passed; one bounded 12-second audio check passed eight start/loop/pitch/stop/restart/muting assertions. Headless shutdown reported object/resource cleanup warnings; no playback script errors. Listening/volume tuning left to manual playtesting. No combat changes.

- Milestone identified by subject: `Add test bait priority and deliberate predictive AI feeding` � host F8 lure-priority toggle, close-turn coasting, velocity-led 65�85% feeding charges; unchanged fight physics. Import and 19 focused checks passed. Preserves the user-selected AI-vs-AI editor launch arguments.

- Milestone identified by subject: `Move AI bait priority off editor stop shortcut` � changed the host test-bait toggle from F8 (Godot stops the running project) to T; updated on-screen hint and guides. No AI or gameplay changes.

- Milestone identified by subject: `Make Drive continuous and give Fisher AI close-out priorities` � continuous Drive-first power, stamina fallback, slower recovery, varied AI commitments, delayed observable landing pressure, moving feeding charges, and solid mouth-attached line. See CONTINUOUS_DRIVE_POLISH.md for values and bounded validation.

- Milestone identified by subject: `Tie spool payout to real separation and polish Fisher control` � force-based finite drag, separate retrieve/slip/payout, efficiency-aware Fisher, boat-framed hookset and audio, shared directional counters/star halo, retained jump launch effort, curved mouth lead. Fisher snapshots 69 floats. Bounded validation and limits: REEL_AND_FISHER_CORRECTION.md.

- Milestone identified by subject: `Steady AI rod pressure and restore close-range pump progress` � prevent unintended pressure/preparation jerks, bounded intentional flicks, safe close pump completion, maximum drag 120 and stronger leverage-based rod assistance. Import and seven focused control/motor checks passed; no batch.

- Milestone identified by subject: `Restore reserved Drive resistance and prioritize jump slack recovery` - revert excessive drag increase, soften pump assistance, give unspent Drive a tunable passive force bonus, enforce spool resistance during outward contact, and prioritize low-rod fast retrieve through jumps. Import and 11 focused checks; no long batch.


Milestone subject: `Make powered commitments readable and steady Fisher close-out decisions` - persistent useful retrieve, varied continuous escape budgets, sustained lateral commitment, human-scale visible counter timing/messages, and raised outboard Fisher view. Eighteen focused checks and one three-encounter sample; no large batch.


Milestone subject: `Calibrate endurance force and prioritize AI escape distance` - fresh 130 stamina/endurance with fixed 100 force reference, nonlinear fatigue and full-Drive reward, preserved payout accounting with higher line acceleration cap, committed side force, distance-defending AI, and right-side notices. Import, 19 focused checks, three short encounters and one graphical layout fixture; no large batch.


Milestone subject: `Fix horizontal escape strategy and close-range Fisher dead zone` - XZ escape scoring/memory, legal terrain-aware bottom recovery, and reachable close-pressure drag targets. Import and 14 focused checks passed; fight physics/resource/counter systems unchanged.


Milestone subject: `Restore fight variety and expose authoritative line load` - remove distance-record planner, restore earlier Fish fight input behavior with depth safety, align powered motor/load factors, and add authoritative debug force comparisons. Import and one seven-second graphical smoke only; no batches.


Milestone subject: `Strengthen Drive reserve and fix feeding pursuit safety` - high-Drive holding, efficient committed sides, momentum-sensitive late counters, stronger hookset presentation, legal wander strokes and freed-bait-safe close feeding approaches. Import plus one seven-second smoke; no batch.


- **Restore measured AI strokes and moving feeding attacks** (2026-10-01): shared legal rhythmic steering, live charged-reach release, modest Fish load calibration, maneuver-progress counter grading. Import only; no batches. Preserves local AI-vs-AI editor launch preference.

- **Restore natural AI swimming and recognize smaller body strokes** (2026-10-01): revert body-relative stroke/navigation regression; reduce head-offset recognition gate to 8 degrees while retaining 4-degree actual body travel. Keeps moving feeding, force and counter changes.

- **Keep active counters effective and defend against spool-out** (2026-10-01): remove late grades/control penalty, escalate emergency drag to 60-90%, strengthen hook body recoil and replicate existing stun stars. Import/parse validation only.

- **Shrink test bait labels and hide engaged lures** (2026-10-01): compact marker with continuous fight/lifecycle visibility guard; import checked.

- **Add clean seeded spectator capture and camera presets** (2026-10-01): --capture with --ai-vs-ai, six local shots, Movie Maker usage in CAPTURE.md, hidden debug/HUD layers. Import/parse only; no movies or fights rendered.

- **Add live cinematic capture director** (2026-10-01): timed event-interest camera selection for exploration/feeding and fights; fish-front preset, conservative variations and collision/framing fallback. Import/parse only; no fights or recordings.

- **Smooth cinematic direction and log capture events** (2026-10-04): longer family-aware shots, action holds, closer breach framing and sparse simulation-time CSV logs. Import/parse only; preserves the user's capture/director editor arguments.

- **Add development mode launcher and Movie Maker frontend** (2026-10-04): no-argument startup menu, six modes, optional persisted seed/skills, safe duplicate-free recordings in user://captures/. Existing CLI workflows preserved; import and headless menu/argument checks only. Editor recording arguments first checkpointed as 531daff.

- **Bound seeded recordings to one test-bait fight** (2026-10-04): automatic lure priority, 3-second result tail, configurable total duration and engine frame cap; blank recording seeds saved for reuse. Import checked; no movie or fight batch.

- **Add recording bait delay and natural-footage toggle**: persisted launcher controls; natural footage uses the duration cap rather than stopping on a fight. Import checked.

- **Fix boat camera feedback and stalled Fish commitments** (2026-10-04): consistent surface framing, slower return to boat, preserve surface dive intent and release invalid/unpowered AI commitments. Import/parse only; manual feel/reproduction pending.

- **Fix capture gates and add comic landing release** (2026-10-04): actual lure eligibility gate, reliable bounded capture completion, right-side events in recordings, pre-oriented boat transitions/committed event viewpoints, and bounded server-owned landing toss with splash-position reuse. Import and direct path checks; no movie/batch.

- **Add P release test across play modes** — Shared landing throw available in solo Fish/bait testing, hosted roles, joined clients and AI spectator/capture modes; no Director dependency.

- **Restore smooth boat retreat and arc release throws** — Restore continuous camera travel with bounded rotation; forward/inward arcing throws, stronger wind-up/tumbling, sky and distant water/seabed scenery.

- **Add social hunting and steadier multi-actor cinematography** - Inches and retained growth, once-only landing score, finite hotspots, hunting Drive, prey preferences, inshore patches, five-actor observer and varied cameras.

- **Add parallel seed recording and multi-actor directing** - Bounded Movie Maker queue, distinct ports/files/logs, automatic subject selection, bounded wide/surface shots, and multiplayer host/join/local-pair launcher.

- **Package join-only multiplayer playtest client** - Separate friend-facing Join screen, guarded launch paths, return-on-disconnect, reproducible Windows ZIP builder and setup guide.

- **29c3c3e Make Fisher spend line condition and strengthen stored hunting Drive** - Observable pressure/closeout, acute overload relief, 86 to 99 prey, 0.0042 growth and passive free-swim Drive. Import, focused checks and one bounded fight; fight physics unchanged.
