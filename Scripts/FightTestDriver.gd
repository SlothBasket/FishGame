class_name FightTestDriver
extends RefCounted
## Deliberately simple server test pilots. No force/outcome cheats in normal AI.
var rng = RandomNumberGenerator.new()
var clock: float = 0
var wait: float = 0
var mode: int = 0
var cast_serial: int = 0
var cast_sent: bool = false
var held: bool = false

func _init() -> void:
	rng.randomize()

func fish_input(fish: FishPlayer, session, delta: float) -> FishInput:
	clock += delta
	wait -= delta
	if wait <= 0: mode = rng.randi_range(0,5); wait = rng.randf_range(1.5,3.5)
	var aim = fish.heading
	var bite = false
	var vertical = 0.0
	if is_instance_valid(fish.fight):
		var toward = (fish.fight.fisher.position-fish.position).normalized()
		aim = toward if mode == 0 else -toward if mode <= 2 else BaitMotion.horizontal(toward).rotated(Vector3.UP,PI*0.5)
		vertical = -1 if mode == 3 else 1 if mode == 4 else 0
		bite = fmod(clock,2.5) < 0.6
	else:
		var nearest: BaitActor
		var distance: float = INF
		for candidate in session.baits.values():
			if candidate.claimed or not is_instance_valid(candidate.fisher_owner): continue
			var d = fish.position.distance_to(candidate.position)
			if d < distance: nearest = candidate; distance = d
		if nearest != null:
			aim = (nearest.position-fish.position).normalized()
			bite = distance < 9 and fmod(clock,1.5) < 0.5
	return FishInput.new(1,0,vertical,aim,mode == 1 or mode == 4,bite)

func fisher_input(actor: FisherActor, delta: float) -> FisherIntent:
	clock += delta
	var input = FisherIntent.new()
	input.species = BaitMotion.Kind.SQUID
	input.tier = 3
	input.aim = Vector3.FORWARD.rotated(Vector3.UP,actor.boat_yaw)
	input.rod = input.aim
	if actor.state == FisherActor.State.SETUP:
		if not cast_sent: cast_serial += 1; cast_sent = true
	else: cast_sent = false
	input.cast_serial = cast_serial
	if is_instance_valid(actor.fight):
		var fight: FightSession = actor.fight
		if fight.phase == FightSession.Phase.CANDIDATE: input.jerk = fight.phase_time > 0.7
		elif fight.phase == FightSession.Phase.METER: input.jerk = fight.meter < 0.72
		else:
			var right = Vector3.RIGHT.rotated(Vector3.UP,actor.boat_yaw)
			var side = (fight.fish.position-actor.position).dot(right)
			input.rod = (input.aim-right*signf(side)*0.8).normalized()
			if fight.fish.airborne: input.rod.y = -0.7
			elif fight.fish.velocity.y < -2: input.rod.y = 0.7
			input.retrieve = 0.2 if fight.tension > fight.stressed_load else 0.6
			input.power = fmod(clock,7) < 1.4 and fight.tension < fight.stressed_load
			input.jerk = fmod(clock,3.2) < 0.15
			if fmod(clock,11) < 1: input.rod = -input.rod # Occasional readable mistake.
	return input
