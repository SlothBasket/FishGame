# Reserve, side cost, counters and feeding follow-up

This supersedes the indicated defaults in VARIETY_AND_LIVE_FORCE.md. Restored fight action scoring, Fisher close-out, camera, jump mechanics, payout accounting and max drag 110 remain unchanged.

## Force reserve and AI

Stored Drive bonus rises 0.35 -> 0.45, still quadratic and multiplied by the existing capped endurance capacity. Healthy stored factors at 0/50/75/100% Drive are 1/1.1125/1.2531/1.45. Existing motion.multiplier also contains a Drive contribution; the complete empty/full force ratio therefore includes that existing term, not just 1.45.

Ordinary fight load scale is now reserve_load_scale = 0.90; powered scale stays propulsion_load_scale = 0.70. Ordinary motor/load both use FishPlayer.reserve_force_capacity = max(0.55, lerp(1, force_capacity(), DriveFraction^2)). This lets fresh endurance strengthen stored reserves and depleted endurance weaken them while retaining a basic motor floor. Powered fight_force_multiplier remains unchanged.

At nominal mass/base acceleration, full built speed and outward alignment, ordinary load is approximately 34.6 empty / 61.1 full at 100 endurance, and 81.6 full at 130, before additional directional loads. These are formula guides, not clamps or live-play guarantees. No extra top-speed multiplier. Actual LINE LOAD still comes directly from FightLine.fish_load.

AI high Drive starts a randomized 0.5-5 s tactical wait rather than an immediate commitment. Useful Dive/Jump opportunity, actual inward line recovery >0.8 m/s or tension >65% strength can override it. No distance records or progress planner. Existing continuous spending budgets remain.

## Side identity, cost and counter shock

Side identity is published as soon as side_time starts: LEFT/RIGHT DRIVE DASH or OVERDRIVE. side_reported remains a physical-quality telemetry threshold. Counter direction uses committed side_sign. Existing quality/heading requirements still govern the maneuver and force bonus.

side_cost_multiplier = lerp(1, 0.75, side_quality) while side_time is active and not counter-recovering. It scales finite powered stamina/exertion and side endurance cost; Drive drain is unchanged. Combined with existing radial opposition cost (about 1.33 for a 55-degree side versus 2 straight), a good side costs about half the comparable straight finite expenditure. Poor quality gets no extra discount. No artificial line awards.

Counter eligibility has no fixed-age cutoff while the active maneuver persists. Existing smooth lateness keeps at least 15% of matched control. Drive/Overdrive intensity changes no longer restart visible_since or maneuver ID. The original base/late jerk spike remains, plus min(40, mass * max(0, velocity dot relevant_axis) * 0.35 * lerp(0.35,1.5,lateness)). Mass includes growth. Axis is radial outward for runs, signed lateral for sides, normalized outward+down for Dive. Slack contact scales the entire spike; wrong direction earns no control. Momentum tuning fields live in FightSession.

## Hookset and ordinary feeding

Rod snap pitch 60 -> 78 degrees, rise 0.18 -> 0.11 s, hold 0.12 -> 0.18 s. Existing head recoil is enlarged 1.6x within the same angular caps and held 0.45 s. Existing gameplay yank velocity/strength and whiss remain; no extra physical impulse.

FishFoodInterest WANDER uses legal alternating steering +/-0.65 plus a matching 24-degree aim swing at the existing stroke cadence. FishSteering still measures actual head/body travel to earn Drive; no numerical grants. Wander auto-boost at 90% is removed. Target detection remains 45 m and target selection rules are preserved.

Attack setup is limited to min(12 m, 75% of chosen lunge reach), direct heading dot >0.8, while continuing forward. Far pursuit uses 0.12 s lead; nearby charge/intercept prediction caps at 0.55 s. When prey is close behind the turn radius, cancel the current attack and swim a shallow forward reset course for 1-1.6 s, preserving the target before another approach. Feeding charge/release rules remain otherwise intact.

eligible and intercept_direction accept Variant bait arguments, check is_instance_valid before the BaitActor type and properties, and safely reject freed references. choose and APPROACH/COMMIT call the guard before access. Invalid targets clear pursuit/reset state and cancel outstanding charge through normal input.

## Validation / files

Import passed. One existing seven-second normal Fisher presentation smoke entered FIGHT with zero hook extension and no script errors. The usual Windows certificate warning remains. Freed-reference call ordering was inspected; no batch or new test harness was run. Existing reserve-value assertions were adjusted, not executed. Force balance, side efficiency/readability, physical outside-fight stroke generation and moving-prey interception remain manual playtest items.

Gameplay files: FishFoodInterest, FishFightMotion, FishPlayer, FightTestDriver and FightSession. Existing DriveJumpChecks/ForceGroundChecks reference values and CODE_GUIDE/MILESTONES documentation updated. The user's 100-fight editor launch preference is preserved; this pass did not execute it. Use `-- --ai-vs-ai` for normal spectator play.
