class_name Geometry
extends RefCounted
## Shared procedural building blocks. Fish and bait use the same material style.

static var _unit_sphere: SphereMesh

static func material(hex: String, metallic: float = 0.0) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = Color(hex)
	result.metallic = metallic
	result.roughness = 0.55
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func sphere(parent: Node3D, label: String, where: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = label
	node.position = where
	node.scale = size
	if _unit_sphere == null:
		_unit_sphere = SphereMesh.new()
		_unit_sphere.radius = 1.0
		_unit_sphere.height = 2.0
		_unit_sphere.radial_segments = 16
		_unit_sphere.rings = 8
	var mesh = _unit_sphere
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	return node

static func triangle(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, mat: Material) -> void:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_set_normal((b - a).cross(c - a).normalized())
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
	mesh.surface_end()
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)

static func box(parent: Node3D, label: String, where: Vector3, size: Vector3, mat: Material, visible: bool = true) -> void:
	var body = StaticBody3D.new()
	body.name = label
	body.position = where
	parent.add_child(body)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if visible:
		var node = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = size
		node.mesh = mesh
		node.material_override = mat
		body.add_child(node)
