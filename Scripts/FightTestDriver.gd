class_name FightTestDriver
extends RefCounted
## Deliberately simple server test pilots. No force/outcome cheats in normal AI.
var rng = RandomNumberGenerator.new()
var clock: float = 0
var wait: float = 0
var mode: int = 0
var cast_serial: int = 0
var cast_sent: bool = false
var outward_bias: float = 0.7
var inward_charge_chance: float = 0.06
var inward_charge_duration: float = 1.5
var side_change_min: float = 3
var side_change_max: float = 5
var side: float = 1
var reversal: bool = false
var resting: bool = false
var sprinting: bool = false

func _init() -> void:
	rng.randomize()

func fish_input(fish: FishPlayer, session, delta: float) -> FishInput:
	clock += delta
	wait -= delta
	if wait <= 0:
		var roll = rng.randf()
		mode = 1 if reversal else 5 if roll < inward_charge_chance else 0 if roll < outward_bias else 2 if roll < 0.84 else 3 if roll < 0.93 else 4
		reversal = mode == 5
		if rng.randf() < 0.55: side *= -1
		wait = inward_charge_duration if mode == 5 else rng.randf_range(side_change_min,side_change_max)
	var aim = fish.heading
	var bite = false
	var vertical = 0.0
	if is_instance_valid(fish.fight):
		var toward = (fish.fight.fisher.position-fish.position).normalized()
		aim = toward if mode == 5 else BaitMotion.horizontal(-toward).rotated(Vector3.UP,side*(0.6 if mode == 2 else 0.15))
		vertical = -1 if mode == 3 else 1 if mode == 4 else 0
		bite = mode in [1,4] and fmod(clock,4.5) < 0.45
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
	if is_instance_valid(fish.fight):
		if fish.stamina < fish.endurance*0.2: resting = true; sprinting = false
		if fish.stamina > fish.endurance*0.75: resting = false
		if not resting and fish.stamina > fish.endurance*0.7 and mode != 5: sprinting = true
		if fish.stamina < fish.endurance*0.25: sprinting = false
		if resting:
			aim = (fish.fight.fisher.position-fish.position).normalized()
			return FishInput.new(0.2,0,0,aim,false,false)
		var outward = BaitMotion.horizontal(fish.position-fish.fight.fisher.position)
		var right = outward.cross(Vector3.UP)
		var choice = FightContest.best_move(fish.fight.rod_horizontal,fish.fight.rod_vertical)
		if mode != 5:
			if choice == FightContest.Move.LEFT: aim = (outward-right*1.3).normalized()
			elif choice == FightContest.Move.RIGHT: aim = (outward+right*1.3).normalized()
			if mode == 3 or choice == FightContest.Move.DIVE: aim = (outward+Vector3.DOWN*1.5).normalized()
		# Legal alternating steering: slightly imperfect cadence, no direct Drive grant.
		var stroke = 0.4 if int(clock/0.53)%2 == 0 else -0.4
		return FishInput.new(1,stroke,vertical,aim,sprinting,bite and fish.stamina > fish.dash_cost*1.5)
	return FishInput.new(1,0,vertical,aim,mode == 1 or mode == 4,bite)

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
			var forward = BaitMotion.horizontal(fight.fish.position-actor.position)
			var right = forward.cross(Vector3.UP)
			var motion = fight.fish.motion
			var choice = FightContest.best_counter(fight.fish.heading,right,motion.diving,motion.dive_power >= motion.dive_counter_window)
			input.rod_horizontal = -0.8 if choice == FightContest.Counter.LEFT else 0.8 if choice == FightContest.Counter.RIGHT else 0
			input.rod_vertical = -0.7 if fight.fish.airborne else 0.8 if fight.fish.velocity.y < -2 else 0.05
			input.drag = 0.3 if fight.spool.condition < 0.6 else 0.4
			input.retrieve = 0.95 if fight.spool.slack > 1 else 0.0 if fight.spool.slipping or fight.spool.fish_load > fight.spool.drag_threshold else 0.6
			input.power = fmod(clock,9) < 1 and not fight.spool.slipping and fight.spool.slack < 0.5 and fight.fish.stamina < fight.fish.endurance*0.5
			input.jerk = fmod(clock,4.2) < 0.15 and fight.spool.slack < 0.5
			if choice == FightContest.Counter.UP: input.rod_vertical = 1
			if choice == FightContest.Counter.LET_RUN:
				input.rod_vertical = -0.4
				input.retrieve = 0
				input.power = false

	return input
