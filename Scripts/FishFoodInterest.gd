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
var stroke_time: float = 0
var stroke_side: float = 1
var rng = RandomNumberGenerator.new()
var prioritize_lures: bool = false
var charge_goal: float = 0.7
var commit_time: float = 0
@export var minimum_charge: float = 0.65
@export var maximum_charge: float = 0.85

func set_lure_priority(enabled: bool) -> void:
	prioritize_lures = enabled
	target = null
	state = State.WANDER
	scan_wait = 0

func intercept_direction(fish: FishPlayer, bait: BaitActor, remaining_charge: float) -> Vector3:
	# Predict through remaining wind-up plus dash travel, without changing physics.
	var travel = fish.position.distance_to(bait.position)/maxf(1,fish.effective_dash_speed())
	var predicted = bait.position
	for i in range(3):
		predicted = bait.position+bait.velocity*minf(2.0,remaining_charge+travel)
		travel = fish.position.distance_to(predicted)/maxf(1,fish.effective_dash_speed())
	return (predicted-fish.position).normalized()

@export var detection_radius: float = 45
func disengage() -> void:
	lure_reset = rng.randf_range(6,9)
	target = null
	state = State.WANDER
	wander_wait = 0
func eligible(bait: BaitActor, fish: FishPlayer) -> bool:
	return is_instance_valid(bait) and not bait.claimed and bait.lifecycle == BaitActor.Lifecycle.ALIVE and fish.size_multiplier() >= bait.minimum_eater_scale and (prioritize_lures or lure_reset <= 0 or not is_instance_valid(bait.fisher_owner))
func choose(fish: FishPlayer, candidates: Array) -> BaitActor:
	var chosen: BaitActor
	var score: float = INF
	for item in candidates:
		if not item is BaitActor or not eligible(item,fish): continue
		var distance = fish.position.distance_to(item.position)
		var lure = is_instance_valid(item.fisher_owner)
		if distance > detection_radius and not (prioritize_lures and lure): continue
		var interest = distance/(1.15 if is_instance_valid(item.fisher_owner) else 1.0)
		if prioritize_lures and lure: interest -= 100000
		if interest < score: chosen = item; score = interest
	return chosen
func input(fish: FishPlayer, candidates: Array, half_width: float, depth: float, delta: float) -> FishInput:
	lure_reset = maxf(0,lure_reset-delta)
	scan_wait -= delta
	wander_wait -= delta
	stroke_time += delta
	if stroke_time >= fish.motion.ideal_stroke_interval: stroke_time = 0; stroke_side *= -1
	if not eligible(target,fish): target = null; state = State.WANDER
	# A new cast can interrupt natural-prey interest while test priority is on.
	if prioritize_lures and scan_wait <= 0 and (not is_instance_valid(target) or not is_instance_valid(target.fisher_owner)):
		var preferred = choose(fish,candidates)
		if preferred != null and is_instance_valid(preferred.fisher_owner):
			scan_wait = 0.7
			target = preferred
			state = State.NOTICE
			notice_wait = 0.35
	if state == State.WANDER and scan_wait <= 0:
		scan_wait = rng.randf_range(0.6,1.0)
		target = choose(fish,candidates)
		if target != null:
			state = State.NOTICE
			notice_wait = rng.randf_range(0.7,1.5)
	if state == State.NOTICE:
		notice_wait -= delta
		if notice_wait <= 0: state = State.APPROACH
	if state in [State.APPROACH,State.COMMIT]:
		var distance = fish.position.distance_to(target.position)
		if distance > detection_radius*1.5 and not (prioritize_lures and is_instance_valid(target.fisher_owner)):
			target = null
			state = State.WANDER
		else:
			var direct = (target.position-fish.position).normalized()
			if state == State.APPROACH and distance < 14 and fish.heading.dot(direct) > 0.75:
				state = State.COMMIT
				charge_goal = rng.randf_range(minimum_charge,maximum_charge)
				commit_time = 0
			var remaining = maxf(0,charge_goal*fish.full_charge_time-fish.feeding._charge_time) if state == State.COMMIT else 0.0
			var aim = intercept_direction(fish,target,remaining)
			# Only weave on a distant approach. Coast while turning to avoid orbiting
			# a nearby target at a speed our legal turn rate cannot sustain.
			if state == State.APPROACH and distance > 18:
				aim = aim.rotated(Vector3.UP,deg_to_rad(12)*stroke_side)
			var alignment = fish.heading.dot(aim)
			var throttle = 0.85 if distance > 18 else lerpf(0.0,0.45,clampf((alignment-0.6)/0.4,0,1))
			var attack = FishInput.new(throttle,0,0,aim,false,false)
			if state == State.COMMIT:
				commit_time += delta
				if distance > 24 or fish.heading.dot(direct) < -0.1 or commit_time > fish.full_charge_time+1.0:
					attack.cancel_bite = true
					state = State.APPROACH
				elif fish.feeding.is_charging:
					# Hold the charge until both power and predicted heading are ready.
					attack.bite_held = fish.feeding.charge_fraction() < charge_goal or alignment < 0.94
					if not attack.bite_held: state = State.APPROACH
				elif not fish.feeding.is_dashing() and fish.feeding.cooldown_remaining <= 0:
					attack.bite_held = alignment > 0.8
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
