> Latest rod-gesture/pump pass: [ROD_GESTURE_GUIDE.md](ROD_GESTURE_GUIDE.md) gives **Godot editor launch arguments**, directional gesture controls, interruption rules, pump audit, 88-actor baseline and current 60-float fisherman snapshots. Supersedes older button-jerk and population descriptions below.

> Current physical-cue/AI pass: [FIGHT_READABILITY_GUIDE.md](FIGHT_READABILITY_GUIDE.md) supersedes historical defaults below: **150 m spool, 42-float fish snapshots**, physical-pressure cues, skill overrides, visible spectator equipment and powered directional wear.

> Latest escape/AI rules: [ESCAPE_BALANCE_GUIDE.md](ESCAPE_BALANCE_GUIDE.md) documents powered resistance load, measured line damage and delayed fisherman perception. CHARGE BOAT is removed; older policy descriptions below are historical. Current snapshots: 41 fish / 56 fisherman floats.

# Readability, cadence and natural AI spectator mode

This pass preserves core fight forces, directional leverage, pump/reel, drag/payout, risk, endurance, run/dive, landing and 250 m spool. It changes cadence storage, development decisions/presentation and testing tools. No GitHub operations were used.

## Spectator launch and controls

```powershell
.\Launch.ps1 -AIVsAI
```

Equivalent Godot user argument: `--ai-vs-ai`. It starts an authoritative local host containing exactly peer **-1 AI fish** and **-2 AI fisherman**. There is no peer-1 gameplay actor. The existing level fish is reused as the AI fish, loses local input ownership and camera control, and remains the only fish participant. Observer input only moves the spectator camera. Incoming player joins are rejected to keep this a two-AI development encounter. The older `--ai=both` remains unchanged and is a different mode.

- **1:** fisherman-oriented camera, looking toward bait/fish.
- **2:** fish-oriented follow camera.
- **3:** independent overview/free camera.
- In overview: **WASD** move, **Q/E** down/up, **hold RMB + mouse** look.
- **F10:** end/freeze the session.

The separate observer HUD shows both chosen actions, Drive/Overdrive, stamina/endurance, phase, line out, tension, drag and last outcome. Normal player HUDs are hidden. The observer cannot steer, cast, hook, feed or land either participant.

The AI fisherman casts its normal minnow. The fish must find and attack it. Normal bite interception creates the opportunity; AI performs the same hook meter and fight inputs. No teleport, forced contact, forced hook result or forced landing is called by this mode. Outcome cleanup permits subsequent normal casts.

## Shared action coaching

`FightDecisions.gd` owns the small state-based policy. `FightSession` evaluates it every .45 seconds and holds the result between decisions. AI drivers read these exact stored choices; player HUDs display the same authoritative choice. There is no independent tutorial prediction.

Fish actions: RUN, LEFT, RIGHT, DIVE, JUMP, REST, CHARGE BOAT.

The policy first continues an active dive or rests at low stamina. Rest persists until 70% current recovery ceiling. Otherwise it scores an ordinary run, following the rod side, a dive opportunity (room below, stamina, Drive, weak upward rod), a pressured near-surface jump, and charging inward when distant/taut/high-pressure to create slack. A centered rod under strong pressure can prompt changing the current side. There is no random mode rotation. Thresholds and score weights are grouped in `FightDecisions.fish_choice()` for alteration.

Fisher actions: PULL LEFT, PULL RIGHT, PULL UP, LOWER ROD, REEL, LET RUN.

The policy lowers for airborne fish, counters an early dive, lets a late dive/high-risk load run, retrieves slack, then chooses opposite lateral leverage or normal retrieval. It calls the existing `FightContest` coefficient logic; no force rules changed. The driver uses the stored action for its main rod/reel decision and retains normal stamina/drag constraints. Hook-set handling remains separate during candidate/meter phases.

Disable coaching through the existing `FishPlayer.show_fight_coaching` and `FisherView.show_fight_coaching` exports. This affects display only. Spectator debug information is intentionally separate and more complete.

## Swim Drive storage and Overdrive

Both A/D and small mouse strokes still feed one tracker. No source-specific bonus was added, and the comfortable hooked camera scaling is unchanged.

`FishFightMotion` now gives full cadence credit inside a timing window, partial credit in a broader window, and no passive decay until strokes have been absent long enough. A missed beat does not immediately remove the bar. Defaults:

| Value | Default |
|---|---|
| ideal_stroke_interval | .48 s per alternating stroke |
| full_credit_window | ±.18 s |
| partial_credit_window | ±.48 s; linear partial credit outside full window |
| decay_delay | 1.1 s since last alternating stroke |
| drive_decay | .055 bar units/s after delay |
| drive_gain | .18 per full-credit stroke |
| overdrive_hold_time | .7 s, refreshed by qualifying fast strokes |
| overdrive_consumption | .18 bar units/s × cadence cost of 1–2 |
| overdrive_max | .35 additive propulsion bonus |
| minimum_stroke_interval | .08 s |
| overdrive_minimum_drive | .08; below this, Overdrive shuts down |
| overdrive_rearm_drive | .35; rebuild before re-entering after exhaustion |

Faster-than-efficient strokes start/refill the short Overdrive hold. Faster movement modestly increases the bonus with diminishing returns while increasing cost. Near-full stored Drive supports several seconds at a reasonable fast cadence, rather than a one-frame flash. The bonus is paid from Drive over time and no longer multiplied by the shrinking Drive a second time. This remains authoritative: `multiplier()` affects actual swim velocity/acceleration and the existing built-propulsion line-load path.

Fish HUD displays **SWIM DRIVE nn%** or **OVERDRIVE nn%**, the bar and a compact GOOD/FAST/LATE grade. Sustainable cadence can rebuild Drive after an error or exhaustion. The rearm threshold prevents near-empty on/off flicker.

## Dive particles and results

Each fish has one reusable 24-bubble CPU emitter, emitting only during an authoritative committed dive. Dive Power modestly increases trail velocity. Particle meshes/materials are procedural; no texture downloads, per-frame node spawning or gameplay collision is involved. Replicas use the replicated Dive state, so both roles and the observer can see the effect. The emitter is visual only.

`FightOutcomeBanner.gd` owns a centered local label with a 2.5-second lifetime. `FightSession.finish()` publishes the authoritative result before cleanup. `NetworkSession` routes a reliable result event to relevant role displays. The banner persists independently after the encounter node is gone. Fish and fisher receive different wording for thrown hooks, breaks, catches and spooling; the spectator receives the fisherman wording. Misses and disconnects also have brief messages. Adjust `duration` in the banner for timing.

## Changed code

- New: `FightDecisions.gd`, `FightSpectator.gd`, `FightOutcomeBanner.gd`, `FightReadabilityChecks.gd`.
- `FishFightMotion.gd`: stored cadence, partial credit, delayed decay, persistent paid Overdrive and exhaustion rearm.
- `FightSession.gd` / `FightTestDriver.gd`: shared held decisions, legal intent execution, reliable result publication; removed random fight-mode cycling.
- `NetworkSession.gd`: spectator bootstrap, participant ownership, result delivery, cadence grade replication and optional bounded validation flag.
- `FishPlayer.gd`: reusable dive bubbles for local and replicated fish.
- `Reef.gd` / `FisherView.gd`: compact action coaching and explicit Drive state/percentage; player HUD hidden for observer.
- `Launch.ps1`: `-AIVsAI` shortcut.

Fish snapshots now contain **40 floats** (cadence grade appended); fisher snapshots stay **55**. Fish input stays seven finite validated floats, and reliable bait lifecycle events remain 19. Matching revisions are required. Result messages are authority-only RPCs and never accept client outcomes.

## Validation and remaining manual checks

Import passed, then one 40-second headless `--ai-vs-ai --spectator-check` run passed. It verified exactly two AI participants and no human actor, ran 11 small pure-state cadence/decision contracts, and observed natural minnow pursuit/attack plus hook-set reaching a fight. No smoke-test setup shortcuts were used. After that run, a small low-Drive rearm latch was added and import rechecked; no additional gameplay simulations were run. The engine still prints its pre-existing certificate-store warning.

The bounded validation flag stops at 40 seconds and reports whether a natural fight was reached. Normal `--ai-vs-ai` has no time limit and allows observing complete encounters. The short run did not prove a complete natural landing or every escape outcome. Outcome banner wording/duration, bubble visibility, camera switches, remote event delivery and extended AI balance remain manual checks.

Manual sequence: launch `-AIVsAI`, switch 1/2/3, watch normal casting and hookup, compare the action labels with movement, then watch an outcome. In a fish-player session, try a late stroke, pause one beat, rebuild at ideal cadence, then spend Drive through several seconds of fast strokes. Verify the percentage and bonus persist, then rebuild after exhaustion. No unrelated fight balancing was attempted.
