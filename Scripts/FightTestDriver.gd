class_name FightTestDriver
extends RefCounted
## Deliberately simple server test pilots. No force/outcome cheats in normal AI.
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
		var cadence = (lerpf(0.28,0.20,f.fish_skill) if burst_remaining > 0 else fish.motion.ideal_stroke_interval)+(1-f.fish_skill)*sin(clock*2.7)*0.2
		if stroke_clock >= cadence: stroke_clock = 0; stroke_side *= -1
		var stroke = stroke_side*0.4
		var input = FishInput.new(0.25 if resting else 1,stroke,0,aim,sprint)
		input.vertical = 1 if action == FightDecisions.FishAction.JUMP else 0
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
	input.species = BaitMotion.Kind.MINNOW
	input.tier = 12
	input.aim = Vector3.FORWARD.rotated(Vector3.UP,actor.boat_yaw)
	if actor.state == FisherActor.State.SETUP:
		if not cast_sent:
			actor.cast_distance = actor.ai_cast_distance
			cast_serial += 1; cast_sent = true
	else: cast_sent = false
	input.cast_serial = cast_serial
	if actor.state == FisherActor.State.BAIT: input.retrieve = 0 if fmod(clock,7) < 0.8 else 0.4
	if is_instance_valid(actor.fight):
		var fight: FightSession = actor.fight
		if fight.phase == FightSession.Phase.CANDIDATE: input.jerk = fight.phase_time > lerpf(1.3,0.65,fight.fisher_skill)
		elif fight.phase == FightSession.Phase.METER: input.jerk = fight.meter < 0.75-(1-fight.fisher_skill)*0.3
		else:
			var action = fight.fisher_action
			input.rod_horizontal = -0.8 if action == FightDecisions.FisherAction.LEFT else 0.8 if action == FightDecisions.FisherAction.RIGHT else 0
			input.rod_horizontal *= lerpf(0.75,1,fight.fisher_skill)
			input.rod_vertical = 1 if action == FightDecisions.FisherAction.UP else -0.6 if action in [FightDecisions.FisherAction.LOWER,FightDecisions.FisherAction.LET_RUN] else 0.1
			var seen = fight.perception.observation
			drag_wait -= delta
			if drag_wait <= 0:
				selected_drag = 0.3 if float(seen.get("condition",1)) < 0.6 or action == FightDecisions.FisherAction.LET_RUN else 0.4
				selected_drag += (1-fight.fisher_skill)*0.12*maxf(0,sin(clock*0.6))
				drag_wait = lerpf(1.4,0.45,fight.fisher_skill)
			input.drag = selected_drag
			input.retrieve = 0.8 if action == FightDecisions.FisherAction.REEL else 0.25 if action in [FightDecisions.FisherAction.LEFT,FightDecisions.FisherAction.RIGHT] else 0
			input.power = action == FightDecisions.FisherAction.REEL and float(seen.get("outward_speed",10)) < 1.5 and float(seen.get("slack",1)) < 0.5 and float(seen.get("tension",110)) < 55 and actor.stamina > 30
			input.jerk = action == FightDecisions.FisherAction.UP and fight.jerk_wait <= 0
			vision_cooldown = maxf(0,vision_cooldown-delta)
			vision_remaining = maxf(0,vision_remaining-delta)
			if vision_cooldown <= 0 and actor.focus > 55 and (fight.perception.uncertainty or (fight.perception.age() > 0.3 and float(seen.get("tension",0)) > 35) or float(seen.get("depth",0)) > 8 or float(seen.get("payout",0)) > 2 or (fight.fisher_skill < 0.75 and sin(clock) > 0.95)):
				vision_remaining = lerpf(1.6,1.0,fight.fisher_skill)
				vision_cooldown = lerpf(11,6,fight.fisher_skill)
			input.vision = vision_remaining > 0

	return input
