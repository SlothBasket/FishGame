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
