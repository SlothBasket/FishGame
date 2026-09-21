class_name BaitHabitat
extends RefCounted
## Replace this provider for irregular level volumes. AI only receives valid points.
var bounds: AABB
var kind: int
var constrain_point: Callable

func _init(area: AABB, species: int, constraint: Callable) -> void:
	bounds = area
	kind = species
	constrain_point = constraint

func constrain(point: Vector3) -> Vector3:
	var bounded = Vector3(clampf(point.x,bounds.position.x,bounds.end.x),
		clampf(point.y,bounds.position.y,bounds.end.y),clampf(point.z,bounds.position.z,bounds.end.z))
	return constrain_point.call(bounded,kind)

func destination(origin: Vector3, direction: Vector3, rng: RandomNumberGenerator, anchors: Array) -> Vector3:
	var best = origin
	var best_score: float = -INF
	var seek_space = rng.randf() < 0.35
	for i in range(4):
		var candidate = bounds.position + Vector3(rng.randf(),rng.randf(),rng.randf())*bounds.size
		candidate = constrain(candidate)
		var travel = BaitMotion.horizontal(candidate-origin)
		var score = travel.dot(direction)*20.0 + rng.randf()*8.0
		if seek_space:
			var nearest: float = 80.0
			for anchor in anchors:
				if anchor.center.distance_squared_to(origin) < 0.01: continue
				nearest = minf(nearest,candidate.distance_to(anchor.center))
			score += nearest
		if score > best_score:
			best = candidate
			best_score = score
	return best
