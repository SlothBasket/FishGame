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
	var fish_view = false
	for subject in get_tree().get_nodes_in_group("fish_line_subjects"):
		if subject.camera.current: fish_view = true; break
	visible = enabled and fish_view and fish.fight_active
	if not visible: return
	shown_tension = lerpf(shown_tension,fish.fight_tension_ratio,1-exp(-delta/0.12))
	material.albedo_color = FishingPresentation.tension_color(shown_tension)
	var side = (fish.fight_rod_tip-fish.mouth_position()).normalized().dot(fish.heading.cross(Vector3.UP))
	if absf(side) > 0.2: flare_side = signf(side)
	var points = FishingPresentation.visual_path(fish.fight_rod_tip,fish.mouth_position(),0,fish.heading,fish.size_multiplier(),flare_side)
	var mesh: ImmediateMesh = line.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	for point in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
