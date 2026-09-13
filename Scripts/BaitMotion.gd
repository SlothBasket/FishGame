class_name BaitMotion
extends RefCounted
## The same small command vocabulary drives live prey and future player lures.

enum Kind { MINNOW, SHRIMP, SQUID }
enum Source { LIVE, FISHERMAN }

class BaitCommand:
	extends RefCounted
	var direction: Vector3
	var effort: float
	var twitch: float
	func _init(p_direction: Vector3 = Vector3.ZERO, p_effort: float = 0.0, p_twitch: float = 0.0) -> void:
		direction = p_direction.limit_length()
		effort = clampf(p_effort, 0.0, 1.0)
		twitch = clampf(p_twitch, 0.0, 1.0)

# GDScript uses a base class in place of C#'s interface.
class IBaitDriver:
	extends RefCounted
	func sample(_bait, _delta: float) -> BaitCommand:
		return BaitCommand.new()

class ControlledBaitDriver:
	extends IBaitDriver
	var command = BaitCommand.new()
	func sample(_bait, _delta: float) -> BaitCommand:
		return command

class LiveBaitDriver:
	extends IBaitDriver
	var home: Vector3
	var roam_radius: float
	var rng = RandomNumberGenerator.new()
	var state: String = "coast"
	var _remaining: float = 0.0
	var _duration: float = 1.0
	var _direction: Vector3 = Vector3.FORWARD
	var _effort: float = 0.0
	var _twitch: float = 0.0

	func _init(p_home: Vector3 = Vector3.ZERO, seed_value: int = -1, p_radius: float = 12.0) -> void:
		home = p_home
		roam_radius = p_radius
		if seed_value < 0:
			rng.randomize()
		else:
			rng.seed = seed_value

	func sample(bait, delta: float) -> BaitCommand:
		_remaining -= delta
		if _remaining <= 0.0:
			choose_behavior(bait)
		# Bursts decay into a glide, using commands also available to controlled bait.
		var pulse = clampf(_remaining / _duration, 0.0, 1.0)
		return BaitCommand.new(_direction, _effort * (pulse if _twitch > 0.0 else 1.0), _twitch * pulse)

	func choose_behavior(bait) -> void:
		var roll = rng.randf()
		match bait.kind:
			Kind.MINNOW:
				state = "cruise" if roll < 0.65 else "coast" if roll < 0.85 else "burst"
			Kind.SHRIMP:
				state = "hover" if roll < 0.7 else "kick"
			Kind.SQUID:
				state = "glide" if roll < 0.65 else "pulse"
		_twitch = 0.0
		match state:
			"cruise":
				_duration = rng.randf_range(1.3, 3.8)
				_effort = rng.randf_range(0.4, 0.7)
			"coast", "hover", "glide":
				_duration = rng.randf_range(1.0, 3.2)
				_effort = rng.randf_range(0.03, 0.22)
			_:
				_duration = rng.randf_range(0.25, 0.75)
				_effort = rng.randf_range(0.75, 1.0)
				_twitch = rng.randf_range(0.65, 1.0)
		_remaining = _duration
		var yaw = rng.randf_range(-1.1, 1.1)
		if state == "kick":
			yaw = rng.randf_range(-PI, PI)
		_direction = bait.heading.rotated(Vector3.UP, yaw)
		_direction.y = rng.randf_range(-0.25, 0.25)
		var offset: Vector3 = home - bait.global_position
		# Soft return on the next decision, never an orbit or teleport.
		if offset.length() > roam_radius:
			_direction = (_direction * 0.2 + offset.normalized()).normalized()
			_effort = maxf(_effort, 0.45)
		if absf(offset.y) > 2.0:
			_direction.y = signf(offset.y) * 0.35
		_direction = _direction.normalized()
