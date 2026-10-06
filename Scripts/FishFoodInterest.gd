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
var allow_lures: bool = true # Recording lead-in gate; natural bait remains eligible.
# Profile seam: keys are BaitMotion.Kind integers, with "lure" as an override.
var prey_weights: Dictionary = {}
var last_prey_kind: int = -1
var hotspot: FeedingHotspot
var commit_time: float = 0
var attack_reset: float = 0
var reset_course: Vector3 = Vector3.FORWARD
@export var attack_setup_distance: float = 12
@export var maximum_prediction: float = 0.55
@export var preferred_launch_distance: float = 7

func set_lure_priority(enabled: bool) -> void:
	prioritize_lures = enabled
	target = null
	state = State.WANDER
	scan_wait = 0

func intercept_direction(fish: FishPlayer, bait, remaining_charge: float) -> Vector3:
	return (intercept_point(fish,bait,remaining_charge)-fish.position).normalized()

func intercept_point(fish: FishPlayer, bait, remaining_charge: float = 0) -> Vector3:
	if not eligible(bait,fish): return fish.position+fish.heading
	# Short arrival prediction, shared by aim and current charged-reach comparison.
	var travel = fish.position.distance_to(bait.position)/maxf(1,fish.effective_dash_speed())
	var predicted = bait.position
	for i in range(3):
		predicted = bait.position+bait.velocity*minf(maximum_prediction,remaining_charge+travel)
		travel = fish.position.distance_to(predicted)/maxf(1,fish.effective_dash_speed())
	return predicted

@export var detection_radius: float = 45
func disengage() -> void:
	lure_reset = rng.randf_range(6,9)
	target = null
	state = State.WANDER
	wander_wait = 0
func eligible(bait, fish: FishPlayer) -> bool:
	return is_instance_valid(bait) and bait is BaitActor and not bait.claimed and bait.lifecycle == BaitActor.Lifecycle.ALIVE and (allow_lures or not is_instance_valid(bait.fisher_owner)) and fish.can_eat(bait) and (prioritize_lures or lure_reset <= 0 or not is_instance_valid(bait.fisher_owner))
func choose(fish: FishPlayer, candidates: Array) -> BaitActor:
	var chosen: BaitActor
	var score: float = INF
	for item in candidates:
		if not eligible(item,fish): continue
		var distance = fish.position.distance_to(item.position)
		var lure = is_instance_valid(item.fisher_owner)
		if distance > detection_radius*(1.6 if hotspot != null and hotspot.contains(item.position) else 1.0) and not (prioritize_lures and lure): continue
		# Modest reward/variety weighting prevents ubiquitous minnows always winning.
		var weight = float(prey_weights.get("lure" if lure else item.kind,1.0))
		weight *= 1.0+minf(0.75,item.nutrition()*0.15)
		if item.kind != last_prey_kind: weight *= 1.15
		var alignment = fish.heading.dot((item.position-fish.position).normalized())
		if hotspot != null and hotspot.contains(item.position): weight *= 1.45
		var interest = distance*(1+0.18*(1-alignment))/maxf(0.05,weight)
		if prioritize_lures and lure: interest -= 100000
		if interest < score: chosen = item; score = interest
	return chosen
func input(fish: FishPlayer, candidates: Array, half_width: float, depth: float, delta: float) -> FishInput:
	lure_reset = maxf(0,lure_reset-delta)
	attack_reset = maxf(0,attack_reset-delta)
	scan_wait -= delta
	wander_wait -= delta
	stroke_time += delta
	if stroke_time >= fish.motion.ideal_stroke_interval: stroke_time = 0; stroke_side *= -1
	if not eligible(target,fish): target = null; state = State.WANDER; attack_reset = 0; commit_time = 0
	# A new cast can interrupt natural-prey interest while test priority is on.
	if prioritize_lures and scan_wait <= 0 and (not is_instance_valid(target) or not is_instance_valid(target.fisher_owner)):
		var preferred = choose(fish,candidates)
		if eligible(preferred,fish) and is_instance_valid(preferred.fisher_owner):
			scan_wait = 0.7
			target = preferred
			state = State.NOTICE
			notice_wait = 0.35
	if state == State.WANDER and scan_wait <= 0:
		scan_wait = rng.randf_range(0.6,1.0)
		target = choose(fish,candidates)
		if eligible(target,fish):
			state = State.NOTICE
			notice_wait = rng.randf_range(0.7,1.5)
	if state == State.NOTICE:
		notice_wait -= delta
		if notice_wait <= 0: state = State.APPROACH
	if state in [State.APPROACH,State.COMMIT] and eligible(target,fish):
		var distance = fish.position.distance_to(target.position)
		if distance > detection_radius*1.5 and not (prioritize_lures and is_instance_valid(target.fisher_owner)):
			target = null
			state = State.WANDER
		else:
			var direct = (target.position-fish.position).normalized()
			var commit_reach = attack_setup_distance
			if attack_reset > 0:
				var reset = FishInput.new(0.7,0,0,reset_course,false,false)
				reset.cancel_bite = fish.feeding.is_charging
				return reset
			var radius = fish.velocity.length()/maxf(0.1,deg_to_rad(fish.forward_turn_rate))
			if distance < maxf(4,radius*1.5) and fish.heading.dot(direct) < 0.15:
				attack_reset = rng.randf_range(1.0,1.6)
				reset_course = fish.heading.rotated(Vector3.UP,deg_to_rad(20)*stroke_side)
				state = State.APPROACH
				var reset = FishInput.new(0.7,0,0,reset_course,false,false)
				reset.cancel_bite = true
				return reset
			if state == State.APPROACH and distance < commit_reach and fish.heading.dot(direct) > 0.8:
				state = State.COMMIT
				commit_time = 0
			var predicted = intercept_point(fish,target)
			var aim = (predicted-fish.position).normalized() if distance <= commit_reach else (target.position+target.velocity*0.12-fish.position).normalized()
			var alignment = fish.heading.dot(aim)
			# Course-relative sway preserves pursuit/wall avoidance; never rotate the
			# desired course around the current heading just to generate Drive.
			if state == State.APPROACH and distance > 18:
				aim = aim.rotated(Vector3.UP,deg_to_rad(12)*stroke_side)
			var attack = FishInput.new(0.9 if state == State.APPROACH else 0.85,0,0,aim,false,false)
			attack.overdrive = state == State.APPROACH and distance > 18 and fish.motion.swim_drive > 0.20
			if state == State.COMMIT:
				commit_time += delta
				if distance > commit_reach*1.5 or fish.heading.dot(direct) < -0.1 or commit_time > fish.full_charge_time+1.0:
					attack.cancel_bite = true
					state = State.APPROACH
				elif fish.feeding.is_charging:
					# Current charge determines reach; no preselected power percentage.
					var reach = lerpf(fish.minimum_lunge_distance,fish.maximum_lunge_distance,fish.feeding.charge_fraction())
					var remaining_distance = fish.position.distance_to(predicted)
					var closing_speed = (fish.velocity-target.velocity).dot(direct)
					var launch_distance = preferred_launch_distance+clampf(closing_speed*0.12,-1,1)+clampf(fish.size_multiplier()-1,0,2)
					var in_launch_zone = distance <= launch_distance or fish.feeding.charge_fraction() >= 1
					attack.bite_held = not (in_launch_zone and reach+fish.bite_radius*fish.size_multiplier() >= remaining_distance and alignment >= 0.88)
					if not attack.bite_held: state = State.APPROACH; last_prey_kind = target.kind
				elif not fish.feeding.is_dashing() and fish.feeding.cooldown_remaining <= 0:
					attack.bite_held = alignment > 0.65
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
	aim = aim.normalized().rotated(Vector3.UP,-stroke_side*deg_to_rad(24))
	var cruise = FishInput.new(cruise_throttle,stroke_side*0.65 if state == State.WANDER else 0,0,aim,false)
	cruise.cancel_bite = fish.feeding.is_charging
	return cruise
