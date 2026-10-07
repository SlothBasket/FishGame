class_name FishingPresentation
extends Node3D
## Local-only reel, striped line and drag sound. Never writes actor state.
var reel: Node3D
var spool: Node3D
var crank: Node3D
var line: MeshInstance3D
var material: ShaderMaterial
var audio: ReelDragAudio
var shown_tension: float = 0
var flare_side: float = 1
var travel: float = 0
var last_points: Array[Vector3] = []
func _ready() -> void:
	reel = Node3D.new()
	add_child(reel)
	Geometry.sphere(reel,"ReelBody",Vector3.ZERO,Vector3(0.16,0.22,0.18),Geometry.material("3a4b50",0.6))
	spool = Node3D.new()
	reel.add_child(spool)
	Geometry.sphere(spool,"Spool",Vector3(0.15,0,0),Vector3(0.10,0.18,0.18),Geometry.material("c8bd86",0.6))
	Geometry.box(spool,"SpoolMarker",Vector3(0.25,0.10,0),Vector3(0.03,0.09,0.04),Geometry.material("313d42"),false)
	crank = Node3D.new()
	reel.add_child(crank)
	Geometry.box(crank,"Crank",Vector3(-0.23,0.10,0),Vector3(0.04,0.22,0.04),Geometry.material("d5d2b3"),false)
	Geometry.sphere(crank,"Grip",Vector3(-0.28,0.22,0),Vector3(0.08,0.045,0.045),Geometry.material("35494b"))
	line = MeshInstance3D.new()
	line.mesh = ImmediateMesh.new()
	add_child(line)
	material = ShaderMaterial.new()
	material.shader = load("res://Shaders/FishingLine.gdshader")
	audio = ReelDragAudio.new()
	add_child(audio)

static func edge_camera(origin: Vector3, forward: Vector3) -> Vector3:
	return origin+Vector3.UP*4.0-forward*5.2+forward.cross(Vector3.UP)*1.8

static func boat_view_target(origin: Vector3, forward: Vector3, rod: Vector3, focus: Vector3) -> Vector3:
	var course = (forward+BaitMotion.horizontal(rod)*0.25).normalized()
	var target = origin+course*12-Vector3.UP*3
	return target+(focus-target).limit_length(8)*0.12

static func visual_rod_offset(forward: Vector3) -> Vector3:
	return forward*1.4+forward.cross(Vector3.UP)*1.0

static func tension_color(ratio: float) -> Color:
	var t = clampf(ratio,0,1.2)
	if t <= 0.7: return Color.WHITE.lerp(Color(1,0.06,0.04),t/0.7)
	return Color(1,0.06,0.04).lerp(Color(0.28,0.005,0.015),clampf((t-0.7)/0.5,0,1))

static func fish_camera_active(tree: SceneTree) -> bool:
	for subject in tree.get_nodes_in_group("fish_line_subjects"):
		if subject.camera.current: return true
	return false

static func visual_path(tip: Vector3, mouth: Vector3, _slack: float, forward: Vector3 = Vector3.FORWARD, scale: float = 1, flare_side: float = 1) -> Array[Vector3]:
	# One tiny quadratic at the mouth; every point beyond its end lies on one straight segment.
	var outgoing = (tip-mouth).normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.1: right = Vector3.RIGHT
	var lead = minf(0.45*scale,tip.distance_to(mouth)*0.25)
	var end = mouth+outgoing*lead
	var control = mouth+outgoing*lead*0.5+right*flare_side*minf(0.12*scale,lead*0.3)
	var points: Array[Vector3] = [tip,end]
	for i in range(1,9):
		var t = 1-i/8.0; var u = 1-t
		points.append(mouth*u*u+control*2*u*t+end*t*t)
	return points

func update_view(delta: float, camera: Camera3D, hand: Vector3, rod: Vector3, tip: Vector3, target: Vector3, fish: FishPlayer, slack: float, line_rate: float, payout: float, retrieve_speed: float, active: bool, audible: bool, requested: float = 0, efficiency: float = 1, phase: int = -1) -> void:
	reel.position = hand+rod*0.18-Vector3.UP*0.16
	if rod.length_squared() > 0.01: reel.look_at(reel.global_position+rod,Vector3.UP)
	crank.rotation.x += maxf(0,retrieve_speed)*3*delta
	spool.rotation.x -= line_rate*4*delta
	travel += line_rate*delta
	material.set_shader_parameter("travel",travel)
	line.visible = active and not (is_instance_valid(fish) and fish.fight_active and fish_camera_active(get_tree()))
	var mouth = target
	if is_instance_valid(fish):
		mouth = fish.fight_mouth_position(tip-fish.global_position)
		flare_side = fish.fight_mouth_side

	shown_tension = lerpf(shown_tension,fish.fight_tension_ratio if is_instance_valid(fish) else 0.0,1-exp(-delta/0.12))
	material.set_shader_parameter("tension_tint",tension_color(shown_tension))

	last_points = visual_path(tip,mouth,slack,fish.heading if is_instance_valid(fish) else (mouth-tip).normalized(),fish.size_multiplier() if is_instance_valid(fish) else 0.0,flare_side)
	var mesh: ImmediateMesh = line.mesh
	mesh.clear_surfaces()
	if active:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
		var width = camera.global_basis.x*0.018
		var distance: float = 0
		for i in range(last_points.size()-1):
			var next = distance+last_points[i].distance_to(last_points[i+1])
			for j in [0,1,2,0,2,3]:
				var end = j >= 2
				mesh.surface_set_uv(Vector2(next if end else distance,1 if j in [1,2] else 0))
				mesh.surface_add_vertex(last_points[i+1 if end else i]+width*(1 if j in [1,2] else -1))
			distance = next
		mesh.surface_end()
	audio.update_payout(delta,payout if active and line_rate > 0.03 else 0,audible and active and line_rate >= -0.03)
	audio.update_reel_cues(delta,requested,efficiency,phase,audible and active)
