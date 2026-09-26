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
