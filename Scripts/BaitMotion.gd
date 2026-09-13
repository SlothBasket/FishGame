class_name BaitMotion
extends RefCounted
## The same small command vocabulary drives live prey and future player lures.

enum Kind { MINNOW, SHRIMP, SQUID, CRAB, JERKBAIT, JIG }
enum Source { LIVE, FISHERMAN }
enum Action { PAUSE, CRUISE, BURST, GLIDE, HOVER, SINK, RISE, DART, JERK, JIG_UP, FALL, CRAWL }
enum IdleAction { NONE, LOOK, QUIVER, FAN, REST }

class BaitCommand:
	extends RefCounted
	var direction: Vector3
	var effort: float
	var twitch: float
	var action: Action
	var idle_action: IdleAction
	func _init(p_direction: Vector3 = Vector3.ZERO, p_effort: float = 0.0, p_twitch: float = 0.0,
			p_action: Action = Action.PAUSE, p_idle: IdleAction = IdleAction.NONE) -> void:
		direction = p_direction.limit_length()
		effort = clampf(p_effort, 0.0, 1.0)
		twitch = clampf(p_twitch, 0.0, 1.0)
		action = p_action
		idle_action = p_idle

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

## A configurable artificial-lure driver. A later rod/network layer only has to
## set anchor_position and these intent inputs; it never writes actor velocity.
class FishingBaitDriver:
	extends IBaitDriver
	var anchor_position: Vector3
	var retrieve_input: float = 0.0
	var steer_input: float = 0.0
	var jerk_pressed: bool = false
	var jig_pressed: bool = false
	var idle_action: IdleAction = IdleAction.NONE
	var retrieve_speed: float = 1.0
	var pause_vertical_rate: float = -0.35
	var retrieve_vertical_influence: float = 0.1
	var jerk_strength: float = 1.0
	var jerk_side_angle: float = 38.0
	var jig_strength: float = 1.0
	var maximum_line_distance: float = 32.0
	var _jerk_side: float = 1.0
	var _impulse_time: float = 0.0
	var _impulse_action: Action = Action.PAUSE
	func _init(p_anchor: Vector3 = Vector3.ZERO) -> void:
		anchor_position = p_anchor
	func sample(bait, delta: float) -> BaitCommand:
		var to_anchor: Vector3 = anchor_position - bait.global_position
		var toward = to_anchor.normalized() if to_anchor.length_squared() > 0.001 else Vector3.UP
		if jerk_pressed:
			jerk_pressed = false
			_jerk_side *= -1.0
			_impulse_time = 0.28
			_impulse_action = Action.JERK
		if jig_pressed:
			jig_pressed = false
			_impulse_time = 0.38
			_impulse_action = Action.JIG_UP
		if _impulse_time > 0.0:
			_impulse_time -= delta
			if _impulse_action == Action.JIG_UP:
				return BaitCommand.new((toward * 0.35 + Vector3.UP).normalized(), jig_strength, 1.0, Action.JIG_UP, idle_action)
			var lateral = toward.cross(Vector3.UP).normalized() * _jerk_side
			return BaitCommand.new((toward + lateral * sin(deg_to_rad(jerk_side_angle)) + Vector3.UP * steer_input * 0.18).normalized(), jerk_strength, 1.0, Action.JERK, idle_action)
		if retrieve_input > 0.01:
			return BaitCommand.new((toward + Vector3.UP * retrieve_vertical_influence * retrieve_input).normalized(), retrieve_input * retrieve_speed, 0.0, Action.CRUISE, idle_action)
		if to_anchor.length() > maximum_line_distance:
			return BaitCommand.new(toward, 0.45, 0.0, Action.GLIDE, idle_action)
		var vertical = Vector3.UP * signf(pause_vertical_rate)
		var action = Action.RISE if pause_vertical_rate > 0 else Action.FALL if pause_vertical_rate < 0 else Action.HOVER
		return BaitCommand.new(vertical, absf(pause_vertical_rate), 0.0, action, idle_action)

class LiveBaitDriver:
	extends IBaitDriver
	var home: Vector3
	var roam_radius: float
	var preferred_y: float
	var depth_band: float
	var rng = RandomNumberGenerator.new()
	var state: String = "coast"
	var _remaining: float = 0.0
	var _duration: float = 1.0
	var _direction: Vector3 = Vector3.FORWARD
	var _effort: float = 0.0
	var _twitch: float = 0.0
	var _action: Action = Action.PAUSE
	var _idle: IdleAction = IdleAction.NONE

	func _init(p_home: Vector3 = Vector3.ZERO, seed_value: int = -1, p_radius: float = 28.0, p_depth_band: float = 5.0) -> void:
		home = p_home
		preferred_y = p_home.y
		roam_radius = p_radius
		depth_band = p_depth_band
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
		return BaitCommand.new(_direction, _effort * (pulse if _twitch > 0.0 else 1.0), _twitch * pulse, _action, _idle)

	func choose_behavior(bait) -> void:
		var roll = rng.randf()
		match bait.kind:
			Kind.MINNOW:
				state = "cruise" if roll < 0.65 else "coast" if roll < 0.85 else "burst"
			Kind.SHRIMP:
				state = "hover" if roll < 0.7 else "kick"
			Kind.SQUID:
				state = "glide" if roll < 0.45 else "hover" if roll < 0.68 else "pulse"
			Kind.CRAB:
				state = "rest" if roll < 0.48 else "crawl" if roll < 0.86 else "scuttle"
			_:
				state = "pause"
		_twitch = 0.0
		_idle = IdleAction.NONE
		match state:
			"cruise":
				_duration = rng.randf_range(2.5, 6.0)
				_effort = rng.randf_range(0.4, 0.7)
				_action = Action.CRUISE
			"coast", "hover", "glide":
				_duration = rng.randf_range(1.0, 3.2)
				_effort = rng.randf_range(0.03, 0.22)
				_action = Action.HOVER if state == "hover" else Action.GLIDE
			"rest":
				_duration = rng.randf_range(1.0, 3.5)
				_effort = 0.0
				_action = Action.PAUSE
				_idle = [IdleAction.LOOK, IdleAction.FAN, IdleAction.REST][rng.randi_range(0, 2)]
			"crawl", "scuttle":
				_duration = rng.randf_range(0.4, 3.0)
				_effort = rng.randf_range(0.25, 0.5) if state == "crawl" else rng.randf_range(0.8, 1.0)
				_action = Action.CRAWL
				_twitch = 0.0 if state == "crawl" else 0.8
			_:
				_duration = rng.randf_range(0.25, 0.75)
				_effort = rng.randf_range(0.75, 1.0)
				_twitch = rng.randf_range(0.65, 1.0)
				_action = Action.BURST
		_remaining = _duration
		var yaw = rng.randf_range(-1.1, 1.1)
		if state == "kick":
			yaw = rng.randf_range(-PI, PI)
		_direction = bait.heading.rotated(Vector3.UP, yaw)
		_direction.y = 0.0 if bait.kind == Kind.CRAB else rng.randf_range(-0.25, 0.25)
		if state == "kick": _direction.y = rng.randf_range(0.3, 0.65)
		var offset: Vector3 = home - bait.global_position
		# Soft return on the next decision, never an orbit or teleport.
		if offset.length() > roam_radius:
			_direction = (_direction * 0.2 + offset.normalized()).normalized()
			_effort = maxf(_effort, 0.45)
		if bait.kind != Kind.CRAB and absf(bait.global_position.y - preferred_y) > depth_band:
			_direction.y = signf(preferred_y - bait.global_position.y) * 0.4
		_direction = _direction.normalized()
