class_name BaitMotion
extends RefCounted
## The same small command vocabulary drives live prey and future player lures.

enum Kind { MINNOW, SHRIMP, SQUID, CRAB, MULLET, GULL }
enum Source { LIVE, FISHERMAN }
enum Action { PAUSE, CRUISE, GLIDE, RISE }

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
	func _init(p_direction: Vector3 = Vector3.ZERO, p_effort: float = 0.0, p_twitch: float = 0.0,
			p_action: Action = Action.PAUSE) -> void:
		direction = p_direction.limit_length()
		effort = clampf(p_effort, 0.0, 1.0)
		twitch = clampf(p_twitch, 0.0, 1.0)
		action = p_action

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

## Human organism inputs; AI also translates its decisions through this driver.
class PlayerLiveDriver:
	extends IBaitDriver
	var anchor_position: Vector3 = Vector3.ZERO
	var use_anchor: bool = false
	var steering_limit_degrees: float = 45.0
	var throttle: float = 0.0
	var steering: float = 0.0
	var descend: bool = false
	var rise: bool = false
	var escape_held: bool = false
	var escape_side: float = 1.0
	var charge: float = 0.0
	var _held: bool = false
	var _pending_escape: BaitCommand
	var squid_axis: Vector3 = Vector3.FORWARD
	var aim_direction: Vector3 = Vector3.ZERO
	var squid_manual_jets: bool = true
	var _vertical_held: int = 0
	func sample(bait, delta: float) -> BaitCommand:
		var bearing = BaitMotion.horizontal(anchor_position - bait.global_position) if use_anchor else BaitMotion.horizontal(bait.heading)
		var direction = bearing.rotated(Vector3.UP, -clampf(steering, -1, 1) * deg_to_rad(steering_limit_degrees))
		var cmd = BaitMotion.swimming(direction, throttle) if throttle > 0 else BaitMotion.gliding(direction)
		cmd.descend = descend and (bait.kind != Kind.SQUID or not squid_manual_jets)
		if bait.kind == Kind.SQUID and squid_manual_jets and throttle > 0: cmd.effort *= 0.3
		var to_anchor: Vector3 = anchor_position - bait.global_position
		if use_anchor and throttle > 0 and not descend and not rise and Vector2(to_anchor.x, to_anchor.z).length() < 6.0:
			cmd.arriving = true
			cmd.arrival_velocity = Vector3(to_anchor.x, to_anchor.y - 0.65, to_anchor.z).limit_length(bait.swim_speed)
		if bait.kind == Kind.SQUID and squid_manual_jets and cmd.arriving: cmd.arrival_velocity = cmd.arrival_velocity.limit_length(0.9)
		if rise and (bait.kind != Kind.SQUID or not squid_manual_jets): cmd.action = Action.RISE; cmd.effort = 1.0
		var vertical = -1 if descend else 1 if rise else 0
		if bait.kind == Kind.SQUID and squid_manual_jets and vertical != 0 and vertical != _vertical_held and not escape_held and not _held:
			_pending_escape = BaitCommand.new(Vector3.UP * vertical)
			_pending_escape.set_meta("fraction", 0.65)
		_vertical_held = vertical
		if escape_held:
			charge = minf(bait.flee_charge_time, charge + delta)
		elif _held and not escape_held:
			cmd.flee_fraction = clampf(charge / maxf(0.01, bait.flee_charge_time), 0, 1)
			cmd.direction = direction
			if bait.kind == Kind.SQUID:
				cmd.direction = Vector3.DOWN if descend else Vector3.UP if rise else aim_direction.normalized() if aim_direction.length_squared() > 0.01 else squid_axis.cross(Vector3.UP) * (-1.0 if steering < 0 else 1.0)
			if bait.kind == Kind.CRAB: cmd.direction = BaitMotion.horizontal(bait.heading).cross(Vector3.UP) * escape_side
			charge = 0.0
			cmd.set_meta("fraction", cmd.flee_fraction)
			_pending_escape = cmd
			cmd.flee_fraction = -1.0
		_held = escape_held
		if _pending_escape != null and bait.flee_recovery <= 0:
			cmd.flee_fraction = _pending_escape.get_meta("fraction", -1.0)
			cmd.direction = _pending_escape.direction
			_pending_escape = null
		return cmd
	func clear_input() -> void:
		throttle = 0
		steering = 0
		descend = false
		rise = false
		escape_held = false
		charge = 0
		_held = false
		_pending_escape = null
		_vertical_held = 0

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
	var _action: Action = Action.PAUSE
	var _sense_time: float = 0.0
	var flee_trigger_distance: float = 14.0
	var ai_charge_min: float = 0.12
	var ai_charge_max: float = 1.0
	var escape_interval_min: float = 3.0
	var escape_interval_max: float = 7.0
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
	var _turn_clock: float = 0.0
	var _mullet_dive: float = 0.0
	var _mullet_dive_wait: float = 7.0
	var controls = PlayerLiveDriver.new()
	var sequence_chance: float = 0.45
	var minnow_sequence_chance: float = 0.7
	var _burst_pending: bool = false
	var _burst_axis: Vector3 = Vector3.FORWARD
	var _burst_side: float = 1.0
	var _burst_strength: float = 0.5
	var _use_burst_bearing: bool = false
	var pod: BaitPod
	var pod_slot: Vector3 = Vector3.ZERO
	var scatter_remaining: float = 0.0
	var pod_separation: Vector3 = Vector3.ZERO
	var squid_floor_clearance: float = 6.0
	var pause_remaining: float = 0.0
	var pause_clock: float = 5.0
	var pause_interval_min: float = 4.0
	var pause_interval_max: float = 9.0

	func _init(p_home: Vector3 = Vector3.ZERO, seed_value: int = -1, p_radius: float = 28.0, p_depth_band: float = 5.0) -> void:
		controls.squid_manual_jets = false
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
		pause_clock = rng.randf_range(pause_interval_min, pause_interval_max)
		_mullet_dive_wait = rng.randf_range(5.0, 15.0)

	func sample(bait, delta: float) -> BaitCommand:
		scatter_remaining = maxf(0, scatter_remaining - delta)
		_use_burst_bearing = false
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
			if pod != null:
				if _threat: scatter_remaining = rng.randf_range(5, 9)
				pod_separation = pod.separation_from(bait)
			var start: Vector3 = bait.global_position + Vector3.UP * 0.2
			var ray = PhysicsRayQueryParameters3D.create(start, start + bait.heading * 2.0, 1)
			var wall = bait.get_world_3d().direct_space_state.intersect_ray(ray)
			if not wall.is_empty():
				_direction = (bait.heading.bounce(wall.normal) + Vector3.UP * 0.2).normalized()
				_effort = 0.7
				_remaining = 0.6
		if _remaining <= 0.0:
			choose_behavior(bait)
		var cmd = BaitCommand.new(_direction, _effort, 0, _action)
		if _action == Action.GLIDE and bait.kind != Kind.CRAB:
			cmd = BaitMotion.gliding(_direction)
		cmd.descend = _mullet_dive > 0 or state == "descending" or (bait.kind == Kind.SQUID and state == "drop")
		_escape_clock -= delta
		# The shared motor now owns squid pulses; players get the same push/coast rhythm.
		if pod != null and scatter_remaining <= 0 and not _threat and _mullet_dive <= 0 and not bait.airborne:
			var offset: Vector3 = pod.center + pod_slot - bait.global_position
			var pull = clampf(offset.length() / 14.0, 0.0, 0.65)
			cmd.direction = BaitMotion.horizontal(cmd.direction.lerp(BaitMotion.horizontal(offset), pull) + pod_separation)
			if offset.y > 1.8:
				cmd.action = Action.RISE
				cmd.descend = false
			elif offset.y < -1.8: cmd.descend = true
		var to_home: Vector3 = home - bait.global_position
		if Vector2(to_home.x, to_home.z).length() > roam_radius or absf(bait.position.x) > 105 or absf(bait.position.z) > 105:
			cmd.direction = BaitMotion.horizontal(to_home)
		if bait.kind == Kind.SQUID:
			if bait.position.y < maxf(bait.floor_height + squid_floor_clearance, preferred_y - depth_band):
				if state != "rise":
					state = "rise"
					_effort = maxf(_effort, 0.75)
					_action = Action.CRUISE
					_remaining = rng.randf_range(2, 4)
				cmd.action = Action.RISE
				cmd.descend = false
			elif bait.position.y > minf(bait.water_height - 2, preferred_y + depth_band):
				cmd.action = Action.GLIDE
				cmd.descend = true
		var threat = _threat
		if bait.kind == Kind.SHRIMP and threat:
			cmd.direction = BaitMotion.horizontal(_threat_direction)
		var escape_direction = _threat_direction if threat else BaitMotion.horizontal(bait.heading)
		if bait.flee_recovery <= 0 and not bait.airborne and _mullet_dive <= 0:
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
					escape_direction = [Vector3.DOWN, Vector3.UP, BaitMotion.horizontal(bait.heading).cross(Vector3.UP)][rng.randi_range(0, 2)]
				cmd.direction = escape_direction
				_charging_escape = false
				_escape_clock = rng.randf_range(escape_interval_min, escape_interval_max)
				if bait.kind in [Kind.MINNOW, Kind.SHRIMP, Kind.SQUID, Kind.CRAB]:
					var followup = _burst_pending
					if followup:
						_burst_side *= -1
						_burst_pending = false
					else:
						_burst_axis = BaitMotion.horizontal(_threat_direction) if bait.kind == Kind.SHRIMP and threat else BaitMotion.horizontal(bait.heading)
						_burst_side = -1.0 if rng.randf() < 0.5 else 1.0
						_burst_pending = rng.randf() < (minnow_sequence_chance if bait.kind == Kind.MINNOW else sequence_chance)
						_burst_strength = rng.randf_range(0.35, 0.6)
					if followup or _burst_pending:
						cmd.flee_fraction = _burst_strength
						_use_burst_bearing = true
						if bait.kind == Kind.MINNOW: cmd.direction = _burst_axis.rotated(Vector3.UP, deg_to_rad(45) * _burst_side)
						elif bait.kind in [Kind.SQUID, Kind.CRAB]: cmd.direction = _burst_axis.cross(Vector3.UP) * _burst_side
						else: cmd.direction = _burst_axis
					if _burst_pending:
						_charging_escape = true
						_random_charge = _burst_strength
						_escape_clock = bait.flee_cooldown + rng.randf_range(0.2, 0.45)
		# Hands-off pauses use the same release/glide command as the player, not a freeze.
		pause_clock -= delta
		pause_remaining = maxf(0, pause_remaining-delta)
		if pause_clock <= 0 and not threat:
			pause_remaining = rng.randf_range(0.5, 1.5)
			pause_clock = pause_remaining + rng.randf_range(pause_interval_min, pause_interval_max)
		if threat or _mullet_dive > 0: pause_remaining = 0
		if pause_remaining > 0:
			cmd = BaitMotion.gliding(bait.heading)
		return player_reproducible_command(bait, cmd, delta)

	func player_reproducible_command(bait, intent: BaitCommand, delta: float) -> BaitCommand:
		# AI can choose a destination, but cannot exceed the player's local steering cone.
		var flat = _burst_axis if _use_burst_bearing else BaitMotion.horizontal(bait.heading)
		controls.use_anchor = _use_burst_bearing
		controls.anchor_position = bait.global_position + flat * 100.0
		var desired = BaitMotion.horizontal(intent.direction)
		controls.steering = clampf(-flat.signed_angle_to(desired, Vector3.UP) / deg_to_rad(controls.steering_limit_degrees), -1, 1)
		controls.throttle = intent.effort if intent.action == Action.CRUISE else 0.0
		controls.rise = intent.action == Action.RISE
		controls.descend = intent.descend
		var result = controls.sample(bait, delta)
		result.flee_fraction = intent.flee_fraction
		if result.flee_fraction >= 0:
			if bait.kind == Kind.SQUID:
				result.direction = Vector3.DOWN if intent.direction.y < -0.5 else Vector3.UP if intent.direction.y > 0.5 else desired
				if bait.position.y < maxf(bait.floor_height + squid_floor_clearance, preferred_y - depth_band) + 1 and result.direction.y < 0: result.direction = Vector3.UP
			elif bait.kind == Kind.SHRIMP:
				result.direction = desired
			elif bait.kind == Kind.CRAB:
				var side = flat.cross(Vector3.UP)
				result.direction = side if side.dot(desired) >= 0 else -side
		return result

	func choose_behavior(bait) -> void:
		var previous = state
		var roll = rng.randf()
		_direction = BaitMotion.horizontal(bait.heading).rotated(Vector3.UP, rng.randf_range(-0.22, 0.22))
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
		_remaining = _duration
