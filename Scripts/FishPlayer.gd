class_name FishPlayer
extends CharacterBody3D
## Owns physical heading and velocity. Visual wiggles live below Visual/Body.

@export_group("Swimming")
@export var swim_speed: float = 8.0
@export var boost_multiplier: float = 1.85
@export var acceleration: float = 12.0
@export var water_drag: float = 4.0
@export_range(0.0, 1.0) var reverse_speed_multiplier: float = 0.4
@export var reverse_acceleration: float = 6.0
@export var vertical_speed_multiplier: float = 0.7
@export_group("Steering (degrees per second)")
@export var forward_turn_rate: float = 85.0
@export var pitch_turn_rate: float = 65.0
@export var manual_steering_strength: float = 125.0
@export var idle_pivot_multiplier: float = 0.45
@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export_group("Feeding")
@export var full_charge_time: float = 1.4
@export var minimum_lunge_distance: float = 3.0
@export var maximum_lunge_distance: float = 15.0
@export var lunge_speed: float = 26.0
@export var bite_cooldown: float = 0.45
@export var bite_grace_duration: float = 0.2
@export_range(0.0, 179.0) var maximum_lunge_turn_angle: float = 65.0
@export var lunge_turn_rate: float = 220.0
@export var charge_swim_multiplier: float = 0.85
@export var charge_response_multiplier: float = 0.28
@export var lunge_acceleration: float = 65.0
@export var camera_clearance: float = 0.35
@export var gamepad_look_speed: float = 2.2
@export var bite_radius: float = 1.08
@export_group("Air and surface")
@export var water_height: float = 32.0
@export var air_gravity: float = 12.0
@export var max_breach_horizontal_speed: float = 8.0
@export var max_breach_vertical_speed: float = 9.5
var airborne: bool = false
var natural_breach: bool = false
var breach_intent_time: float = 0
@export var minimum_mouse_stroke: float = 6
@export var hooked_sway_camera_scale: float = 0.45
@export var show_fight_coaching: bool = true
var motion = FishFightMotion.new()
var head = FishSteering.new()
@export var exhausted_swim_fraction: float = 0.55
@export var endurance_power_exponent: float = 0.8
var dive_particles: CPUParticles3D
var overdrive_particles: CPUParticles3D
var maneuver_burst: CPUParticles3D
var was_diving: bool = false
var was_overdriving: bool = false
var mouse_stroke_axis: float = 0
var mouse_stroke_distance: float = 0
var fight_best_move: int = 0
var fight_anchor: Vector3
var fight_roll: float = 0
var damaging_line: bool = false
var fight_active: bool = false
var fight_pressure: float = 0
var fight_gain: float = 0
var fight_leverage: float = 0
var fight_counter: float = 0
var directional_pressure: float = 0
var fight_slack: bool = false
@export_group("Growth")
@export var starting_size: float = 0.58
@export var growth_rate: float = 0.006
@export var maximum_size: float = 2.1

@export_group("Stamina and size speed")
@export var stamina_capacity: float = 100
@export var sprint_drain: float = 18
@export var dash_cost: float = 14
@export var stamina_regen: float = 12
@export var fight_regen_multiplier: float = 0.5
@export var swim_growth_bonus: float = 0.20
@export var dash_growth_bonus: float = 0.25
@export var max_tension_camera_roll: float = 0.08
@export var tension_camera_smoothing: float = 5
@export var endurance_floor: float = 0.0
@export var sprint_endurance_drain: float = 0.55
@export var dash_endurance_cost: float = 0.8
var endurance: float = 100
var fight_regen_scale: float = 1
var sprint_exhausted: bool = false
var stamina: float = 100
var fight
var line_force: Vector3 = Vector3.ZERO
var sprint_locked: bool = false
var free_bursts: bool = false
var camera_roll: float = 0
var networked: bool = false
var locally_owned: bool = true
var replica: bool = false
var heading: Vector3 = Vector3.FORWARD
var external_input: bool = false
var command: FishInput = FishInput.new()
var boosting: bool = false
var feeding: FishFeeding
var suppress_bite_until_release: bool = false
var _spawn: Vector3
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.08
var _body_radius: float
@onready var pivot: Node3D = $CameraPivot
@onready var visual: FishVisual = $Visual
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

func _ready() -> void:
	_spawn = position
	collision_mask &= ~8
	wall_min_slide_angle = 0.0
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate()
	_body_radius = $CollisionShape3D.shape.radius
	dive_particles = CPUParticles3D.new()
	dive_particles.amount = 96
	dive_particles.lifetime = 1.2
	dive_particles.local_coords = false
	dive_particles.emitting = false
	dive_particles.spread = 25
	dive_particles.gravity = Vector3.UP*1.5
	var bubble = SphereMesh.new()
	bubble.radius = 0.10
	bubble.radial_segments = 8
	bubble.rings = 4
	bubble.height = 0.20
	var bubble_material = StandardMaterial3D.new()
	bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.albedo_color = Color(0.7,0.9,1,0.7)
	bubble.material = bubble_material
	dive_particles.mesh = bubble
	add_child(dive_particles)
	overdrive_particles = dive_particles.duplicate()
	overdrive_particles.amount = 64
	overdrive_particles.lifetime = 0.65
	add_child(overdrive_particles)
	maneuver_burst = dive_particles.duplicate()
	maneuver_burst.amount = 48
	maneuver_burst.one_shot = true
	maneuver_burst.explosiveness = 1
	maneuver_burst.spread = 100
	maneuver_burst.initial_velocity_min = 2
	maneuver_burst.initial_velocity_max = 5
	add_child(maneuver_burst)
	feeding = FishFeeding.new(self)
	if locally_owned and not FightBatch.requested():
		var references = FishFightReferences.new()
		references.fish = self
		add_child(references)
	update_growth_collision()
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())
	GameControls.install()
	# A swept sphere protects the camera volume, including beside slopes and rocks.
	var clearance = SphereShape3D.new()
	clearance.radius = camera_clearance
	$CameraPivot/SpringArm3D.shape = clearance
	if locally_owned: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else: camera.current = false
	pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not locally_owned: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel_attack()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			suppress_bite_until_release = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if fight_active:
			mouse_stroke_distance += event.relative.x
			if absf(mouse_stroke_distance) >= minimum_mouse_stroke:
				mouse_stroke_axis = signf(mouse_stroke_distance)
				mouse_stroke_distance = 0
		_camera_yaw -= event.relative.x * mouse_sensitivity * (hooked_sway_camera_scale if fight_active else 1.0)
		_camera_pitch = clampf(_camera_pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)
	if not networked and not is_instance_valid(fight) and event.is_action_pressed("reset"):
		reset_fish()

func read_local_input() -> FishInput:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var cancelled = FishInput.new()
		cancelled.cancel_bite = true
		return cancelled
	if not Input.is_action_pressed("bite"):
		suppress_bite_until_release = false
	var intent = FishInput.new(Input.get_axis("back", "forward"), Input.get_axis("left", "right"),
		Input.get_axis("dive", "rise"), -pivot.global_basis.z, Input.is_action_pressed("boost"),
		Input.is_action_pressed("bite") and not suppress_bite_until_release)
	intent.stroke_axis = mouse_stroke_axis if fight_active else 0
	# Aim correction is useful for the bite; regular swimming follows camera direction.
	if feeding.is_charging:
		intent.aim_direction = aim_through_crosshair()
	return intent

func aim_through_crosshair() -> Vector3:
	var origin = camera.global_position
	var end = origin - camera.global_basis.z * 200.0
	var query = PhysicsRayQueryParameters3D.create(origin, end, 1 | 4)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", end)
	var direction = target - global_position
	return direction.normalized() if direction.dot(-pivot.global_basis.z) > 0.1 else -pivot.global_basis.z.normalized()

func _physics_process(delta: float) -> void:
	if camera.current:
		var roll_target = clampf(-line_force.dot(pivot.global_basis.x)/45,-1,1)*max_tension_camera_roll
		camera_roll = lerpf(camera_roll,roll_target,1-exp(-tension_camera_smoothing*delta))
		camera.rotation.z = camera_roll
		var look = GameControls.look() * gamepad_look_speed * delta
		_camera_yaw -= look.x
		_camera_pitch = clampf(_camera_pitch-look.y,-1.35,1.35)
		pivot.rotation = Vector3(_camera_pitch,_camera_yaw,0)
	breach_intent_time = maxf(0,breach_intent_time-delta)
	if not FightBatch.requested(): update_fight_presentation()
	if replica: return # NetworkSession interpolates state; no client feeding or movement.
	var intent = command if external_input else read_local_input()
	var in_fight = is_instance_valid(fight)
	if not intent.boost: sprint_exhausted = false
	if stamina < 1: sprint_exhausted = true
	if not free_bursts and (sprint_exhausted or sprint_locked): intent.boost = false
	heading = head.step(delta,heading,intent,maxf(0,velocity.dot(heading)))
	if in_fight: motion.step(delta,intent,heading,velocity.length()/maxf(0.1,effective_swim_speed()),stamina,touching_bottom(),head.stroke,power_capacity(),velocity.y)
	var sprinting = intent.boost and intent.throttle > 0 and not free_bursts
	if in_fight and sprinting: fatigue(sprint_endurance_drain*delta)
	var regeneration = stamina_regen*(fight_regen_multiplier*fight_regen_scale if in_fight else 1.0)
	stamina = clampf(stamina+(-sprint_drain if sprinting else regeneration)*delta,0,endurance if in_fight else stamina_capacity)
	if in_fight and motion.diving: stamina = maxf(0,stamina-motion.dive_stamina_drain*delta)
	if in_fight: stamina = maxf(0,stamina-motion.ascent_stamina_drain*motion.ascent_power*delta)
	var bite_start = global_position
	feeding.update_attack(intent, delta)
	boosting = intent.boost and intent.throttle > 0.0 and not feeding.is_charging and not feeding.is_dashing()
	if feeding.is_dashing():
		feeding.advance_dash(delta)
	elif airborne:
		apply_line_force(delta)
		velocity.y -= air_gravity * delta
		if in_fight: fight.constrain_velocity(delta)
		move_and_slide()
		if velocity.length() > 0.1:
			heading = FishInput.turn_toward(heading, velocity.normalized(), deg_to_rad(pitch_turn_rate) * delta)
	else:
		# Head steering above supplies the physical body heading for this motor tick.
		var swim = FishInput.new(intent.throttle, intent.steering, intent.vertical, intent.aim_direction, boosting)
		var speed = effective_swim_speed() * (motion.multiplier() if in_fight else 1.0) * (charge_swim_multiplier if feeding.is_charging else 1.0)
		var response = (charge_response_multiplier if feeding.is_charging else 1.0)*(0.3 if head.impact_time > 0 else 1.0)
		velocity = FishInput.next_velocity(velocity, heading, swim, speed, fight_boost_multiplier(),
			reverse_speed_multiplier, acceleration * response * (motion.multiplier() if in_fight else 1.0) * (fight_boost_multiplier() if in_fight and boosting else 1.0), reverse_acceleration * response, water_drag * response, vertical_speed_multiplier, delta)
		if in_fight and motion.diving: velocity.y -= motion.dive_acceleration*motion.dive_power*delta
		if in_fight and not airborne: velocity.y += motion.ascent_acceleration*motion.ascent_power*delta
		apply_line_force(delta)
		if in_fight: fight.constrain_velocity(delta)
		move_and_slide()
	if global_position.y > water_height and not airborne:
		natural_breach = breach_intent_time > 0
		limit_breach_velocity()
	airborne = global_position.y > water_height
	if not airborne: natural_breach = false
	if is_instance_valid(fight):
		motion.track_jump(delta,airborne,global_position.y-water_height,velocity.y)
		if motion.landed_event:
			fight.jump_commit = 0
			fight.jump_cooldown = 12
			fight.hook.violent_landing(motion.jump_severity)
		fight.after_fish_move(delta)
	if feeding.grace_remaining > 0.0 and not feeding.is_dashing():
		feeding.sweep_bite(bite_start, global_position)
	# Heading, not velocity, owns facing. Backpedaling cannot flip the model.
	var facing = FishInput.angles(heading)
	visual.rotation = Vector3(facing.x, facing.y, fight_roll if fight_active else 0.0)
	visual.scale = Vector3.ONE * size_multiplier()
	visual.swim_intensity = velocity.length() / maxf(0.1, swim_speed)
	visual.charge_intensity = feeding.charge_fraction()
	visual.biting = feeding.is_dashing() or feeding.bite_flash > 0.0
	var fov = 88.0 if feeding.is_dashing() else 67.0 if feeding.is_charging else 80.0 if boosting else 72.0
	camera.fov = lerpf(camera.fov, fov, 1.0 - exp(-6.0 * delta))

func size_multiplier() -> float:
	return starting_size + (maximum_size - starting_size) * (1.0 - exp(-growth_rate * feeding.food))

func mouth_position() -> Vector3:
	return global_position + heading * 1.25 * size_multiplier()

func update_growth_collision() -> void:
	$CollisionShape3D.shape.radius = _body_radius * size_multiplier()

func cancel_attack() -> void:
	if feeding != null and not replica:
		feeding.cancel_attack()
	suppress_bite_until_release = true

func reset_fish() -> void:
	cancel_attack()
	feeding.cooldown_remaining = 0.0
	airborne = false
	position = _spawn
	velocity = Vector3.ZERO
	heading = Vector3.FORWARD
	visual.rotation = Vector3.ZERO
	_camera_yaw = 0.0
	_camera_pitch = -0.08
	pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

func _notification(what: int) -> void:
	if locally_owned and what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_attack()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func limit_breach_velocity() -> void:
	var flat = Vector3(velocity.x, 0, velocity.z).limit_length(max_breach_horizontal_speed)
	velocity = flat + Vector3.UP * minf(velocity.y, max_breach_vertical_speed)

func effective_swim_speed() -> float:
	return swim_speed*(1+swim_growth_bonus*growth_fraction())*(lerpf(exhausted_swim_fraction,1,power_capacity()) if is_instance_valid(fight) else 1.0)

func effective_dash_speed() -> float:
	return lunge_speed*(1+dash_growth_bonus*growth_fraction())

func growth_fraction() -> float:
	return clampf((size_multiplier()-starting_size)/maxf(0.01,maximum_size-starting_size),0,1)

func spend_dash_stamina() -> bool:
	if free_bursts: return true
	if stamina < dash_cost: return false
	stamina -= dash_cost
	if is_instance_valid(fight): fatigue(dash_endurance_cost)
	return true

func fatigue(amount: float) -> void:
	endurance = maxf(stamina_capacity*endurance_floor,endurance-maxf(0,amount))
	stamina = minf(stamina,endurance)

func fight_boost_multiplier() -> float:
	# Only fight sprint output fades; ordinary swim speed and turns remain available.
	return 1+(lerpf(1,boost_multiplier,power_capacity())-1)*motion.run_build*(0.65+0.35*motion.swim_drive/maxf(0.01,motion.sustainable_max)) if is_instance_valid(fight) else boost_multiplier

func apply_line_force(delta: float) -> void:
	# Measure fish-driven upward intent before adding any line acceleration.
	if velocity.y > 2 and (command.vertical > 0 or command.aim_direction.y > 0.2): breach_intent_time = 0.25
	if not is_instance_valid(fight):
		velocity += line_force*delta
		return
	var inward = BaitMotion.horizontal(fight.fisher.position-position)
	var before = velocity.dot(inward)
	velocity += line_force*delta
	var added_excess = maxf(0,velocity.dot(inward)-maxf(before,fight.maximum_pull_speed))
	velocity -= inward*added_excess

func touching_bottom() -> bool:
	# Fish use floating CharacterBody mode, so is_on_floor() is not sufficient.
	for i in range(get_slide_collision_count()):
		if get_slide_collision(i).get_normal().y > 0.55: return true
	return false

func power_capacity() -> float:
	return pow(clampf(endurance/maxf(1,stamina_capacity),0,1),endurance_power_exponent)
func receive_impact(force: Vector3, severity: float) -> void:
	var body = FishInput.angles(heading)
	var wanted = FishInput.angles(force.normalized())
	head.knock(Vector2(wanted.x-body.x,angle_difference(body.y,wanted.y)),0.18+0.18*severity)

func update_fight_presentation() -> void:
	dive_particles.emitting = fight_active and motion.diving
	dive_particles.direction = (-heading+Vector3.UP*0.8).normalized()
	dive_particles.initial_velocity_min = 2+motion.dive_power*3
	dive_particles.initial_velocity_max = 4+motion.dive_power*5
	visual.head_offset = head.offset
	visual.impact = head.impact_time
	visual.drive = motion.swim_drive if fight_active else 0.0
	visual.overdrive = motion.overdrive/maxf(0.01,motion.overdrive_max) if fight_active else 0.0
	overdrive_particles.emitting = fight_active and motion.overdrive > 0
	overdrive_particles.direction = -heading
	overdrive_particles.initial_velocity_min = 2+visual.overdrive*2
	overdrive_particles.initial_velocity_max = 4+visual.overdrive*4
	if (dive_particles.emitting and not was_diving) or (overdrive_particles.emitting and not was_overdriving):
		maneuver_burst.restart()
		maneuver_burst.emitting = true
	was_diving = dive_particles.emitting
	was_overdriving = overdrive_particles.emitting
