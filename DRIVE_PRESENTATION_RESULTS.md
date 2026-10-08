# Drive and Fisher presentation measurements - 2026-10-08

Deterministic component fixtures, not win-rate estimates. Default 220-strength line. Hazard is a rate per second; instantaneous one-second probability would be `1-exp(-hazard)` if the rate remained fixed. The after-10s column isolates acute exposure while holding condition/load constant; normal play also changes condition, motion and drag.

| Condition | Tension | Initial hazard/s | Hazard/s after 10s |
|---|---:|---:|---:|
| Fresh | 110 | 0 | 0 |
| Fresh | 150 | 0.000000686 | 0.000000686 |
| Fresh | 180 | 0.003964 | 0.011401 |
| Fresh | 200 | 0.060316 | 0.241264 |
| 50% | 100 | 0.0000784 | 0.0000784 |
| 50% | 110 | 0.003449 | 0.006088 |
| 50% | 120 | 0.011795 | 0.036828 |
| 50% | 140 | 0.042448 | 0.169792 |
| 50% | 160 | 0.143242 | 0.572969 |

Threshold: `220 * lerp(0.38, 0.85, condition^1.4)` = 187 fresh, 122.781 at half condition. The warning region starts at 80% of this threshold. Breaks remain stochastic. Yielding clears acute exposure; countering removes Fish power through the existing motor.

| Stored Drive | Measured steady free speed (m/s) | Fresh smallest Fish available fight load |
|---|---:|---:|
| 0% | 8.0 | 178.30 |
| 50% | 9.6 | 211.61 |
| 100% | 11.2 | 311.78 |
| 100% + sustained Overdrive | - | 561.12 |

Force fixture: smallest Fish, default full 130 maximum/current stamina, outward alignment, full throttle, neutral side multiplier, no sprint. It holds reserve fixed to compare capability after motor response settles; an actual Overdrive consumes reserve and its force falls. Existing short activation pulse reaches 701.40 in this fixture. The printed stored ratios include the tiny ordinary decay tick. Acceleration bonus reaches +55%; turning unchanged.

Actual spool comparison at 90% drag: empty Drive/correct leverage transmitted 178.30 tension with 0.004119/s risk; a preloaded full-Drive Overdrive commitment against wrong leverage transmitted 183.96 with 0.039139/s risk and allowed payout. Available Fish force is not identical to transmitted tension: drag/spool response limits the latter. This is about 9.5 times the immediate hazard, not guaranteed snapping. The more forgiving correct-leverage holding limit is 233.64 versus 162.36 on the yielding/wrong side.

Rod test: small alternating lateral samples kept held pressure centered; +0.7 for 0.5s established opposing pressure, a brief crossing did not reverse it, and sustained -0.7 did. The discrete LEFT counter request still passed.

Forty-second deterministic intent samples per species passed serialization, 5% reel tiers and shared PlayerLiveDriver conversion:

- Minnow: retrieve, pause, sweep, charge, glide, sink; 4 charged releases.
- Shrimp: charge, glide, retrieve, pause, sink; 10 charged releases.
- Squid: rise, glide, descend, pause, charge; 22 discrete motor jets, including 7 charged lateral releases.
- Crab: bottom-seek, settle, retrieve, pause, charge, sweep; 3 charged releases.
- Mullet: retrieve, sweep, pause, charge, glide; 2 charged releases.

The fixture fixes observed bait positions to isolate intent phases; the separate single graphical preview exercised real casts/movement through FisherActor for all five species. No movie and no fight batch. Inspect real multiplayer counterplay, risk severity, species dwell times and chase selection manually before further balance changes.

Changed files:

- `Scripts/FightLine.gd`: dynamic threshold, sustained exposure and preloaded shock danger.
- `Scripts/FishPlayer.gd`, `Scripts/FishFightMotion.gd`: passive cruise/acceleration and stored fight force.
- `Scripts/FishFoodInterest.gd`: target costs, post-meal forward preference and selective hunting Overdrive.
- `Scripts/FightTestDriver.gd`: reserve-scaled tension challenges, presentation/cast lifecycle and held-course integration.
- `Scripts/FisherPerception.gd`, new `Scripts/FisherRodCourse.gd`: delayed observed lateral motion and held-pressure hysteresis.
- New `Scripts/FisherBaitPresentationAI.gd`: all five legal-control profiles, seeded species bag and blind colors.
- New `Scripts/DrivePresentationChecks.gd`, new `Scripts/BaitPresentationPreview.gd`: focused component checks and optional graphical control-path preview.
- `Scripts/FightCorrectionChecks.gd`, `Scripts/HuntingDriveChecks.gd`: existing expectations updated for intentional risk/Drive policy changes.
- `CODE_GUIDE.md`, `MILESTONES.md`, this report and generated helper/check script UID files.

Existing local `project.godot` edits, `fight_test.avi` and `Scripts/CaptureWorkflowChecks.gd.uid` were preserved and excluded from the commit.
