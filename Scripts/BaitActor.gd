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
@export var sink_speed: float = 1.0
@export var bottom_clearance: float = 0.32
@export_group("Escape and depth")
@export var flee_charge_time: float = 1.0
@export var flee_cooldown: float = 2.0
@export var minimum_flee_strength: float = 0.25
@export var maximum_flee_strength: float = 1.0
@export var dart_speed: float = 7.0
@export var shrimp_kick_speed: float = 5.0
@export var squid_jet_speed: float = 6.0
@export var crab_scuttle_speed: float = 5.5
@export var powered_descent_speed: float = 2.8
@export var breach_impulse: float = 8.5
@export var airborne_gravity: float = 6.5
@export var water_height: float = 32.0
@export var surface_depth: float = 0.45
var flee_remaining: float = 0.0
var flee_recovery: float = 0.0
var flee_velocity: Vector3 = Vector3.ZERO
var airborne: bool = false
var _breaching: bool = false
var _visual_pitch: float = 0.0
@export var minnow_escape_curve: float = 100.0
var _curve_side: float = 1.0
var driver: BaitMotion.IBaitDriver
var claimed: bool = false
var heading: Vector3 = Vector3.FORWARD
var visual: BaitVisual
var _eater
var _swallow: float = 0.0

func hit_radius() -> float:
	return [0.28, 0.28, 0.42, 0.38, 0.30, 0.32, 0.34][kind]

func nutrition() -> int:
	return [1, 2, 3, 2, 1, 1, 3][kind]

func display_name() -> String:
	return ["Minnow", "Shrimp", "Squid", "Crab", "Jerkbait", "Jig", "Mullet"][kind]

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 if kind == BaitMotion.Kind.MULLET else 1 | 8
	motion_mode = MOTION_MODE_FLOATING
	if swim_speed <= 0.0:
		swim_speed = [3.2, 3.0, 3.1, 1.5, 3.4, 3.0, 4.2][kind]
	if acceleration <= 0.0:
		acceleration = [4.5, 14.0, 6.0, 8.0, 11.0, 12.0, 6.0][kind]
	if turn_rate <= 0.0:
		turn_rate = [100.0, 250.0, 105.0, 180.0, 260.0, 220.0, 100.0][kind]
	var shape = SphereShape3D.new()
	shape.radius = hit_radius()
	var collision = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	visual = BaitVisual.new()
	visual.kind = kind
	add_child(visual)
	add_to_group("bait")
	if driver == null:
		driver = BaitMotion.LiveBaitDriver.new(global_position)

func _physics_process(delta: float) -> void:
	if claimed:
		return
	var command = driver.sample(self, delta)
	flee_recovery = maxf(0.0, flee_recovery - delta)
	if command.flee_fraction >= 0.0:
		start_flee(command.flee_fraction, command.direction)
	# Horizontal steering and vertical travel are independent. This same motor runs
	# AI and player bait, so neither can invent a different retrieve silhouette.
	var direction = BaitMotion.horizontal(command.direction)
	var bottom_kind = kind in [BaitMotion.Kind.CRAB, BaitMotion.Kind.JIG, BaitMotion.Kind.SHRIMP]
	var passive = command.action in [BaitMotion.Action.GLIDE, BaitMotion.Action.FALL, BaitMotion.Action.SINK, BaitMotion.Action.RISE]
	if kind != BaitMotion.Kind.CRAB and flee_remaining <= 0 and not airborne and command.direction.length_squared() > 0.001 and not command.action in [BaitMotion.Action.FALL, BaitMotion.Action.SINK, BaitMotion.Action.RISE]:
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
		target = BaitMotion.horizontal(heading) * 0.18
		target.y = -1.5 if passive else 2.0 * command.effort
		if command.action == BaitMotion.Action.JIG_UP: target.y = 4.5
	elif kind == BaitMotion.Kind.SHRIMP:
		target.y = -1.4
		target *= Vector3(0.55, 1, 0.55)
		if command.action == BaitMotion.Action.JIG_UP:
			target = BaitMotion.horizontal(heading) * 0.15 + Vector3.UP * 5.5
	elif kind == BaitMotion.Kind.CRAB:
		target = direction * (crab_scuttle_speed if command.action == BaitMotion.Action.DART else swim_speed) * command.effort
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
			flee_velocity = flee_velocity.rotated(Vector3.UP, _curve_side * deg_to_rad(minnow_escape_curve) * delta)
			heading = BaitMotion.horizontal(flee_velocity)
		velocity = flee_velocity
	else:
		velocity.x = move_toward(velocity.x, target.x, response * delta)
		velocity.z = move_toward(velocity.z, target.z, response * delta)
		velocity.y = move_toward(velocity.y, target.y, (6.0 if kind == BaitMotion.Kind.SQUID else 2.5 if passive else response) * delta)
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
	visual.rotation = Vector3(facing.x, facing.y, 0.0)
	visual.speed = velocity.length()
	visual.twitch = clampf(command.twitch, 0.0, 1.0)
	visual.action = command.action
	visual.idle_action = command.idle_action

func start_flee(fraction: float, away: Vector3) -> bool:
	if flee_recovery > 0.0 or airborne or _breaching: return false
	var strength = lerpf(minimum_flee_strength, maximum_flee_strength, clampf(fraction, 0, 1))
	flee_recovery = flee_cooldown
	flee_remaining = lerpf(0.16, 0.48, strength)
	var flat = BaitMotion.horizontal(away)
	_curve_side = 1.0 if BaitMotion.horizontal(heading).cross(flat).y > 0 else -1.0
	match kind:
		BaitMotion.Kind.SHRIMP:
			flee_velocity = (-BaitMotion.horizontal(heading) * 1.3 + flat * 0.8) * strength + Vector3.UP * shrimp_kick_speed * strength
			flee_remaining = lerpf(0.25, 0.65, strength)
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
	visual.scale = Vector3.ONE * maxf(0.01, 1.0 - _swallow / 0.22)
	if _swallow >= 0.22:
		queue_free()
