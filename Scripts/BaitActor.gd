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
var driver: BaitMotion.IBaitDriver
var claimed: bool = false
var heading: Vector3 = Vector3.FORWARD
var visual: BaitVisual
var _eater
var _swallow: float = 0.0

func hit_radius() -> float:
	return 0.42 if kind == BaitMotion.Kind.SQUID else 0.28

func nutrition() -> int:
	return kind + 1

func display_name() -> String:
	return ["Minnow", "Shrimp", "Squid"][kind]

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	if swim_speed <= 0.0:
		swim_speed = [2.1, 2.6, 2.3][kind]
	if acceleration <= 0.0:
		acceleration = [5.0, 13.0, 5.0][kind]
	if turn_rate <= 0.0:
		turn_rate = [150.0, 260.0, 110.0][kind]
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
	if command.direction.length_squared() > 0.0001:
		heading = FishInput.turn_toward(heading, command.direction.normalized(), deg_to_rad(turn_rate) * delta)
	var target = heading * swim_speed * clampf(command.effort, 0.0, 1.0)
	velocity = velocity.move_toward(target, acceleration * delta)
	move_and_slide()
	var facing = FishInput.angles(heading)
	visual.rotation = Vector3(facing.x, facing.y, 0.0)
	visual.speed = velocity.length()
	visual.twitch = clampf(command.twitch, 0.0, 1.0)

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
