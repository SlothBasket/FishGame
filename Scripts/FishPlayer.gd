class_name FishPlayer
extends CharacterBody3D
## Owns physical heading and velocity. Visual wiggles live below Visual/Body.

@export_group("Swimming")
@export var swim_speed: float = 8.0
@export var boost_multiplier: float = 1.85
@export var acceleration: float = 12.0
@export var water_drag: float = 4.0
@export_range(0.0, 1.0) var reverse_speed_multiplier: float = 0.4
@export var reverse_acceleration: float = 6.0
@export var vertical_speed_multiplier: float = 0.7
@export_group("Steering (degrees per second)")
@export var forward_turn_rate: float = 85.0
@export var pitch_turn_rate: float = 65.0
@export var manual_steering_strength: float = 125.0
@export var idle_pivot_multiplier: float = 0.45
@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export_group("Feeding")
@export var full_charge_time: float = 1.4
@export var minimum_lunge_distance: float = 3.0
@export var maximum_lunge_distance: float = 15.0
@export var lunge_speed: float = 26.0
@export var bite_cooldown: float = 0.45
@export_range(0.0, 179.0) var maximum_lunge_turn_angle: float = 65.0
@export var lunge_turn_rate: float = 220.0
@export var charge_swim_multiplier: float = 0.25
@export var bite_radius: float = 0.9
@export_group("Growth")
@export var growth_per_food: float = 0.01
@export var maximum_size: float = 1.6

var heading: Vector3 = Vector3.FORWARD
var external_input: bool = false
var command: FishInput = FishInput.new()
var boosting: bool = false
var feeding: FishFeeding
var suppress_bite_until_release: bool = false
var _spawn: Vector3
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.08
var _body_radius: float
@onready var pivot: Node3D = $CameraPivot
@onready var visual: FishVisual = $Visual
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

func _ready() -> void:
	_spawn = position
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate()
	_body_radius = $CollisionShape3D.shape.radius
	feeding = FishFeeding.new(self)
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"rise": KEY_SPACE, "dive": KEY_CTRL, "boost": KEY_SHIFT, "reset": KEY_R}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("bite"):
		InputMap.add_action("bite")
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("bite", event)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel_attack()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			suppress_bite_until_release = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw -= event.relative.x * mouse_sensitivity
		_camera_pitch = clampf(_camera_pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)
	if event.is_action_pressed("reset"):
		reset_fish()

func read_local_input() -> FishInput:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var cancelled = FishInput.new()
		cancelled.cancel_bite = true
		return cancelled
	if not Input.is_action_pressed("bite"):
		suppress_bite_until_release = false
	var intent = FishInput.new(Input.get_axis("back", "forward"), Input.get_axis("left", "right"),
		Input.get_axis("dive", "rise"), -pivot.global_basis.z, Input.is_action_pressed("boost"),
		Input.is_action_pressed("bite") and not suppress_bite_until_release)
	# Aim correction is useful for the bite; regular swimming follows camera direction.
	if feeding.is_charging:
		intent.aim_direction = aim_through_crosshair()
	return intent

func aim_through_crosshair() -> Vector3:
	var origin = camera.global_position
	var end = origin - camera.global_basis.z * 200.0
	var query = PhysicsRayQueryParameters3D.create(origin, end, 1 | 4)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", end)
	var direction = target - global_position
	return direction.normalized() if direction.dot(-pivot.global_basis.z) > 0.1 else -pivot.global_basis.z.normalized()

func _physics_process(delta: float) -> void:
	var intent = command if external_input else read_local_input()
	feeding.update_attack(intent, delta)
	boosting = intent.boost and intent.throttle > 0.0 and not feeding.is_charging and not feeding.is_dashing()
	if feeding.is_dashing():
		feeding.advance_dash(delta)
	else:
		heading = FishInput.steer_heading(heading, intent, forward_turn_rate, pitch_turn_rate,
			manual_steering_strength, idle_pivot_multiplier, delta)
		var swim = FishInput.new(intent.throttle, intent.steering, intent.vertical, intent.aim_direction, boosting)
		var speed = swim_speed * (charge_swim_multiplier if feeding.is_charging else 1.0)
		velocity = FishInput.next_velocity(velocity, heading, swim, speed, boost_multiplier,
			reverse_speed_multiplier, acceleration, reverse_acceleration, water_drag, vertical_speed_multiplier, delta)
		move_and_slide()
	# Heading, not velocity, owns facing. Backpedaling cannot flip the model.
	var facing = FishInput.angles(heading)
	visual.rotation = Vector3(facing.x, facing.y, 0.0)
	visual.scale = Vector3.ONE * size_multiplier()
	visual.swim_intensity = velocity.length() / maxf(0.1, swim_speed)
	visual.charge_intensity = feeding.charge_fraction()
	visual.biting = feeding.is_dashing() or feeding.bite_flash > 0.0
	var fov = 88.0 if feeding.is_dashing() else 67.0 if feeding.is_charging else 80.0 if boosting else 72.0
	camera.fov = lerpf(camera.fov, fov, 1.0 - exp(-6.0 * delta))

func size_multiplier() -> float:
	return minf(maximum_size, 1.0 + feeding.food * growth_per_food)

func mouth_position() -> Vector3:
	return global_position + heading * 1.25 * size_multiplier()

func update_growth_collision() -> void:
	$CollisionShape3D.shape.radius = _body_radius * size_multiplier()

func cancel_attack() -> void:
	if feeding != null:
		feeding.cancel_attack()
	suppress_bite_until_release = true

func reset_fish() -> void:
	cancel_attack()
	feeding.cooldown_remaining = 0.0
	position = _spawn
	velocity = Vector3.ZERO
	heading = Vector3.FORWARD
	visual.rotation = Vector3.ZERO
	_camera_yaw = 0.0
	_camera_pitch = -0.08
	pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_attack()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
