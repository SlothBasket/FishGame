class_name FisherView
extends Node3D
## Owner-only camera, rod/line art and HUD. Never moves a gameplay actor.
@export var rod_mouse_response: float = 0.0035
@export var rod_stick_response: float = 1.2
@export var fight_camera_response: float = 5
var rod_horizontal: float = 0
var rod_vertical: float = 0
var drag_setting: float = 0.4
var centered_focus: Vector3
var bars: Dictionary = {}
var drag_slider: HSlider
var readings: Label
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
var drag_value: Label
var hook_panel: PanelContainer
var fight_panel: PanelContainer
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
	rod_mesh.mesh = ImmediateMesh.new()
	line_mesh = MeshInstance3D.new()
	line_mesh.mesh = ImmediateMesh.new()
	add_child(rod_mesh)
	add_child(line_mesh)
	camera = Camera3D.new()
	camera.fov = 60
	add_child(camera)
	camera.make_current()
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var root = Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_panel = PanelContainer.new()
	root.add_child(fight_panel)
	fight_panel.anchor_left = 0.71
	fight_panel.anchor_right = 0.98
	fight_panel.anchor_top = 0.04
	fight_panel.anchor_bottom = 0.96
	var margin = MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	fight_panel.add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",6)
	scroll.add_child(box)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",16)
	box.add_child(label)
	readings = Label.new()
	readings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(readings)
	var drag_caption = Label.new()
	drag_caption.text = "DRAG"
	box.add_child(drag_caption)
	drag_slider = HSlider.new()
	drag_slider.min_value = 0
	drag_slider.max_value = 100
	drag_slider.step = 5
	drag_slider.value = 40
	drag_slider.custom_minimum_size.y = 22
	drag_slider.value_changed.connect(func(value): drag_setting = value/100.0)
	box.add_child(drag_slider)
	drag_value = Label.new()
	box.add_child(drag_value)
	for title in ["Tension","Line condition","Retrieve","Power stamina","Focus"]:
		var caption = Label.new()
		caption.text = title.to_upper()
		box.add_child(caption)
		var bar = ProgressBar.new()
		bar.custom_minimum_size.y = 22
		box.add_child(bar)
		bars[title] = bar
	# Hook timing owns its own centered area, outside the scrolling fight panel.
	hook_panel = PanelContainer.new()
	root.add_child(hook_panel)
	hook_panel.anchor_left = 0.32
	hook_panel.anchor_right = 0.68
	hook_panel.anchor_top = 0.44
	hook_panel.anchor_bottom = 0.56
	var hook_box = VBoxContainer.new()
	hook_panel.add_child(hook_box)
	var hook_caption = Label.new()
	hook_caption.text = "HOOK SET — release near 75%"
	hook_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook_box.add_child(hook_caption)
	var hook_bar = ProgressBar.new()
	hook_bar.custom_minimum_size.y = 30
	hook_box.add_child(hook_bar)
	bars["Hook meter"] = hook_bar
	hook_panel.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative*rod_mouse_response)
	if event.is_echo(): return
	if event.is_action_pressed("cast"): cast_serial = mini(1000000,cast_serial+1)
	if event.is_action_pressed("bait_species"): species = (species+1)%5
	if event.is_action_pressed("reel_up"): reel.step(1)
	if event.is_action_pressed("reel_down"): reel.step(-1)
	if event.is_action_pressed("bait_camera"): alternate_view = not alternate_view
	if event.is_action_pressed("drag_up"): drag_setting = minf(1,drag_setting+0.05)
	if event.is_action_pressed("drag_down"): drag_setting = maxf(0,drag_setting-0.05)
	drag_slider.set_value_no_signal(drag_setting*100)

func sample() -> FisherIntent:
	var intent = FisherIntent.new()
	intent.tier = reel.selected_tier
	intent.species = species
	intent.cast_serial = cast_serial
	intent.aim = FishInput.from_angles(pitch,yaw)
	intent.rod_horizontal = rod_horizontal
	intent.rod_vertical = rod_vertical
	intent.drag = drag_setting
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
	if data.size() != 50: return
	apply_look(GameControls.look()*rod_stick_response*delta)
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
	impact_age += delta
	previous_phase = phase
	var underwater = roundi(data[4]) == FisherActor.State.BAIT or (fighting and phase <= FightSession.Phase.METER) or data[16] > 0
	centered_focus = centered_focus.lerp(focus,1-exp(-fight_camera_response*delta))
	var direction = BaitMotion.horizontal(centered_focus-origin) if fighting else FishInput.from_angles(pitch,yaw)
	if fighting: focus = centered_focus
	var boat_camera = origin+Vector3.UP*2.8-direction*3.5
	var desired = focus-direction*(6 if alternate_view else 10.8)+Vector3.UP*(2 if fighting else 0) if underwater else boat_camera
	# Impact remains underwater briefly, then blends into the boat view during the yank.
	if fighting and phase == FightSession.Phase.IMPACT:
		desired = (focus-direction*8).lerp(boat_camera,clampf((impact_age-0.15)/0.5,0,1))
	camera.position = camera.position.lerp(desired,1-exp(-7*delta))
	var target = focus if underwater or fighting else camera.position+direction*10
	if camera.position.distance_to(target) > 0.1: camera.look_at(target,Vector3.UP)
	camera.rotation.z = sin(impact_age*22)*0.025*maxf(0,1-impact_age/0.5) if fighting else 0
	var rod = Vector3(data[17],data[18],data[19])
	var hand = Vector3(data[42],data[43],data[44])
	var tip = Vector3(data[39],data[40],data[41])
	if not fighting: hand = origin+Vector3.UP*1.3; tip = hand+rod*3
	var rod_points: Array = []
	var control = hand+rod*1.5
	for i in range(7):
		var t = i/6.0
		rod_points.append(hand*(1-t)*(1-t)+control*2*t*(1-t)+tip*t*t)
	draw_rod(rod_points)
	var line_points: Array = []
	var line_end = Vector3(data[21],data[22],data[23]) if fighting else focus
	for i in range(9):
		var t = i/8.0
		line_points.append(tip.lerp(line_end,t)+Vector3.DOWN*sin(PI*t)*minf(6,data[31]*0.45))
	draw_line(line_mesh,line_points,rod_material)
	rod_mesh.visible = not underwater or fighting
	line_mesh.visible = fighting or roundi(data[4]) == FisherActor.State.BAIT
	var phase_name = ["BAIT TAKEN — hold Q / RB when ready","HOOK: release near 75%","HOOK IMPACT","OPENING RUN — Power locked","FIGHT"][clampi(phase,0,4)] if fighting else BaitMotion.Kind.keys()[roundi(data[5])]
	label.text = "FISHER — %s\nG cast/setup | X species | W/RT retrieve | Wheel/D-pad up/down reel\nMouse/right stick: rod during fight | [ ] / D-pad left/right: drag\nQ/RB hook/jerk | Shift/LB Power | V/LS Focus | C/RS bait view" % phase_name
	if not fighting and data[27] > 0: label.text += "\n"+FightSession.Outcome.keys()[roundi(data[27])]
	var pressure = "SLACK — REEL!" if data[31] > 0.5 else "CRITICAL" if data[13] > data[45] else "HEAVY" if data[13] > data[45]*0.7 else "DRAG" if data[38] > 0 else "WORKING" if data[13] > data[45]*0.2 else "LIGHT"
	var pull_direction = "LEFT" if data[49] < -0.3 else "RIGHT" if data[49] > 0.3 else "AWAY"
	readings.text = "LINE %.1f / %.0f m\n%s | %s\nSlack %.1f m | Line rate %+.1f m/s\nTension %.0f | Drag limit %.0f\nSaved retrieve %d%% | %s" % [data[12],data[48],pressure,pull_direction if fighting else "READY",data[31],data[35],data[13],data[33],roundi(data[7]*5),"POWER" if data[15] > 0 else "NORMAL"]
	bars["Tension"].max_value = data[45]
	bars["Tension"].value = data[13]
	bars["Line condition"].value = data[14]*100
	bars["Retrieve"].value = data[37]*100
	bars["Power stamina"].value = data[8]
	bars["Focus"].value = data[9]
	hook_panel.visible = fighting and phase == FightSession.Phase.METER
	bars["Hook meter"].value = data[11]*100
	drag_value.text = "%d%%" % roundi(drag_setting*100)

func apply_look(movement: Vector2) -> void:
	if data.size() == 50 and roundi(data[4]) == FisherActor.State.FIGHT:
		if data[16] <= 0:
			rod_horizontal = clampf(rod_horizontal+movement.x,-1,1)
			rod_vertical = clampf(rod_vertical-movement.y,-1,1)
	else:
		yaw -= movement.x
		pitch = clampf(pitch-movement.y,-1.5,1.5)

func draw_rod(points: Array) -> void:
	var mesh: ImmediateMesh = rod_mesh.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,rod_material)
	var width = camera.global_basis.x*0.035
	for i in range(points.size()-1):
		for point in [points[i]-width,points[i]+width,points[i+1]+width,points[i]-width,points[i+1]+width,points[i+1]-width]: mesh.surface_add_vertex(point)
	mesh.surface_end()

func draw_line(node: MeshInstance3D, points: Array, material: Material) -> void:
	var mesh: ImmediateMesh = node.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	for point in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
	node.mesh = mesh

func layout_fits() -> bool:
	var viewport_rect = get_viewport().get_visible_rect()
	return viewport_rect.encloses(fight_panel.get_global_rect()) and viewport_rect.encloses(hook_panel.get_global_rect()) and hook_panel.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 2 and not fight_panel.get_global_rect().intersects(session.status.get_global_rect())
