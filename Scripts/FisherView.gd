class_name FisherView
extends Node3D
## Owner-only camera, rod/line art, audio and HUD. Never moves a gameplay actor.
var session
var data = PackedFloat32Array()
var reel = ReelSpeed.new()
var species: int = 0
var cast_serial: int = 0
var yaw: float = 0.87
var pitch: float = -0.2
var alternate_view: bool = false
var camera: Camera3D
var boat: Node3D
var rod_mesh: MeshInstance3D
var line_mesh: MeshInstance3D
var rod_material: StandardMaterial3D
var label: Label
var hiss: AudioStreamPlayer
var previous_phase: int = -1
var impact_age: float = 0

func _ready() -> void:
	boat = Node3D.new()
	add_child(boat)
	Geometry.sphere(boat,"Hull",Vector3(0,-0.45,0),Vector3(1.4,0.6,2.8),Geometry.material("58473c"))
	Geometry.sphere(boat,"Rim",Vector3.ZERO,Vector3(1.5,0.14,2.8),Geometry.material("bfaa85"))
	rod_material = Geometry.material("d8cda0")
	rod_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rod_mesh = MeshInstance3D.new()
	line_mesh = MeshInstance3D.new()
	add_child(rod_mesh)
	add_child(line_mesh)
	camera = Camera3D.new()
	camera.fov = 60
	add_child(camera)
	camera.make_current()
	var canvas = CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(40,205)
	label.add_theme_font_size_override("font_size",16)
	canvas.add_child(label)
	hiss = AudioStreamPlayer.new()
	add_child(hiss)
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_8_BITS
	sound.mix_rate = 22050
	var samples = PackedByteArray()
	samples.resize(6615)
	var noise = RandomNumberGenerator.new()
	noise.seed = 812
	for i in range(samples.size()): samples[i] = clampi(128+roundi(noise.randf_range(-32,32)*(1-float(i)/samples.size())),0,255)
	sound.data = samples
	hiss.stream = sound
	hiss.volume_db = -18

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x*0.004
		pitch = clampf(pitch-event.relative.y*0.004,-1.5,1.5)
	if event.is_echo(): return
	if event.is_action_pressed("cast"): cast_serial = mini(1000000,cast_serial+1)
	if event.is_action_pressed("bait_species"): species = (species+1)%5
	if event.is_action_pressed("reel_up"): reel.step(1)
	if event.is_action_pressed("reel_down"): reel.step(-1)
	if event.is_action_pressed("bait_camera"): alternate_view = not alternate_view

func sample() -> FisherIntent:
	var intent = FisherIntent.new()
	intent.tier = reel.selected_tier
	intent.species = species
	intent.cast_serial = cast_serial
	intent.aim = FishInput.from_angles(pitch,yaw)
	intent.rod = intent.aim
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return intent
	intent.move_forward = Input.get_axis("back","forward")
	intent.move_side = Input.get_axis("left","right")
	intent.steering = intent.move_side
	intent.retrieve = reel.retrieve(Input.is_action_pressed("retrieve"),Input.get_action_strength("retrieve_trigger"))
	intent.rise = Input.is_action_pressed("rise")
	intent.descend = Input.is_action_pressed("dive")
	intent.escape = Input.is_action_pressed("bite")
	intent.jerk = Input.is_action_pressed("rod_jerk")
	intent.power = Input.is_action_pressed("power_reel")
	intent.vision = Input.is_action_pressed("fish_vision")
	return intent

func _process(delta: float) -> void:
	if data.size() != 30: return
	var look = GameControls.look()*2.2*delta
	yaw -= look.x
	pitch = clampf(pitch-look.y,-1.5,1.5)
	var origin = Vector3(data[0],data[1],data[2])
	boat.position = origin
	boat.rotation.y = data[3]
	var phase = roundi(data[10])
	var fighting = roundi(data[4]) == FisherActor.State.FIGHT
	var focus = Vector3(data[21],data[22],data[23]) if fighting else origin
	var bait_id = roundi(data[6])
	if not fighting and session.baits.has(bait_id): focus = session.baits[bait_id].position
	if phase == FightSession.Phase.IMPACT and previous_phase != phase:
		impact_age = 0
		hiss.play()
	impact_age += delta
	previous_phase = phase
	var underwater = roundi(data[4]) == FisherActor.State.BAIT or (fighting and phase <= FightSession.Phase.METER) or data[16] > 0
	var direction = FishInput.from_angles(pitch,yaw)
	var boat_camera = origin+Vector3.UP*2.1-Vector3.FORWARD.rotated(Vector3.UP,data[3])*2
	var desired = focus-direction*(6 if alternate_view else 10.8) if underwater else boat_camera
	# Impact remains underwater briefly, then blends into the boat view during the yank.
	if fighting and phase == FightSession.Phase.IMPACT:
		desired = (focus-direction*8).lerp(boat_camera,clampf((impact_age-0.15)/0.5,0,1))
	camera.position = camera.position.lerp(desired,1-exp(-7*delta))
	var target = focus if underwater or fighting else camera.position+direction*10
	if camera.position.distance_to(target) > 0.1: camera.look_at(target,Vector3.UP)
	camera.rotation.z = sin(impact_age*22)*0.025*maxf(0,1-impact_age/0.5) if fighting else 0
	var rod = Vector3(data[17],data[18],data[19])
	var tip = origin+Vector3.UP*2+rod*3
	var load = clampf(data[13]/110,0,1)
	draw_line(rod_mesh,[origin+Vector3.UP,origin+Vector3.UP*2+rod*1.2,tip+(focus-tip).normalized()*load*0.7],rod_material)
	draw_line(line_mesh,[tip,focus],rod_material)
	rod_mesh.visible = fighting or not underwater
	line_mesh.visible = fighting or roundi(data[4]) == FisherActor.State.BAIT
	var species_name: String = BaitMotion.Kind.keys()[roundi(data[5])]
	label.text = "FISHER %s | Reel %d%% | Line %.1fm | Tension %.0f | Condition %d%%\nPower stamina %d | Focus %d\nG cast/setup | X species | W/RT reel | LMB/RB bait escape | Q/RB hook/jerk\nShift/LB Power Reel | V/LS Focus | Mouse/right stick rod/look | C/RS view" % [species_name,roundi(data[7]*20),data[12],data[13],roundi(data[14]*100),roundi(data[8]),roundi(data[9])]
	if fighting:
		label.text += "\n"+["BAIT TAKEN — choose when to hold Q / RB","HOOK SET: release near 75%","HOOK IMPACT","OPENING RUN — Power Reel locked","FIGHT"][clampi(phase,0,4)]
		if phase == FightSession.Phase.METER: label.text += "  %d%%" % roundi(data[11]*100)
	elif data[27] > 0: label.text += "\n"+FightSession.Outcome.keys()[roundi(data[27])]

func draw_line(node: MeshInstance3D, points: Array, material: Material) -> void:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	for point in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
	node.mesh = mesh
