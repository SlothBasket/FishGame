class_name LureTestController
extends Node
## Development controls: fish view, bait view, or boat setup before a cast.
const ROSTER = [BaitMotion.Kind.MINNOW, BaitMotion.Kind.SHRIMP, BaitMotion.Kind.SQUID, BaitMotion.Kind.CRAB, BaitMotion.Kind.MULLET]
@export var cast_distance: float = 65.0
@export var cast_distance_variation: float = 0.22
@export var cast_angle_variation: float = 0.12
@export var origin_move_speed: float = 12.0
@export var orbit_distance: float = 10.8
var reel_speed = ReelSpeed.new()
var fish
var bait_parent: Node3D
var lure: BaitActor
var live_driver: BaitMotion.PlayerLiveDriver
var boat: Node3D
var bait_camera: Camera3D
var mode_label: Label
var selected_kind: int = BaitMotion.Kind.MINNOW
var active: bool = false
var boat_aiming: bool = false
var anchor_position: Vector3
var spawn_position: Vector3
var camera_focus: Vector3
var use_fish_camera: bool = false
var orbit_yaw: float = 0.93
var orbit_pitch: float = 0.38
var arena_half_width: float = 132.0
var boat_yaw: float = 0.0
var boat_pitch: float = -0.12

func setup(owner_fish, parent: Node3D, anchor: Vector3) -> void:
	fish = owner_fish
	fish.add_to_group("fish_predators")
	bait_parent = parent
	arena_half_width = parent.arena_width*0.5
	anchor_position = Vector3(90, anchor.y + 1, 75)
	spawn_position = fish.global_position + Vector3(0,2,-8)
	boat_yaw = FishInput.angles(BaitMotion.horizontal(-anchor_position)).y
	boat = Node3D.new()
	boat.name = "TestBoat"
	parent.add_child(boat)
	boat.position = anchor_position
	Geometry.sphere(boat, "Hull", Vector3(0,-0.45,0), Vector3(1.4,0.6,2.8), Geometry.material("58473c"))
	Geometry.sphere(boat, "Rim", Vector3.ZERO, Vector3(1.5,0.14,2.8), Geometry.material("bfaa85"))
	boat.visible = false
	bait_camera = Camera3D.new()
	bait_camera.fov = 52
	parent.add_child(bait_camera)
	camera_focus = spawn_position
	var layer = CanvasLayer.new()
	parent.add_child(layer)
	mode_label = Label.new()
	mode_label.position = Vector2(40,140)
	mode_label.add_theme_font_size_override("font_size",16)
	mode_label.add_theme_color_override("font_color",Color("efc581"))
	layer.add_child(mode_label)
	_update_label()

func _input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if boat_aiming:
			boat_yaw -= event.relative.x * 0.004
			boat_pitch = clampf(boat_pitch - event.relative.y * 0.004, -0.6, 0.65)
		elif not use_fish_camera: orbit_mouse(event.relative)
		else: return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("cast"): cast_bait()
	if event.is_action_pressed("bait_mode"): set_active(not active)
	if event.is_action_pressed("bait_camera"): toggle_camera()
	if event.is_action_pressed("bait_reset") and active and not boat_aiming: reset_lure()
	if event.is_action_pressed("bait_species") and active: switch_lure()
	if event.is_action_pressed("reel_up"): reel_speed.step(1)
	if event.is_action_pressed("reel_down"): reel_speed.step(-1)

func freeze_fish() -> void:
	fish.external_input = true
	fish.cancel_attack()
	fish.command = FishInput.new()
	fish.velocity = Vector3.ZERO

func set_active(value: bool) -> void:
	active = value
	boat_aiming = false
	if active:
		freeze_fish()
		boat.visible = true
		if not is_instance_valid(lure): _spawn_lure(selected_kind)
		reset_lure()
		camera_focus = lure.global_position
		_select_camera()
	else:
		fish.external_input = false
		fish.camera.make_current()
		if live_driver != null: live_driver.clear_input()
	_update_label()

func deployment_position() -> Vector3:
	return Vector3(anchor_position.x, anchor_position.y-1, anchor_position.z) if selected_kind == BaitMotion.Kind.SQUID else spawn_position

func reset_lure() -> void:
	if not is_instance_valid(lure) or lure.claimed: return
	lure.global_position = deployment_position()
	lure.clear_actions()
	live_driver.clear_input()
	lure.heading = BaitMotion.horizontal(anchor_position-lure.global_position)

func _spawn_lure(kind: int) -> void:
	assert(kind in ROSTER)
	selected_kind = kind
	lure = BaitActor.new()
	lure.name = "FishermanTestBait"
	lure.kind = kind
	lure.arena_half_width = arena_half_width
	var size_rng = RandomNumberGenerator.new()
	size_rng.randomize()
	lure.randomize_size(size_rng)
	lure.water_height = anchor_position.y
	lure.position = deployment_position()
	lure.heading = BaitMotion.horizontal(anchor_position-lure.position)
	live_driver = BaitMotion.PlayerLiveDriver.new()
	live_driver.use_anchor = true
	live_driver.anchor_position = anchor_position
	live_driver.squid_axis = Vector3.FORWARD.rotated(Vector3.UP,boat_yaw)
	lure.driver = live_driver
	lure.bitten.connect(_on_lure_bitten)
	bait_parent.add_child(lure)
	_update_label()

func _on_lure_bitten(_bait, _eater) -> void:
	await get_tree().create_timer(1).timeout
	if active and not boat_aiming and not is_instance_valid(lure): _spawn_lure(selected_kind)

func switch_lure() -> void:
	selected_kind = ROSTER[(ROSTER.find(selected_kind)+1) % ROSTER.size()]
	if not boat_aiming:
		if is_instance_valid(lure): lure.queue_free()
		_spawn_lure(selected_kind)
	_update_label()

func cast_bait() -> void:
	# First press enters boat setup from either fish or bait mode. Second press launches.
	if not boat_aiming:
		active = true
		boat_aiming = true
		freeze_fish()
		boat.visible = true
		if is_instance_valid(lure): lure.queue_free()
		lure = null
		bait_camera.make_current()
		_update_label()
		return
	var aim = Vector3.FORWARD.rotated(Vector3.UP,boat_yaw)
	var direction = aim.rotated(Vector3.UP,randf_range(-cast_angle_variation,cast_angle_variation))
	var distance = cast_distance * randf_range(1-cast_distance_variation,1+cast_distance_variation)
	# Shorten a cast at the walls without rotating it away from the player's aim.
	for axis in [0,2]:
		if absf(direction[axis]) > 0.001:
			var edge = arena_half_width-10 if direction[axis] > 0 else -arena_half_width+10
			distance = minf(distance,maxf(0,(edge-anchor_position[axis])/direction[axis]))
	spawn_position = anchor_position + direction * distance
	spawn_position.y -= 0.45
	boat_aiming = false
	_spawn_lure(selected_kind)
	lure.launch_cast(anchor_position + Vector3.UP*0.7,deployment_position(),0.55 if selected_kind == BaitMotion.Kind.SQUID else 1.8)
	camera_focus = anchor_position
	_select_camera()

func _physics_process(delta: float) -> void:
	if not active: return
	if boat_aiming:
		var forward = Vector3.FORWARD.rotated(Vector3.UP,boat_yaw)
		move_origin(forward*Input.get_axis("back","forward") + forward.cross(Vector3.UP)*Input.get_axis("left","right"),delta)
		return
	if not is_instance_valid(lure) or lure.claimed or lure.cast_windup > 0 or lure.cast_remaining > 0: return
	if reel_speed.retrieve(Input.is_action_pressed("retrieve"),Input.get_action_strength("retrieve_trigger")) > 0 and lure.global_position.distance_to(anchor_position - Vector3.UP*0.65) < 1.2:
		cast_bait()
		return
	live_driver.throttle = reel_speed.retrieve(Input.is_action_pressed("retrieve"),Input.get_action_strength("retrieve_trigger"))
	live_driver.steering = Input.get_axis("left","right")
	live_driver.rise = Input.is_action_pressed("rise")
	live_driver.descend = Input.is_action_pressed("dive")
	live_driver.aim_direction = current_dash_aim()
	live_driver.escape_held = Input.is_action_pressed("bite")
	_update_label()

func move_origin(direction: Vector3, delta: float) -> void:
	anchor_position += Vector3(direction.x,0,direction.z).limit_length()*origin_move_speed*delta
	anchor_position.x = clampf(anchor_position.x,-arena_half_width+15,arena_half_width-15)
	anchor_position.z = clampf(anchor_position.z,-arena_half_width+15,arena_half_width-15)
	boat.position = anchor_position
	if live_driver != null: live_driver.anchor_position = anchor_position

func _process(delta: float) -> void:
	if not active: return
	var look = GameControls.look() * 2.2 * delta
	if boat_aiming:
		boat_yaw -= look.x
		boat_pitch = clampf(boat_pitch-look.y,-0.6,0.65)
	elif not use_fish_camera: orbit_mouse(look / 0.004)
	if boat_aiming:
		var forward = Vector3.FORWARD.rotated(Vector3.UP,boat_yaw)
		boat.rotation.y = boat_yaw
		bait_camera.position = anchor_position + Vector3.UP*1.8 - forward
		bait_camera.look_at(bait_camera.position + forward*10 + Vector3.UP*tan(boat_pitch)*10)
		return
	if not is_instance_valid(lure): return
	camera_focus = camera_focus.lerp(lure.global_position,1-exp(-5*delta))
	var offset = Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_distance
	bait_camera.position = camera_focus + offset
	bait_camera.look_at(camera_focus + Vector3.FORWARD*0.7)

func current_dash_aim() -> Vector3:
	return -(fish.camera if use_fish_camera else bait_camera).global_basis.z.normalized()

func orbit_mouse(relative: Vector2) -> void:
	orbit_yaw -= relative.x*0.004
	var limit = 1.52 if selected_kind == BaitMotion.Kind.SQUID else 1.25
	orbit_pitch = clampf(orbit_pitch+relative.y*0.004,-limit if selected_kind == BaitMotion.Kind.SQUID else -0.65,limit)

func toggle_camera() -> void:
	if boat_aiming: return
	use_fish_camera = not use_fish_camera
	if active: _select_camera()

func _select_camera() -> void:
	if use_fish_camera: fish.camera.make_current()
	else: bait_camera.make_current()

func _update_label() -> void:
	if mode_label == null: return
	if boat_aiming:
		mode_label.text = "BOAT: WASD move | Mouse aim | G cast | X species | TAB fish\nSelected: %s" % BaitMotion.Kind.keys()[selected_kind].capitalize()
	elif active:
		mode_label.text = "BAIT: W reel | A/D steer | Hold/release LMB escape | X species | G boat setup | C camera | TAB fish"
		if selected_kind == BaitMotion.Kind.SQUID:
			mode_label.text += "\nSQUID: Mouse aims dash | SPACE up jet | CTRL down jet | W slow reel | elastic line"
		mode_label.text += "\nWheel / D-pad: reel %d%% | RT analog reel | RB escape" % roundi(reel_speed.selected_speed()*100)
		if live_driver != null and is_instance_valid(lure): mode_label.text += "\nCharge %d%%" % int(live_driver.charge / lure.flee_charge_time * 100)
	else: mode_label.text = "TAB bait control | G enter boat and prepare a cast"
