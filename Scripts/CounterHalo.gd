class_name CounterHalo
extends Node3D
## Short local-only head sparks, spawned by the reliable strong-counter event.
var effectiveness: float = 1
var age: float = 0
var sparks: Array[MeshInstance3D] = []
func _ready() -> void:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1,0.85,0.25)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for i in range(10):
		mesh.surface_add_vertex(Vector3.ZERO)
		for j in [i,i+1]:
			var angle = j*TAU/10
			var radius = 0.12 if j%2 == 0 else 0.05
			mesh.surface_add_vertex(Vector3(cos(angle),sin(angle),0)*radius)
	mesh.surface_end()
	for i in range(5):
		var spark = MeshInstance3D.new()
		spark.mesh = mesh
		add_child(spark)
		sparks.append(spark)
func _process(delta: float) -> void:
	age += delta
	if age >= 0.85:
		queue_free()
		return
	var fish = get_parent() as FishPlayer
	if fish == null: queue_free(); return
	global_position = fish.mouth_position()+Vector3.UP*0.25*fish.size_multiplier()
	var size = fish.size_multiplier()*(0.8+0.4*clampf(effectiveness,0,1))
	for i in range(sparks.size()):
		var angle = age*8+i*TAU/sparks.size()
		sparks[i].position = Vector3(cos(angle)*0.5,sin(angle*2)*0.09,sin(angle)*0.5)*size
		sparks[i].scale = Vector3.ONE*size*minf(1,(0.85-age)*6)
