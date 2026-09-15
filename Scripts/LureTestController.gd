class_name LureTestController
extends Node
## Development-only bridge from keyboard to FishingBaitDriver intent.

var fish
var lure: BaitActor
var driver: BaitMotion.FishingBaitDriver
var live_driver: BaitMotion.PlayerLiveDriver
@export var cast_distance: float = 65.0
@export var cast_distance_variation: float = 0.22
@export var cast_angle_variation: float = 0.3
@export var cast_entry_speed: float = 4.0
@export var origin_move_speed: float = 12.0
var boat: Node3D
var selected_kind: int = BaitMotion.Kind.MINNOW
var active: bool = false
var anchor_position: Vector3
var spawn_position: Vector3
var mode_label: Label
var bait_parent: Node3D
var bait_camera: Camera3D
var camera_focus: Vector3
var use_fish_camera: bool = false
var orbit_yaw: float = 0.93
var orbit_pitch: float = 0.38
var orbit_distance: float = 10.8

func setup(owner_fish, parent: Node3D, anchor: Vector3) -> void:
	fish = owner_fish
	fish.add_to_group("fish_predators")
	bait_parent = parent
	anchor_position = Vector3(90.0, anchor.y + 1.0, 75.0)
	spawn_position = fish.global_position + Vector3(0, 2, -8)
	driver = BaitMotion.FishingBaitDriver.new(anchor_position)
	driver.pause_vertical_rate = -0.42
	driver.retrieve_vertical_influence = 0.12
	# No stray test lure is spawned until the player enters bait mode.
	boat = Node3D.new()
	boat.name = "TestBoat"
	parent.add_child(boat)
	boat.position = anchor_position
	Geometry.sphere(boat, "Hull", Vector3(0, -0.45, 0), Vector3(1.4, 0.6, 2.8), Geometry.material("58473c"))
	Geometry.sphere(boat, "Rim", Vector3.ZERO, Vector3(1.5, 0.14, 2.8), Geometry.material("bfaa85"))
	boat.visible = false
	_make_label(parent)
	bait_camera = Camera3D.new()
	bait_camera.fov = 52
	parent.add_child(bait_camera)
	camera_focus = spawn_position

func _make_label(parent: Node) -> void:
	var layer = CanvasLayer.new()
	parent.add_child(layer)
	mode_label = Label.new()
	mode_label.position = Vector2(40, 140)
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_label.add_theme_color_override("font_color", Color("efc581"))
	layer.add_child(mode_label)
	_update_label()

func _input(event: InputEvent) -> void:
	if active and not use_fish_camera and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		orbit_mouse(event.relative)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB: set_active(not active)
			KEY_C: toggle_camera()
			KEY_G:
				if active: cast_bait()
			KEY_F:
				if active: reset_lure()
			KEY_X:
				if active: switch_lure()
func set_active(value: bool) -> void:
	active = value
	# Freeze player intent while testing the lure; camera remains available for viewing.
	fish.external_input = active
	if active:
		fish.command = FishInput.new()
		boat.visible = true
		if not is_instance_valid(lure): _spawn_lure(selected_kind)
		fish.velocity = Vector3.ZERO
		reset_lure()
		camera_focus = spawn_position
		bait_camera.position = camera_focus + Vector3(8, 4, 6)
		bait_camera.look_at(camera_focus)
		_select_camera()
	else:
		fish.external_input = false
		fish.camera.make_current()
		driver.retrieve_input = 0.0
		driver.escape_held = false
		driver._escape_was_held = false
		driver._escape_charge = 0.0
		driver.pending_fraction = -1.0
		if live_driver != null:
			live_driver.throttle = 0.0
			live_driver.descend = false
			live_driver.rise = false
			live_driver.escape_held = false
			live_driver._held = false
			live_driver.charge = 0.0
			live_driver._pending_escape = null
	_update_label()

func reset_lure() -> void:
	if not is_instance_valid(lure) or lure.claimed: return
	lure.global_position = deployment_position()
	lure.clear_actions()
	if live_driver != null:
		live_driver.charge = 0.0
		live_driver._pending_escape = null
		live_driver._held = false
		live_driver.escape_held = false
	lure.heading = BaitMotion.horizontal(anchor_position - spawn_position)
	driver._impulse_time = 0.0
	driver._escape_charge = 0.0
	driver.pending_fraction = -1.0
	driver._escape_was_held = false
	driver.escape_held = false
	driver.jerk_pressed = false
	driver.jig_pressed = false
	driver._travel_direction = Vector3.FORWARD
	driver.cast_direction = BaitMotion.horizontal(anchor_position - spawn_position)

func switch_lure() -> void:
	if not is_instance_valid(lure) or lure.claimed: return
	var next_kind = (int(lure.kind) + 1) % 7
	lure.queue_free()
	_spawn_lure(next_kind)

func _spawn_lure(kind: BaitMotion.Kind) -> void:
	lure = BaitActor.new()
	lure.name = "FishermanTestLure"
	lure.kind = kind
	selected_kind = kind
	lure.water_height = anchor_position.y
	lure.source = BaitMotion.Source.LIVE if is_live_selection() else BaitMotion.Source.FISHERMAN
	lure.position = deployment_position()
	lure.heading = BaitMotion.horizontal(anchor_position - spawn_position)
	driver._impulse_time = 0.0
	driver._escape_charge = 0.0
	driver.pending_fraction = -1.0
	driver._escape_was_held = false
	driver.escape_held = false
	driver.jerk_pressed = false
	driver.jig_pressed = false
	driver._travel_direction = Vector3.FORWARD
	driver.cast_direction = BaitMotion.horizontal(anchor_position - spawn_position)
	live_driver = BaitMotion.PlayerLiveDriver.new()
	live_driver.squid_axis = BaitMotion.horizontal(-anchor_position)
	live_driver.use_anchor = true
	live_driver.anchor_position = anchor_position
	lure.driver = live_driver if is_live_selection() else driver
	lure.bitten.connect(_on_lure_bitten)
	bait_parent.add_child(lure)
	driver.pause_vertical_rate = -0.4
	_update_label()

func _on_lure_bitten(_bait, _eater) -> void:
	var kind = lure.kind
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(lure): _spawn_lure(kind)

func is_live_selection() -> bool:
	return selected_kind not in [BaitMotion.Kind.JERKBAIT, BaitMotion.Kind.JIG]

func _physics_process(delta: float) -> void:
	if not active: return
	if is_instance_valid(lure) and (lure.cast_windup > 0 or lure.cast_remaining > 0): return
	var moving_origin = Input.is_physical_key_pressed(KEY_ALT)
	if moving_origin:
		var move = Vector3(Input.get_axis("left", "right"), 0, Input.get_axis("forward", "back"))
		move_origin(move, delta)
		driver._escape_was_held = false
		driver._escape_charge = 0.0
		driver.pending_fraction = -1.0
	driver.retrieve_input = 0.0 if moving_origin else Input.get_action_strength("forward")
	driver.steer_input = 0.0 if moving_origin else Input.get_axis("left", "right")
	driver.escape_held = not moving_origin and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if live_driver != null:
		live_driver.throttle = driver.retrieve_input
		live_driver.steering = driver.steer_input
		live_driver.descend = not moving_origin and Input.is_physical_key_pressed(KEY_CTRL)
		live_driver.rise = not moving_origin and Input.is_physical_key_pressed(KEY_SPACE)
		if moving_origin:
			live_driver._held = false
			live_driver.charge = 0.0
			live_driver._pending_escape = null
		live_driver.escape_held = not moving_origin and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		live_driver.escape_side = -1.0 if driver.steer_input < 0 else 1.0
	_update_label()

func cast_bait() -> void:
	var cast_direction = BaitMotion.horizontal(-anchor_position).rotated(Vector3.UP, randf_range(-cast_angle_variation, cast_angle_variation))
	var distance = cast_distance * randf_range(1.0 - cast_distance_variation, 1.0 + cast_distance_variation)
	spawn_position = anchor_position + cast_direction * distance
	spawn_position.x = clampf(spawn_position.x, -110, 110)
	spawn_position.z = clampf(spawn_position.z, -110, 110)
	spawn_position.y = anchor_position.y - 0.45
	if is_instance_valid(lure): lure.queue_free()
	_spawn_lure(selected_kind)
	lure.launch_cast(anchor_position + Vector3.UP * 0.7, deployment_position(), 0.55 if selected_kind == BaitMotion.Kind.SQUID else 1.8)

func deployment_position() -> Vector3:
	return Vector3(anchor_position.x, anchor_position.y - 1.0, anchor_position.z) if selected_kind == BaitMotion.Kind.SQUID else spawn_position

func _update_label() -> void:
	if mode_label == null:
		return
	var kind_name = lure.display_name() if is_instance_valid(lure) else "Respawning"
	mode_label.text = ("LURE TEST: %s  |  W retrieve  A/D steer  LMB charge escape  X species  F reset\n" % kind_name
		+ "Live: hold/release LMB escape, A/D direction, CTRL descend, SPACE rise | Lure: hold/release LMB escape\nALT+WASD boat | G cast | C camera | Mouse orbit | TAB fish") if active else "TAB  bait control  |  C choose bait/fish camera"
	if active and live_driver != null and is_live_selection() and is_instance_valid(lure):
		mode_label.text += "\nEscape charge: %d%%  Recovery: %.1fs" % [100 * live_driver.charge / lure.flee_charge_time, lure.flee_recovery]


func _process(delta: float) -> void:
	if not active or not is_instance_valid(lure): return
	camera_focus = camera_focus.lerp(lure.global_position, 1.0 - exp(-5.0 * delta))
	# Fixed world angle makes rise/fall and sideways darts readable without rolling.
	var offset = Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
	bait_camera.global_position = camera_focus + offset
	bait_camera.look_at(camera_focus + Vector3.FORWARD * 0.7)

func toggle_camera() -> void:
	use_fish_camera = not use_fish_camera
	if active: _select_camera()
	_update_label()

func _select_camera() -> void:
	if use_fish_camera: fish.camera.make_current()
	else: bait_camera.make_current()

func orbit_mouse(relative: Vector2) -> void:
	orbit_yaw -= relative.x * 0.004
	orbit_pitch = clampf(orbit_pitch + relative.y * 0.004, -0.65, 1.25)



func move_origin(direction: Vector3, delta: float) -> void:
	anchor_position += Vector3(direction.x, 0, direction.z).limit_length() * origin_move_speed * delta
	anchor_position.x = clampf(anchor_position.x, -105, 105)
	anchor_position.z = clampf(anchor_position.z, -105, 105)
	boat.position = anchor_position
	driver.anchor_position = anchor_position
	if live_driver != null: live_driver.anchor_position = anchor_position
	driver.cast_direction = BaitMotion.horizontal(anchor_position - lure.global_position) if is_instance_valid(lure) else Vector3.FORWARD
