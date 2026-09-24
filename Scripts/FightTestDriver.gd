class_name FightTestDriver
extends RefCounted
## Deliberately simple server test pilots. No force/outcome cheats in normal AI.
var side_wait: float = 2
var side_aim: Vector3 = Vector3.FORWARD
var side_hold: float = 0
var clock: float = 0
var cast_serial: int = 0
var cast_sent: bool = false
var stroke_clock: float = 0
var stroke_side: float = 1
var burst_remaining: float = 0
var run_committed: bool = false
var vision_remaining: float = 0
var vision_cooldown: float = 0
var drag_wait: float = 0
var selected_drag: float = 0.4
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
		var f = fish.fight
		var action = f.fish_action
		aim = FightDecisions.heading_for(f,action)
		var resting = action == FightDecisions.FishAction.REST
		var energy = fish.stamina/maxf(1,fish.endurance)
		if resting or energy < 0.28: run_committed = false
		elif energy > 0.7 and fish.motion.swim_drive > 0.55: run_committed = true
		var sprint = action == FightDecisions.FishAction.JUMP or run_committed or (not resting and f.spool.distance < 12 and energy > 0.4)
		burst_remaining = maxf(0,burst_remaining-delta)
		if burst_remaining <= 0 and sprint and fish.motion.swim_drive > 0.85 and energy > 0.55 and (absf(fish.directional_pressure) > 0.2 or f.spool.line_rate > 0): burst_remaining = 1.5
		# Bank Drive with efficient legal strokes, spend it during a strong run/turn.
		stroke_clock += delta
		var cadence = (lerpf(0.29,0.25,f.fish_skill) if burst_remaining > 0 else fish.motion.ideal_stroke_interval)+(0.03+(1-f.fish_skill)*0.2)*sin(clock*2.7)
		if stroke_clock >= cadence: stroke_clock = 0; stroke_side *= -1
		if clock > next_lapse:
			stroke_pause = lerpf(1.7,1.2,f.fish_skill)
			next_lapse = clock+execution_rng.randf_range(7,12)*f.fish_skill
		stroke_pause = maxf(0,stroke_pause-delta)
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
		if action in [FightDecisions.FishAction.RUN,FightDecisions.FishAction.LEFT,FightDecisions.FishAction.RIGHT] and sprint and fish.motion.swim_drive >= fish.motion.side_burst_drive and not fish.airborne:
			if side_wait <= 0 and fish.motion.side_wait <= 0:
				var side = -1 if execution_rng.randf() < 0.5 else 1
				side_aim = side_burst_aim(fish.heading,side)
				var edge = session.world.arena_width*0.5-8
				var projected = fish.position+side_aim*16
				if absf(projected.x) > edge or absf(projected.z) > edge: side_aim = side_burst_aim(fish.heading,-side)
				side_hold = 0.9
				side_wait = execution_rng.randf_range(3,5)
			if side_hold > 0: aim = side_aim
		else: side_hold = 0
		var input = FishInput.new(0.25 if resting else 1,0,0,aim,sprint)
		input.vertical = 1 if action == FightDecisions.FishAction.JUMP and not fish.airborne and fish.motion.jump_recovery <= 0 else 0
		if fish.motion.jump_recovery > 0: input.boost = false; input.aim_direction.y = -0.25
		input.cancel_bite = fish.feeding.is_charging
		return input
	else:
		var nearest: BaitActor
		var distance: float = INF
		for candidate in session.baits.values():
			if candidate.claimed or not is_instance_valid(candidate.fisher_owner): continue
			var d = fish.position.distance_to(candidate.position)
			if d < distance: nearest = candidate; distance = d
		if nearest != null:
			aim = (nearest.position-fish.position).normalized()
			var aligned = fish.heading.dot(aim) > 0.92
			var attack = FishInput.new(0.55 if distance < 6 else 1,0,0,aim,false,false)
			if fish.feeding.is_charging:
				attack.cancel_bite = not aligned or distance > 10
				attack.bite_held = not attack.cancel_bite and distance > 3.0 and fish.feeding._charge_time < 0.3
			else: attack.bite_held = aligned and distance < 7 and distance > 1
			return attack
		if fish.feeding.is_charging:
			var cancel = FishInput.new()
			cancel.cancel_bite = true
			return cancel
	return FishInput.new()

func fisher_input(actor: FisherActor, delta: float) -> FisherIntent:
	clock += delta
	var input = FisherIntent.new()
	input.drag = selected_drag
	input.species = BaitMotion.Kind.MINNOW
	input.tier = 12
	input.aim = Vector3.FORWARD.rotated(Vector3.UP,actor.boat_yaw)
	if actor.state == FisherActor.State.SETUP:
		if not cast_sent:
			cast_serial += 1; cast_sent = true
	else: cast_sent = false
	input.cast_serial = cast_serial
	if actor.state == FisherActor.State.BAIT: input.retrieve = 0 if fmod(clock,7) < 0.8 else 0.4
	if is_instance_valid(actor.fight):
		var fight: FightSession = actor.fight
		if fight.phase == FightSession.Phase.CANDIDATE: input.jerk = fight.phase_time > lerpf(1.3,0.65,fight.fisher_skill)
		elif fight.phase == FightSession.Phase.METER: input.jerk = fight.meter < 0.75-(1-fight.fisher_skill)*0.3
		else:
			var seen = fight.perception.observation
			var plan = FisherControls.plan(seen,actor.stamina)
			input.rod_horizontal = plan.horizontal*lerpf(0.75,1,fight.fisher_skill)
			input.rod_vertical = plan.vertical
			input.retrieve = plan.retrieve
			input.power = plan.power
			drag_wait -= delta
			if drag_wait <= 0:
				selected_drag = snappedf(move_toward(selected_drag,plan.drag,0.05),0.05)
				drag_wait = lerpf(1.4,0.9,fight.fisher_skill)
			input.drag = selected_drag
			input.jerk = false
			gesture_wait = maxf(0,gesture_wait-delta)
			# Ascent/air/fall abort preparation too: do not finish an obsolete UP jerk.
			if plan.label in ["REEL SLACK","ABSORB FALL"]: gesture_phase = -1
			if gesture_phase < 0 and gesture_wait <= 0 and plan.jerk != Vector2.ZERO and not actor.vision_active and actor.stamina >= fight.jerk_cost and int(seen.get("maneuver_id",0)) != attempted_maneuver:
				attempted_maneuver = int(seen.get("maneuver_id",0))
				gesture_axis = plan.jerk
				gesture_phase = 0
				gesture_wait = fight.jerk_cooldown+lerpf(1.0,0.25,fight.fisher_skill)
			if gesture_phase >= 0:
				gesture_phase += delta
				var prepare = lerpf(0.65,0.45,fight.fisher_skill)
				var rod = -gesture_axis*0.35 if gesture_phase < prepare else gesture_axis
				if gesture_axis.x != 0: input.rod_horizontal = rod.x
				else: input.rod_vertical = rod.y
				input.power = false
				if gesture_phase > prepare+0.4: gesture_phase = -1
				pump_clock = 0
			elif plan.pump and not actor.vision_active:
				pump_clock = fmod(pump_clock+delta,3.8)
				if pump_clock < 1.6:
					input.rod_vertical = pump_clock/1.6
					input.retrieve = 0.15
				elif pump_clock < 2.0:
					input.rod_vertical = 1
					input.retrieve = 0.15
				else:
					input.rod_vertical = maxf(0,1-(pump_clock-2.0)/1.4)
					input.retrieve = lerpf(0.65,1,fight.fisher_skill)
				input.power = false
			else: pump_clock = 0
			vision_cooldown = maxf(0,vision_cooldown-delta)
			vision_remaining = maxf(0,vision_remaining-delta)
			if gesture_phase < 0 and gesture_wait < 0.3 and vision_cooldown <= 0 and actor.focus > 55 and plan.vision and fight.perception.uncertainty:
				vision_remaining = lerpf(1.0,0.7,inverse_lerp(0.6,1.0,fight.fisher_skill))
				vision_cooldown = lerpf(18,12,inverse_lerp(0.6,1.0,fight.fisher_skill))
			input.vision = vision_remaining > 0

	return input

static func side_burst_aim(heading: Vector3, side: int) -> Vector3:
	return heading.rotated(Vector3.UP,-side*deg_to_rad(60))
