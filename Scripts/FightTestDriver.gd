class_name FightTestDriver
extends RefCounted
## Deliberately simple server test pilots. No force/outcome cheats in normal AI.
var side_wait: float = 2
var side_aim: Vector3 = Vector3.FORWARD
var side_hold: float = 0
var food = FishFoodInterest.new()
var fish_was_fighting: bool = false
var fisher_was_fighting: bool = false
var recast_wait: float = 0
var retrieve_wait: float = 0
var retrieve_level: float = 0.4
var food_seeded: bool = false
var clock: float = 0
var cast_serial: int = 0
var cast_sent: bool = false
var stroke_clock: float = 0
var stroke_side: float = 1
var run_committed: bool = false
var run_stall_time: float = 0
var run_budget: float = 0
var run_spent_start: float = 0
var run_pause: float = 0
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
	var aim = fish.heading
	if is_instance_valid(fish.fight):
		fish_was_fighting = true
		var f = fish.fight
		var energy = fish.stamina/maxf(1,fish.endurance)
		run_pause = maxf(0,run_pause-delta)
		# A commitment must yield to recovery/invalid maneuvers, and cannot stay
		# latched forever while legal inputs produce no actual powered swimming.
		run_stall_time = run_stall_time+delta if run_committed and not fish.motion.powered_active else 0.0
		var invalid_move = (committed_action == FightDecisions.FishAction.DIVE and (fish.motion.dive_blocked or bottom_recovery)) or (committed_action == FightDecisions.FishAction.JUMP and f.jump_commit <= 0 and not fish.airborne)
		if run_committed and (run_stall_time > 1.5 or invalid_move or energy < 0.22 or fish.motion.drive_spent-run_spent_start >= run_budget or fish.motion.drive_lockout > 0 or fish.motion.jump_recovery > 0):
			completed_commitments.append({"start_drive":run_start_drive,"end_drive":fish.motion.swim_drive,"spent_fraction":fish.motion.drive_spent-run_spent_start,"target":run_budget,"interrupted":fish.motion.drive_lockout > 0})
			if session.batch_runner != null:
				session.batch_runner.telemetry.event("AI_COMMITMENT_END",f)
				session.batch_runner.telemetry.events[-1].state.merge(completed_commitments[-1],true)
			if completed_commitments.size() > 64: completed_commitments.pop_front()
			run_committed = false
			run_pause = 1.0
			side_hold = 0
			f.fish_action = FightDecisions.fish_choice(f,f.fish_action)
		var action = committed_action if run_committed else f.fish_action
		if (side_hold > 0 or fish.motion.side_time > 0) and fish.motion.drive_lockout <= 0: action = FightDecisions.FishAction.RUN
		aim = FightDecisions.heading_for(f,action)
		var resting = action == FightDecisions.FishAction.REST
		if fish.motion.swim_drive < 0.9: reserve_wait = -1
		elif reserve_wait < 0: reserve_wait = execution_rng.randf_range(0.5,5.0)
		else: reserve_wait = maxf(0,reserve_wait-delta)
		var spend_reserve = reserve_wait == 0 or f.spool.line_rate < -0.8 or f.tension > f.spool.strength*0.65 or action in [FightDecisions.FishAction.DIVE,FightDecisions.FishAction.JUMP]
		if not run_committed and not resting and spend_reserve and run_pause <= 0 and fish.motion.swim_drive >= 0.95:
			run_committed = true
			run_stall_time = 0
			committed_action = action
			run_start_drive = fish.motion.swim_drive
			run_budget = minf(fish.motion.swim_drive,choose_run_budget(f.spool.distance < 12))
			run_spent_start = fish.motion.drive_spent
		var sprint = run_committed
		# Ordinary powered cadence spends Drive; major commitments escalate faster.
		var cadence = (0.26 if run_budget >= 0.5 else 0.36) if sprint else fish.motion.ideal_stroke_interval
		stroke_clock += delta
		if stroke_clock >= cadence: stroke_clock = 0; stroke_side *= -1
		if not sprint and clock > next_lapse:
			stroke_pause = lerpf(1.7,1.2,f.fish_skill)
			next_lapse = clock+execution_rng.randf_range(7,12)*f.fish_skill
		stroke_pause = 0 if sprint else maxf(0,stroke_pause-delta)
		shake_wait = maxf(0,shake_wait-delta)
		shake_until = maxf(0,shake_until-delta)
		if shake_wait <= 0 and (f.spool.slack > 0.8 or fish.airborne):
			shake_wait = lerpf(3,1.4,f.fish_skill)
			if execution_rng.randf() < 0.45+0.35*f.fish_skill: shake_until = 1.1
		if shake_until > 0:
			aim = fish.heading.rotated(Vector3.UP,sin(clock*22)*deg_to_rad(9))
		elif stroke_pause <= 0 and not resting:
			aim = aim.rotated(Vector3.UP,stroke_side*deg_to_rad(24))
		side_wait = maxf(0,side_wait-delta)
		side_hold = maxf(0,side_hold-delta)
		if action in [FightDecisions.FishAction.RUN,FightDecisions.FishAction.LEFT,FightDecisions.FishAction.RIGHT] and ((sprint and fish.motion.swim_drive >= fish.motion.side_burst_drive) or side_hold > 0 or fish.motion.side_time > 0) and not fish.airborne:
			if sprint and side_wait <= 0 and fish.motion.side_wait <= 0:
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
		input.vertical = 1 if action == FightDecisions.FishAction.JUMP and not fish.airborne and fish.motion.jump_recovery <= 0 else 0
		if fish.motion.jump_recovery > 0: input.boost = false; input.aim_direction.y = -0.25
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
		fish_was_fighting = false
		run_committed = false
		run_stall_time = 0
		side_hold = 0
		food.disengage()
	if food.prioritize_lures != session.ai_test_bait_priority:
		food.set_lure_priority(session.ai_test_bait_priority)
	return food.input(fish,session.baits.values(),session.world.arena_width*0.5,session.world.water_depth,delta)

func fisher_input(actor: FisherActor, delta: float) -> FisherIntent:
	clock += delta
	var input = FisherIntent.new()
	input.drag = selected_drag
	input.species = BaitMotion.Kind.MINNOW
	input.tier = 12
	input.aim = Vector3.FORWARD.rotated(Vector3.UP,actor.boat_yaw)
	if is_instance_valid(actor.fight): fisher_was_fighting = true
	elif fisher_was_fighting:
		fisher_was_fighting = false
		recast_wait = execution_rng.randf_range(6,9)
		cast_sent = false
	recast_wait = maxf(0,recast_wait-delta)
	if actor.state == FisherActor.State.SETUP:
		if not cast_sent and recast_wait <= 0:
			cast_serial += 1; cast_sent = true
	else: cast_sent = false
	input.cast_serial = cast_serial
	if actor.state == FisherActor.State.BAIT: input.retrieve = bait_retrieve(actor.kind,delta)
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
			var plan = FisherControls.plan(planning,actor.stamina)
			plan = persist_settings(plan,seen,delta)
			if plan.power and power_pause <= 0:
				power_push = 0.9
				power_pause = 3.5
			plan.power = plan.power and power_push > 0
			input.rod_horizontal = plan.horizontal*lerpf(0.75,1,fight.fisher_skill)
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
			elif (plan.pump or (pump_clock > 0 and not observed_run and float(seen.get("tension",0)) < float(seen.get("break_threshold",93.5))*0.8 and not seen.get("descending",false) and not seen.get("ascending",false) and not seen.get("airborne",false) and not seen.get("jump_fall",false))) and not actor.vision_active:
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

func bait_retrieve(kind: int, delta: float) -> float:
	# Strategy seam for future species; each output remains a legal retrieve input.
	retrieve_wait -= delta
	if retrieve_wait <= 0:
		match kind:
			BaitMotion.Kind.MINNOW:
				retrieve_level = 0.0 if execution_rng.randf() < 0.2 else float(execution_rng.randi_range(3,5))*0.1
			_: retrieve_level = 0.4
		retrieve_wait = execution_rng.randf_range(0.6,1.3) if retrieve_level == 0 else execution_rng.randf_range(2,5)
	return retrieve_level

# Hold ordinary settings; only observable state transitions bypass the hold.
func persist_settings(plan: Dictionary, seen: Dictionary, delta: float) -> Dictionary:
	setting_wait = maxf(0,setting_wait-delta)
	var danger = float(seen.get("tension",0))/maxf(1,float(seen.get("break_threshold",93.5)))
	var mode = "SLACK" if plan.get("capture_slack",false) else "SPOOL" if plan.get("spool_pressure",false) else "DANGER" if danger > 0.85 else "RUN" if float(seen.get("line_rate",0)) > 0.1 and float(seen.get("payout",0)) > 2 else "DIVE" if seen.get("descending",false) else "OPENING" if seen.get("opportunity",false) else "NORMAL"
	if setting_wait <= 0 or mode != setting_mode:
		held_retrieve = plan.retrieve
		if absf(plan.drag-selected_drag) >= 0.09 or mode in ["DANGER","SLACK","SPOOL"] or (plan.get("close_pressure",false) and plan.drag > selected_drag+0.01):
			selected_drag = snappedf(move_toward(selected_drag,plan.drag,0.2 if mode in ["DANGER","SPOOL"] else 0.1),0.05)
		setting_wait = 0.5 if mode == "SPOOL" else execution_rng.randf_range(1.5,2.5)
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
