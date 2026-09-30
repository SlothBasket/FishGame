# Commitment and counter readability

Current defaults supersede the AI/camera portions of REEL_AND_FISHER_CORRECTION.md. Reel force/payout, bait acquisition, audio, endurance, Power/Overdrive ordering and jump physics are unchanged.

## AI retrieve and drag

FightTestDriver.persist_settings holds ordinary retrieve/drag decisions for a seeded 1.5-2.5 seconds. Observable danger, run, dive, slack or an opening changing state overrides that hold. Drag changes require at least 0.09 difference and move by 0.10 (0.20 for danger); this prevents ordinary 40/45 oscillation. FisherControls caps inefficient cranking to actual recovery / 4.5, including zero rather than a permanent 10% minimum. Efficient inward line travel permits a cautious 10% probe. Existing close-range pumping, landing pressure and useful Power remain. Jump/slack recovery still takes priority.

## Drive commitments

FightTestDriver chooses a continuous spending target: 80% of draws average two uniform 30-70% samples (concentrating on 40-60%), 10% tactical 20-30%, 10% major 70-90%. Inside 12 m selects major. Ordinary decisions and artificial stroke lapses no longer cancel a powered commitment. Counter lockout, low stamina or jump recovery can interrupt; reaching budget stops powered effort. Fast cadence is used for budgets at least 50%, ordinary powered cadence otherwise. No resource is purchased up front. Drive still drains through shared physical strokes. Up to 64 completed decisions are retained locally; batch AI_COMMITMENT_END records start/end Drive, target, actual bar fraction spent and interruption.

Drive gain remains 0.10 per good stroke, ideal interval 0.48 s. Empty-to-95% ideal rebuilding measured 4.82 s; the three natural encounters averaged 0.074-0.084 bars gained per combat second (roughly 12-14 s/bar including escape and rest). Existing low-stamina recovery/output restrictions remain. No additional gain slowdown was warranted by that sample.

## Shared side commitment and human reaction

FishFightMotion still turns physically. Side preparation is 0.35 s; nominal duration is now 1.8 s. The aim permits up to 12 degrees of legal rhythmic movement around its course so holding the side does not silently eliminate powered strokes. Visible commitment requires 0.2 continuous seconds with boat-relative heading component >0.6 and lateral velocity >2 m/s. Quality builds over 0.5 s, declines off course, and disappears on abandonment. The final 35% of the existing powered bonus is withheld until quality develops; abandoning cannot instantly reclaim it by straightening during the remaining side cooldown. No extra maximum powered force is added.

Classification stays active while lateral heading/velocity remain committed, including a coast after the spending budget finishes. Contrary input cancels; 0.25 s of lost physical direction cancels. Telemetry records maintained fraction, signed direction and displacement; full commitment requires at least 0.7 good seconds and 70% maintained time. The initial SIDE_BURST event means a visible attempt, not automatic full success.

FightSession owns visible maneuver identity and its timestamp. Human counter timing starts there, not on initial boost input: lateness = clamp((reaction delay - 0.25) / human_counter_window, 0, 1), default window 1.2 s. Existing control scales smoothly from 100% to 15% while shock grows. Timing labels are EARLY below 25% lateness, GOOD below 60%, LATE below 90%, then VERY LATE. Direction remains opposite a lateral dash, UP for straight runs and dives. Delayed FisherPerception carries the same authoritative visible ID/hint; AI has no pre-visible counter hint. Strong counters retain physical recoil, recovery, head response and stars.

## Event presentation

FightSession emits maneuver transitions, combined jerk/result messages, Power Reel and interruption through a reliable authority-only NetworkSession RPC. Both participants receive role-specific wording; spectators receive Fisher wording. FightOutcomeBanner displays the last three notices for 2.5 s below the connection status, separately from outcome/star cues. No per-frame UI inference. Counter telemetry includes visible time, input time, delay, grade and authoritative maneuver ID. Both peers should run this revision; existing snapshot sizes are unchanged.

## Camera / rod

FishingPresentation.edge_camera is 4 m above the boat reference, 5.2 m back and 1.8 m sideways. The existing boat-heading + 25% rod-direction target and capped 0.96 m Fish influence remain, so Fish directly under the boat cannot rotate the view straight downward. Main view remains 60 degrees FOV. Vision/bait alternate views are unchanged.

The actual authoritative rod hand and tip now include the shared 1.4 m forward / 1.0 m sideways outboard offset; FisherView and FightSpectator no longer add a second visual-only translation. The rendered line starts at that authoritative rod tip. The existing water-level boat reference for spool separation and separate rod take-up remain unchanged, avoiding a reel-balance change. Camera and offset tune in FishingPresentation; rod geometry in FightSession.update_rod.

## Bounded validation and limits

Latest prior 100-fight data: 84 landed, 10 thrown, 6 setup timeouts. No bait targeting changes were made to shorten setup.

Import passed after an indentation repair. CommitmentChecks passed 18 checks for settings persistence/override, side sustain/abandonment, continued classification, directional rules, 0.4/0.8/1.1/1.5 second counter responses, under-boat framing, Drive rebuilding and exhausted fallback. The first rebuild check incorrectly started from the default 20% reserve; corrected to empty. Existing directional/budget fixtures were updated for the new visible-state contract.

Only three natural batch encounters (seed 713, timeout 180 s each, normal 1/60 simulated step) were run. All landed in 105-141 combat seconds. Forty completed powered commitments spent mean 46.59%, median 47.75%, P25 35.62%, P75 53.72%; six were interrupted. Range 18.5-86.5%. Two SIDE_BURST counters were classified correctly at 0.65-0.67 s reaction delay. Drag-change median intervals were 1.43-1.73 s including exceptional state transitions. This small sample is not a win-rate balance result.

After that sample, a focused correction preserved lateral coasting after the budget ends and retained side classification while motion stays readable; this was checked directly, without another batch. One seven-second normal graphical Fisher presentation fixture entered FIGHT with zero hook extension and captured the full rod/reel, boat edge and surrounding water. Manual sweeping of every rod pose, subjective counter feel, low-endurance long fights and two-client notice delivery remain playtest items. Root-certificate warnings were present; no gameplay script errors occurred. No long simulation or 100/500-fight run.

Editor launch examples: `-- --ai-vs-ai` for spectator testing, `-- --host --role=fisher --ai=fish` for Fisher. The user's existing 100-fight editor arguments were checkpointed and preserved; change them before ordinary play.
