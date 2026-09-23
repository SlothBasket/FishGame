class_name RodGesture
extends Resource
## Samples authoritative smoothed rod positions, not buttons or device events.
enum Direction { NONE, LEFT, RIGHT, UP }
@export var minimum_displacement: float = 0.55
@export var minimum_velocity: float = 2.4
@export var maximum_window: float = 0.24
@export var ending_position: float = 0.6
var samples: Array[Vector3] = []
var clock: float = 0
func step(delta: float, rod: Vector2, enabled: bool) -> int:
	clock += delta
	if not enabled:
		samples.clear()
		samples.append(Vector3(rod.x,rod.y,clock))
		return Direction.NONE
	while not samples.is_empty() and clock-samples[0].z > maximum_window: samples.pop_front()
	var result = Direction.NONE
	for sample in samples:
		var span = maxf(0.001,clock-sample.z)
		var motion = rod-Vector2(sample.x,sample.y)
		if absf(motion.x) >= minimum_displacement and absf(motion.x)/span >= minimum_velocity and absf(rod.x) >= ending_position and signf(motion.x) == signf(rod.x):
			result = Direction.LEFT if motion.x < 0 else Direction.RIGHT
		if motion.y >= minimum_displacement and motion.y/span >= minimum_velocity and rod.y >= ending_position and motion.y > absf(motion.x): result = Direction.UP
	if result != Direction.NONE: samples.clear()
	samples.append(Vector3(rod.x,rod.y,clock))
	return result
static func caption(direction: int) -> String:
	return ["","JERK LEFT!","JERK RIGHT!","JERK UP!"][clampi(direction,0,3)]
