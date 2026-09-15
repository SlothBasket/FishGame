class_name BaitMotion
extends RefCounted
## The same small command vocabulary drives live prey and future player lures.

enum Kind { MINNOW, SHRIMP, SQUID, CRAB, JERKBAIT, JIG, MULLET, GULL }
enum Source { LIVE, FISHERMAN }
enum Action { PAUSE, CRUISE, BURST, GLIDE, HOVER, SINK, RISE, DART, JERK, JIG_UP, FALL, CRAWL }
enum IdleAction { NONE, LOOK, QUIVER, FAN, REST }

# Both drivers use this profile: powered travel rises gently, slack glides down.
static func horizontal(direction: Vector3) -> Vector3:
	var flat = Vector3(direction.x, 0, direction.z)
	return flat.normalized() if flat.length_squared() > 0.001 else Vector3.FORWARD

static func swimming(direction: Vector3, effort: float) -> BaitCommand:
	return BaitCommand.new(horizontal(direction), effort, 0, Action.CRUISE)

static func gliding(direction: Vector3) -> BaitCommand:
	return BaitCommand.new(horizontal(direction), 0.25, 0, Action.GLIDE)

class BaitCommand:
	extends RefCounted
	var flee_fraction: float = -1.0
	var descend: bool = false
	var arrival_velocity: Vector3 = Vector3.ZERO
	var arriving: bool = false
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
	var escape_held: bool = false
	var _escape_was_held: bool = false
	var _escape_charge: float = 0.0
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
	var maximum_line_distance: float = 120.0
	var _jerk_side: float = 1.0
	var _impulse_time: float = 0.0
	var _impulse_action: Action = Action.PAUSE
	var _travel_direction: Vector3 = Vector3.FORWARD
	var cast_direction: Vector3 = Vector3.ZERO
	var steering_limit_degrees: float = 40.0
	func _init(p_anchor: Vector3 = Vector3.ZERO) -> void:
		anchor_position = p_anchor
	func sample(bait, delta: float) -> BaitCommand:
		if escape_held and bait.flee_recovery <= 0:
			_escape_charge = minf(bait.flee_charge_time, _escape_charge + delta)
		var released = _escape_was_held and not escape_held
		_escape_was_held = escape_held
		if released:
			var cmd = BaitCommand.new(Vector3.UP if bait.kind == Kind.JIG else BaitMotion.horizontal(bait.heading))
			cmd.flee_fraction = _escape_charge / maxf(0.01, bait.flee_charge_time)
			_escape_charge = 0.0
			return cmd
		if cast_direction == Vector3.ZERO:
			cast_direction = BaitMotion.horizontal(anchor_position - bait.global_position)
		var offset: Vector3 = anchor_position - bait.global_position
		var distance = Vector2(offset.x, offset.z).length()
		var toward = BaitMotion.horizontal(offset) if distance > 0.2 else cast_direction
		if retrieve_input > 0.01 and distance < 6.0:
			var arrival = BaitCommand.new(toward, 0.0)
			arrival.arriving = true
			arrival.arrival_velocity = Vector3(offset.x, offset.y - 0.65, offset.z).limit_length(bait.swim_speed) * retrieve_input
			return arrival
		# Rod deflection is absolute, not cumulative. Passing the origin cannot reverse it.
		_travel_direction = toward.rotated(Vector3.UP, -clampf(steer_input, -1, 1) * deg_to_rad(steering_limit_degrees) * clampf(distance / 12.0, 0, 1))
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
				if bait.kind == Kind.CRAB:
					return BaitCommand.new(toward.cross(Vector3.UP) * _jerk_side, jig_strength, 1.0, Action.DART)
				return BaitCommand.new(_travel_direction, jig_strength, 1.0, Action.JIG_UP)
			var lateral = toward.cross(Vector3.UP).normalized() * _jerk_side
			return BaitCommand.new((toward * 0.3 + lateral).normalized(), jerk_strength, 1.0, Action.JERK)
		if retrieve_input > 0.01:
			return BaitMotion.swimming(_travel_direction, retrieve_input * retrieve_speed)
		return BaitMotion.gliding(_travel_direction)

## Human organism inputs; AI also translates its decisions through this driver.
class PlayerLiveDriver:
	extends IBaitDriver
	var anchor_position: Vector3 = Vector3.ZERO
	var use_anchor: bool = false
	var steering_limit_degrees: float = 40.0
	var throttle: float = 0.0
	var steering: float = 0.0
	var descend: bool = false
	var rise: bool = false
	var escape_held: bool = false
	var escape_side: float = 1.0
	var charge: float = 0.0
	var _held: bool = false
	func sample(bait, delta: float) -> BaitCommand:
		var bearing = BaitMotion.horizontal(anchor_position - bait.global_position) if use_anchor else BaitMotion.horizontal(bait.heading)
		var direction = bearing.rotated(Vector3.UP, -clampf(steering, -1, 1) * deg_to_rad(steering_limit_degrees))
		var cmd = BaitMotion.swimming(direction, throttle) if throttle > 0 else BaitMotion.gliding(direction)
		cmd.descend = descend
		var to_anchor: Vector3 = anchor_position - bait.global_position
		if use_anchor and throttle > 0 and not descend and not rise and Vector2(to_anchor.x, to_anchor.z).length() < 6.0:
			cmd.arriving = true
			cmd.arrival_velocity = Vector3(to_anchor.x, to_anchor.y - 0.65, to_anchor.z).limit_length(bait.swim_speed)
		if rise: cmd.action = Action.RISE; cmd.effort = 1.0
		if escape_held and bait.flee_recovery <= 0.0:
			charge = minf(bait.flee_charge_time, charge + delta)
		elif _held and not escape_held:
			cmd.flee_fraction = clampf(charge / maxf(0.01, bait.flee_charge_time), 0, 1)
			cmd.direction = direction
			if bait.kind == Kind.SQUID: cmd.direction = Vector3.DOWN if descend else Vector3.UP
			if bait.kind == Kind.CRAB: cmd.direction = BaitMotion.horizontal(bait.heading).cross(Vector3.UP) * escape_side
			charge = 0.0
		_held = escape_held
		return cmd
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
	var _sense_time: float = 0.0
	var flee_trigger_distance: float = 14.0
	var ai_charge_min: float = 0.12
	var ai_charge_max: float = 1.0
	var _pending_flee: float = -1.0
	var _escape_direction: Vector3
	var escape_interval_min: float = 2.5
	var escape_interval_max: float = 6.0
	var mullet_threat_distance: float = 20.0
	var peer_trigger_distance: float = 1.7
	var peer_recovery_time: float = 9.0
	var _peer_recovery: float = 0.0
	var _threat: bool = false
	var _threat_direction: Vector3 = Vector3.FORWARD
	var sense_interval: float = 0.3
	var _escape_clock: float = 1.0
	var _charging_escape: bool = false
	var _random_charge: float = 0.5
	var _pulse_clock: float = 0.0
	var _turn_clock: float = 0.0
	var _mullet_dive: float = 0.0
	var _mullet_dive_wait: float = 7.0
	var controls = PlayerLiveDriver.new()
	var shelter_enabled: bool = false
	var shelter: RockShelter
	var shelter_wait: float = 5.0
	var shelter_remaining: float = 0.0
	var shelter_linger: float = 0.0

	func _init(p_home: Vector3 = Vector3.ZERO, seed_value: int = -1, p_radius: float = 28.0, p_depth_band: float = 5.0) -> void:
		home = p_home
		preferred_y = p_home.y
		roam_radius = p_radius
		depth_band = p_depth_band
		if seed_value < 0:
			rng.randomize()
		else:
			rng.seed = seed_value
		_escape_clock = rng.randf_range(escape_interval_min, escape_interval_max)
		_sense_time = rng.randf_range(0.0, sense_interval)
		_mullet_dive_wait = rng.randf_range(5.0, 15.0)
		_pulse_clock = rng.randf_range(0, TAU)
		shelter_wait = rng.randf_range(3, 12)

	func sample(bait, delta: float) -> BaitCommand:
		_remaining -= delta
		_turn_clock -= delta
		_mullet_dive_wait -= delta
		_mullet_dive = maxf(0.0, _mullet_dive - delta)
		if bait.kind == Kind.MULLET and _mullet_dive_wait <= 0 and not bait.airborne:
			_mullet_dive = rng.randf_range(3.0, 5.0)
			_mullet_dive_wait = rng.randf_range(12.0, 22.0)
		if _turn_clock <= 0:
			_turn_clock = rng.randf_range(0.6, 1.8)
			_direction = BaitMotion.horizontal(bait.heading).rotated(Vector3.UP, rng.randf_range(-0.65, 0.65))
		_sense_time -= delta
		_peer_recovery = maxf(0.0, _peer_recovery - delta)
		if _sense_time <= 0.0:
			_sense_time = sense_interval
			_threat = false
			for predator in bait.get_tree().get_nodes_in_group("fish_predators"):
				var away: Vector3 = bait.global_position - predator.global_position
				if away.length() < (mullet_threat_distance if bait.kind == Kind.MULLET else flee_trigger_distance):
					_threat = true
					_threat_direction = away.normalized()
					break
			if not _threat and _peer_recovery <= 0.0:
				for peer in bait.get_tree().get_nodes_in_group("bait"):
					if peer == bait or peer.claimed or peer.flee_remaining <= 0: continue
					if bait.global_position.distance_squared_to(peer.global_position) < peer_trigger_distance * peer_trigger_distance:
						_escape_clock = minf(_escape_clock, 0.25)
						_peer_recovery = peer_recovery_time
						break
			var start: Vector3 = bait.global_position + Vector3.UP * 0.2
			var ray = PhysicsRayQueryParameters3D.create(start, start + bait.heading * 2.0, 1)
			var wall = bait.get_world_3d().direct_space_state.intersect_ray(ray)
			if not wall.is_empty():
				_direction = (bait.heading.bounce(wall.normal) + Vector3.UP * 0.2).normalized()
				_effort = 0.7
				_remaining = 0.6
		if _remaining <= 0.0:
			choose_behavior(bait)
		var cmd = BaitCommand.new(_direction, _effort, _twitch, _action)
		if _action in [Action.GLIDE, Action.FALL, Action.HOVER] and bait.kind != Kind.CRAB:
			cmd = BaitMotion.gliding(_direction)
		cmd.descend = _mullet_dive > 0 or state == "descending" or (bait.kind == Kind.SQUID and state == "drop")
		_escape_clock -= delta
		_pulse_clock += delta
		# The shared motor now owns squid pulses; players get the same push/coast rhythm.
		cmd = shelter_intent(bait, cmd, delta)
		var threat = _threat
		var escape_direction = _threat_direction if threat else BaitMotion.horizontal(bait.heading)
		if bait.flee_recovery <= 0 and not bait.airborne and _mullet_dive <= 0 and (threat or shelter_linger <= 0):
			if threat:
				cmd.flee_fraction = rng.randf_range(0.5, ai_charge_max)
			elif _escape_clock <= 0:
				if not _charging_escape:
					_random_charge = rng.randf_range(maxf(0.3, ai_charge_min), ai_charge_max)
					_escape_clock = _random_charge * bait.flee_charge_time
					_charging_escape = true
				else:
					cmd.flee_fraction = _random_charge
			if cmd.flee_fraction >= 0:
				if not threat and bait.kind == Kind.SQUID:
					escape_direction = Vector3.DOWN if rng.randf() < 0.45 else Vector3.UP
				cmd.direction = escape_direction
				_charging_escape = false
				_escape_clock = rng.randf_range(escape_interval_min, escape_interval_max)
		return player_reproducible_command(bait, cmd, delta)

	func player_reproducible_command(bait, intent: BaitCommand, delta: float) -> BaitCommand:
		# AI can choose a destination, but cannot exceed the player's local steering cone.
		var flat = BaitMotion.horizontal(bait.heading)
		var desired = BaitMotion.horizontal(intent.direction)
		controls.steering = clampf(-flat.signed_angle_to(desired, Vector3.UP) / deg_to_rad(controls.steering_limit_degrees), -1, 1)
		controls.throttle = intent.effort if intent.action in [Action.CRUISE, Action.CRAWL, Action.BURST] else 0.0
		controls.rise = intent.action == Action.RISE
		controls.descend = intent.descend
		var result = controls.sample(bait, delta)
		result.flee_fraction = intent.flee_fraction
		if result.flee_fraction >= 0:
			if bait.kind == Kind.SQUID: result.direction = Vector3.DOWN if intent.direction.y < 0 else Vector3.UP
			elif bait.kind == Kind.CRAB:
				var side = flat.cross(Vector3.UP)
				result.direction = side if side.dot(desired) >= 0 else -side
		return result

	func shelter_intent(bait, cmd: BaitCommand, delta: float) -> BaitCommand:
		if not shelter_enabled: return cmd
		shelter_wait -= delta
		if is_instance_valid(shelter):
			shelter_remaining -= delta
			if _threat or shelter_remaining <= 0:
				shelter.release(bait)
				shelter = null
				shelter_linger = 0
				shelter_wait = rng.randf_range(18, 30)
				return cmd
		elif shelter_wait <= 0 and not _threat:
			shelter_wait = rng.randf_range(10, 18)
			var nearest: RockShelter
			var distance: float = 24.0 * 24.0
			for candidate in bait.get_tree().get_nodes_in_group("rock_shelters"):
				var d: float = bait.global_position.distance_squared_to(candidate.global_position)
				if d < distance and not candidate.occupied():
					nearest = candidate
					distance = d
			if nearest != null and nearest.reserve(bait):
				shelter = nearest
				shelter_remaining = 16.0
		if not is_instance_valid(shelter): return cmd
		var offset: Vector3 = shelter.spot - bait.global_position
		if offset.length() < 1.6 or shelter_linger > 0:
			shelter_linger += delta
			if shelter_linger > 4: shelter_remaining = 0
			return BaitMotion.gliding(bait.heading)
		var seek = BaitMotion.swimming(offset, 0.65)
		seek.descend = offset.y < -1.0
		if offset.y > 1.0: seek.action = Action.RISE
		return seek

	func choose_behavior(bait) -> void:
		var previous = state
		var roll = rng.randf()
		_direction = BaitMotion.horizontal(bait.heading).rotated(Vector3.UP, rng.randf_range(-0.22, 0.22))
		_twitch = 0.0
		_effort = rng.randf_range(0.65, 0.95)
		_duration = rng.randf_range(2.0, 4.0)
		match bait.kind:
			Kind.MINNOW:
				# Alternating longer strokes/glides make readable shallow rise/fall.
				state = "coast" if previous == "cruise" else "cruise"
				_action = Action.GLIDE if state == "coast" else Action.CRUISE
				_duration = rng.randf_range(3.0, 6.0)
				if home.y > 29.0 and bait.global_position.y > 2.0:
					state = "descending"
					_action = Action.GLIDE
				elif bait.global_position.y < 2.0:
					_action = Action.CRUISE
			Kind.SHRIMP:
				state = "coast" if previous == "scoot" else "scoot"
				_action = Action.GLIDE if state == "coast" else Action.CRUISE
				_duration = rng.randf_range(1.0, 2.5)
			Kind.SQUID:
				state = "drop" if previous == "rise" else "rise"
				_action = Action.GLIDE if state == "drop" else Action.CRUISE
				_duration = rng.randf_range(2.0, 4.0)
			Kind.MULLET:
				state = "cruise" if roll < 0.7 else "coast"
				_action = Action.CRUISE if state == "cruise" else Action.GLIDE
				_duration = rng.randf_range(3.0, 7.0)
			Kind.CRAB:
				state = "rest" if roll < 0.35 else "crawl"
				_action = Action.GLIDE if state == "rest" else Action.CRUISE
				_effort = 0.0 if state == "rest" else 0.7
			_:
				_action = Action.CRUISE
		var offset: Vector3 = home - bait.global_position
		if Vector2(offset.x, offset.z).length() > roam_radius:
			_direction = BaitMotion.horizontal(offset)
		if bait.kind in [Kind.SQUID, Kind.MINNOW] and home.y <= 29.0:
			if bait.global_position.y < maxf(2.0, preferred_y - depth_band): _action = Action.CRUISE
			if bait.global_position.y > preferred_y + depth_band: _action = Action.GLIDE
		if bait.kind == Kind.SQUID:
			if bait.global_position.y < 2.0: _action = Action.CRUISE
			if bait.global_position.y > 29.0: _action = Action.GLIDE
		_remaining = _duration
