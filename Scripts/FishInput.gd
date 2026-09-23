class_name FishInput
extends RefCounted
## Intent only. The motor never needs to read a camera, keyboard, or mouse.

var stroke_axis: float = 0 # Signed mouse-stroke intent; shares cadence with steering.
var throttle: float = 0.0 # W = +1, S = -1
var steering: float = 0.0 # A = -1, D = +1; no strafe
var vertical: float = 0.0
var boost: bool = false
var bite_held: bool = false
var cancel_bite: bool = false
var aim_direction: Vector3 = Vector3.FORWARD

func _init(p_throttle: float = 0.0, p_steering: float = 0.0, p_vertical: float = 0.0,
		p_aim: Vector3 = Vector3.FORWARD, p_boost: bool = false, p_bite: bool = false) -> void:
	throttle = clampf(p_throttle, -1.0, 1.0)
	steering = clampf(p_steering, -1.0, 1.0)
	vertical = clampf(p_vertical, -1.0, 1.0)
	aim_direction = p_aim.normalized() if p_aim.length_squared() > 0.0001 else Vector3.FORWARD
	boost = p_boost
	bite_held = p_bite

static func angles(direction: Vector3) -> Vector2:
	return Vector2(asin(clampf(direction.y, -1.0, 1.0)), atan2(-direction.x, -direction.z))

static func from_angles(pitch: float, yaw: float) -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))

static func approach_angle(current: float, target: float, step: float) -> float:
	return current + clampf(wrapf(target - current, -PI, PI), -step, step)

## Exact antiparallel directions need a chosen axis; always pick world-up yaw.
static func turn_toward(current: Vector3, target: Vector3, max_angle: float) -> Vector3:
	var angle = current.angle_to(target)
	if angle <= max_angle or angle < 0.00001:
		return target
	var axis = current.cross(target)
	if axis.length_squared() < 0.000001:
		axis = Vector3.UP - current * current.dot(Vector3.UP)
		if axis.length_squared() < 0.000001:
			axis = Vector3.RIGHT
	return current.rotated(axis.normalized(), maxf(0.0, max_angle)).normalized()

static func steer_heading(current: Vector3, intent: FishInput, yaw_rate: float,
		pitch_rate: float, manual_rate: float, pivot_multiplier: float, delta: float) -> Vector3:
	var actual = angles(current)
	var wanted = angles(intent.aim_direction)
	# Only forward throttle follows mouse aim. Reverse preserves facing.
	if intent.throttle > 0.0:
		actual.y = approach_angle(actual.y, wanted.y, deg_to_rad(yaw_rate) * delta)
		actual.x = approach_angle(actual.x, wanted.x, deg_to_rad(pitch_rate) * delta)
	var assist = 1.0 if intent.throttle > 0.0 else pivot_multiplier
	actual.y -= intent.steering * deg_to_rad(manual_rate) * assist * delta
	actual.x = clampf(actual.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	return from_angles(actual.x, actual.y)

static func next_velocity(current: Vector3, heading: Vector3, intent: FishInput,
		speed: float, boost_multiplier: float, reverse_multiplier: float,
		acceleration: float, reverse_acceleration: float, drag: float,
		vertical_multiplier: float, delta: float) -> Vector3:
	var propulsion = intent.throttle
	if propulsion < 0.0:
		propulsion *= reverse_multiplier
	elif intent.boost:
		propulsion *= boost_multiplier
	var target = (heading * propulsion + Vector3.UP * intent.vertical * vertical_multiplier)
	var cap = boost_multiplier if intent.boost and intent.throttle > 0.0 else 1.0
	if intent.throttle < 0.0:
		cap = maxf(reverse_multiplier, absf(intent.vertical) * vertical_multiplier)
	target = target.limit_length(cap) * speed
	var rate = reverse_acceleration if intent.throttle < 0.0 else acceleration
	if target.length_squared() < 0.0001:
		rate = drag
	return current.move_toward(target, rate * delta)
