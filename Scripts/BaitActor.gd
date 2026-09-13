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
	# Action modifies intent within the same actor motor; drivers never bypass limits.
	if command.action in [BaitMotion.Action.SINK, BaitMotion.Action.FALL]:
		command.direction = (command.direction + Vector3.DOWN * sink_speed).normalized()
	elif command.action == BaitMotion.Action.RISE:
		command.direction = (command.direction + Vector3.UP * sink_speed).normalized()
	elif command.action == BaitMotion.Action.CRAWL:
		command.direction.y = 0.0
	if kind == BaitMotion.Kind.CRAB:
		# Bottom prey descend through the same limited motor until terrain is found.
		command.direction = (command.direction + Vector3.DOWN * sink_speed / maxf(0.1, swim_speed)).normalized()
	var bottom_kind = kind in [BaitMotion.Kind.CRAB, BaitMotion.Kind.JIG]
	if command.direction.length_squared() > 0.0001:
		heading = FishInput.turn_toward(heading, command.direction.normalized(), deg_to_rad(turn_rate) * delta)
	var target = heading * swim_speed * clampf(command.effort, 0.0, 1.0)
	velocity = velocity.move_toward(target, acceleration * delta)
	move_and_slide()
	if bottom_kind or command.action in [BaitMotion.Action.FALL, BaitMotion.Action.SINK]:
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
	var floor_y: float = hit.position.y + bottom_clearance
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
