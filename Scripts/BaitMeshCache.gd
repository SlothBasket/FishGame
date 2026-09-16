class_name BaitMeshCache
extends RefCounted
## Bake rigid pieces together once per species/appendage. Articulated joints stay separate.
static var meshes: Dictionary = {}
static var material: StandardMaterial3D
static func combine(root: Node3D, key: String) -> void:
	var pieces: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D: pieces.append(child)
	if pieces.size() <= 1: return
	if not meshes.has(key):
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var colors = PackedColorArray()
		var indices = PackedInt32Array()
		for piece in pieces:
			for surface in range(piece.mesh.get_surface_count()):
				var data = piece.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
				var offset = vertices.size()
				var normal_basis = piece.transform.basis.inverse().transposed()
				var tint = piece.material_override.albedo_color
				for i in range(points.size()):
					vertices.append(piece.transform * points[i])
					normals.append((normal_basis * data[Mesh.ARRAY_NORMAL][i]).normalized())
					colors.append(tint)
				if data[Mesh.ARRAY_INDEX] != null and data[Mesh.ARRAY_INDEX].size() > 0:
					for index in data[Mesh.ARRAY_INDEX]: indices.append(offset+index)
				else:
					for i in range(points.size()): indices.append(offset+i)
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		meshes[key] = mesh
	if material == null:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.55
		material.metallic = 0.15
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for piece in pieces:
		root.remove_child(piece)
		piece.queue_free()
	var combined = MeshInstance3D.new()
	combined.mesh = meshes[key]
	combined.material_override = material
	root.add_child(combined)
