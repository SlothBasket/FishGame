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
@export var pursuit_stroke_degrees: float = 24
@export var minimum_attack_charge: float = 0.45

func set_lure_priority(enabled: bool) -> void:
	stop_hunting_drive()
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

@export var hunting_drive_start: float = 0.98
@export var hunting_drive_budget: float = 0.25
@export var hunting_drive_duration: float = 1.25
@export var hunting_drive_cooldown: float = 8.0
var hunting_drive_time: float = 0
var hunting_drive_wait: float = 0
var hunting_drive_spent: float = 0
var hunting_drive_target: BaitActor

@export var detection_radius: float = 45
func disengage() -> void:
	stop_hunting_drive()
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
	# A released lunge owns its trajectory. Pursuit must not cancel it merely
	# because the prey crosses beside/behind the fish partway through the sweep.
	if fish.feeding.is_dashing():
		stop_hunting_drive()
		return FishInput.new(1,0,0,fish.feeding.dash_target,false,false)
	hunting_drive_wait = maxf(0,hunting_drive_wait-delta)
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
				stop_hunting_drive()
				var reset = FishInput.new(0.7,0,0,reset_course,false,false)
				reset.cancel_bite = fish.feeding.is_charging
				return reset
			var radius = fish.velocity.length()/maxf(0.1,deg_to_rad(fish.forward_turn_rate))
			if distance < maxf(4,radius*1.5) and fish.heading.dot(direct) < 0.15:
				stop_hunting_drive()
				attack_reset = rng.randf_range(1.0,1.6)
				# Open turning room before reacquiring; choose the side toward the prey.
				var turn_side = signf(fish.heading.cross(direct).y)
				reset_course = fish.heading.rotated(Vector3.UP,deg_to_rad(35)*turn_side)
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
			if state == State.APPROACH:
				aim = aim.rotated(Vector3.UP,deg_to_rad(pursuit_stroke_degrees)*stroke_side)
			# Leave time to align during charging instead of rushing past the prey.
			var attack = FishInput.new(0.9 if state == State.APPROACH else 0.45,0,0,aim,false,false)
			attack.overdrive = hunting_overdrive(fish,distance,alignment,delta)
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
					attack.bite_held = not (in_launch_zone and fish.feeding.charge_fraction() >= minimum_attack_charge and reach+fish.bite_radius*fish.size_multiplier() >= remaining_distance and launch_aligned(fish,predicted,target.hit_radius()))
					if not attack.bite_held: state = State.APPROACH; last_prey_kind = target.kind
				elif not fish.feeding.is_dashing() and fish.feeding.cooldown_remaining <= 0:
					attack.bite_held = alignment > 0.65
			return attack

	stop_hunting_drive()
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

func stop_hunting_drive() -> void:
	if hunting_drive_target != null:
		hunting_drive_wait = maxf(hunting_drive_wait,hunting_drive_cooldown)
	hunting_drive_time = 0
	hunting_drive_target = null

func hunting_overdrive(fish: FishPlayer, distance: float, alignment: float, delta: float) -> bool:
	var allowed = state == State.APPROACH and not fish.feeding.is_charging and not fish.feeding.is_dashing() and fish.motion.drive_lockout <= 0 and fish.motion.counter_recovery <= 0
	if hunting_drive_target != null:
		hunting_drive_time -= delta
		if not allowed or target != hunting_drive_target or not is_instance_valid(target) or distance <= 14 or alignment < 0.6 or hunting_drive_time <= 0 or fish.motion.drive_spent-hunting_drive_spent >= hunting_drive_budget or fish.motion.swim_drive <= 0.05:
			stop_hunting_drive()
		else: return true
	# Bank passive Drive until there is both enough fuel and useful straight approach room.
	# Passive full Drive is the default cruise. Spend only when prey is actually
	# outrunning normal pursuit, with space left to settle before the attack.
	var needs_chase = is_instance_valid(target) and target.velocity.dot((target.position-fish.position).normalized()) > fish.effective_swim_speed()*0.8
	if allowed and needs_chase and hunting_drive_wait <= 0 and distance > 30 and alignment >= 0.95 and fish.motion.swim_drive >= hunting_drive_start:
		hunting_drive_target = target
		hunting_drive_spent = fish.motion.drive_spent
		hunting_drive_time = hunting_drive_duration
		return true
	return false

func launch_aligned(fish: FishPlayer, predicted: Vector3, prey_radius: float) -> bool:
	var offset = predicted-fish.position
	var along = offset.dot(fish.heading)
	if along <= 0: return false
	# Account for sideways momentum while the shared dash motor accelerates.
	var lateral_velocity = fish.velocity-fish.heading*fish.velocity.dot(fish.heading)
	var settle_time = minf(0.3,lateral_velocity.length()/maxf(1,fish.lunge_acceleration))
	var miss = offset-fish.heading*along-lateral_velocity*settle_time*0.5
	var tolerance = (fish.bite_radius*fish.size_multiplier()+prey_radius)*0.7
	return miss.length() <= tolerance
