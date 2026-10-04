class_name InshoreHabitat
extends Node3D
## Visual-only patch landmarks. No new terrain collision or per-frame simulation.
static func sites(half: float) -> Array[Vector3]:
	return [Vector3(-0.45,0,-0.3)*half,Vector3(0.42,0,0.35)*half,Vector3(-0.35,0,0.55)*half,Vector3(0.5,0,-0.55)*half]

func build(half: float) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 2047
	var grass = BoxMesh.new()
	grass.size = Vector3(0.07,0.8,0.12)
	var shell = SphereMesh.new()
	shell.radial_segments = 8
	shell.rings = 4
	var grass_transforms: Array[Transform3D] = []
	var shell_transforms: Array[Transform3D] = []
	for center in sites(half):
		for i in range(240):
			var angle = rng.randf()*TAU
			var radius = sqrt(rng.randf())*14
			var point = center+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			# Gaps leave sandy openings; short blades retain prey readability.
			if sin(point.x*0.3)+cos(point.z*0.23) > 0.4: continue
			var height = rng.randf_range(0.45,1.2)
			grass_transforms.append(Transform3D(Basis.from_euler(Vector3(0.2,rng.randf()*TAU,0.15)).scaled(Vector3(1,height,1)),point+Vector3.UP*height*0.35))
		for i in range(35):
			var point = center+Vector3(13+rng.randf_range(-3,3),0.12,rng.randf_range(-4,4))
			shell_transforms.append(Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(Vector3(0.6,0.18,0.35)),point))
	instances(grass,grass_transforms,Geometry.material("335c48"))
	instances(shell,shell_transforms,Geometry.material("a39c7e"))
	# A few edge root/piling silhouettes make useful casting landmarks.
	var roots: Array[Transform3D] = []
	var root_mesh = CylinderMesh.new()
	root_mesh.top_radius = 0.18
	root_mesh.bottom_radius = 0.3
	root_mesh.height = 7
	root_mesh.radial_segments = 8
	for i in range(18):
		var point = Vector3(-half+9+(i%3)*3,3.2,-half*0.6+i*4)
		roots.append(Transform3D(Basis.from_euler(Vector3(0.2*sin(i),0,0.25*cos(i))),point))
	instances(root_mesh,roots,Geometry.material("594d3b"))

func instances(mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()): batch.set_instance_transform(i,transforms[i])
	var view = MultiMeshInstance3D.new()
	view.multimesh = batch
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
