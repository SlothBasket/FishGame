# Restored fight variety and authoritative force readings

This pass supersedes distance-priority behavior and the previous force-estimate chain. Reference: 5f5d8e263a86f196f59993bb12000a2f4402df42. Only the Fish fight-input block was restored from that reference; later Fisher persistence/close-pressure fixes remain.

Removed best/recent distance memory, losing-ground tests, record-dependent Drive preservation and forced RUN/full-throttle rebuilding. Restored weak distance/alignment weights (0.06 / 0.2), state-based maneuver scoring with occasional close runner-up selection, ordinary LEFT/RIGHT intent, REST throttle 0.25 and earlier side-dash opportunities during powered runs. Continuous spending budgets, authoritative visible counter windows and telemetry remain. Horizontal scoring/ordinary heading and terrain-aware bottom protection remain as harmless safety; no vertical distance reward. Below 3 m surface depth, ordinary non-JUMP/non-airborne intent gets a gentle -0.2 vertical aim component; intentional JUMP is exempt. No scripted maneuver rotation or new planner.

## Force path and calibration

FishFightMotion.propulsion is a 0.25-second smoothed estimate of positive throttle * (0.35 + 0.65 * clamped speed fraction) * motion.multiplier() * stored_force_multiplier(). The former extra (1 + run_build * 0.6 * capped capacity) * lerp(0.3, 1, capped capacity) approximation has been removed.

FightSession.propulsion_force = directional alignment * motion.propulsion * base acceleration * size-dependent mass * propulsion_load_scale * powered_force. powered_force is FishPlayer.fight_force_multiplier() when powered, otherwise 1. It is exactly the existing physical motor multiplier: max(1, fight_boost_multiplier() * force_capacity() * side_force_multiplier()). Thus the motor and line-load estimator now use the same powered factor instead of different boost curves. Stored Drive is already inside propulsion; it is not multiplied again in FightSession. Counter recovery and existing side-quality gates remain.

Final movement_load = propulsion_force + directional_load + dive_power * 35. FightLine.step clamps this nonnegative into fish_load; elastic stretch and transient shocks contribute separately to tension, not to this displayed load. These force-equivalent units are not a second UI physics model.

propulsion_load_scale: 0.85 -> 0.70, calibrated around max_drag_force = 110 (unchanged). Force capacity now uses (endurance / 100)^1.1 above 100 and ^0.8 at/below 100: 130 -> 1.335, 100 -> 1, 75 -> 0.794, 50 -> 0.574, 25 -> 0.330. The exponents are exported in FishPlayer. Capacity affects powered force without raising ordinary top speed; locomotion floor remains. Starting 130 stamina/endurance and exertion fatigue formula are unchanged. Stored Drive remains 1 + 0.35 * fraction^2 * existing capped capacity; healthy values at 0/50/75/100% are 1/1.0875/1.1969/1.35. No further Drive multiplier was stacked.

For orientation only, at nominal mass 3.2/base acceleration 12/full built speed and half Drive, the basic straight powered formula gives about 66 force at 100 endurance and 88 at 130, before directional/dive additions. Full-Drive fresh Overdrive can exceed 120. These are arithmetic guides, not promises of live force at every speed or heading. Drag remains 44/66/88/99/110 at 40/60/80/90/100%.

## Readouts and networking

Spectator reads FightLine.fish_load and drag_threshold directly. Fisher snapshots append fish_load, force_capacity and stored_force_multiplier at indices 69-71 (72 floats total). Existing drag threshold is index 33. Both views use FightSession.force_readout: LINE LOAD, DRAG HOLD, FORCE / DRAG, FORCE CAP and DRIVE FORCE. Zero drag displays -- for the undefined ratio. Both peers must use this revision. No change to notices or camera.

## Minimal validation

Import passed. One existing seven-second graphical Fisher-view fixture entered a real fight with zero initial extension and no script errors; the captured readout displayed LINE LOAD 21.9, DRAG HOLD 44, ratio 0.50x, capacity 1.33x and Drive 1.00x. The ordinary Windows root-certificate warning remains. No batches, matrix checks or new harnesses. Obsolete distance-planner assertions were removed from the existing ForceGroundChecks, whose formula/reference calls were updated without running its matrix. Maneuver variety, force/drag feel and network-client play remain manual evaluation. Stop here rather than auto-tuning subjective behavior.
