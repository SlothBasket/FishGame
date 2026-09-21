# Fight controls and physical model

This milestone replaces the checkpoint's abstract line with an explicit spool model. All gameplay remains host-authoritative. The current protocol requires matching revisions on both instances.

## Launch

Run PowerShell in the FishGame folder:

```powershell
# Recommended first manual test: you fish, AI controls the fish.
.\Launch.ps1 -HostGame -Role fisher -AI fish

# Two human instances:
.\Launch.ps1 -HostGame -Role fish
.\Launch.ps1 -JoinIP 127.0.0.1 -Role fisher

# Roles can also be reversed:
.\Launch.ps1 -HostGame -Role fisher
.\Launch.ps1 -JoinIP 127.0.0.1 -Role fish

# Other solo configurations:
.\Launch.ps1 -HostGame -Role fish -AI fisher
.\Launch.ps1 -HostGame -Role fish -AI both
```

Argument-free Godot F5/Launch.ps1 remains the original sandbox. The previous local editor launch arguments were checkpointed in `d6fa7e7`, then removed so F5 no longer silently starts a network fisherman session. F10 disconnects a network session. No pushing was performed by this pass.

## Controls

| Action | Keyboard/mouse | Gamepad |
|---|---|---|
| Boat movement / bait steering | WASD | Left stick |
| Aim before fight | Mouse | Right stick |
| Rod during fight | Mouse; bounded left/right and up/down | Right stick |
| Retrieve | Hold W at saved setting | Continuous RT travel |
| Saved reel setting | Wheel, 5% steps | D-pad up/down |
| Drag | `[` decrease / `]` increase, 5% steps | D-pad left/right |
| Drag slider | Escape releases cursor; drag the slider | Use D-pad |
| Cast / return to setup | G | X |
| Select bait in setup | X | Y |
| Bait escape charge/release | LMB | RB |
| Hook-set / fight jerk | Hold/release Q for hook meter; press Q for fight jerk | RB |
| Power Reel | Hold Shift | Hold LB |
| Fish Vision | Hold V | Hold left-stick click |
| Alternate bait view | C | Right-stick click |
| Rise / descend bait | Space / Ctrl | A / B |

The saved keyboard reel setting defaults to 60%, is independent of continuous trigger input, and survives casting and fights. Drag defaults to 40% and persists in the fisher actor/view. During fights the mouse changes normalized rod offsets, not free camera yaw. Server clamps these offsets and constructs a rod direction relative to the current horizontal boat-to-fish direction. Default limits: ±75° yaw, +55°/-40° pitch. Fish Vision freezes these offsets; it does not let the camera create new rod input or jerks.

## Ownership and code map

- `FightLine.gd`: spool accounting, continuous requested/actual load, drag payout, retrieval, shock and wear. Exported Resource defaults are duplicated per encounter.
- `FightSession.gd`: hook phases, bounded rod, movement-derived load, physical force, stamina, hook security, jerks/jumps and landing. No camera or device reads.
- `FisherIntent.gd`: normalized retrieve, normalized horizontal/vertical rod intent and drag target. Fixed 13-number payload; no transforms/outcomes/target IDs. Reel preference index is now 0–20.
- `FisherActor.gd`: authoritative boat/bait and persistent preferences/resources. Existing bait motors and cast code remain in use.
- `FisherView.gd`: fish-centered camera, one connected thick rod, one thin sagging/taut line, standard Godot bars/slider and local procedural audio.
- `NetworkSession.gd`: role ownership, validation, snapshots and reliable fisherman input. Existing fish input checks remain unchanged. Fisher role/sequence/rate/payload validation is retained. Fisher input timeout is 1.25 s; fish remains 0.35 s. Reliable delivery avoids discarding critical hold/release state during gaps. A stale fisher input still neutralizes controls and cancels a pending hook-set. This is not latency compensation.
- `FightTestDriver.gd`: legal FishInput/FisherIntent test pilots. No private movement or forced outcomes in ordinary AI.
- `ReelSpeed.gd`, `GameControls.gd`: continuous trigger/fine keyboard preference and drag bindings.
- `FightCoreChecks.gd`: short deterministic contracts used by the bounded localhost smoke.

Fisher snapshots now contain 48 numeric fields. The original 0–29 fields retain their positions; 30–47 are distance, slack, drag, drag threshold, requested load, line rate, payout, actual retrieve, slipping, tip XYZ, hand XYZ, line strength and rod offsets. Cameras are not replicated. The view draws the line from the **same bent tip** used for authoritative distance, eliminating the disconnected visual pivot. No boat, rod, line or fisher HUD is created for fish clients.

## Line behavior

`line_out` is metres released from the spool. It changes only through recovery and payout. Distance is fish-to-rod-tip separation. `slack = max(0, line_out-distance)`; swimming inward never silently removes spool line. Positive line rate means fish taking line; negative means recovery.

Requested load combines elastic extension, outward actual velocity, outward heading/throttle propulsion, lateral movement opposed by the rod, retrieve closure and short jerk load. Conservative size-dependent mass influences both load and resulting acceleration. Inward swimming removes the outward velocity/heading contribution and produces slack; lateral motion only adds extra load when countered. External force is applied through the existing FishPlayer motor, never by rotating or teleporting the fish.

Normal drag threshold is `strength * drag^drag_curve`. At the defaults (110 and 1.3), 40% gives approximately 33 force units. Above the threshold the spool pays out, limited to line actually demanded by separation. Sustained normal tension stays near drag; brief load-derivative shocks may exceed it. Tension eases toward the requested/capped load instead of switching on/off. Slack suppresses force.

Reeling rapidly takes up slack; under load, normal recovery slows. Reeling against slipping drag adds wear proportional to retrieve squared and actual load. Power Reel suppresses payout entirely, actively recovers line and exposes the line to uncapped requested load. It retains stamina cost and the existing sprint-start timing lock. Depletion requires releasing Power Reel before restarting, preventing resource flicker.

Sudden slack recovery/reversal changes requested load quickly. That derivative produces transient load and wear, rather than a special reversal combo. Line breaks remain probabilistic, driven by actual stress and accumulated condition loss. There is no guaranteed break threshold.

Sustained slack after a short grace reduces internal hook security; rapid turns and airborne activity accelerate it. Moderate steady tension slowly restores security. Hook-loss probability grows as security deteriorates. Lowering the rod during jumps reduces throw chance; jerking upward against a committed dive retains its stamina counter and temporary load. Jerks feed the smoothed load model rather than adding a permanent maximum-force step.

Landing requires boat proximity, recovered line and a valid connected fight held for 0.75 s. **Stamina is no longer a landing condition.** Success clears the bait/fight, resets the fish, restores resources/controls and returns the fisher to setup.

## Important tuning locations

| Location | Main defaults |
|---|---|
| `FightLine` | strength 110; elasticity 22; retrieve 4.5 m/s; Power 7 m/s; drag curve 1.3; payout response 6; cap 22 m/s; tension response 12 |
| `FightLine` wear | load 0.009; reeling against drag 0.022; shock 0.003; Power 0.018 |
| `FightSession` rod | yaw 75°; up 55°; down 40°; response 5; length 3 m; bend 0.65 m |
| `FightSession` slack | tolerance 0.5 m; security decay 0.055/s; recovery 0.035/s; slack throw rate 0.035 |
| `FightSession` landing | 3 m boat distance; 0.75 s confirmation; no stamina gate |
| `FisherView` | mouse response 0.0035; stick response 1.2; camera response 5 |
| `FightTestDriver` | outward bias 0.7; inward-charge chance 0.06; inward duration 1.5 s; decisions every 3–5 s |

These are first-pass values, not automatically balanced results. Inspector exports appear on FightSession/FisherActor and the FightLine resource; runtime-created instances use script defaults unless configured before adding them.

## Manual test sequence

1. Start `-HostGame -Role fisher -AI fish`. Choose squid with X, cast G, then let it descend until the AI fish takes it.
2. Wait intentionally, hold Q, release near 75%. Confirm underwater impact transitions to the stable boat/fish view.
3. Move mouse fully left/right/up/down: fish remains the view reference, rod stays forward, line begins at the bent tip.
4. Begin at 40% drag. Release retrieve; observe outward runs paying line and tension near the displayed threshold. Lower/raise drag with brackets.
5. Reel moderately, then strongly against slipping drag. Observe line-rate direction and condition wear. Briefly Power Reel during a run and then while yielding/tired; watch payout stop and load change.
6. Watch the rare inward-charge/reversal: line out persists, slack appears, fast retrieve removes it, and reversal can shock the line.
7. Try up-jerks during dives, lower rod during jumps, and hold/release Fish Vision. Confirm camera/reference and controls restore.
8. Reel to the boat and confirm landing/reset/recast without needing zero fish stamina.
9. Repeat with the second human localhost instance to assess network delay and hold/release feel. Do not mix old/new revisions.

## Validation and deferred work

One import check passed. The focused two-instance check initially exposed pending hook-set cancellation from input gaps. Short blocker-diagnosis reruns were needed; after reliable fisherman delivery/timeout handling, it passed hook candidate → meter → impact → fight, eight deterministic line/input/rod contracts, full-stamina landing/reset, replicated fight/landing and client departure. No long sessions, profiling, screenshots or balance tournaments were run. The camera/UI were exercised headlessly; visual feel, AI tactics, controller hardware and special-mechanic balance require manual testing.

Priority 3 **was not implemented**. Bait retrieve still drives its existing motor rather than a separate propulsion-plus-line-force model. Shared input infrastructure now supplies continuous human retrieve and finer saved settings, but this is not the requested full bait parity/bottom-friction overhaul. Minor cosmetics, fine audio design and automatic tuning were deliberately deferred. Existing broad historical tests contain old tier/movement assumptions and were not run as a substitute for the targeted core-fight check.
