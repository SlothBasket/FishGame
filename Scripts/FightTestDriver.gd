class_name FightTestDriver
extends RefCounted
## Deliberately simple server test pilots. No force/outcome cheats in normal AI.
var side_wait: float = 2
var side_aim: Vector3 = Vector3.FORWARD
var side_hold: float = 0
var food = FishFoodInterest.new()
var presentation = FisherBaitPresentationAI.new()
var presentation_seeded: bool = false
var cast_color: int = BaitColors.Tag.SILVER
var cast_kind: int = BaitMotion.Kind.MINNOW
var rod_course = FisherRodCourse.new()
var fish_was_fighting: bool = false
var fisher_was_fighting: bool = false
var recast_wait: float = 0
var food_seeded: bool = false
var clock: float = 0
var cast_serial: int = 0
var cast_sent: bool = false
var stroke_clock: float = 0
var stroke_side: float = 1
var run_committed: bool = false
var closeout_escape: bool = false
@export var closeout_enter_distance: float = 28
@export var closeout_leave_distance: float = 38
@export var emergency_sprint_distance: float = 16
var run_stall_time: float = 0
var run_budget: float = 0
var run_spent_start: float = 0
var run_pause: float = 0
var tension_attack_wait: float = 0
var tension_attack: bool = false
var tension_attack_aim: Vector3 = Vector3.FORWARD
var tension_attacks: int = 0
var reserve_wait: float = -1
var committed_action: int = 0
var bottom_recovery: bool = false
var run_start_drive: float = 0
var completed_commitments: Array[Dictionary] = []
var setting_wait: float = 0
var held_retrieve: float = 0.4
var setting_mode: String = ""
var progress_window: float = 0
var power_push: float = 0
var power_pause: float = 0
var was_observed_run: bool = false

func choose_run_budget(major: bool = false) -> float:
	var roll = execution_rng.randf()
	if major or roll > 0.9: return execution_rng.randf_range(0.7,0.9)
	if roll < 0.1: return execution_rng.randf_range(0.2,0.3)
	return (execution_rng.randf_range(0.3,0.7)+execution_rng.randf_range(0.3,0.7))*0.5

var vision_remaining: float = 0
var vision_cooldown: float = 0
var selected_drag: float = 0.4
var stalled_seconds: float = 0
var steady_rod: Vector2 = Vector2.ZERO
@export var pressure_rod_rate: float = 0.85
@export var flick_rod_rate: float = 8.0
var attempted_maneuver: int = -1
var gesture_phase: float = -1
var gesture_axis: Vector2 = Vector2.ZERO
var gesture_wait: float = 0
var pump_clock: float = 0
var shake_until: float = 0
var shake_wait: float = 0
var stroke_pause: float = 0
var next_lapse: float = 8
var execution_rng = RandomNumberGenerator.new()
func _init() -> void:
	execution_rng.randomize()

func fish_input(fish: FishPlayer, session, delta: float) -> FishInput:
	clock += delta
	if is_instance_valid(fish.landing_show): return FishInput.new()
	food.allow_lures = session.test_bait_allowed()
	var aim = fish.heading
	if is_instance_valid(fish.fight):
		fish_was_fighting = true
		var f = fish.fight
		var energy = fish.stamina/maxf(1,fish.endurance)
		run_pause = maxf(0,run_pause-delta)
		tension_attack_wait = maxf(0,tension_attack_wait-delta)
		# A commitment must yield to recovery/invalid maneuvers, and cannot stay
		# latched forever while legal inputs produce no actual powered swimming.
		run_stall_time = run_stall_time+delta if run_committed and not fish.motion.powered_active else 0.0
		var invalid_move = (committed_action == FightDecisions.FishAction.DIVE and (fish.motion.dive_blocked or bottom_recovery)) or (committed_action == FightDecisions.FishAction.JUMP and f.jump_commit <= 0 and not fish.airborne)
		if run_committed and (run_stall_time > 1.5 or invalid_move or fish.motion.drive_spent-run_spent_start >= run_budget or fish.motion.drive_lockout > 0 or fish.motion.jump_recovery > 0):
			completed_commitments.append({"start_drive":run_start_drive,"end_drive":fish.motion.swim_drive,"spent_fraction":fish.motion.drive_spent-run_spent_start,"target":run_budget,"interrupted":fish.motion.drive_lockout > 0})
			if session.batch_runner != null:
				session.batch_runner.telemetry.event("AI_COMMITMENT_END",f)
				session.batch_runner.telemetry.events[-1].state.merge(completed_commitments[-1],true)
			if completed_commitments.size() > 64: completed_commitments.pop_front()
			run_committed = false
			tension_attack = false
			run_pause = 1.0
			side_hold = 0
			f.fish_action = FightDecisions.fish_choice(f,f.fish_action)
		var action = committed_action if run_committed else f.fish_action
		if (side_hold > 0 or fish.motion.side_time > 0) and fish.motion.drive_lockout <= 0: action = FightDecisions.FishAction.RUN
		aim = FightDecisions.heading_for(f,action)
		var resting = action == FightDecisions.FishAction.REST
		update_closeout(f.spool.distance)
		if closeout_escape and not fish.airborne:
			# Do not rest or attempt another jump inside the landing approach.
			action = FightDecisions.FishAction.RUN
			resting = false
			aim = FightDecisions.heading_for(f,action)
			tension_attack = false
			if run_committed: committed_action = action
		if fish.motion.swim_drive < 0.9: reserve_wait = -1
		elif reserve_wait < 0: reserve_wait = execution_rng.randf_range(0.5,5.0)
		else: reserve_wait = maxf(0,reserve_wait-delta)
		var spend_reserve = closeout_escape or reserve_wait == 0 or f.spool.line_rate < -0.8 or f.tension > f.spool.strength*0.65 or action in [FightDecisions.FishAction.DIVE,FightDecisions.FishAction.JUMP]
		if not run_committed and not resting and spend_reserve and run_pause <= 0 and fish.motion.swim_drive >= (0.3 if closeout_escape else 0.95) and fish.motion.drive_lockout <= 0 and fish.motion.counter_recovery <= 0 and (closeout_escape or tension_attack_wait > 0 or not tension_opportunity(fish,f)):
			run_committed = true
			run_stall_time = 0
			committed_action = action
			run_start_drive = fish.motion.swim_drive
			run_budget = minf(fish.motion.swim_drive,choose_run_budget(f.spool.distance < 12))
			run_spent_start = fish.motion.drive_spent
		# Use felt pressure and visible rod posture, never hidden line condition/dynamic break threshold.
		if not closeout_escape and not run_committed and tension_attack_wait <= 0 and tension_opportunity(fish,f) and run_pause <= 0:
			tension_attack_wait = execution_rng.randf_range(4,7)
			if execution_rng.randf() < tension_willingness(fish.motion.swim_drive,f.fish_skill):
				tension_attack_aim = choose_tension_angle(fish,f)
				if tension_attack_aim != Vector3.ZERO:
					tension_attack = true
					tension_attacks += 1
					run_committed = true
					run_stall_time = 0
					committed_action = FightDecisions.FishAction.RUN
					action = committed_action
					resting = false
					run_start_drive = fish.motion.swim_drive
					run_spent_start = fish.motion.drive_spent
					run_budget = minf(fish.motion.swim_drive,execution_rng.randf_range(0.65,0.85) if fish.motion.swim_drive >= 0.9 else execution_rng.randf_range(0.3,0.55))
					if session.batch_runner != null: session.batch_runner.telemetry.event("AI_TENSION_ATTACK",f)
		if tension_attack: aim = tension_attack_aim
		var spending_drive = run_committed and fish.motion.swim_drive > 0.01 and fish.motion.drive_lockout <= 0 and fish.motion.counter_recovery <= 0
		# Spend renewable reserve independently. Sprint for vertical maneuvers or an urgent run.
		var sprint = (energy > 0.4 and not resting and action in [FightDecisions.FishAction.DIVE,FightDecisions.FishAction.JUMP]) or closeout_sprint(f.spool.distance,f.spool.line_rate,fish.stamina,spending_drive)
		# Ordinary powered cadence spends Drive; major commitments escalate faster.
		var cadence = fish.motion.ideal_stroke_interval
		stroke_clock += delta
		if stroke_clock >= cadence: stroke_clock = 0; stroke_side *= -1
		if not sprint and clock > next_lapse:
			stroke_pause = lerpf(1.7,1.2,f.fish_skill)
			next_lapse = clock+execution_rng.randf_range(7,12)*f.fish_skill
		stroke_pause = 0 if sprint or closeout_escape else maxf(0,stroke_pause-delta)
		shake_wait = maxf(0,shake_wait-delta)
		shake_until = maxf(0,shake_until-delta)
		if shake_wait <= 0 and (f.spool.slack > 0.8 or fish.airborne):
			shake_wait = lerpf(3,1.4,f.fish_skill)
			if execution_rng.randf() < 0.45+0.35*f.fish_skill: shake_until = 1.1
		if shake_until > 0 and not closeout_escape:
			aim = fish.heading.rotated(Vector3.UP,sin(clock*22)*deg_to_rad(9))
		elif stroke_pause <= 0 and not resting:
			aim = aim.rotated(Vector3.UP,stroke_side*deg_to_rad(24))
		side_wait = maxf(0,side_wait-delta)
		side_hold = maxf(0,side_hold-delta)
		if action in [FightDecisions.FishAction.RUN,FightDecisions.FishAction.LEFT,FightDecisions.FishAction.RIGHT] and ((spending_drive and fish.motion.swim_drive >= fish.motion.side_burst_drive) or side_hold > 0 or fish.motion.side_time > 0) and not fish.airborne and not tension_attack and not closeout_escape:
			if spending_drive and side_wait <= 0 and fish.motion.side_wait <= 0:
				var side = -1 if execution_rng.randf() < 0.5 else 1
				side_aim = side_burst_aim(BaitMotion.horizontal(fish.position-f.fisher.position),side)
				var edge = session.world.arena_width*0.5-8
				var projected = fish.position+side_aim*16
				if absf(projected.x) > edge or absf(projected.z) > edge: side_aim = side_burst_aim(BaitMotion.horizontal(fish.position-f.fisher.position),-side)
				side_hold = 2.2
				side_wait = execution_rng.randf_range(3,5)
			if side_hold > 0 or fish.motion.side_time > 0:
				aim = side_aim.rotated(Vector3.UP,stroke_side*deg_to_rad(9))
		else: side_hold = 0
		var input = FishInput.new(0.25 if resting else 1,0,0,aim,sprint)
		input.overdrive = spending_drive
		input.vertical = 1 if action == FightDecisions.FishAction.JUMP and not fish.airborne and fish.motion.jump_recovery <= 0 else 0
		if fish.motion.jump_recovery > 0: input.overdrive = false; input.boost = false; input.aim_direction.y = -0.25
		# Keep ordinary tools submerged; deliberate jumps retain full upward control.
		if action not in [FightDecisions.FishAction.JUMP,FightDecisions.FishAction.DIVE] and not fish.airborne and fish.water_height-fish.position.y < 3:
			input.aim_direction = (BaitMotion.horizontal(input.aim_direction)+Vector3.DOWN*0.2).normalized()
		input = avoid_bottom(input,fish,FightDecisions.bottom_clearance(fish))
		input.cancel_bite = fish.feeding.is_charging
		return input
	if not food_seeded:
		food.rng.seed = execution_rng.randi()
		food_seeded = true
	if fish_was_fighting:
		closeout_escape = false
		fish_was_fighting = false
		tension_attack = false
		tension_attack_wait = 0
		run_committed = false
		run_stall_time = 0
		side_hold = 0
		food.disengage()
	if food.prioritize_lures != session.ai_test_bait_priority:
		food.set_lure_priority(session.ai_test_bait_priority)
	food.hotspot = session.school.hotspot if session.school != null else null
	return food.input(fish,session.baits.values(),session.world.arena_width*0.5,session.world.water_depth,delta)

func update_closeout(distance: float) -> void:
	# Hysteresis keeps escape intent stable while the fish fights for separation.
	if distance < closeout_enter_distance: closeout_escape = true
	elif distance > closeout_leave_distance: closeout_escape = false

func closeout_sprint(distance: float, line_rate: float, stamina: float, using_drive: bool) -> bool:
	# Renewable first; combine both when close enough to lose, or being hauled
	# in quickly despite Overdrive. Never demand a 40% reserve before saving itself.
	return closeout_escape and stamina > 1 and (distance < emergency_sprint_distance or line_rate < -1.0 or (not using_drive and line_rate < -0.2))

func fisher_input(actor: FisherActor, delta: float) -> FisherIntent:
	clock += delta
	var input = FisherIntent.new()
	if is_instance_valid(actor.landing_show):
		presentation.reset()
		input.cast_serial = actor.last_cast
		return input
	input.drag = selected_drag
	if not presentation_seeded:
		presentation.rng.seed = execution_rng.randi()
		presentation_seeded = true
	input.species = cast_kind
	input.color_tag = cast_color
	input.tier = 12
	input.aim = Vector3.FORWARD.rotated(Vector3.UP,actor.boat_yaw)
	if is_instance_valid(actor.fight): fisher_was_fighting = true
	elif fisher_was_fighting:
		fisher_was_fighting = false
		rod_course = FisherRodCourse.new()
		stalled_seconds = 0
		recast_wait = execution_rng.randf_range(6,9)
		cast_sent = false
	recast_wait = maxf(0,recast_wait-delta)
	if actor.state == FisherActor.State.SETUP:
		presentation.reset()
		if not cast_sent and recast_wait <= 0:
			var choice = presentation.choose_cast()
			cast_kind = choice.species; cast_color = choice.color_tag
			input.species = cast_kind; input.color_tag = cast_color
			cast_serial += 1; cast_sent = true
	else: cast_sent = false
	input.cast_serial = cast_serial
	if actor.state == FisherActor.State.BAIT and not is_instance_valid(actor.fight) and is_instance_valid(actor.lure):
		var presented = presentation.input(actor.lure,actor.position,delta)
		input.retrieve = presented.retrieve; input.tier = presented.tier
		input.steering = presented.steering; input.aim = presented.aim
		input.rise = presented.rise; input.descend = presented.descend; input.escape = presented.escape
		# Bottom/jig presentations cannot always reel home; retire an old cast legally.
		if presentation.cast_age > presentation.return_after:
			cast_serial += 1; input.cast_serial = cast_serial
			presentation.reset(); recast_wait = 2
	else: presentation.reset()
	if is_instance_valid(actor.fight):
		var fight: FightSession = actor.fight
		if fight.phase == FightSession.Phase.CANDIDATE: input.jerk = fight.phase_time > lerpf(1.3,0.65,fight.fisher_skill)
		elif fight.phase == FightSession.Phase.METER: input.jerk = fight.meter < 0.75-(1-fight.fisher_skill)*0.3
		else:
			var seen = fight.perception.observation
			var intentional_flick = false
			progress_window = maxf(0,progress_window-delta)
			power_push = maxf(0,power_push-delta)
			power_pause = maxf(0,power_pause-delta)
			var observed_run = float(seen.get("outward_speed",0)) > 3 or float(seen.get("payout",0)) > 2
			if bool(seen.get("counter_success",false)) or (was_observed_run and not observed_run): progress_window = 2.5
			was_observed_run = observed_run
			var planning = seen.duplicate()
			planning["opportunity"] = progress_window > 0
			if float(seen.get("line_rate",0)) >= -0.1 and float(seen.get("slack",0)) < 0.8:
				stalled_seconds = minf(8,stalled_seconds+delta)
			else: stalled_seconds = maxf(0,stalled_seconds-delta*2)
			planning["stalled_seconds"] = stalled_seconds
			var plan = FisherControls.plan(planning,actor.stamina)
			plan = persist_settings(plan,planning,delta)
			if plan.power and power_pause <= 0:
				power_push = 0.9
				power_pause = 3.5
			plan.power = plan.power and power_push > 0
			input.rod_horizontal = rod_course.step(float(seen.get("course_side",seen.get("side",0))),delta)*lerpf(0.75,1,fight.fisher_skill)
			input.rod_vertical = plan.vertical
			input.retrieve = plan.retrieve
			input.power = plan.power
			selected_drag = plan.drag
			input.drag = selected_drag
			input.jerk = false
			gesture_wait = maxf(0,gesture_wait-delta)
			# Ascent/air/fall abort preparation too: do not finish an obsolete UP jerk.
			if plan.label in ["REEL SLACK","ABSORB FALL"]:
				gesture_phase = -1
				pump_clock = 0
				vision_remaining = 0
			if gesture_phase < 0 and gesture_wait <= 0 and plan.jerk != Vector2.ZERO and not actor.vision_active and actor.stamina >= fight.jerk_cost and int(seen.get("visible_maneuver_id",seen.get("maneuver_id",0))) != attempted_maneuver:
				attempted_maneuver = int(seen.get("visible_maneuver_id",seen.get("maneuver_id",0)))
				gesture_axis = plan.jerk
				gesture_phase = 0
				gesture_wait = maxf(4.0,fight.jerk_cooldown+lerpf(1.0,0.25,fight.fisher_skill))
			if gesture_phase >= 0:
				gesture_phase += delta
				var prepare = lerpf(0.65,0.45,fight.fisher_skill)
				var rod = -gesture_axis*0.35 if gesture_phase < prepare else gesture_axis
				intentional_flick = gesture_phase >= prepare and gesture_phase <= prepare+0.2
				if gesture_axis.x != 0: input.rod_horizontal = rod.x
				else: input.rod_vertical = rod.y
				input.power = false
				if gesture_phase > prepare+0.4: gesture_phase = -1
				pump_clock = 0
			elif (plan.pump or (pump_clock > 0 and not observed_run and float(seen.get("tension",0)) < float(seen.get("break_threshold",FightForceUnits.BASE_BREAK))*0.8 and not seen.get("descending",false) and not seen.get("ascending",false) and not seen.get("airborne",false) and not seen.get("jump_fall",false))) and not actor.vision_active:
				pump_clock += delta
				if pump_clock < 1.6:
					input.rod_vertical = pump_clock/1.6
					input.retrieve = minf(plan.retrieve,0.55)
				elif pump_clock < 2.0:
					input.rod_vertical = 1
					input.retrieve = minf(plan.retrieve,0.55)
				else:
					input.rod_vertical = maxf(0,1-(pump_clock-2.0)/1.4)
					input.retrieve = minf(lerpf(0.65,1,fight.fisher_skill),plan.retrieve+0.15)
				input.power = false
				if pump_clock >= 3.8: pump_clock = 0
			else: pump_clock = 0
			var rod_request = Vector2(input.rod_horizontal,input.rod_vertical)
			if plan.get("capture_slack",false):
				steady_rod.x = move_toward(steady_rod.x,rod_request.x,pressure_rod_rate*delta)
				steady_rod.y = move_toward(steady_rod.y,rod_request.y,3.0*delta)
			else:
				steady_rod = steady_rod.move_toward(rod_request,(flick_rod_rate if intentional_flick else pressure_rod_rate)*delta)
			input.rod_horizontal = steady_rod.x
			input.rod_vertical = steady_rod.y
			vision_cooldown = maxf(0,vision_cooldown-delta)
			vision_remaining = maxf(0,vision_remaining-delta)
			if gesture_phase < 0 and gesture_wait < 0.3 and vision_cooldown <= 0 and actor.focus > 55 and plan.vision and fight.perception.uncertainty:
				vision_remaining = lerpf(1.0,0.7,inverse_lerp(0.6,1.0,fight.fisher_skill))
				vision_cooldown = lerpf(18,12,inverse_lerp(0.6,1.0,fight.fisher_skill))
			input.vision = vision_remaining > 0

	return input

static func side_burst_aim(heading: Vector3, side: int) -> Vector3:
	return heading.rotated(Vector3.UP,-side*deg_to_rad(60))

# Hold ordinary settings; only observable state transitions bypass the hold.
func persist_settings(plan: Dictionary, seen: Dictionary, delta: float) -> Dictionary:
	setting_wait = maxf(0,setting_wait-delta)
	var mode = "SLACK" if plan.get("capture_slack",false) else "DANGER" if plan.get("acute_danger",false) else "SPOOL" if plan.get("spool_pressure",false) else "RUN" if float(seen.get("line_rate",0)) > 0.1 and float(seen.get("payout",0)) > 2 else "DIVE" if seen.get("descending",false) else "OPENING" if seen.get("opportunity",false) else str(plan.get("stage","NORMAL"))
	if setting_wait <= 0 or mode != setting_mode:
		held_retrieve = plan.retrieve
		if absf(plan.drag-selected_drag) >= (0.025 if plan.get("pressure",false) else 0.09) or mode in ["DANGER","SLACK","SPOOL"] or (plan.get("close_pressure",false) and plan.drag > selected_drag+0.01):
			selected_drag = snappedf(move_toward(selected_drag,plan.drag,0.2 if mode in ["DANGER","SPOOL"] else 0.1),0.05)
		setting_wait = 0.25 if mode == "DANGER" else 0.65 if plan.get("pressure",false) else 0.5 if mode == "SPOOL" else execution_rng.randf_range(1.5,2.5)
		setting_mode = mode
	plan.retrieve = held_retrieve
	plan.drag = selected_drag
	return plan

# Last legal-input override: stale committed dives or shakes cannot pin the nose.
func avoid_bottom(input: FishInput, fish: FishPlayer, clearance: float) -> FishInput:
	if clearance < 3 or fish.touching_bottom(): bottom_recovery = true
	elif clearance > 4.5: bottom_recovery = false
	if not bottom_recovery: return input
	input.aim_direction = (BaitMotion.horizontal(input.aim_direction)+Vector3.UP*0.8).normalized()
	input.throttle = 1
	input.vertical = 1
	input.boost = false # Basic swimming must suffice, including at zero Drive.
	return input

func tension_opportunity(fish: FishPlayer, f: FightSession) -> bool:
	return f.phase == FightSession.Phase.FIGHT and f.spool.slack < 0.5 and f.tension/maxf(1,f.spool.strength) >= 0.62 and fish.motion.swim_drive >= 0.45 and fish.motion.counter_recovery <= 0 and fish.motion.drive_lockout <= 0 and fish.motion.jump_recovery <= 0 and not fish.airborne

func choose_tension_angle(fish: FishPlayer, f: FightSession) -> Vector3:
	var outward = BaitMotion.horizontal(fish.position-f.fisher.position)
	var right = outward.cross(Vector3.UP)
	var selected = Vector3.ZERO
	var best = -INF
	for degrees in [-55.0,0.0,55.0]:
		var course = outward.rotated(Vector3.UP,deg_to_rad(degrees))
		var destination = fish.position+course*12
		var edge = f.fisher.session.world.arena_width*0.5-6
		if absf(destination.x) > edge or absf(destination.z) > edge: continue
		var leverage = FightContest.held_leverage(course,outward,right,f.rod_horizontal,f.rod_vertical)
		var score = course.dot(outward)*0.7-leverage*1.2+course.dot(fish.heading)*0.15
		if score > best: best = score; selected = course
	return selected

func tension_willingness(drive: float, skill: float) -> float:
	var reserve = smoothstep(0.45,1.0,drive)
	return lerpf(0.15,0.95,reserve)*lerpf(0.65,1.0,skill)
