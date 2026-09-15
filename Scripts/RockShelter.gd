class_name RockShelter
extends Node3D
## One guest per rock, with a small global cap. Reservations cannot keep bait alive.
@export var radius: float = 4.0
@export var max_guests: int = 6
var guest: WeakRef
var spot: Vector3

func _ready() -> void:
	add_to_group("rock_shelters")

func occupied() -> bool:
	var actor = guest.get_ref() if guest != null else null
	return is_instance_valid(actor) and not actor.claimed

func reserve(actor) -> bool:
	if occupied(): return false
	var count = 0
	for shelter in get_tree().get_nodes_in_group("rock_shelters"):
		if shelter.occupied(): count += 1
	if count >= max_guests: return false
	# Try the near-side skirt first; reject spots covered by a neighboring rock.
	var approach = BaitMotion.horizontal(actor.global_position - global_position)
	var found = false
	for angle in [0.0, 0.7, -0.7, 1.4, -1.4]:
		var candidate = global_position + approach.rotated(Vector3.UP, angle) * radius
		var ray = PhysicsRayQueryParameters3D.create(Vector3(candidate.x, actor.water_height - 1, candidate.z), Vector3(candidate.x, -2, candidate.z), 1)
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.position.y > 0.2: continue
		spot = candidate
		spot.y = 0.5 if actor.kind == BaitMotion.Kind.MINNOW else actor.bottom_clearance + 0.05
		found = true
		break
	if not found: return false
	guest = weakref(actor)
	return true

func release(actor) -> void:
	if guest != null and guest.get_ref() == actor: guest = null
