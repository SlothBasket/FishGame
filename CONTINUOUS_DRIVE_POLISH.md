# Continuous Drive and goal-directed Fisher correction

## Resource flow and tuning

`FishFightMotion.step` remains the shared measured-body-stroke path. A quality reversal earns `drive_gain = 0.10`; about ten good reversals (4.8 seconds at ideal cadence) refill an empty bar. Quality uses the existing timing windows. Below 25 stamina, gain is multiplied by clamp(stamina / 25, 0.4, 1): at 5-10 stamina a good reversal earns 0.04, requiring about 25 reversals / 12 seconds for a full bar. Passive decay remains 0.055/s after 1.1 seconds without a stroke. No normal swim-speed reduction was made.

Forward boost plus recent measured rhythm spends Drive continuously: `drive_drain = 0.30/s`, or `overdrive_drive_drain = 0.48/s` during fast reversals (under 0.30 s). There is no activation purchase or minimum full-bar requirement. Stop boosting to preserve the remainder immediately; stop stroking and ordinary power expires after the 0.62 s rhythm grace. Fast Overdrive expires after 0.40 s without another fast reversal, then ordinary rhythm can sustain normal powered swimming. No Drive gain or stamina regeneration occurs during active spending. `drive_burst_threshold = 0.10` is only readiness display guidance. `drive_burst_time` is retained as a positive activity/output signal for existing snapshots/VFX, not a purchased-duration timer.

`stamina_share` is the fraction of this frame's demand that the available Drive could not cover. FishPlayer charges its existing 18 stamina/s sprint cost times this share. Overdrive adds 8 stamina/s times the same share. Existing radial opposition multiplies those costs (1x lateral to 2x directly against a taut line). Dive/ascent, rod resistance, counters and endurance costs remain legitimate separate costs. The stamina-funded propulsion portion scales down below 15 stamina; stored Drive still provides useful effort at low stamina, subject to existing endurance power capacity. Power ends when neither Drive nor sufficient stamina supports it. This prevents free continuous high output without disabling normal swimming.

Overdrive serials still identify the beginning of a legitimate fast escalation. Existing Power-Reel-first / Overdrive-second punishment ordering and minimum output gate are unchanged. Side bursts retain their physical 55-degree boat-relative geometry and steering commitment; releasing boost stops powered spending even while the steering arc completes.

## AI commitment

FightTestDriver starts a run after rebuilding at least 95% Drive and chooses a seeded spending budget: 20% probability of 40-60% of a bar, 65% probability of 65-85%, 15% probability of 90-100%. Near-boat emergencies choose the major range. Budget is capped to available Drive. The AI releases boost when cumulative actual Drive spent reaches its target, or rest/counter disruption interrupts it. It pauses at least one second before another commitment and must rebuild the reserve. Ordinary cadence is 0.36 s while spending; major commitments use 0.26 s to seek Overdrive. Real measured strokes, not these intent flags alone, earn/spend propulsion. Desired budgets averaged 72.9% in the seeded contract check; real fights may interrupt commitments earlier.

## Fisher progression

FisherControls reads only delayed FisherPerception geometry, line measurements and visible counter success. Stages use actual distance: FAR >=70 m, MID 40-70 m, CLOSE 15-40 m, LANDING PUSH <15 m. Safe progress means tension / current break threshold <0.65, condition >0.8, no hard outward run (outward speed >3 or payout >2), Dive, ascent or fall.

When safe, retrieve is 100% inside 40 m or during an opening; otherwise 80%. Working drag remains 40%, close/opening drag targets 55%, and within 15 m at danger <0.45 it can target 65%. Existing danger/poor-condition/Dive/fall branches reduce drag to 30-35%. Increases step 5 percentage points at the existing 0.9-1.4 s decision interval; reductions can step 20 points at that same delayed interval. Defaults are not globally raised.

A delayed observed counter success or hard run ending opens 2.5 seconds of progress intent. Healthy line, danger <0.55 and Fisher stamina >25 permit 0.9 s Power pushes, with 3.5 s between starts. Safety can abort sooner. Near the boat use loaded rod pressure and retrieve rather than large pumps. Farther out, safe pumps retrieve at 55% during lift/hold (previously 15%), then 65-100% while lowering, depending on existing Fisher skill. No hidden Fish energy reads or faster perception were added.

## Feeding approach

FishFoodInterest retains awareness, prediction, natural prey, T test-lure priority, disengagement and recast timing. Approach throttle is 0.85 and charge throttle 0.70. Only a close off-axis target inside the approximate speed/turn-rate radius permits 0.20 braking. Charge entry uses expected dash reach plus relative closing velocity times charge duration instead of a fixed 14 m stop point. Aim continues predicting target velocity through remaining charge and flight. Release alignment is 0.88, allowing a moving physical attack rather than waiting for near-perfect aim. Charge goals remain 65-85%; impossible/overshot approaches cancel and retry legally.

## Line presentation

FishingLine keeps a constant base color with subtle short moving highlights every 4 m. Actual line rate still determines marker direction and speed; the geometry itself does not move with texture travel. Crank/spool direction, camera, water and recorded drag audio remain unchanged.

The generic sphere and angular support points were removed. FishingPresentation uses the permitted clean fallback: a smooth slack-sagged direct path from tip to the actual mouth attachment. This can pass through part of the body at some angles, but introduces no fake angular wrap and never changes authoritative line physics. Ellipsoid wrapping is intentionally deferred.

## Validation scope

Import passed. Focused Drive/side and Fisher-experience checks cover resource timing, low-stamina recovery, fallback, Power ordering, lateral geometry, close-out choices, continued feeding propulsion and mouth attachment. Two bounded 60-second smoke encounters at 20x (seed 712) produced one THROWN and one TIMEOUT, no line breaks or script errors; hook-impact extension was zero. A 28-second graphical AI-vs-AI run entered a natural fight without script errors; its Fisher view showed the continuous mouth line and preserved camera/reel/water. A screenshot cannot validate moving-marker feel. No large batch or win-rate tuning was performed. These checks do not prove that the full late-fight stalemate is eliminated; manual low-stamina play remains the important follow-up.

Editor Main Run Args: `-- --ai-vs-ai`, or `-- --host --role=fisher --ai=fish`. T toggles test-bait priority in hosted sessions. Existing boost + alternating body strokes control continuous power; no new gameplay buttons.
