class_name SurfaceFeedback
extends Node3D
## Bounded crossing effects. Track sides with hysteresis so floating birds do not spam splashes.
@export var water_height: float = 32.0
@export var max_effects: int = 12
var sides: Dictionary = {}
var effects: Array = []
var ring_mesh: TorusMesh
var droplet_material: StandardMaterial3D

func _ready() -> void:
	ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.94
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6
	droplet_material = Geometry.material("c5ece1")
	droplet_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _physics_process(delta: float) -> void:
	var actors = get_tree().get_nodes_in_group("bait")
	actors.append_array(get_tree().get_nodes_in_group("fish_predators"))
	var alive: Dictionary = {}
	for actor in actors:
		var id = actor.get_instance_id()
		alive[id] = true
		var height: float = actor.global_position.y - water_height
		var side = 1 if height > 0.12 else -1 if height < -0.12 else 0
		if side == 0: continue
		if sides.has(id) and sides[id] != side:
			emit_crossing(actor.global_position, actor.velocity.length())
		sides[id] = side
	for id in sides.keys():
		if not alive.has(id): sides.erase(id)
	for i in range(effects.size()-1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.age += delta
		var t: float = effect.age
		effect.ring.scale = Vector3.ONE * (0.3 + t * effect.strength)
		effect.material.albedo_color.a = maxf(0, 0.7 * (1-t/1.3))
		for j in range(effect.drops.size()):
			var angle = j * TAU / effect.drops.size()
			effect.drops[j].position = Vector3(cos(angle)*t, maxf(0, 2.2*t-4*t*t), sin(angle)*t) * effect.strength * 0.45
			effect.drops[j].visible = t < 0.55
		if t >= 1.3:
			effect.root.queue_free()
			effects.remove_at(i)

func emit_crossing(where: Vector3, speed: float) -> void:
	if effects.size() >= max_effects: return
	var root = Node3D.new()
	root.position = Vector3(where.x, water_height + 0.035, where.z)
	add_child(root)
	var ring = MeshInstance3D.new()
	ring.mesh = ring_mesh
	var mat = Geometry.material("c5ece1")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	root.add_child(ring)
	var drops: Array = []
	for i in range(5):
		drops.append(Geometry.sphere(root, "Drop", Vector3.ZERO, Vector3.ONE*0.06, droplet_material))
	effects.append({"root":root, "ring":ring, "material":mat, "drops":drops, "age":0.0, "strength":clampf(speed*0.2, 0.8, 2.5)})
