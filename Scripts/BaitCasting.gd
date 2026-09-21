class_name BaitCasting
extends RefCounted
## Shared cast destination calculation; callers own input/state/randomness.
static func destination(origin: Vector3, aim: Vector3, half_width: float, distance: float, angle_offset: float) -> Vector3:
	var direction = BaitMotion.horizontal(aim).rotated(Vector3.UP,angle_offset)
	for axis in [0,2]:
		if absf(direction[axis]) > 0.001:
			var edge = half_width-10 if direction[axis] > 0 else -half_width+10
			distance = minf(distance,maxf(0,(edge-origin[axis])/direction[axis]))
	return origin+direction*distance-Vector3.UP*0.45
