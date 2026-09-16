# Performance investigation - September 15

## User reports

The 23:27:12 report contains sustained slowdown: its final ten seconds have median 178.8 ms and mean 180.5 ms (about 5.5 FPS), with 226 bait and roughly 4,054 nodes. The whole-window median of 16.69 ms mixed in startup and concealed this. Later physics samples approached 30 ms. These are measurements of this machine, not multiplayer capacity estimates.

## Changes under test

- Default population reduced to 142; dense benchmark retains 226.
- Combine rigid body pieces into cached colored meshes; articulated joints remain independent.
- Shared spatial lookup replaces every actor scanning every peer for escape reactions.
- AI decisions run at 15 Hz; player input, motion, collisions and escape trajectories remain at 60 Hz.
- Resolve supported ground settling before movement sweeps.
- Reports include recent-window summaries, physics updates per rendered frame and optional named timing sections.

## Controlled comparisons

Fixed seed 23, identical 60-second camera tour, measured after second 30; no concurrent engine tests.

| Configuration | Bait | Median frame | p95 | Maximum | Median draw calls |
|---|---:|---:|---:|---:|---:|
| Previous movement/rendering plus optional instrumentation | 226 | 16.62 ms | 22.35 ms | 47.05 ms | 897 |
| Mesh cache + spatial lookup | 226 | 16.66 ms | 17.29 ms | 48.83 ms | 468 |

These first runs did not reproduce the user's worst slowdown. A subsequent dense run with AI decision caching did reproduce it: median 154.15 ms, p95 175.45 ms, eight physics steps per rendered frame. Driver cost fell from about 21.9 to 7.2 microseconds per actor tick, but movement sweep cost rose from 8.7 to 43.9 microseconds. This indicates collision/catch-up pressure remains important and disproves a claim that draw-call reduction alone fixes the problem. Changing AI timing can change where actors accumulate; compare more than one seed and trajectory before raising population again.

## Next boundaries

Keep the normal population modest. Profile movement costs by species and contact location before more growth. If substantially larger populations become necessary, consider simpler static collision geometry, a dedicated lightweight prey collision representation, and batched distant rendering. Those are future changes, not implemented fixes. Multiplayer replication/authority and network load have not been tested; this pass does not certify multiplayer readiness.

F9 saves the latest 1800 render-frame timings plus snapshot details. Press it after sustained slowdown as well as hitches. Send both timestamp-matched files and what you were doing. Optional `--profile-bait` adds driver, per-species movement and pose costs; leave it off for ordinary play.

## Final validation

101 checks pass. Final 142-bait default: median 16.68 ms, p95 17.48 ms, worst 19.01 ms, peak physics 9.11 ms, median 354 draw calls and no more than one physics tick per rendered frame in the measured window. Visual captures verified the combined meshes and retained animated parts.

The final 226-bait stress test still fails the performance target (median 154.37 ms, p95 181.36 ms, worst 209.32 ms). Per-species timing attributes 22.8 seconds of the 60-second run to minnow movement sweeps, versus 0.3-0.6 seconds per other species. Ground pre-settling did not solve this dense case. Do not re-enable that population for normal play. The remaining investigation should isolate expensive individual minnow contacts and compare decision frequencies/positions; aggregate section timing does not identify a specific engine defect or collider yet.
