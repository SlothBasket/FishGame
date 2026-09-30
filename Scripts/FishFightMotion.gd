class_name FishFightMotion
extends Resource
## Server-owned fight effort. Keyboard, mouse and AI share one alternating stroke clock.
@export var sustainable_max: float = 1
@export var overdrive_max: float = 0.35
@export var ideal_stroke_interval: float = 0.48
@export var full_credit_window: float = 0.18
@export var partial_credit_window: float = 0.48
@export var decay_delay: float = 1.1
@export var stored_drive_force_bonus: float = 0.35
@export var stored_drive_force_exponent: float = 2.0
@export var side_force_bonus: float = 0.5
@export var drive_gain: float = 0.10
@export var drive_decay: float = 0.055
@export var drive_drain: float = 0.30
@export var overdrive_drive_drain: float = 0.48
@export var drive_burst_threshold: float = 0.10 # UI readiness, not an activation price.
@export var powered_rhythm_window: float = 0.62
@export var overdrive_stamina_drain: float = 8
var powered_active: bool = false
var stamina_share: float = 0
var powered_output: float = 0
# Kept as a positive activity signal for existing snapshots, telemetry and VFX.
var drive_burst_time: float = 0
var drive_bursts: int = 0
var overdrive_serial: int = 0
var drive_gained: float = 0
var drive_spent: float = 0
var stamina_cost: float = 0
@export var minimum_stroke_interval: float = 0.08
@export var run_build_time: float = 0.6
@export var dive_angle: float = 35
@export var dive_commit_time: float = 0.4
@export var dive_build_time: float = 1.0
@export var dive_counter_window: float = 0.8
@export var dive_stamina_drain: float = 12
@export var dive_acceleration: float = 9
var swim_drive: float = 0.2
var overdrive: float = 0
var run_build: float = 0
var dive_power: float = 0
var diving: bool = false
var dive_blocked: bool = false
var propulsion: float = 0
var stroke_age: float = 10
var last_side: int = 0
var overdrive_remaining: float = 0
var cadence_grade: int = 0 # 0 none, 1 GOOD, 2 FAST, 3 LATE
@export var ascent_acceleration: float = 8
@export var ascent_build_time: float = 1.2
@export var ascent_stamina_drain: float = 6
var ascent_power: float = 0
var jump_launch_power: float = 0
@export var jump_recovery_duration: float = 3
var jump_recovery: float = 0
var jump_severity: float = 0
var jump_peak: float = 0
var airborne_time: float = 0
var was_airborne: bool = false
var falling: bool = false
var landed_event: bool = false
var power_capacity: float = 1
var dive_hold: float = 0
var dive_age: float = 0
var run_age: float = 0
var counter_recovery: float = 0
@export var counter_recovery_duration: float = 0.85
@export var overdrive_recovery_duration: float = 1.4
@export var dive_recovery_duration: float = 1.5
@export var drive_counter_lockout: float = 2.25
var drive_lockout: float = 0

func step(delta: float, input: FishInput, heading: Vector3, speed_fraction: float, stamina: float, bottom: bool, measured_stroke: float = 0, capacity: float = 1, upward_speed: float = 0, fight_mode: bool = true) -> void:
	power_capacity = clampf(capacity,0,1)
	stamina_cost = 0
	var was_powered = powered_active
	counter_recovery = maxf(0,counter_recovery-delta)
	drive_lockout = maxf(0,drive_lockout-delta)
	stroke_age += delta
	var wants_power = input.boost and input.throttle > 0 and counter_recovery <= 0 and drive_lockout <= 0
	var axis = measured_stroke
	var side = int(signf(axis)) if absf(axis) > 0.25 else 0
	overdrive_remaining = maxf(0,overdrive_remaining-delta)
	if input.throttle > 0 and side != 0 and side != last_side and stroke_age >= minimum_stroke_interval:
		if last_side != 0 and drive_lockout <= 0:
			var fast_boundary = ideal_stroke_interval-full_credit_window
			var error = absf(stroke_age-ideal_stroke_interval)
			var quality = 1-clampf((error-full_credit_window)/maxf(0.01,partial_credit_window-full_credit_window),0,1)
			if wants_power and stroke_age < fast_boundary:
				# Escalation is sustained by fast reversals, never purchased up front.
				if overdrive_remaining <= 0: overdrive_serial += 1
				overdrive_remaining = fast_boundary+0.10
				cadence_grade = 2
			else:
				# Exhausted Fish rebuild more slowly; no refill while demanding power.
				var recovery = clampf(stamina/25.0,0.4,1.0)
				var gain = minf(sustainable_max-swim_drive,drive_gain*quality*recovery) if not wants_power and not was_powered else 0.0
				swim_drive += gain
				drive_gained += gain
				cadence_grade = 1 if error <= full_credit_window else 3
		last_side = side
		stroke_age = 0
	powered_active = wants_power and last_side != 0 and stroke_age <= powered_rhythm_window and (swim_drive > 0 or stamina > 1)
	if not powered_active: overdrive_remaining = 0
	var escalating = powered_active and overdrive_remaining > 0
	stamina_share = 0
	if powered_active:
		var requested = (overdrive_drive_drain if escalating else drive_drain)*delta
		var spent = minf(swim_drive,requested)
		swim_drive -= spent
		drive_spent += spent
		stamina_share = 1-spent/maxf(0.000001,requested)
		if not was_powered: drive_bursts += 1
		if escalating: stamina_cost = overdrive_stamina_drain*stamina_share*delta
	# Only the stamina-funded portion fades with exhaustion; base swim is unchanged.
	powered_output = lerpf(1,clampf(stamina/15.0,0,1),stamina_share) if powered_active else 0.0
	drive_burst_time = powered_output if powered_active else 0.0
	overdrive = overdrive_max*power_capacity*powered_output if escalating else 0.0
	var passive_decay = drive_decay if stroke_age > decay_delay else 0.0
	swim_drive = maxf(0,swim_drive-passive_decay*delta)
	run_age = run_age+delta if powered_active else 0.0
	run_build = move_toward(run_build,powered_output,delta/maxf(0.05,run_build_time))
	if not input.boost: dive_blocked = false
	if not fight_mode or not input.boost or stamina <= 1 or bottom or power_capacity <= 0.01 or heading.y > 0.25 or counter_recovery > 0:
		diving = false
		dive_power = 0
		dive_hold = 0
	elif not diving and not dive_blocked:
		dive_hold = dive_hold+delta if heading.y < -sin(deg_to_rad(dive_angle)) and input.throttle > 0 else 0
		if dive_hold >= dive_commit_time: diving = true
	dive_age = dive_age+delta if diving else 0.0
	if diving: dive_power = minf(power_capacity,dive_power+delta*power_capacity/maxf(0.1,dive_build_time))
	var ascending = fight_mode and counter_recovery <= 0 and jump_recovery <= 0 and not was_airborne and input.boost and input.throttle > 0 and stamina > 1 and (heading.y > 0.35 or input.vertical > 0.5)
	# A real upward start earns a commitment. Subsequent line resistance cannot
	# erase the effort while upward powered intent continues.
	if ascending and (upward_speed > 0.5 or ascent_power > 0.01):
		ascent_power = move_toward(ascent_power,power_capacity,delta*power_capacity/maxf(0.1,ascent_build_time))
	else:
		ascent_power = move_toward(ascent_power,0,delta*0.4)
	ascent_power = minf(ascent_power,power_capacity)
	# Base effort carries movement and stored Drive once; FightSession applies the
	# same powered force multiplier as the physical motor, not a second boost curve.
	var target = maxf(0,input.throttle)*(0.35+0.65*clampf(speed_fraction,0,1))*multiplier()*stored_force_multiplier()
	propulsion = lerpf(propulsion,target,1-exp(-delta/0.25))

func stored_force_multiplier() -> float:
	# Reserved Drive supplies passive force; spending/disruption gives it up.
	return 1+stored_drive_force_bonus*pow(clampf(swim_drive/maxf(0.01,sustainable_max),0,1),stored_drive_force_exponent)*power_capacity

func side_force_multiplier() -> float:
	return 1+side_force_bonus*side_quality if side_time > 0 and counter_recovery <= 0 else 1.0

func multiplier() -> float:
	return (1+0.22*maxf(swim_drive,powered_output)/maxf(0.01,sustainable_max)*power_capacity+overdrive)*(0.65 if counter_recovery > 0 else 1.0)

func interrupt_dive() -> void:
	diving = false
	dive_power = 0
	dive_hold = 0
	dive_blocked = true # Require a new sprint commitment, not repeated instant dives.

func interrupt_run(recovery: float = -1, disrupt_drive: bool = false) -> void:
	overdrive = 0
	overdrive_remaining = 0
	powered_active = false
	powered_output = 0
	ascent_power = 0
	drive_burst_time = 0
	run_build = 0
	propulsion *= 0.5
	counter_recovery = counter_recovery_duration if recovery < 0 else recovery
	side_time = 0
	side_quality = 0
	if disrupt_drive:
		swim_drive = 0
		drive_lockout = drive_counter_lockout

func track_jump(delta: float, airborne: bool, height: float, vertical_speed: float) -> void:
	landed_event = was_airborne and not airborne
	jump_recovery = maxf(0,jump_recovery-delta)
	if airborne:
		if not was_airborne:
			jump_peak = 0
			airborne_time = 0
			jump_launch_power = ascent_power
			jump_severity = clampf(maxf(0,vertical_speed)/9,0,1)*jump_launch_power
		airborne_time += delta
		jump_peak = maxf(jump_peak,height)
		jump_severity = maxf(jump_severity,clampf(jump_peak/3,0,2)*(0.5+0.5*jump_launch_power))
	if landed_event: jump_recovery = jump_recovery_duration
	falling = (airborne and vertical_speed < -0.5) or (jump_recovery > jump_recovery_duration-0.6 and vertical_speed < -0.5)
	was_airborne = airborne

# Side burst commits existing run propulsion to a fixed 55-degree course.
@export var side_burst_drive: float = 0.55
@export var side_burst_angle: float = 55
@export var side_burst_duration: float = 1.8
@export var side_burst_cooldown: float = 2.5
@export var side_burst_prepare: float = 0.35
var side_time: float = 0
var side_wait: float = 0
var side_hold: float = 0
var side_candidate: int = 0
var side_sign: int = 0
var side_start: Vector3 = Vector3.FORWARD
var side_target: Vector3 = Vector3.FORWARD
var side_reported: bool = false
var side_event: int = 0
var side_frame: Vector3 = Vector3.FORWARD
var side_origin: Vector3 = Vector3.ZERO
var side_measure_time: float = 0
var side_elapsed: float = 0
var side_good_time: float = 0
var side_bad_time: float = 0
var side_visible_age: float = 0
var side_quality: float = 0
var side_lateral_velocity: float = 0
var side_radial_velocity: float = 0
var side_angle: float = 0
var side_lateral_displacement: float = 0
var side_radial_displacement: float = 0

func steer_burst(delta: float, input: FishInput, heading: Vector3, allowed: bool, outward: Vector3 = Vector3.FORWARD) -> FishInput:
	side_event = 0
	side_wait = maxf(0,side_wait-delta)
	side_time = maxf(0,side_time-delta)
	if not allowed or input.throttle <= 0 or counter_recovery > 0 or (not input.boost and side_time <= 0):
		side_time = 0
		side_hold = 0
		return input
	var yaw = angle_difference(FishInput.angles(outward).y,FishInput.angles(input.aim_direction).y)
	var requested = int(signf(input.steering)) if absf(input.steering) > 0.8 else -int(signf(yaw)) if absf(yaw) > deg_to_rad(20 if side_hold > 0 else 40) else 0
	if requested != side_candidate:
		side_hold = 0
		if requested != 0 and side_time <= 0:
			side_start = heading
			side_frame = BaitMotion.horizontal(outward)
			side_target = side_frame.rotated(Vector3.UP,-requested*deg_to_rad(side_burst_angle))
	side_candidate = requested
	side_hold = side_hold+delta if requested != 0 else 0.0
	if side_time <= 0 and side_wait <= 0 and side_hold >= side_burst_prepare and (swim_drive >= side_burst_drive or drive_burst_time > 0) and run_build >= 0.6:
		side_sign = requested
		run_age = 0 # A visibly renewed commitment opens its own counter window.
		side_time = side_burst_duration
		side_wait = side_burst_cooldown
		side_reported = false
		side_measure_time = 0
		side_elapsed = 0
		side_good_time = 0
		side_bad_time = 0
		side_visible_age = 0
		side_quality = 0
		side_lateral_displacement = 0
		side_radial_displacement = 0
	if side_time > 0 and requested != side_sign:
		side_time = 0
		side_quality = 0
	if side_time > 0:
		var committed = FishInput.new(input.throttle,0,input.vertical,FishInput.turn_toward(side_target,input.aim_direction,deg_to_rad(12)),input.boost,input.bite_held)
		committed.cancel_bite = input.cancel_bite
		return committed
	return input

func measure_side(delta: float, heading: Vector3, velocity: Vector3, current_outward: Vector3 = Vector3.ZERO) -> void:
	side_event = 0
	if side_time <= 0: return
	var frame = side_frame if current_outward.length_squared() < 0.01 else BaitMotion.horizontal(current_outward)
	var right = frame.cross(Vector3.UP)
	side_radial_velocity = velocity.dot(frame)
	side_lateral_velocity = velocity.dot(right)
	side_angle = rad_to_deg(atan2(heading.dot(right),heading.dot(frame)))
	side_radial_displacement += side_radial_velocity*delta
	side_lateral_displacement += side_lateral_velocity*delta
	var real_lateral = heading.dot(right)*side_sign > 0.6 and side_lateral_velocity*side_sign > 2
	side_elapsed += delta
	side_good_time += delta if real_lateral else 0.0
	side_bad_time = 0 if real_lateral else side_bad_time+delta
	side_visible_age += delta if side_reported else 0.0
	side_quality = move_toward(side_quality,1 if real_lateral else 0,delta/0.5)
	if side_reported and side_bad_time > 0.25: side_time = 0; side_quality = 0
	if side_reported and real_lateral: side_time = maxf(side_time,delta*2)
	side_measure_time = side_measure_time+delta if real_lateral else 0.0
	if not side_reported and side_measure_time >= 0.2:
		side_reported = true
		side_event = side_sign

static func opposition_cost(heading: Vector3, outward: Vector3, contact: float) -> float:
	return 1+clampf(contact,0,1)*pow(maxf(0,heading.dot(outward)),2)
