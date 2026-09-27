class_name FishingPresentation
extends Node3D
## Local-only reel, striped line and optional drag sound. Never writes actor state.
@export var drag_loop: AudioStream
var reel: Node3D
var spool: Node3D
var crank: Node3D
var line: MeshInstance3D
var material: ShaderMaterial
var audio: AudioStreamPlayer
var travel: float = 0
var audio_level: float = 0
var wrap_side: Vector3 = Vector3.RIGHT
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
	audio = AudioStreamPlayer.new()
	add_child(audio)
	if drag_loop == null:
		var path = str(ProjectSettings.get_setting("pelagic/audio/drag_loop","res://Audio/drag_loop.ogg"))
		if ResourceLoader.exists(path): drag_loop = load(path) as AudioStream
		elif ResourceLoader.exists("res://Audio/drag_loop.wav"): drag_loop = load("res://Audio/drag_loop.wav") as AudioStream
	if drag_loop != null:
		audio.stream = drag_loop.duplicate()
		if audio.stream is AudioStreamOggVorbis: audio.stream.loop = true
		elif audio.stream is AudioStreamWAV:
			audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if audio.stream.loop_end <= audio.stream.loop_begin: audio.stream.loop_end = maxi(1,int(audio.stream.get_length()*audio.stream.mix_rate))
		audio.volume_db = -60

static func edge_camera(origin: Vector3, forward: Vector3) -> Vector3:
	return origin+Vector3.UP*2.05-forward*0.85+forward.cross(Vector3.UP)*0.75

static func visual_path(tip: Vector3, mouth: Vector3, center: Vector3, radius: float, side: Vector3, slack: float) -> Array[Vector3]:
	var route: Array[Vector3] = [tip]
	var closest = FishFeeding.closest_point(tip,mouth,center)
	if radius > 0 and closest.distance_to(center) < radius and tip.distance_to(center) > radius:
		# Stable flank bypass, with two support points around the body sphere.
		var toward = (tip-center).normalized()
		var flank = side-toward*side.dot(toward)
		if flank.length_squared() < 0.01: flank = toward.cross(Vector3.UP)
		if flank.length_squared() < 0.01: flank = Vector3.RIGHT
		flank = flank.normalized()
		route.append(center+toward*radius*1.2+flank*radius*1.35)
		route.append(center+(mouth-center).normalized()*radius*1.2+flank*radius*1.35)
	route.append(mouth)
	var points: Array[Vector3] = []
	for segment in range(route.size()-1):
		for i in range(17):
			var t = i/16.0
			var sag = minf(6,slack*0.4) if segment == 0 else 0.0
			points.append(route[segment].lerp(route[segment+1],t)-Vector3.UP*sin(PI*t)*sag)
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
	var center = target
	var radius = 0.0
	if is_instance_valid(fish):
		mouth = fish.mouth_position()
		center = fish.global_position
		radius = fish.size_multiplier()*0.85
		var right = fish.heading.cross(Vector3.UP).normalized()
		# Keep the chosen side through small heading changes to avoid wrap flicker.
		if absf((tip-center).normalized().dot(right)) > 0.25: wrap_side = right*signf((tip-center).dot(right))
	last_points = visual_path(tip,mouth,center,radius,wrap_side,slack)
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
	update_audio(delta,payout if audible and active else 0)

func update_audio(delta: float, payout: float) -> void:
	if audio.stream == null: return
	var level = clampf(payout/14,0,1)
	audio_level = lerpf(audio_level,level,1-exp(-delta*6))
	audio.pitch_scale = lerpf(audio.pitch_scale,lerpf(0.75,1.4,level),1-exp(-delta*5))
	audio.volume_db = linear_to_db(maxf(0.001,audio_level*0.4))
	if payout > 0.05 and not audio.playing: audio.play()
	elif payout <= 0.05 and audio_level < 0.005 and audio.playing: audio.stop()
