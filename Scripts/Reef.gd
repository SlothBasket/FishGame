extends Node3D
## Prototype level + HUD. Arena dimensions below drive seabed, surface, bounds and zones.

@export var arena_width: float = 240.0
@export var water_depth: float = 32.0
@export var rock_count: int = 24
var _fish
var _telemetry: Label
var _status: Label
var _score: Label
var _time: float = 0.0
var _capture: bool = false
var _captured: bool = false
var _feeding_preview: bool = false
var _charge_preview: bool = false
var _lure_test: LureTestController

func _ready() -> void:
	_fish = $FishPlayer
	_fish.water_height = water_depth
	var args = OS.get_cmdline_user_args()
	if "--perf-check" in args:
		add_child(PerformanceProbe.new())
	_capture = "--capture" in args
	_feeding_preview = "--feeding-preview" in args
	_charge_preview = "--charge-preview" in args
	_capture = _capture or _feeding_preview or _charge_preview
	build_water()
	build_reef()
	build_hud()
	if "--self-test" in args:
		_fish.external_input = true
		var checks = FeedingChecks.new()
		checks.fish = _fish
		add_child(checks)
	else:
		var school = BaitSchool.new()
		school.arena_half_width = arena_width * 0.5
		school.water_depth = water_depth
		add_child(school)
		_lure_test = LureTestController.new()
		add_child(_lure_test)
		_lure_test.setup(_fish, self, Vector3(0, water_depth - 1, 12))
	if "--readability-preview" in args:
		add_child(ReadabilityPreview.new())
	if _capture:
		_fish.pivot.rotation = Vector3(-0.13, -0.45, 0)
	if _feeding_preview or _charge_preview:
		_fish.external_input = true
		_fish.pivot.rotation = Vector3.ZERO
		for i in range(3):
			var bait = BaitActor.new()
			bait.kind = i
			bait.position = Vector3(0, 6, 7 - i * 2)
			bait.driver = BaitMotion.ControlledBaitDriver.new()
			add_child(bait)

func build_water() -> void:
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("124555")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("95b7bf")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("154655")
	environment.fog_light_energy = 0.5
	environment.fog_density = 0.025
	world.environment = environment
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_color = Color("d0e4dc")
	sun.light_energy = 0.85
	sun.shadow_enabled = false
	add_child(sun)
	var water = ShaderMaterial.new()
	water.shader = load("res://Shaders/WaterSurface.gdshader")
	var surface = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2.ONE * arena_width
	surface.mesh = plane
	surface.position.y = water_depth
	surface.material_override = water
	surface.name = "WaterSurface"
	add_child(surface)
	var feedback = SurfaceFeedback.new()
	feedback.water_height = water_depth
	add_child(feedback)

func build_reef() -> void:
	var half = arena_width * 0.5
	var sand = ShaderMaterial.new()
	sand.shader = load("res://Shaders/Sand.gdshader")
	Geometry.box(self, "Seabed", Vector3(0, -1, 0), Vector3(arena_width, 2, arena_width), sand)
	Geometry.box(self, "SurfaceBoundary", Vector3(0, water_depth + 1, 0), Vector3(arena_width, 2, arena_width), sand, false)
	get_node("SurfaceBoundary").collision_layer = 8
	for side in [-1, 1]:
		Geometry.box(self, "ZBoundary", Vector3(0, water_depth, side * half), Vector3(arena_width, water_depth * 3, 2), sand, false)
		Geometry.box(self, "XBoundary", Vector3(side * half, water_depth, 0), Vector3(2, water_depth * 3, arena_width), sand, false)
	var rng = RandomNumberGenerator.new()
	rng.seed = 426 # Stable terrain; live behavior uses independent varied seeds.
	var stone = Geometry.material("42686b")
	# Eight separated clusters leave open lanes through the center and between zones.
	var clusters = [Vector2(-17,-17), Vector2(22,-36), Vector2(-48,18), Vector2(45,35), Vector2(-68,-58), Vector2(72,-62), Vector2(-20,74), Vector2(72,78)]
	for i in range(rock_count):
		var cluster: Vector2 = clusters[i % clusters.size()]
		var offset = Vector2.from_angle(float(i / clusters.size()) * 2.4) * float(i / clusters.size()) * 7.0
		var x = cluster.x + offset.x
		var z = cluster.y + offset.y
		if absf(x) < 5 and z > -32 and z < 20:
			continue
		var size = Vector3(rng.randf_range(2, 4.5), rng.randf_range(1.3, 3.5), rng.randf_range(2, 4.5))
		var rock = StaticBody3D.new()
		rock.position = Vector3(x, size.y * 0.35, z)
		add_child(rock)
		var mesh = Geometry.sphere(rock, "Rock", Vector3.ZERO, size, stone)
		var collision = CollisionShape3D.new()
		var shape = mesh.mesh.create_convex_shape()
		var points = shape.points
		for j in range(points.size()):
			points[j] *= size
		shape.points = points
		collision.shape = shape
		rock.add_child(collision)
		var shelter = RockShelter.new()
		shelter.radius = maxf(size.x, size.z) + 1.1
		rock.add_child(shelter)
	# One instanced draw for small, non-colliding seabed detail.
	var pebbles = MultiMeshInstance3D.new()
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var pebble_mesh = SphereMesh.new()
	pebble_mesh.radial_segments = 8
	pebble_mesh.rings = 4
	batch.mesh = pebble_mesh
	batch.instance_count = 650
	for i in range(batch.instance_count):
		var scale = Vector3(rng.randf_range(0.12,0.45), rng.randf_range(0.06,0.18), rng.randf_range(0.12,0.4))
		batch.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(scale), Vector3(rng.randf_range(-half,half),0.04,rng.randf_range(-half,half))))
	pebbles.multimesh = batch
	pebbles.material_override = Geometry.material("728378")
	add_child(pebbles)
	var ring_material = Geometry.material("efc581", 0.45)
	ring_material.emission_enabled = true
	ring_material.emission = Color("896a35")
	# The original practice hoops remain; distant hoops provide zone landmarks.
	var centers = [Vector3(0, 6, -3), Vector3(0, 9, -18), Vector3(9, 13, -29),
		Vector3(-half * 0.52, 5, half * 0.38), Vector3(half * 0.52, water_depth * 0.5, -half * 0.5),
		Vector3(-half * 0.5, water_depth * 0.38, -half * 0.5), Vector3(half * 0.58, 5, half * 0.48), Vector3(0, water_depth * 0.57, half * 0.65)]
	for center in centers:
		var ring = Node3D.new()
		ring.position = center
		add_child(ring)
		var node = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 2.65
		torus.outer_radius = 2.85
		torus.rings = 48
		torus.ring_segments = 12
		node.mesh = torus
		node.rotation_degrees.x = 90
		node.material_override = ring_material
		ring.add_child(node)
		var body = StaticBody3D.new()
		ring.add_child(body)
		for segment in range(32):
			var angle = segment * TAU / 32.0
			var collision = CollisionShape3D.new()
			collision.position = Vector3(cos(angle), sin(angle), 0) * 2.75
			var shape = SphereShape3D.new()
			shape.radius = 0.29
			collision.shape = shape
			body.add_child(collision)
	var particle_material = Geometry.material("91c5bc")
	for i in range(160):
		Geometry.sphere(self, "SuspendedParticle", Vector3(rng.randf_range(-half + 5, half - 5), rng.randf_range(2, water_depth - 1), rng.randf_range(-half + 5, half - 5)), Vector3.ONE * rng.randf_range(0.015, 0.045), particle_material)

func hud_text(root: Control, value: String, size: int, color: Color, where: Vector2) -> Label:
	var label = Label.new()
	label.text = value
	label.position = where
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	root.add_child(label)
	return label

func anchor(label: Control, preset: Control.LayoutPreset, offsets: Rect2) -> void:
	label.set_anchors_and_offsets_preset(preset)
	label.offset_left = offsets.position.x
	label.offset_top = offsets.position.y
	label.offset_right = offsets.end.x
	label.offset_bottom = offsets.end.y

func build_hud() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cream = Color("e6efe3")
	var muted = Color("a4c8c8")
	hud_text(root, "P E L A G I C", 30, cream, Vector2(38, 30))
	hud_text(root, "03  /  THE HUNTING GROUNDS", 13, Color("e7c184"), Vector2(40, 75))
	hud_text(root, "MINNOW +1 / SHRIMP +2 / SQUID +3 / CRAB +4", 13, muted, Vector2(40, 102))
	_score = hud_text(root, "", 20, cream, Vector2.ZERO)
	anchor(_score, Control.PRESET_TOP_RIGHT, Rect2(-300, 92, 262, 63))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var top = hud_text(root, "FEED / GROW / REPEAT\nOPEN REEF / DAY", 13, muted, Vector2.ZERO)
	anchor(top, Control.PRESET_TOP_RIGHT, Rect2(-282, 36, 244, 50))
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint = hud_text(root, "Hold LMB. Line it up. Release.", 24, cream, Vector2.ZERO)
	anchor(hint, Control.PRESET_BOTTOM_LEFT, Rect2(40, -125, 520, 40))
	var controls = hud_text(root, "W forward / S reverse    A/D steer    MOUSE look    SHIFT boost\nSPACE / CTRL rise / dive    R reset    ESC release cursor", 15, muted, Vector2.ZERO)
	anchor(controls, Control.PRESET_BOTTOM_LEFT, Rect2(40, -83, 740, 58))
	_telemetry = hud_text(root, "", 20, cream, Vector2.ZERO)
	anchor(_telemetry, Control.PRESET_BOTTOM_RIGHT, Rect2(-260, -103, 220, 60))
	_telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status = hud_text(root, "", 14, Color("e7c184"), Vector2.ZERO)
	anchor(_status, Control.PRESET_CENTER_TOP, Rect2(-200, 35, 400, 30))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var feeding_hud = FeedingHud.new()
	feeding_hud.fish = _fish
	root.add_child(feeding_hud)
	feeding_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_time += delta
	if _feeding_preview or _charge_preview:
		_fish.command = FishInput.new(0, 0, 0, Vector3.FORWARD, false, _time < 1.5 or _charge_preview)
	_telemetry.text = "%.1f m/s\n%.1f m depth" % [_fish.velocity.length(), water_depth - _fish.position.y]
	_score.text = "%d FOOD / %d EATEN\n%.2f× SIZE" % [_fish.feeding.food, _fish.feeding.bait_eaten, _fish.size_multiplier()]
	_status.text = "CLICK TO SWIM" if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED else "FEEDING LUNGE" if _fish.feeding.is_dashing() else "BOOST" if _fish.boosting else ""
	if _capture and not _captured and _time > (1.85 if _feeding_preview else 2.0):
		_captured = true
		await RenderingServer.frame_post_draw
		var filename = "FishGame-feeding.png" if _feeding_preview else "FishGame-charge.png" if _charge_preview else "FishGame-preview.png"
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../" + filename))
		get_tree().quit()
