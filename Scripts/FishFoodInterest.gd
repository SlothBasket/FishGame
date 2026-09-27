class_name FishFoodInterest
extends RefCounted
## Per-Fish simulated-time awareness and legal-input feeding. No actor writes.
enum State { WANDER, NOTICE, APPROACH, COMMIT }
var state: int = State.WANDER
var target: BaitActor
var notice_wait: float = 0
var scan_wait: float = 0
var wander_wait: float = 0
var lure_reset: float = 0
var cruise_throttle: float = 0.55
var course: Vector3 = Vector3.FORWARD
var curve_side: float = 1
var stroke_time: float = 0
var stroke_side: float = 1
var rng = RandomNumberGenerator.new()
@export var detection_radius: float = 45
func disengage() -> void:
	lure_reset = rng.randf_range(6,9)
	target = null
	state = State.WANDER
	wander_wait = 0
func eligible(bait: BaitActor, fish: FishPlayer) -> bool:
	return is_instance_valid(bait) and not bait.claimed and bait.lifecycle == BaitActor.Lifecycle.ALIVE and fish.size_multiplier() >= bait.minimum_eater_scale and (lure_reset <= 0 or not is_instance_valid(bait.fisher_owner))
func choose(fish: FishPlayer, candidates: Array) -> BaitActor:
	var chosen: BaitActor
	var score: float = INF
	for item in candidates:
		if not item is BaitActor or not eligible(item,fish): continue
		var distance = fish.position.distance_to(item.position)
		if distance > detection_radius: continue
		var interest = distance/(1.15 if is_instance_valid(item.fisher_owner) else 1.0)
		if interest < score: chosen = item; score = interest
	return chosen
func input(fish: FishPlayer, candidates: Array, half_width: float, depth: float, delta: float) -> FishInput:
	lure_reset = maxf(0,lure_reset-delta)
	scan_wait -= delta
	wander_wait -= delta
	stroke_time += delta
	if stroke_time >= fish.motion.ideal_stroke_interval: stroke_time = 0; stroke_side *= -1
	if not eligible(target,fish): target = null; state = State.WANDER
	if state == State.WANDER and scan_wait <= 0:
		scan_wait = rng.randf_range(0.6,1.0)
		target = choose(fish,candidates)
		if target != null:
			state = State.NOTICE
			notice_wait = rng.randf_range(0.7,1.5)
			curve_side = -1 if rng.randf() < 0.5 else 1
	if state == State.NOTICE:
		notice_wait -= delta
		if notice_wait <= 0: state = State.APPROACH
	if state in [State.APPROACH,State.COMMIT]:
		var distance = fish.position.distance_to(target.position)
		if distance > detection_radius*1.5: target = null; state = State.WANDER
		else:
			var direct = (target.position-fish.position).normalized()
			if distance < 8 and fish.heading.dot(direct) > 0.85: state = State.COMMIT
			var aim = (target.position+target.velocity*minf(0.4,distance/30)-fish.position).normalized()
			if state == State.APPROACH: aim = aim.rotated(Vector3.UP,deg_to_rad(14)*curve_side+deg_to_rad(16)*stroke_side)
			var attack = FishInput.new(0.55 if distance < 6 else 0.85,0,0,aim,false,false)
			if state == State.COMMIT:
				var aligned = fish.heading.dot(direct) > 0.92
				if fish.feeding.is_charging:
					attack.cancel_bite = not aligned or distance > 10
					attack.bite_held = not attack.cancel_bite and distance > 3 and fish.feeding._charge_time < 0.3
				else: attack.bite_held = aligned and distance < 7 and distance > 1
			return attack
	if wander_wait <= 0:
		wander_wait = rng.randf_range(2,4)
		cruise_throttle = rng.randf_range(0.4,0.7)
		course = fish.heading.rotated(Vector3.UP,rng.randf_range(-0.65,0.65))
		course.y = rng.randf_range(-0.2,0.2)
	var aim = course
	var ahead = fish.position+aim*18
	for axis in [0,2]:
		if absf(ahead[axis]) > half_width-10: aim[axis] = -signf(ahead[axis])*0.6
	if ahead.y < 3: aim.y = 0.35
	elif ahead.y > depth-3: aim.y = -0.3
	aim = aim.normalized().rotated(Vector3.UP,stroke_side*deg_to_rad(18))
	var cruise = FishInput.new(cruise_throttle,0,0,aim,fish.motion.swim_drive >= 0.9 and state == State.WANDER)
	cruise.cancel_bite = fish.feeding.is_charging
	return cruise
