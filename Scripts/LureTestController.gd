class_name LureTestController
extends Node
## Development-only bridge from keyboard to FishingBaitDriver intent.

var fish
var lure: BaitActor
var driver: BaitMotion.FishingBaitDriver
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
	anchor_position = Vector3(0, anchor.y, -75)
	spawn_position = fish.global_position + Vector3(0, 2, -8)
	driver = BaitMotion.FishingBaitDriver.new(anchor_position)
	driver.pause_vertical_rate = -0.42
	driver.retrieve_vertical_influence = 0.12
	_spawn_lure(BaitMotion.Kind.MINNOW)
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
			KEY_Q:
				if active: driver.jerk_pressed = true
			KEY_E:
				if active: driver.jig_pressed = true
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
	_update_label()

func reset_lure() -> void:
	if not is_instance_valid(lure) or lure.claimed: return
	lure.global_position = spawn_position
	lure.velocity = Vector3.ZERO
	lure.heading = Vector3.FORWARD
	driver._impulse_time = 0.0
	driver.jerk_pressed = false
	driver.jig_pressed = false
	driver._travel_direction = Vector3.FORWARD
	driver.cast_direction = Vector3.FORWARD

func switch_lure() -> void:
	if not is_instance_valid(lure) or lure.claimed: return
	var next_kind = (int(lure.kind) + 1) % 6
	lure.queue_free()
	_spawn_lure(next_kind)

func _spawn_lure(kind: BaitMotion.Kind) -> void:
	lure = BaitActor.new()
	lure.name = "FishermanTestLure"
	lure.kind = kind
	lure.source = BaitMotion.Source.FISHERMAN
	lure.position = spawn_position
	lure.heading = Vector3.FORWARD
	driver._impulse_time = 0.0
	driver.jerk_pressed = false
	driver.jig_pressed = false
	driver._travel_direction = Vector3.FORWARD
	driver.cast_direction = Vector3.FORWARD
	lure.driver = driver
	lure.bitten.connect(_on_lure_bitten)
	bait_parent.add_child(lure)
	driver.pause_vertical_rate = [-0.03, -0.22, 0.0, -0.7, -0.08, -0.65][kind]
	_update_label()

func _on_lure_bitten(_bait, _eater) -> void:
	var kind = lure.kind
	await get_tree().create_timer(1.0).timeout
	_spawn_lure(kind)

func _physics_process(_delta: float) -> void:
	if not active:
		return
	driver.retrieve_input = Input.get_action_strength("forward")
	driver.steer_input = Input.get_axis("left", "right")

func _update_label() -> void:
	if mode_label == null:
		return
	var kind_name = lure.display_name() if is_instance_valid(lure) else "Respawning"
	mode_label.text = ("LURE TEST: %s  |  W retrieve  A/D steer  Q jerk  E jig  X species  F reset\n" % kind_name
		+ "Release W: drop/glide  |  C camera  |  Mouse orbit  |  TAB return to fish") if active else "TAB  bait control  |  C choose bait/fish camera"


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
