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
var driver: BaitMotion.IBaitDriver
var claimed: bool = false
var heading: Vector3 = Vector3.FORWARD
var visual: BaitVisual
var _eater
var _swallow: float = 0.0

func hit_radius() -> float:
	return [0.28, 0.28, 0.42, 0.38, 0.30, 0.32][kind]

func nutrition() -> int:
	return [1, 2, 3, 2, 1, 1][kind]

func display_name() -> String:
	return ["Minnow", "Shrimp", "Squid", "Crab", "Jerkbait", "Jig"][kind]

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	if swim_speed <= 0.0:
		swim_speed = [3.2, 3.0, 3.1, 1.5, 3.4, 3.0][kind]
	if acceleration <= 0.0:
		acceleration = [4.5, 14.0, 6.0, 8.0, 11.0, 12.0][kind]
	if turn_rate <= 0.0:
		turn_rate = [100.0, 250.0, 105.0, 180.0, 260.0, 220.0][kind]
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
	# Horizontal steering and vertical travel are independent. This same motor runs
	# AI and player bait, so neither can invent a different retrieve silhouette.
	var direction = BaitMotion.horizontal(command.direction)
	var bottom_kind = kind in [BaitMotion.Kind.CRAB, BaitMotion.Kind.JIG, BaitMotion.Kind.SHRIMP]
	var passive = command.action in [BaitMotion.Action.GLIDE, BaitMotion.Action.FALL, BaitMotion.Action.SINK, BaitMotion.Action.RISE]
	if command.direction.length_squared() > 0.001 and not command.action in [BaitMotion.Action.FALL, BaitMotion.Action.SINK, BaitMotion.Action.RISE]:
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
		target.y = -4.5
		if passive: target.x = 0.0; target.z = 0.0
		if command.action == BaitMotion.Action.JIG_UP:
			target = BaitMotion.horizontal(heading).cross(Vector3.UP) * 4.0 + Vector3.DOWN * 4.5
	velocity.x = move_toward(velocity.x, target.x, response * delta)
	velocity.z = move_toward(velocity.z, target.z, response * delta)
	# Vertical response remains visible even while forward momentum is decaying.
	velocity.y = move_toward(velocity.y, target.y, (6.0 if kind == BaitMotion.Kind.SQUID else 2.5 if passive else response) * delta)
	move_and_slide()
	if bottom_kind or passive:
		_apply_bottom_constraint(command.action == BaitMotion.Action.CRAWL or kind == BaitMotion.Kind.CRAB)
	var facing = FishInput.angles(heading)
	if kind == BaitMotion.Kind.CRAB:
		facing.x = 0.0
	visual.rotation = Vector3(facing.x, facing.y, 0.0)
	visual.speed = velocity.length()
	visual.twitch = clampf(command.twitch, 0.0, 1.0)
	visual.action = command.action
	visual.idle_action = command.idle_action

func _apply_bottom_constraint(stick_to_bottom: bool) -> void:
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 4.0, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var floor_y: float = hit.position.y + maxf(bottom_clearance, hit_radius() + 0.02)
	if global_position.y <= floor_y + (0.3 if stick_to_bottom else 0.0):
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
