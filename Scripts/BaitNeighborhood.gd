class_name BaitNeighborhood
extends RefCounted
## Shared spatial lookup for peer escapes; rebuilt at most ten times/second.
const CELL_SIZE: float = 8.0
var cells: Dictionary = {}
var last_frame: int = -100
func nearby_fleeing(bait) -> Array:
	var frame = Engine.get_physics_frames()
	if frame-last_frame >= 6:
		last_frame = frame
		cells.clear()
		for peer in bait.get_tree().get_nodes_in_group("bait"):
			if peer.claimed or peer.flee_remaining <= 0: continue
			var key = cell(peer.global_position)
			if not cells.has(key): cells[key] = []
			cells[key].append(weakref(peer))
	var found: Array = []
	var center = cell(bait.global_position)
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				for reference in cells.get(center+Vector3i(x,y,z),[]):
					var peer = reference.get_ref()
					if is_instance_valid(peer): found.append(peer)
	return found
func cell(where: Vector3) -> Vector3i:
	return Vector3i(floori(where.x/CELL_SIZE),floori(where.y/CELL_SIZE),floori(where.z/CELL_SIZE))
