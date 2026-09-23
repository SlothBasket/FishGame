class_name FishFightReferences
extends Node3D
## Local, optional spatial aids; never authoritative and hidden outside a hook-up.
@export var enabled: bool = true
var fish: FishPlayer
var line: MeshInstance3D
var boat: Label3D
var material: StandardMaterial3D
func _ready() -> void:
	top_level = true
	global_position = Vector3.ZERO
	line = MeshInstance3D.new()
	line.mesh = ImmediateMesh.new()
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.7,0.85,0.8,0.13)
	add_child(line)
	boat = Label3D.new()
	boat.text = "▱"
	boat.font_size = 36
	boat.modulate = Color(0.7,0.85,0.8,0.22)
	boat.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	boat.no_depth_test = true
	boat.fixed_size = true
	add_child(boat)
func _process(_delta: float) -> void:
	visible = enabled and fish.locally_owned and fish.fight_active
	if not visible: return
	boat.global_position = fish.fight_anchor
	var mesh: ImmediateMesh = line.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
	mesh.surface_add_vertex(fish.global_position)
	mesh.surface_add_vertex(fish.fight_anchor)
	mesh.surface_end()
