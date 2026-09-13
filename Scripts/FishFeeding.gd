class_name FishFeeding
extends RefCounted
## FishPlayer calls this component once per physics tick. It never reads the camera.

signal ate_bait(bait)
var fish # Owning CharacterBody3D (a Node, so this does not form a RefCounted cycle).
var is_charging: bool = false
var cooldown_remaining: float = 0.0
var food: int = 0
var bait_eaten: int = 0
var last_meal: String = ""
var meal_notice_time: float = 0.0
var bite_flash: float = 0.0
var last_lunge_distance: float = 0.0
var dash_target: Vector3 = Vector3.FORWARD
var release_heading: Vector3 = Vector3.FORWARD
var _was_held: bool = false
var _charge_time: float = 0.0
var _dash_remaining: float = 0.0
var _trail_time: float = 0.0

func _init(owner_fish) -> void:
	fish = owner_fish

func charge_fraction() -> float:
	return clampf(_charge_time / maxf(0.01, fish.full_charge_time), 0.0, 1.0)

func is_dashing() -> bool:
	return _dash_remaining > 0.0

func update_attack(intent: FishInput, delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	meal_notice_time = maxf(0.0, meal_notice_time - delta)
	bite_flash = maxf(0.0, bite_flash - delta)
	if intent.cancel_bite:
		cancel_attack()
		return
	if not is_dashing() and cooldown_remaining <= 0.0 and intent.bite_held and not _was_held:
		is_charging = true
		_charge_time = 0.0
	if is_charging:
		if intent.bite_held:
			_charge_time = minf(maxf(0.01, fish.full_charge_time), _charge_time + delta)
		else:
			last_lunge_distance = lerpf(fish.minimum_lunge_distance, fish.maximum_lunge_distance, charge_fraction())
			_dash_remaining = maxf(0.1, last_lunge_distance)
			release_heading = fish.heading
			# Clamp once on release, then physically steer toward this fixed target.
			dash_target = FishInput.turn_toward(release_heading, intent.aim_direction,
				deg_to_rad(fish.maximum_lunge_turn_angle))
			is_charging = false
			_charge_time = 0.0
			_trail_time = 0.0
	_was_held = intent.bite_held

func advance_dash(delta: float) -> void:
	# Short substeps also keep curved high-speed sweeps close to the actual arc.
	var time_left = delta
	while time_left > 0.000001 and is_dashing():
		var dt = minf(time_left, 1.0 / 120.0)
		dt = minf(dt, _dash_remaining / maxf(1.0, fish.lunge_speed))
		var start: Vector3 = fish.global_position
		fish.heading = FishInput.turn_toward(fish.heading, dash_target, deg_to_rad(fish.lunge_turn_rate) * dt)
		fish.velocity = fish.heading * maxf(1.0, fish.lunge_speed)
		var step = fish.lunge_speed * dt
		var collision = fish.move_and_collide(fish.heading * step)
		sweep_bite(start, fish.global_position)
		_dash_remaining -= step
		time_left -= dt
		_trail_time -= dt
		if _trail_time <= 0.0:
			spawn_burst(fish.global_position - fish.heading * 0.8, Color("b7e8e2"), 3)
			_trail_time = 0.045
		if collision != null or _dash_remaining <= 0.001:
			_dash_remaining = 0.0
			cooldown_remaining = fish.bite_cooldown
			fish.velocity = Vector3.ZERO if collision != null else fish.heading * fish.swim_speed
			bite_flash = 0.16

func sweep_bite(from: Vector3, to: Vector3) -> int:
	if not is_dashing():
		return 0
	var count = 0
	for bait in fish.get_tree().get_nodes_in_group("bait"):
		if bait.claimed:
			continue
		var nearest = closest_point(from, to, bait.global_position)
		var radius = fish.bite_radius * fish.size_multiplier() + bait.hit_radius()
		if nearest.distance_squared_to(bait.global_position) > radius * radius:
			continue
		# Use the travelled segment, and reject nearby food on the far side of a rock.
		var ray = PhysicsRayQueryParameters3D.create(nearest, bait.global_position, 1)
		if not fish.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		if bait.try_bite(fish):
			count += 1
	return count

static func closest_point(from: Vector3, to: Vector3, point: Vector3) -> Vector3:
	var segment = to - from
	if segment.length_squared() < 0.000001:
		return from
	return from + segment * clampf((point - from).dot(segment) / segment.length_squared(), 0.0, 1.0)

func award_food(bait) -> void:
	food += bait.nutrition()
	bait_eaten += 1
	last_meal = "%s  +%d" % [bait.display_name().to_upper(), bait.nutrition()]
	meal_notice_time = 1.8
	bite_flash = 0.25
	fish.update_growth_collision()
	spawn_burst(bait.global_position, Color("f4d79d"), 10)
	ate_bait.emit(bait)

func spawn_burst(where: Vector3, color: Color, count: int) -> void:
	var burst = FeedingBurst.new()
	burst.position = where
	burst.tint = color
	burst.count = count
	fish.get_parent().add_child(burst)

func cancel_attack() -> void:
	is_charging = false
	_charge_time = 0.0
	if is_dashing():
		fish.velocity = Vector3.ZERO
	_dash_remaining = 0.0
	_was_held = false
