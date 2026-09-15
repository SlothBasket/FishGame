class_name BaitActor
extends CharacterBody3D
## Both drivers obey this motor. The renderer never sees source (live/fisherman).

signal bitten(bait, eater)
@export var kind: BaitMotion.Kind = BaitMotion.Kind.MINNOW
@export var source: BaitMotion.Source = BaitMotion.Source.LIVE
# Zero selects a simple species default; override these before adding a bait.
@export var swim_speed: float = 0.0
@export var acceleration: float = 0.0
@export var turn_rate: float = 0.0 # degrees/sec, applies to both AI and controlled bait
@export var body_size: float = 0.8
@export var sink_speed: float = 1.0
@export var bottom_clearance: float = 0.32
@export_group("Escape and depth")
@export var flee_charge_time: float = 0.65
@export var flee_cooldown: float = 0.6
@export var minimum_flee_strength: float = 0.25
@export var maximum_flee_strength: float = 1.0
@export var dart_speed: float = 11.0
@export var shrimp_kick_speed: float = 5.0
@export var shrimp_glide_speed: float = 4.5
@export var shrimp_glide_duration: float = 1.1
var _shrimp_kick_duration: float = 0.4
var _escape_strength: float = 1.0
var _motion_age: float = 0.0
@export var squid_jet_speed: float = 6.0
@export var crab_scuttle_speed: float = 5.5
@export var powered_descent_speed: float = 2.8
@export var breach_impulse: float = 10.0
@export var airborne_gravity: float = 6.5
@export var water_height: float = 32.0
@export var surface_depth: float = 0.45
var flee_remaining: float = 0.0
var flee_recovery: float = 0.0
var flee_velocity: Vector3 = Vector3.ZERO
var airborne: bool = false
var _breaching: bool = false
var _visual_pitch: float = 0.0
@export var minnow_wiggle_speed: float = 2.2
@export var minnow_wiggle_frequency: float = 12.0
var _escape_axis: Vector3
var _escape_age: float = 0.0
var entry_remaining: float = 0.0
var cast_remaining: float = 0.0
var cast_gravity: float = 14.0
var cast_windup: float = 0.0
var cast_windup_duration: float = 0.28
var cast_origin: Vector3
var cast_launch_velocity: Vector3
@export var squid_roam_radius: float = 6.0
var floor_height: float = 0.0
var _floor_scan: float = 0.0
var cast_destination: Vector3
var _visual_yaw: float = 0.0
var _curve_side: float = 1.0
var driver: BaitMotion.IBaitDriver
var claimed: bool = false
var heading: Vector3 = Vector3.FORWARD
var visual: BaitVisual
var _eater
var _swallow: float = 0.0

func hit_radius() -> float:
	return [0.28, 0.28, 0.42, 0.38, 0.30, 0.32, 0.34, 0.55][kind] * body_size

func nutrition() -> int:
	return [1, 2, 3, 2, 1, 1, 3, 5][kind]

func display_name() -> String:
	return ["Minnow", "Shrimp", "Squid", "Crab", "Jerkbait", "Jig", "Mullet", "Seagull"][kind]

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 if kind in [BaitMotion.Kind.MULLET, BaitMotion.Kind.GULL] else 1 | 8
	motion_mode = MOTION_MODE_FLOATING
	if swim_speed <= 0.0:
		swim_speed = [3.2, 3.0, 3.1, 1.5, 3.4, 3.0, 4.2, 6.0][kind]
	if acceleration <= 0.0:
		acceleration = [4.5, 14.0, 6.0, 8.0, 11.0, 12.0, 6.0, 5.0][kind]
	if turn_rate <= 0.0:
		turn_rate = [100.0, 250.0, 105.0, 180.0, 260.0, 220.0, 100.0, 90.0][kind]
	var shape = SphereShape3D.new()
	shape.radius = hit_radius()
	var collision = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	visual = BaitVisual.new()
	visual.kind = kind
	add_child(visual)
	visual.scale = Vector3.ONE * body_size
	add_to_group("bait")
	if driver == null:
		driver = BaitMotion.LiveBaitDriver.new(global_position)

func _physics_process(delta: float) -> void:
	if claimed:
		return
	if cast_windup > 0:
		cast_windup = maxf(0, cast_windup - delta)
		var t = 1.0 - cast_windup / cast_windup_duration
		var back = -BaitMotion.horizontal(cast_destination - cast_origin)
		position = cast_origin + (back * 1.5 + Vector3.UP * 0.4) * sin(t * PI)
		if cast_windup <= 0:
			position = cast_origin
			velocity = cast_launch_velocity
		return
	if cast_remaining > 0:
		var dt = minf(delta, cast_remaining)
		position += velocity * dt + Vector3.DOWN * 0.5 * cast_gravity * dt * dt
		velocity.y -= cast_gravity * dt
		cast_remaining = maxf(0.0, cast_remaining - dt)
		if cast_remaining <= 0:
			position = cast_destination
			velocity = Vector3.DOWN * 4.0
			entry_remaining = 0.35
		return
	_floor_scan -= delta
	if kind == BaitMotion.Kind.SQUID and _floor_scan <= 0:
		_floor_scan = 0.25
		var ray = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, Vector3(global_position.x, -2, global_position.z), 1)
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		floor_height = hit.position.y if not hit.is_empty() else 0.0
	_motion_age += delta
	var command = driver.sample(self, delta)
	flee_recovery = maxf(0.0, flee_recovery - delta)
	if command.flee_fraction >= 0.0:
		start_flee(command.flee_fraction, command.direction)
	# Horizontal steering and vertical travel are independent. This same motor runs
	# AI and player bait, so neither can invent a different retrieve silhouette.
	var direction = BaitMotion.horizontal(command.direction)
	var bottom_kind = kind in [BaitMotion.Kind.CRAB, BaitMotion.Kind.JIG, BaitMotion.Kind.SHRIMP]
	var passive = command.action in [BaitMotion.Action.GLIDE, BaitMotion.Action.FALL, BaitMotion.Action.SINK, BaitMotion.Action.RISE]
	if flee_remaining <= 0 and not airborne and command.direction.length_squared() > 0.001 and not command.action in [BaitMotion.Action.FALL, BaitMotion.Action.SINK, BaitMotion.Action.RISE]:
		heading = FishInput.turn_toward(BaitMotion.horizontal(heading), direction, deg_to_rad(turn_rate) * delta)
	var target = BaitMotion.horizontal(heading) * swim_speed * command.effort
	var response = acceleration
	match command.action:
		BaitMotion.Action.CRUISE, BaitMotion.Action.BURST:
			target.y = swim_speed * 0.18 * command.effort
		BaitMotion.Action.GLIDE, BaitMotion.Action.FALL, BaitMotion.Action.SINK:
			target = BaitMotion.horizontal(heading) * swim_speed * 0.24
			target.y = -sink_speed * 0.65
			response = 1.8
		BaitMotion.Action.RISE:
			target.y = sink_speed * command.effort
		BaitMotion.Action.JERK, BaitMotion.Action.DART:
			# A short sideways kick, not a turn-limited copy of reeling.
			target = direction * swim_speed * 1.5
			target.y = 0.05
			response = 28.0
		BaitMotion.Action.JIG_UP:
			target = BaitMotion.horizontal(heading) * swim_speed * 0.18
			target.y = 2.8
			response = 24.0
	# Species profiles apply equally to human commands and AI commands.
	if kind == BaitMotion.Kind.SQUID:
		target = BaitMotion.horizontal(heading) * 0.45
		target.y = -1.5 if passive else 2.0 * command.effort * (0.2 + 0.8 * pow(maxf(0, sin(_motion_age * 4)), 2))
		if command.action == BaitMotion.Action.JIG_UP: target.y = 4.5
	elif kind == BaitMotion.Kind.SHRIMP:
		target.y = -1.4
		target *= Vector3(0.55, 1, 0.55)
		if command.action == BaitMotion.Action.JIG_UP:
			target = BaitMotion.horizontal(heading) * 0.15 + Vector3.UP * 5.5
	elif kind == BaitMotion.Kind.CRAB:
		target = (direction if command.action == BaitMotion.Action.DART else BaitMotion.horizontal(heading)) * (crab_scuttle_speed if command.action == BaitMotion.Action.DART else swim_speed) * command.effort
		target.y = -4.5
		if passive: target.x = 0.0; target.z = 0.0
		if command.action == BaitMotion.Action.JIG_UP:
			target = BaitMotion.horizontal(heading).cross(Vector3.UP) * 4.0 + Vector3.DOWN * 4.5
	if kind == BaitMotion.Kind.MULLET:
		target.y = clampf((water_height - surface_depth - global_position.y) * 2.0, -1.5, 2.5)
	if command.action == BaitMotion.Action.RISE and kind != BaitMotion.Kind.CRAB:
		target.y = powered_descent_speed * 0.7
	if command.descend and kind != BaitMotion.Kind.CRAB:
		target.y = -powered_descent_speed
	if command.arriving:
		target = command.arrival_velocity
		response = acceleration
	if airborne or _breaching:
		velocity.y -= airborne_gravity * delta
	elif flee_remaining > 0.0:
		if kind == BaitMotion.Kind.MINNOW:
			flee_velocity = _escape_axis * flee_velocity.dot(_escape_axis) + _escape_axis.cross(Vector3.UP) * sin(_escape_age * minnow_wiggle_frequency) * minnow_wiggle_speed
			heading = _escape_axis
		if kind == BaitMotion.Kind.SHRIMP:
			if _escape_age < _shrimp_kick_duration:
				flee_velocity = -_escape_axis * 0.65 * _escape_strength + Vector3.UP * shrimp_kick_speed * _escape_strength
			else:
				var glide = clampf((_escape_age - _shrimp_kick_duration) / shrimp_glide_duration, 0, 1)
				var glide_target = _escape_axis * shrimp_glide_speed * _escape_strength * lerpf(1.0, 0.45, glide)
				glide_target.y = lerpf(0.65, -0.9, glide)
				flee_velocity = flee_velocity.move_toward(glide_target, 22.0 * delta)
			heading = _escape_axis
		velocity = flee_velocity
	else:
		velocity.x = move_toward(velocity.x, target.x, response * delta)
		velocity.z = move_toward(velocity.z, target.z, response * delta)
		velocity.y = move_toward(velocity.y, target.y, (6.0 if kind == BaitMotion.Kind.SQUID else 2.5 if passive else response) * delta)
	_escape_age += delta
	if entry_remaining > 0.0:
		entry_remaining = maxf(0.0, entry_remaining - delta)
		velocity.y = minf(velocity.y, -2.5)
	if kind == BaitMotion.Kind.SQUID:
		# Ground protection also applies to player jets; collision cannot pin a downward escape.
		if global_position.y < floor_height + 0.65 and velocity.y < 0:
			velocity.y = 0
			flee_velocity.y = maxf(0, flee_velocity.y)
		if driver is BaitMotion.PlayerLiveDriver and driver.use_anchor:
			var offset = Vector3(global_position.x - driver.anchor_position.x, 0, global_position.z - driver.anchor_position.z)
			var radius = offset.length()
			if radius > squid_roam_radius - 0.6:
				var outward = offset.normalized()
				var radial_speed = velocity.dot(outward)
				if radial_speed > 0: velocity -= outward * radial_speed
				velocity -= outward * minf(3.0, maxf(0, radius - squid_roam_radius + 0.6) * 5.0)
	flee_remaining = maxf(0.0, flee_remaining - delta)
	move_and_slide()
	if kind == BaitMotion.Kind.MULLET:
		if global_position.y >= water_height: airborne = true
		if velocity.y < 0 and global_position.y < water_height:
			airborne = false
			_breaching = false
	if bottom_kind or passive:
		_apply_bottom_constraint(command.action == BaitMotion.Action.CRAWL or kind == BaitMotion.Kind.CRAB)
	var facing = FishInput.angles(heading)
	if kind == BaitMotion.Kind.CRAB:
		facing.x = 0.0
	if kind == BaitMotion.Kind.SQUID or kind == BaitMotion.Kind.MULLET:
		var desired_pitch = atan2(velocity.y, Vector2(velocity.x, velocity.z).length()) if velocity.length() > 0.15 else 0.0
		_visual_pitch = lerp_angle(_visual_pitch, desired_pitch, 1.0 - exp(-8.0 * delta))
		facing.x = _visual_pitch
		if Vector2(velocity.x, velocity.z).length() > 0.15:
			_visual_yaw = lerp_angle(_visual_yaw, FishInput.angles(velocity.normalized()).y, 1.0 - exp(-12.0 * delta))
		facing.y = _visual_yaw
	if kind == BaitMotion.Kind.SHRIMP:
		var pitch = -1.0 if flee_remaining > 0 and _escape_age < _shrimp_kick_duration else 0.0
		_visual_pitch = lerp_angle(_visual_pitch, pitch, 1.0-exp(-12.0*delta))
		facing.x = _visual_pitch
	visual.rotation = Vector3(facing.x, facing.y, 0.0)
	visual.speed = velocity.length()
	visual.twitch = maxf(clampf(command.twitch, 0.0, 1.0), 1.0 if flee_remaining > 0 else 0.0)
	visual.action = command.action
	visual.idle_action = command.idle_action

func start_flee(fraction: float, away: Vector3) -> bool:
	if flee_recovery > 0.0 or airborne or _breaching: return false
	var strength = lerpf(minimum_flee_strength, maximum_flee_strength, clampf(fraction, 0, 1))
	_escape_strength = strength
	flee_recovery = flee_cooldown
	flee_remaining = lerpf(0.16, 0.48, strength)
	var flat = BaitMotion.horizontal(away)
	_escape_axis = flat
	_escape_age = 0.0
	_curve_side = 1.0 if BaitMotion.horizontal(heading).cross(flat).y > 0 else -1.0
	match kind:
		BaitMotion.Kind.SHRIMP:
			# Body-relative kick then forward glide: identical for AI and human input.
			_escape_axis = BaitMotion.horizontal(heading)
			_shrimp_kick_duration = lerpf(0.22, 0.5, strength)
			flee_velocity = -_escape_axis * 0.65 * strength + Vector3.UP * shrimp_kick_speed * strength
			flee_remaining = _shrimp_kick_duration + shrimp_glide_duration
			flee_recovery = maxf(flee_cooldown, _shrimp_kick_duration + 0.12)
		BaitMotion.Kind.SQUID:
			flee_velocity = (away.normalized() if away.length() > 0.01 else Vector3.UP) * squid_jet_speed * strength
			flee_remaining = lerpf(0.3, 0.8, strength)
		BaitMotion.Kind.CRAB:
			var side = BaitMotion.horizontal(heading).cross(Vector3.UP)
			if side.dot(flat) < 0: side = -side
			flee_velocity = side * crab_scuttle_speed * strength + Vector3.DOWN * 4.5
		BaitMotion.Kind.MULLET:
			heading = BaitMotion.horizontal(BaitMotion.horizontal(heading) * 0.4 + flat * 0.6)
			velocity = heading * maxf(Vector2(velocity.x, velocity.z).length(), swim_speed * 0.7) + Vector3.UP * breach_impulse * strength
			_breaching = true
			flee_remaining = 0.0
		_:
			flee_velocity = flat * dart_speed * strength
	return true

func clear_actions() -> void:
	flee_remaining = 0.0
	flee_recovery = 0.0
	airborne = false
	_breaching = false
	velocity = Vector3.ZERO
	cast_remaining = 0.0
	cast_windup = 0.0
	entry_remaining = 0.0

func _apply_bottom_constraint(stick_to_bottom: bool) -> void:
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 4.0, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var floor_y: float = hit.position.y + maxf(bottom_clearance, hit_radius() + 0.02)
	if velocity.y <= 0 and global_position.y <= floor_y + (0.3 if stick_to_bottom else 0.0):
		global_position.y = floor_y
		velocity.y = 0.0

func try_bite(eater) -> bool:
	if claimed:
		return false
	claimed = true
	_eater = eater
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("bait")
	set_physics_process(false)
	if source == BaitMotion.Source.LIVE:
		eater.feeding.award_food(self)
	bitten.emit(self, eater)
	return true

func _process(delta: float) -> void:
	if not claimed:
		return
	_swallow += delta
	if is_instance_valid(_eater):
		global_position = global_position.lerp(_eater.mouth_position(), 1.0 - exp(-22.0 * delta))
	visual.scale = Vector3.ONE * body_size * maxf(0.01, 1.0 - _swallow / 0.22)
	if _swallow >= 0.22:
		queue_free()

func launch_cast(origin: Vector3, destination: Vector3, duration: float = 1.8) -> void:
	clear_actions()
	position = origin
	cast_destination = destination
	cast_remaining = maxf(0.2, duration)
	cast_origin = origin
	cast_launch_velocity = (destination - origin) / cast_remaining + Vector3.UP * cast_gravity * cast_remaining * 0.5
	cast_windup = cast_windup_duration
	velocity = Vector3.ZERO
