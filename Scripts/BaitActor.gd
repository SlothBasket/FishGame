class_name BaitActor
extends CharacterBody3D
## Both drivers obey this motor. The renderer never sees source (live/fisherman).

var fisher_owner
var hook_held: bool = false
var network_id: int = 0
var network_replica: bool = false
signal bitten(bait, eater)
enum Lifecycle { ALIVE, DEAD_SINKING, DEAD_SETTLED, CLAIMED }
var lifecycle: Lifecycle = Lifecycle.ALIVE
@export var size_variation: float = 0.15
@export var carcass_sink_speed: float = 0.7
@export var retrieve_lift: float = 2.8
@export var minnow_prepare_limit: float = 0.55
var _prepare_fraction: float = -1.0
var _prepare_direction: Vector3 = Vector3.FORWARD
var _prepare_time: float = 0.0
var _bird_carry: float = 0.0
@export var kind: BaitMotion.Kind = BaitMotion.Kind.MINNOW
@export var source: BaitMotion.Source = BaitMotion.Source.LIVE
# Zero selects a simple species default; override these before adding a bait.
@export var swim_speed: float = 0.0
@export var acceleration: float = 0.0
@export var turn_rate: float = 0.0 # degrees/sec, applies to both AI and controlled bait
@export var body_size: float = 0.8
@export var arena_half_width: float = 132.0
@export var minimum_eater_scale: float = -1.0 # -1 selects species progression; zero disables gating.
@export var maximum_jump_chain: int = 3
var jump_chain: int = 0
var forced_dive_remaining: float = 0.0
@export var sink_speed: float = 1.0
@export var bottom_clearance: float = 0.32
@export_group("Escape and depth")
@export var flee_charge_time: float = 0.65
@export var flee_cooldown: float = 0.95
@export var minimum_flee_strength: float = 0.25
@export var maximum_flee_strength: float = 1.0
@export var dart_speed: float = 10.0
@export var shrimp_kick_speed: float = 4.5
@export var shrimp_glide_speed: float = 4.0
@export var shrimp_glide_duration: float = 1.1
var _shrimp_kick_duration: float = 0.4
var _escape_strength: float = 1.0
var _motion_age: float = 0.0
@export var squid_jet_speed: float = 5.5
@export var crab_scuttle_speed: float = 5.0
@export var powered_descent_speed: float = 2.8
@export var breach_impulse: float = 10.0
@export var airborne_gravity: float = 6.5
@export var water_height: float = 32.0
@export var surface_depth: float = 0.45
var flee_remaining: float = 0.0
var flee_recovery: float = 0.0
var flee_velocity: Vector3 = Vector3.ZERO
var airborne: bool = false
var _breaching: bool = false
var _visual_pitch: float = 0.0
@export var minnow_wiggle_speed: float = 2.2
@export var minnow_wiggle_frequency: float = 12.0
var _escape_axis: Vector3
var _escape_age: float = 0.0
var entry_remaining: float = 0.0
var cast_remaining: float = 0.0
var cast_gravity: float = 14.0
var cast_windup: float = 0.0
var cast_windup_duration: float = 0.28
var cast_origin: Vector3
var cast_launch_velocity: Vector3
@export var squid_roam_radius: float = 8.4
@export var tether_stiffness: float = 4.0
@export var tether_damping: float = 2.0
@export var tether_recovery_extension: float = 1.4
@export var tether_recovery_duration: float = 0.8
@export var tether_safety_extension: float = 6.0
var tether_recovery: float = 0.0
var floor_height: float = 0.0
var _floor_scan: float = 0.0
var cast_destination: Vector3
var _visual_yaw: float = 0.0
@export var ai_decision_interval: float = 1.0/15.0
var _ai_wait: float = 0.0
var _ai_elapsed: float = 0.0
var _ai_command: BaitMotion.BaitCommand
var neighborhood: BaitNeighborhood
var driver: BaitMotion.IBaitDriver
var claimed: bool = false
var heading: Vector3 = Vector3.FORWARD
var visual: BaitVisual
var _eater
var _swallow: float = 0.0

func motion_command(delta: float) -> BaitMotion.BaitCommand:
	if not driver is BaitMotion.LiveBaitDriver: return driver.sample(self,delta)
	_ai_wait -= delta
	_ai_elapsed += delta
	if _ai_command == null or _ai_wait <= 0:
		_ai_command = driver.sample(self,_ai_elapsed)
		_ai_elapsed = 0
		_ai_wait = ai_decision_interval
	return _ai_command

func nearby_fleeing() -> Array:
	return neighborhood.nearby_fleeing(self) if neighborhood != null else get_tree().get_nodes_in_group("bait")

func hit_radius() -> float:
	return [0.28, 0.28, 0.42, 0.38, 0.34, 0.55][kind] * body_size

func nutrition() -> int:
	return [1, 4, 3, 5, 3, 5][kind]

func randomize_size(random: RandomNumberGenerator) -> void:
	# Set before _ready so mesh, collision and bite reach agree. No score randomness.
	body_size *= random.randf_range(1.0-size_variation, 1.0+size_variation)

func caught_by_bird(bird) -> bool:
	if claimed or lifecycle != Lifecycle.ALIVE: return false
	_bird_carry = 2.5
	lifecycle = Lifecycle.CLAIMED
	claimed = true
	_eater = bird
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("bait")
	set_physics_process(false)
	bitten.emit(self, bird) # Reuses the normal population replacement queue, without player points.
	return true

func display_name() -> String:
	return ["Minnow", "Shrimp", "Squid", "Crab", "Mullet", "Seagull"][kind]

func _ready() -> void:
	if minimum_eater_scale < 0: minimum_eater_scale = [0.0, 0.0, 0.0, 0.72, 0.0, 1.05][kind]
	collision_layer = 4
	collision_mask = 1 if kind in [BaitMotion.Kind.MULLET, BaitMotion.Kind.GULL] else 1 | 8
	motion_mode = MOTION_MODE_FLOATING
	if swim_speed <= 0.0:
		swim_speed = [2.9, 2.7, 2.8, 1.35, 3.8, 6.0][kind]
	if acceleration <= 0.0:
		acceleration = [4.5, 14.0, 6.0, 8.0, 6.0, 5.0][kind]
	if turn_rate <= 0.0:
		turn_rate = [75.0, 250.0, 105.0, 180.0, 100.0, 90.0][kind]
	var shape = SphereShape3D.new()
	shape.radius = hit_radius()
	var collision = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	visual = BaitVisual.new()
	visual.kind = kind
	add_child(visual)
	visual.scale = Vector3.ONE * body_size
	add_to_group("bait")
	if network_replica:
		set_physics_process(false)
		set_process(false)
		return
	if driver == null:
		driver = BaitMotion.LiveBaitDriver.new(global_position)

func _physics_process(delta: float) -> void:
	if claimed:
		return
	if lifecycle != Lifecycle.ALIVE:
		dead_motion(delta)
		return
	if cast_windup > 0:
		cast_windup = maxf(0, cast_windup - delta)
		var t = 1.0 - cast_windup / cast_windup_duration
		var back = -BaitMotion.horizontal(cast_destination - cast_origin)
		position = cast_origin + (back * 1.5 + Vector3.UP * 0.4) * sin(t * PI)
		if cast_windup <= 0:
			position = cast_origin
			velocity = cast_launch_velocity
		return
	if cast_remaining > 0:
		var dt = minf(delta, cast_remaining)
		position += velocity * dt + Vector3.DOWN * 0.5 * cast_gravity * dt * dt
		velocity.y -= cast_gravity * dt
		cast_remaining = maxf(0.0, cast_remaining - dt)
		if cast_remaining <= 0:
			position = cast_destination
			velocity = Vector3.DOWN * 4.0
			entry_remaining = 0.35
		return
	_floor_scan -= delta
	if kind == BaitMotion.Kind.SQUID and _floor_scan <= 0:
		_floor_scan = 0.25
		var ray = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, Vector3(global_position.x, -2, global_position.z), 1)
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		floor_height = hit.position.y if not hit.is_empty() else 0.0
	_motion_age += delta
	if kind == BaitMotion.Kind.MULLET:
		forced_dive_remaining = maxf(0, forced_dive_remaining-delta)
		# A real underwater retreat, not a momentary waterline contact, resets the chain.
		if position.y < water_height-5 and forced_dive_remaining <= 0: jump_chain = 0
	var profile_start = Time.get_ticks_usec() if BaitProfile.enabled else 0
	var command = motion_command(delta)
	if BaitProfile.enabled: BaitProfile.add_sample("driver",profile_start)
	if kind == BaitMotion.Kind.MULLET and forced_dive_remaining > 0:
		command.descend = true
		command.action = BaitMotion.Action.GLIDE
		command.flee_fraction = -1
	flee_recovery = maxf(0.0, flee_recovery - delta)
	if command.flee_fraction >= 0.0:
		start_flee(command.flee_fraction, command.direction)
		if driver is BaitMotion.LiveBaitDriver: command.flee_fraction = -1 # Consume cached escape once.
	if _prepare_fraction >= 0:
		_prepare_time += delta
		command.direction = _prepare_direction
		command.action = BaitMotion.Action.CRUISE
	if tether_recovery > 0:
		tether_recovery = maxf(0,tether_recovery-delta)
	# Horizontal steering and vertical travel are independent. This same motor runs
	# AI and player bait, so neither can invent a different retrieve silhouette.
	var direction = BaitMotion.horizontal(command.direction)
	var bottom_kind = kind in [BaitMotion.Kind.CRAB, BaitMotion.Kind.SHRIMP]
	var passive = command.action in [BaitMotion.Action.GLIDE, BaitMotion.Action.RISE]
	if flee_remaining <= 0 and not airborne and command.direction.length_squared() > 0.001 and command.action != BaitMotion.Action.RISE:
		heading = FishInput.turn_toward(BaitMotion.horizontal(heading), direction, deg_to_rad(turn_rate) * delta)
	if _prepare_fraction >= 0 and (heading.dot(_prepare_direction) > cos(deg_to_rad(10)) or _prepare_time >= minnow_prepare_limit):
		var fraction = _prepare_fraction
		_prepare_fraction = -1
		_release_flee(fraction,heading)
	var target = BaitMotion.horizontal(heading) * swim_speed * command.effort
	var response = acceleration
	match command.action:
		BaitMotion.Action.CRUISE:
			target.y = -sink_speed + retrieve_lift * command.effort * command.line_lift
		BaitMotion.Action.GLIDE:
			target = Vector3.ZERO
			target.y = -sink_speed
			response = 1.8
		BaitMotion.Action.RISE:
			target.y = sink_speed * command.effort
	# Species profiles apply equally to human commands and AI commands.
	if kind == BaitMotion.Kind.SQUID:
		target = BaitMotion.horizontal(heading) * 0.45
		target.y = -1.5 if passive else 2.0 * command.effort * (0.2 + 0.8 * pow(maxf(0, sin(_motion_age * 4)), 2))
	elif kind == BaitMotion.Kind.SHRIMP:
		target.y = -1.4 + retrieve_lift * command.effort * command.line_lift if not passive else -1.4
		target *= Vector3(0.55, 1, 0.55)
	elif kind == BaitMotion.Kind.CRAB:
		target = BaitMotion.horizontal(heading) * swim_speed * command.effort
		target.y = -4.5
		if passive: target.x = 0.0; target.z = 0.0
	if kind == BaitMotion.Kind.MULLET:
		target.y = clampf((water_height - surface_depth - global_position.y) * 2.0, -1.5, 2.5)
	if command.action == BaitMotion.Action.RISE and kind != BaitMotion.Kind.CRAB:
		target.y = powered_descent_speed * 0.7
	if command.descend:
		target.y = -maxf(powered_descent_speed,4.5 if kind == BaitMotion.Kind.CRAB else 0.0) * (2.0 if bottom_kind else 1.0)
	if command.arriving:
		target = command.arrival_velocity
		response = acceleration
	if tether_recovery > 0:
		target = velocity
		target.y = move_toward(velocity.y, -0.7, delta)
		flee_remaining = 0
	if airborne or _breaching:
		velocity.y -= airborne_gravity * delta
	elif flee_remaining > 0.0:
		if kind == BaitMotion.Kind.MINNOW:
			flee_velocity = _escape_axis * flee_velocity.dot(_escape_axis) + _escape_axis.cross(Vector3.UP) * sin(_escape_age * minnow_wiggle_frequency) * minnow_wiggle_speed
			heading = _escape_axis
		if kind == BaitMotion.Kind.SHRIMP:
			if _escape_age < _shrimp_kick_duration:
				flee_velocity = _escape_axis * 3.0 * _escape_strength + Vector3.UP * shrimp_kick_speed * _escape_strength
			else:
				var glide = clampf((_escape_age - _shrimp_kick_duration) / shrimp_glide_duration, 0, 1)
				var glide_target = _escape_axis * shrimp_glide_speed * _escape_strength * lerpf(1.0, 0.45, glide)
				glide_target.y = lerpf(0.65, -0.9, glide)
				flee_velocity = flee_velocity.move_toward(glide_target, 22.0 * delta)
			heading = _escape_axis
		velocity = flee_velocity
	else:
		velocity.x = move_toward(velocity.x, target.x, response * delta)
		velocity.z = move_toward(velocity.z, target.z, response * delta)
		velocity.y = move_toward(velocity.y, target.y, (6.0 if kind == BaitMotion.Kind.SQUID else 2.5 if passive else response) * delta)
	_escape_age += delta
	if entry_remaining > 0.0:
		entry_remaining = maxf(0.0, entry_remaining - delta)
		velocity.y = minf(velocity.y, -2.5)
	if kind == BaitMotion.Kind.SQUID:
		# Ground protection also applies to player jets; collision cannot pin a downward escape.
		if global_position.y < floor_height + 0.65 and velocity.y < 0:
			velocity.y = 0
			flee_velocity.y = maxf(0, flee_velocity.y)
		if driver is BaitMotion.PlayerLiveDriver and driver.use_anchor:
			apply_squid_tether(delta,driver.anchor_position)

	flee_remaining = maxf(0.0, flee_remaining - delta)
	# Remove downward settling velocity before sweeping a supported body. Otherwise
	# every grounded crab repeatedly collides with the floor and resolves the same contact.
	if bottom_kind or passive:
		_apply_bottom_constraint(kind == BaitMotion.Kind.CRAB)
	profile_start = Time.get_ticks_usec() if BaitProfile.enabled else 0
	move_and_slide()
	if BaitProfile.enabled: BaitProfile.add_sample("move_"+display_name(),profile_start)
	if kind == BaitMotion.Kind.MULLET:
		if global_position.y >= water_height: airborne = true
		if velocity.y < 0 and global_position.y < water_height:
			if (airborne or _breaching) and jump_chain >= maximum_jump_chain:
				forced_dive_remaining = 4.0
			airborne = false
			_breaching = false
	profile_start = Time.get_ticks_usec() if BaitProfile.enabled else 0
	var facing = FishInput.angles(heading)
	if kind == BaitMotion.Kind.CRAB:
		facing.x = 0.0
	if kind == BaitMotion.Kind.SQUID or kind == BaitMotion.Kind.MULLET:
		var desired_pitch = atan2(velocity.y, Vector2(velocity.x, velocity.z).length()) if velocity.length() > 0.15 else 0.0
		_visual_pitch = lerp_angle(_visual_pitch, desired_pitch, 1.0 - exp(-8.0 * delta))
		facing.x = _visual_pitch
		if Vector2(velocity.x, velocity.z).length() > 0.15:
			_visual_yaw = lerp_angle(_visual_yaw, FishInput.angles(velocity.normalized()).y, 1.0 - exp(-12.0 * delta))
		facing.y = _visual_yaw
	if kind == BaitMotion.Kind.SHRIMP:
		var pitch = -1.0 if flee_remaining > 0 and _escape_age < _shrimp_kick_duration else 0.0
		_visual_pitch = lerp_angle(_visual_pitch, pitch, 1.0-exp(-12.0*delta))
		facing.x = _visual_pitch
		facing.y += PI # Shrimp nose trails the tail/line while reeling and kicking.
	visual.rotation = Vector3(facing.x, facing.y, 0.0)
	visual.speed = velocity.length()
	visual.twitch = maxf(clampf(command.twitch, 0.0, 1.0), 1.0 if flee_remaining > 0 else 0.0)
	visual.action = command.action
	if BaitProfile.enabled: BaitProfile.add_sample("pose",profile_start)

func start_flee(fraction: float, away: Vector3) -> bool:
	if lifecycle != Lifecycle.ALIVE or flee_recovery > 0.0 or airborne or _breaching or tether_recovery > 0: return false
	if kind == BaitMotion.Kind.MINNOW:
		if _prepare_fraction >= 0: return false
		_prepare_fraction = fraction
		_prepare_direction = BaitMotion.horizontal(away)
		_prepare_time = 0
		return true
	return _release_flee(fraction,away)

func _release_flee(fraction: float, away: Vector3) -> bool:
	if kind == BaitMotion.Kind.MULLET:
		if forced_dive_remaining > 0: return false
		if jump_chain >= maximum_jump_chain:
			forced_dive_remaining = 4.0
			return false
		jump_chain += 1
	var strength = lerpf(minimum_flee_strength, maximum_flee_strength, clampf(fraction, 0, 1))
	_escape_strength = strength
	flee_recovery = flee_cooldown
	flee_remaining = lerpf(0.16, 0.48, strength)
	var flat = BaitMotion.horizontal(away)
	_escape_axis = flat
	_escape_age = 0.0
	match kind:
		BaitMotion.Kind.SHRIMP:
			# Heading denotes tail-first travel for shrimp; the visual faces backward.
			_escape_axis = flat
			_shrimp_kick_duration = lerpf(0.22, 0.5, strength)
			flee_velocity = _escape_axis * 3.0 * strength + Vector3.UP * shrimp_kick_speed * strength
			flee_remaining = _shrimp_kick_duration + shrimp_glide_duration
			flee_recovery = maxf(flee_cooldown, _shrimp_kick_duration + 0.12)
		BaitMotion.Kind.SQUID:
			flee_velocity = (away.normalized() if away.length() > 0.01 else Vector3.UP) * squid_jet_speed * strength
			flee_remaining = lerpf(0.3, 0.8, strength)
		BaitMotion.Kind.CRAB:
			var side = BaitMotion.horizontal(heading).cross(Vector3.UP)
			if side.dot(flat) < 0: side = -side
			flee_velocity = side * crab_scuttle_speed * strength + Vector3.DOWN * 4.5
		BaitMotion.Kind.MULLET:
			heading = BaitMotion.horizontal(BaitMotion.horizontal(heading) * 0.4 + flat * 0.6)
			velocity = heading * maxf(Vector2(velocity.x, velocity.z).length(), swim_speed * 0.7) + Vector3.UP * breach_impulse * strength
			_breaching = true
			flee_remaining = 0.0
		_:
			flee_velocity = flat * dart_speed * strength
	return true

func clear_actions() -> void:
	_prepare_fraction = -1
	tether_recovery = 0
	jump_chain = 0
	forced_dive_remaining = 0
	flee_remaining = 0.0
	flee_recovery = 0.0
	airborne = false
	_breaching = false
	velocity = Vector3.ZERO
	cast_remaining = 0.0
	cast_windup = 0.0
	entry_remaining = 0.0

func _apply_bottom_constraint(stick_to_bottom: bool) -> void:
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 4.0, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var floor_y: float = hit.position.y + maxf(bottom_clearance, hit_radius() + 0.02)
	if velocity.y <= 0 and global_position.y <= floor_y + (0.3 if stick_to_bottom else 0.0):
		global_position.y = floor_y
		velocity.y = 0.0

func try_bite(eater) -> bool:
	if network_replica: return false
	if not claimed and is_instance_valid(fisher_owner):
		if not fisher_owner.take_bait(eater): return false
		claimed = true
		lifecycle = Lifecycle.CLAIMED
		hook_held = true
		_eater = eater
		collision_layer = 0
		collision_mask = 0
		remove_from_group("bait")
		set_physics_process(false)
		bitten.emit(self,eater)
		return true
	if not claimed and eater.size_multiplier() < minimum_eater_scale:
		eater.feeding.last_meal = "%s needs %.2fx size" % [display_name(), minimum_eater_scale]
		eater.feeding.meal_notice_time = 1.8
		return false
	if claimed:
		return false
	lifecycle = Lifecycle.CLAIMED
	claimed = true
	_eater = eater
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("bait")
	set_physics_process(false)
	if source == BaitMotion.Source.LIVE:
		eater.feeding.award_food(self)
	bitten.emit(self, eater)
	return true

func _process(delta: float) -> void:
	if not claimed:
		return
	if hook_held:
		if is_instance_valid(_eater): global_position = _eater.mouth_position()
		return
	if _bird_carry > 0:
		_bird_carry -= delta
		if is_instance_valid(_eater):
			global_position = _eater.mouth_position()
			visual.rotation.z = PI * 0.5
			return
	_swallow += delta
	if is_instance_valid(_eater):
		global_position = global_position.lerp(_eater.mouth_position(), 1.0 - exp(-22.0 * delta))
	visual.scale = Vector3.ONE * body_size * maxf(0.01, 1.0 - _swallow / 0.22)
	if _swallow >= 0.22:
		queue_free()

func launch_cast(origin: Vector3, destination: Vector3, duration: float = 1.8) -> void:
	clear_actions()
	position = origin
	cast_destination = destination
	cast_remaining = maxf(0.2, duration)
	cast_origin = origin
	cast_launch_velocity = (destination - origin) / cast_remaining + Vector3.UP * cast_gravity * cast_remaining * 0.5
	cast_windup = cast_windup_duration
	velocity = Vector3.ZERO

func apply_squid_tether(delta: float, anchor: Vector3) -> void:
	var offset = Vector3(global_position.x-anchor.x,0,global_position.z-anchor.z)
	var radius = offset.length()
	var extension = radius-squid_roam_radius
	if extension <= 0: return # No changes to the good movement inside the normal range.
	var outward = offset / radius
	var radial_speed = velocity.dot(outward)
	velocity -= outward * (tether_stiffness*extension*extension + tether_damping*maxf(0,radial_speed)*extension) * delta
	if extension > tether_recovery_extension:
		tether_recovery = tether_recovery_duration
		flee_remaining = 0
	flee_velocity = velocity # Preserve tension's change across subsequent jet ticks.
	if extension > tether_safety_extension:
		global_position -= outward * (extension-tether_safety_extension)
		velocity -= outward * maxf(0,velocity.dot(outward))

func die_naturally() -> void:
	if lifecycle != Lifecycle.ALIVE or claimed: return
	lifecycle = Lifecycle.DEAD_SINKING
	flee_remaining = 0
	_prepare_fraction = -1
	airborne = false
	_breaching = false
	visual.alive = false

func dead_motion(delta: float) -> void:
	visual.rotation.z = lerp_angle(visual.rotation.z,PI,1-exp(-2*delta))
	if lifecycle == Lifecycle.DEAD_SETTLED: return
	velocity = velocity.move_toward(Vector3.DOWN*carcass_sink_speed,2*delta)
	_apply_bottom_constraint(false)
	move_and_slide()
	for i in range(get_slide_collision_count()):
		if get_slide_collision(i).get_normal().y > 0.5:
			lifecycle = Lifecycle.DEAD_SETTLED
			velocity = Vector3.ZERO
	if velocity.length_squared() < 0.0001:
		lifecycle = Lifecycle.DEAD_SETTLED
