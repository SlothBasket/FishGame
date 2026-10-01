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


## Measured AI strokes and moving feeding correction (2026-10-01)

This supersedes the earlier feeding setup and force defaults above. FishInput.rhythmic_swim supplies legal alternating steering (+/-0.75) reinforcing a 24-degree body-relative aim swing. An 8-degree maximum course bias keeps navigation from swallowing one half-stroke. FightTestDriver and FishFoodInterest share this input generator at the existing cadence. Committed side courses keep their 9-degree aim swing and retain bounded steering instead of discarding it. FishSteering thresholds and measured head.stroke -> FishFightMotion.step Drive awards are unchanged; deliberate head shakes, pauses and tactical reserve holding remain.

FishFoodInterest aims early (0.12 s far lead; arrival prediction capped at 0.55 s), begins charge only inside attack_setup_distance=12 with heading dot >0.8, and keeps 0.90 approach / 0.85 charge throttle. Current charge produces actual min/max lunge reach, compared against predicted remaining distance with scaled bite-radius tolerance. preferred_launch_distance=7 m shifts by +/-1 m for closing speed and up to 2 m for fish growth; full charge may release outside this preferred zone. Alignment >=0.88 is still required. No chosen charge percentage or alignment braking. Existing freed-target guards, awareness radius and broad overshoot reset remain.

FightSession propulsion_load_scale=0.80 and reserve_load_scale=1.0. Drag calibration and Fisher decisions are unchanged. Counter lateness uses side_elapsed/side_burst_duration for side bursts, or elapsed/(elapsed+counter_lateness_timescale) for variable maneuvers (timescale=2.5 s). Active maneuver state determines eligibility, not a timer. Existing minimum matched control and momentum-dependent late shock remain.

Validation: one import/parse check only; no batches or fight simulations. Movement feel, measured Drive gain and balance are left for manual playtesting. Editor spectator arguments (-- --ai-vs-ai) are preserved.


### Restore course-relative swimming (2026-10-01)
The previous body-relative AI stroke helper amplified alternating turns and capped navigation correction at 8 degrees. Removed it and restored the prior FightTestDriver/FishInput behavior, course-relative feeding/wander sway, and original side-burst steering constraint. Navigation and wall avoidance again supply the full desired course. No new oscillation strength or direct Drive grants.

FishSteering.stroke_head_degrees is now 8 (was 12): a completed reversal still needs at least 4 degrees of measured body travel. Head shakes below that body threshold remain head shakes, regardless of the overlapping head-angle range. This modest shared recognition adjustment allows smaller head offsets as the body follows; cadence, gain, decay, and boost spending are unchanged. The prior moving feeding charge/reach logic, force scales, and counter timing are preserved. Import-only validation; actual Drive gain and restored movement feel need manual confirmation.


### Active counters, spool defense, and hook recoil (2026-10-01)
FightSession now uses authoritative dive/side/powered state for counter eligibility, without waiting for visible text or run buildup. Correct direction plus line contact keeps its force-based effectiveness for the entire maneuver: no elapsed-time effectiveness multiplier, EARLY/LATE grades, or timing expiry. Notices and the retained timing_grade telemetry field report SUCCESS. counter_risk_progress (side elapsed/duration or elapsed/(elapsed+2.5)) increases only the existing jerk shock and momentum shock; counter_timing retains this risk progress for report compatibility. Force/contact may still affect interruption strength. Airborne/ascent exclusions and directional rules remain.

FisherControls overrides passive line-condition caution when line usage >=65%, line_rate >0.1 m/s and the line is taut. Requested drag ramps from 60% at 65% spool usage to 90% at 90% usage. Acute tension exceeding break_threshold*(1.25+0.25*urgency) still requests a temporary 10-point reduction, then reassesses. Ordinary wear/condition no longer forbids escalation in this losing position. FightTestDriver applies the SPOOL setting mode every 0.5 seconds with up to 20-point legal drag steps. Jump/slack capture remains the earlier priority; physical drag capacity, wear and break mechanics are unchanged.

Hook impact uses hook_recoil_duration=0.85 s and hook_recoil_authority=1.0. FishSteering retains normal 20% recoil authority for other hits, but hook recoil can turn the body at full authority even when forward speed is low. Head angular caps and the original yank velocity remain. NetworkSession publishes a separate reliable hook_impact visual event reusing CounterHalo stars on host and clients, without counter rewards/banners or batch telemetry contamination. No movement wiggle changes.

Validation: Godot import/parse passed; no fight batches or gameplay simulations. Drag risk balance and hook-turn feel remain manual playtest items.
