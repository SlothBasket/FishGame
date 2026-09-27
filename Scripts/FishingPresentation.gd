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
	return origin+Vector3.UP*2.05-forward*0.85+forward.cross(Vector3.UP)*0.75

static func visual_path(tip: Vector3, mouth: Vector3, slack: float) -> Array[Vector3]:
	# Clean mouth attachment beats a visibly angular approximate body wrap.
	# This local ribbon has no influence on authoritative line geometry.
	var points: Array[Vector3] = []
	for i in range(33):
		var t = i/32.0
		points.append(tip.lerp(mouth,t)-Vector3.UP*sin(PI*t)*minf(6,slack*0.4))
	return points

func update_view(delta: float, camera: Camera3D, hand: Vector3, rod: Vector3, tip: Vector3, target: Vector3, fish: FishPlayer, slack: float, line_rate: float, payout: float, retrieve_speed: float, active: bool, audible: bool) -> void:
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

	last_points = visual_path(tip,mouth,slack)
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
	audio.update_payout(delta,payout if active else 0,audible and active)
