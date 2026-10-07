class_name FishFightReferences
extends Node3D
## Local line art for every hooked fish, visible from any Fish camera.
@export var enabled: bool = true
var fish: FishPlayer
var line: MeshInstance3D
var material: StandardMaterial3D
var shown_tension: float = 0
var flare_side: float = 1
func _ready() -> void:
	top_level = true
	global_position = Vector3.ZERO
	line = MeshInstance3D.new()
	line.mesh = ImmediateMesh.new()
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add_child(line)
func _process(delta: float) -> void:
	visible = enabled and FishingPresentation.fish_camera_active(get_tree()) and fish.fight_active
	if not visible: return
	shown_tension = lerpf(shown_tension,fish.fight_tension_ratio,1-exp(-delta/0.12))
	material.albedo_color = FishingPresentation.tension_color(shown_tension)
	var mouth = fish.fight_mouth_position(fish.fight_rod_tip-fish.global_position)
	var points = FishingPresentation.visual_path(fish.fight_rod_tip,mouth,0,fish.heading,fish.size_multiplier(),fish.fight_mouth_side)
	var mesh: ImmediateMesh = line.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	for point in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
