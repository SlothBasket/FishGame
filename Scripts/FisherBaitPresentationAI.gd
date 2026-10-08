class_name FisherBaitPresentationAI
extends RefCounted
## Seeded legal intents only. FisherActor forwards them to PlayerLiveDriver.
## Never writes lure position, velocity or BaitCommand, or reads hidden color rules.
const PROFILES = [
	["retrieve","pause","sweep","charge","glide","retrieve","sink"],
	["charge","glide","retrieve","pause","charge","sink"],
	["rise","glide","descend","pause","charge","glide"],
	["settle","retrieve","pause","charge","settle","sweep"],
	["retrieve","sweep","retrieve","pause","charge","glide"]]
var rng = RandomNumberGenerator.new()
var bag: Array[int] = []
var lure_id: int = 0
var phase: String = ""
var phase_index: int = -1
var remaining: float = 0
var cast_age: float = 0
var reel: float = 0
var side: float = 1
var steer: float = 0
var target_steer: float = 0
var aim: Vector3 = Vector3.FORWARD
var return_after: float = 50

func choose_cast() -> Dictionary:
	if bag.is_empty():
		for kind in range(5): bag.append(kind)
	var index = rng.randi_range(0,bag.size()-1)
	var kind = bag[index]; bag.remove_at(index)
	return {"species":kind,"color_tag":rng.randi_range(0,6)}

func reset() -> void:
	lure_id = 0; phase = ""; phase_index = -1; remaining = 0
	cast_age = 0; steer = 0; target_steer = 0; reel = 0; side = 1; aim = Vector3.FORWARD

func next_phase(bait: BaitActor, boat: Vector3) -> void:
	var releasing = phase == "charge"
	var release_aim = aim
	phase_index = (phase_index+1)%PROFILES[bait.kind].size()
	phase = PROFILES[bait.kind][phase_index]
	side = -side if rng.randf() < 0.7 else side
	aim = BaitMotion.horizontal(bait.heading).cross(Vector3.UP)*side
	target_steer = side*rng.randf_range(0.15,0.45) if phase == "sweep" else 0
	reel = 0
	match phase:
		"retrieve", "sweep":
			reel = [0.35,0.15,0.10,0.10,0.55][bait.kind]
			reel = ReelSpeed.quantize(reel+rng.randf_range(-0.05,0.05))
			remaining = rng.randf_range(4,7) if bait.kind == BaitMotion.Kind.MULLET else rng.randf_range(1.5,3.5)
		"charge":
			var fraction = rng.randf_range(0.3,0.5) if bait.kind == BaitMotion.Kind.MINNOW else rng.randf_range(0.55,0.85)
			remaining = bait.flee_charge_time*fraction
			target_steer = side*0.4
		"rise", "descend": remaining = 0.12 # Edge-triggered squid jet, then release.
		"pause": remaining = rng.randf_range(0.5,1.3)
		"sink": remaining = rng.randf_range(0.6,1.2)
		_: remaining = rng.randf_range(1.3,2.5)
	if bait.kind == BaitMotion.Kind.SQUID:
		aim = BaitMotion.horizontal(boat-bait.position).rotated(Vector3.UP,side*PI/2)
	if releasing: aim = release_aim

func input(bait: BaitActor, boat: Vector3, delta: float) -> FisherIntent:
	var result = FisherIntent.new()
	result.species = bait.kind
	result.aim = BaitMotion.horizontal(boat-bait.position)
	if lure_id != bait.get_instance_id():
		reset(); lure_id = bait.get_instance_id()
		return_after = rng.randf_range(45,65)
	if bait.claimed: reset(); return result
	if bait.cast_remaining > 0 or bait.cast_windup > 0: return result
	cast_age += delta
	if bait.kind == BaitMotion.Kind.CRAB and phase_index < 0 and bait.position.y > bait.floor_height+0.7:
		phase = "bottom-seek"; result.descend = true
		return result
	remaining -= delta
	if remaining <= 0: next_phase(bait,boat)
	steer = move_toward(steer,target_steer,delta*0.5)
	result.retrieve = reel
	result.tier = roundi(reel/ReelSpeed.KEYBOARD_STEP)
	result.steering = steer
	result.escape = phase == "charge"
	result.aim = aim
	result.descend = phase in ["sink","descend"]
	result.rise = phase == "rise"
	if bait.kind == BaitMotion.Kind.SQUID:
		# Safety remains a pulse of ordinary controls, never a position clamp.
		if bait.position.y < bait.floor_height+3:
			result.descend = false
			result.rise = fmod(cast_age,1.4) < 0.12
			result.escape = false
		elif bait.position.y > bait.water_height-2:
			result.rise = false
			result.descend = fmod(cast_age,1.4) < 0.12
			result.escape = false
	return result
