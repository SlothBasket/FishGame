class_name FisherPerception
extends Resource
## Delayed observations available to a human fisher. No fish energy/Drive/AI-state reads.
@export var sample_interval: float = 0.12
@export var reaction_delay: float = 0.30
@export var reaction_jitter: float = 0.10
@export var late_reaction_chance: float = 0.12
@export var late_reaction_extra: float = 0.20
@export var vision_reaction_delay: float = 0.08
var clock: float = 0
var next_sample: float = 0
var observation: Dictionary = {}
var pending: Array[Dictionary] = []
var descending_time: float = 0
var uncertainty: bool = false
var last_air_time: float = -10
var rng = RandomNumberGenerator.new()
func _init() -> void:
	rng.randomize()
func tick(delta: float, f: FightSession) -> void:
	clock += delta
	if clock >= next_sample:
		next_sample = clock+sample_interval
		var delay = vision_reaction_delay if f.fisher.vision_active else maxf(0.05,reaction_delay+rng.randf_range(-reaction_jitter,reaction_jitter))
		if not f.fisher.vision_active and rng.randf() < late_reaction_chance: delay += late_reaction_extra
		var sample = capture(f)
		sample["sample_time"] = clock
		sample["ready_time"] = clock+delay
		pending.append(sample)
	while not pending.is_empty() and pending[0].ready_time <= clock:
		var previous_side = float(observation.get("side",0))
		observation = pending.pop_front()
		uncertainty = previous_side*float(observation.side) < -0.08 or bool(observation.descending)
	# Side is a delayed coarse visual estimate outside Vision, never an AI action.
	if observation.get("descending",false): descending_time += delta
	else: descending_time = 0
	if not observation.is_empty(): observation["descending_time"] = descending_time
func capture(f: FightSession) -> Dictionary:
	var right = BaitMotion.horizontal(f.fish.position-f.fisher.position).cross(Vector3.UP)
	var outward = (f.fish.position-f.fisher.position).normalized()
	# Normal view observes coarse motion; Vision resolves body direction sooner.
	var direction = f.fish.heading if f.fisher.vision_active else f.fish.velocity.normalized()
	var side = direction.dot(right)
	if not f.fisher.vision_active: side = snappedf(clampf(side+rng.randf_range(-0.12,0.12),-1,1),0.5)
	var airborne = f.fish.position.y > f.fish.water_height
	if airborne: last_air_time = clock
	var falling = f.fish.velocity.y < -0.5 and (airborne or clock-last_air_time < 1)
	return {"speed":f.fish.velocity.length(),"jump_fall":falling,"side":side,"ascending":f.fish.velocity.y > 3,"descending":f.fish.velocity.y < -3 and not falling,"airborne":f.fish.position.y > f.fish.water_height,
		"outward_speed":f.fish.velocity.dot(outward),"tension":f.tension,"condition":f.spool.condition,
		"slack":f.spool.slack,"payout":f.spool.payout,"strength":f.spool.strength,
		"depth":snappedf(f.fish.water_height-f.fish.position.y,4),"line_out":f.spool.line_out,"capacity":f.spool.maximum_line_out,"drag":f.fisher.drag_setting,"distance":f.spool.distance}
func age() -> float:
	return clock-float(observation.get("sample_time",clock))
