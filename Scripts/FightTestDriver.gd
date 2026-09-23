class_name FightTestDriver
extends RefCounted
## Deliberately simple server test pilots. No force/outcome cheats in normal AI.
var clock: float = 0
var cast_serial: int = 0
var cast_sent: bool = false

func fish_input(fish: FishPlayer, session, delta: float) -> FishInput:
	clock += delta
	var aim = fish.heading
	if is_instance_valid(fish.fight):
		var f = fish.fight
		var action = f.fish_action
		var outward = BaitMotion.horizontal(fish.position-f.fisher.position)
		var right = outward.cross(Vector3.UP)
		aim = outward
		if action == FightDecisions.FishAction.LEFT: aim = (outward-right*1.3).normalized()
		if action == FightDecisions.FishAction.RIGHT: aim = (outward+right*1.3).normalized()
		if action == FightDecisions.FishAction.DIVE: aim = (outward+Vector3.DOWN*1.5).normalized()
		if action == FightDecisions.FishAction.JUMP: aim = (outward+Vector3.UP*1.8).normalized()
		if action == FightDecisions.FishAction.CHARGE: aim = -outward
		var resting = action == FightDecisions.FishAction.REST
		var sprint = not resting and fish.stamina > fish.endurance*0.3
		var stroke = 0.4 if int(clock/0.53)%2 == 0 else -0.4
		var input = FishInput.new(0.25 if resting else 1,0 if resting else stroke,0,aim,sprint)
		input.bite_held = action == FightDecisions.FishAction.JUMP and (not fish.feeding.is_charging or fish.feeding._charge_time < 0.25)
		input.cancel_bite = fish.feeding.is_charging and action != FightDecisions.FishAction.JUMP
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
		if not cast_sent: cast_serial += 1; cast_sent = true
	else: cast_sent = false
	input.cast_serial = cast_serial
	if is_instance_valid(actor.fight):
		var fight: FightSession = actor.fight
		if fight.phase == FightSession.Phase.CANDIDATE: input.jerk = fight.phase_time > 0.7
		elif fight.phase == FightSession.Phase.METER: input.jerk = fight.meter < 0.72
		else:
			var action = fight.fisher_action
			input.rod_horizontal = -0.8 if action == FightDecisions.FisherAction.LEFT else 0.8 if action == FightDecisions.FisherAction.RIGHT else 0
			input.rod_vertical = 1 if action == FightDecisions.FisherAction.UP else -0.6 if action in [FightDecisions.FisherAction.LOWER,FightDecisions.FisherAction.LET_RUN] else 0.1
			input.drag = 0.3 if fight.spool.condition < 0.6 else 0.4
			input.retrieve = 0.8 if action == FightDecisions.FisherAction.REEL else 0.25 if action in [FightDecisions.FisherAction.LEFT,FightDecisions.FisherAction.RIGHT] else 0
			input.power = action == FightDecisions.FisherAction.REEL and fight.fish.stamina < fight.fish.endurance*0.4 and fight.spool.slack < 0.5
			input.jerk = action == FightDecisions.FisherAction.UP and fight.jerk_wait <= 0

	return input
