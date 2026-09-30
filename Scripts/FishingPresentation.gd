class_name FishingPresentation
extends Node3D
## Local-only reel, striped line and drag sound. Never writes actor state.
var reel: Node3D
var spool: Node3D
var crank: Node3D
var line: MeshInstance3D
var material: ShaderMaterial
var audio: ReelDragAudio
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

static func visual_path(tip: Vector3, mouth: Vector3, slack: float, forward: Vector3 = Vector3.FORWARD, scale: float = 1) -> Array[Vector3]:
	# A short mouth lead, not a body collision/wrap solver. Stable smooth side bias.
	var approach = (tip-mouth).normalized()
	var right = forward.cross(Vector3.UP).normalized()
	var lead = mouth+(forward*0.9+right*clampf(approach.dot(right),-0.5,0.5))*scale
	var span = tip.distance_to(mouth)
	var control = tip.lerp(lead,0.55)-Vector3.UP*minf(6,slack*0.4)
	lead = mouth+(lead-mouth).limit_length(span*0.35)
	var points: Array[Vector3] = []
	for i in range(33):
		var t = i/32.0
		var u = 1-t
		points.append(tip*u*u*u+control*3*u*u*t+lead*3*u*t*t+mouth*t*t*t)
	return points

func update_view(delta: float, camera: Camera3D, hand: Vector3, rod: Vector3, tip: Vector3, target: Vector3, fish: FishPlayer, slack: float, line_rate: float, payout: float, retrieve_speed: float, active: bool, audible: bool, requested: float = 0, efficiency: float = 1, phase: int = -1) -> void:
	reel.position = hand+rod*0.18-Vector3.UP*0.16
	if rod.length_squared() > 0.01: reel.look_at(reel.global_position+rod,Vector3.UP)
	crank.rotation.x += maxf(0,retrieve_speed)*3*delta
	spool.rotation.x -= line_rate*4*delta
	travel += line_rate*delta
	material.set_shader_parameter("travel",travel)
	line.visible = active
	var mouth = target
	if is_instance_valid(fish):
		mouth = fish.mouth_position()

	last_points = visual_path(tip,mouth,slack,fish.heading if is_instance_valid(fish) else (mouth-tip).normalized(),fish.size_multiplier() if is_instance_valid(fish) else 0.0)
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
