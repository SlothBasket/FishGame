# Force and escape calibration

This small patch supersedes the force/AI/notice defaults in COMMITMENT_AND_COUNTER_READABILITY.md. Bait, camera, reel accounting, hook and jump mechanics, continuous Drive spending, human counter timing and Power/Overdrive ordering remain unchanged.

## Fish force and endurance

FishPlayer starts stamina_capacity, stamina and endurance at 130. Endurance remains current maximum stamina; fatigue immediately caps stamina to the new maximum. The independent normal_power_reference is 100, not the starting capacity.

force_capacity = (max(0, endurance) / 100)^0.9. At 130/100/75/50/25 endurance this yields 1.266/1/0.772/0.536/0.287. FishPlayer.fight_force_multiplier applies capacity to powered acceleration together with the existing powered boost and committed side multiplier, with a floor of 1 on the base motor multiplier. FightSession applies the same capacity/side factors to the powered propulsion load estimate. Existing speed/jump capacity stays capped at 1, now relative to the fixed 100 reference. Basic forward/reverse/steering and existing exhausted swimming floor remain available. Size-dependent speed/growth and line-force mass scaling are unchanged.

Fatigue cost multiplier = max(0.12, (max(0, endurance) / 100)^1.6). This is 1.522 at 130, 1 at 100, 0.631 at 75, 0.330 at 50 and 0.12 at 25. It multiplies existing exertion/counter costs only. No passive endurance depletion was added. The tunables are normal_power_reference, force_capacity_exponent, fatigue_curve_exponent and fatigue_low_multiplier in FishPlayer.

FishFightMotion stored force = 1 + 0.35 * normalized_Drive^2 * existing capped endurance power_capacity. At healthy capacity full Drive gives +35%; half gives +8.75%. stored_drive_force_bonus/exponent tune these. This changes motor force and its load estimate, not another top-speed multiplier.

## Drag and side force

FightSession.maximum_line_acceleration increases 20 -> 40. The former cap flattened the stopping difference above roughly 58% drag at nominal mass 3.2; 40 permits the full existing 110-force reel range to affect acceleration. Max drag force, strength, payout rule, useful retrieve, wear/hazard equations and vertical force limits were not changed. Thus greater drag transmits greater tension and stopping force without failed retrieve deploying line.

FishFightMotion.side_force_bonus = 0.5: multiplier = 1 + 0.5 * side_quality while a side maneuver remains active and is not counter-recovering. It affects powered acceleration and projected line load, not awarded distance or speed caps. Existing direction tests/quality buildup/cancellation still apply. A counter clears side_quality and side_time, removing the extra force; wrong counters leave it alone. Existing radial opposition cost makes lateral effort cheaper than direct outward effort. Straight runs retain greatest radial projection.

## Escape-oriented AI

FightDecisions projected distance reward rises from 0.06 to 0.65 per metre, plus another 0.65 penalty per negative metre; outward alignment weight rises 0.2 -> 1.0. Remove the random runner-up action selection. RUN and REST aim outward in 3D, with existing boundary avoidance, rather than voluntarily rising toward the boat. Existing jump commitment and hook-risk logic remains.

FightTestDriver tracks best escape distance and a 3-second smoothed recent distance. Ordinary rebuilding uses full-throttle outward swimming, allowing existing nonpowered regeneration. Once Drive reaches 90%, it deliberately holds the reserve for at least 2.5 seconds before a new powered commitment; losing 1 m versus recent distance, 3 m versus best, or nearing within 15 m overrides preservation. Initial full Drive is held similarly. Side dashes are initiated only when the action scorer chooses LEFT/RIGHT, in that chosen direction, rather than a random side during RUN. Existing continuous varied spending budgets remain.

## Notices

FightOutcomeBanner anchors notices at the right edge, 28% down, with 32 px margin and a 488 px wrapping region. Keeps the last three messages, ignores consecutive duplicates while visible, holds newest event for 2.0 seconds including a final 0.3-second fade. Strong-counter captions use the same right-side region; outcome banners remain centered. FisherView stats move left, matching spectator stats. Network connection text moves to the top-center clear of both regions. Camera/rod code is unchanged.

## Focused validation

Import passed. ForceGroundChecks passed 19 assertions after repairing an uninitialized feeding component in the isolated fixture. Covers initial values, capacity/fatigue curve, zero-cost conservation, nonlinear Drive, side bonus removal, physical drag comparisons, depleted Fish containment, full-Drive AI preservation and lost-ground response. Previous DriveJumpChecks expectations were updated for the intentional nonlinear bonus.

A two-second motor/spool fixture from 30 m, ordinary powered rhythm, full initial Drive and full retrieve ended at 51.91/49.51/45.75/37.79 m for 35/50/70/100% drag. Peak tension was 38.5/55/77/110 respectively. At 25 endurance and maximum drag distance fell to 25.72 m. A high-quality fresh 55-degree side dash at half drag reached 47.34 m radius with 30.08 m lateral displacement. These isolate force relationships (fixed endurance and maintained side quality), not live balance; no teleport/line award is involved.

Three natural AI encounters, seed 714, 100 combat-second limit, all timed out alive rather than concluding. Final endurance 90.1-91.9, final line 65.8-121.5 m; maximum tension 55 because these AI Fish/Fisher decisions did not select high drag. Therefore the high-drag risk relationship was verified in the focused fixture, not observed in those short fights. No long batch or win-rate claims. One seven-second graphical Fisher fixture confirmed right-side notices separated from left-side stats; final connection-label relocation and duplicate suppression were inspected in code. No new controls. Subjective force, long-fight close-out and counter-to-recovery feel remain manual playtests. The usual certificate warning appeared; the repaired focused check and game sessions had no script errors.
