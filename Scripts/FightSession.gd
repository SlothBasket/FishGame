class_name FightSession
extends Node
## Server-only encounter. Drivers supply intent; this node owns outcomes and forces.
enum Phase { CANDIDATE, METER, IMPACT, OPENING, FIGHT, FINISHED }
enum Outcome { NONE, MISSED, LINE_BROKE, THROWN, LANDED, DISCONNECT }
@export var opportunity_window: float = 5
@export var meter_duration: float = 1.2
@export var meter_target: float = 0.75
@export var perfect_window: float = 0.045
@export var good_window: float = 0.14
@export var weak_window: float = 0.28
@export var yank_speed: float = 5
@export var hook_stamina_damage: float = 12
@export var recovery_time: float = 0.65
@export var opening_run_duration: float = 3.5
@export var spool: FightLine = FightLine.new()
@export var rod_horizontal_degrees: float = 75
@export var rod_up_degrees: float = 55
@export var rod_down_degrees: float = 40
@export var rod_response: float = 5
@export var rod_length: float = 3
@export var rod_bend: float = 0.65
@export var slack_tolerance: float = 0.5
@export var security_decay: float = 0.055
@export var security_recovery: float = 0.035
@export var slack_throw_rate: float = 0.035
@export var landing_confirmation: float = 0.75
var hook_security: float = 1
var slack_time: float = 0
var rod_horizontal: float = 0
var rod_vertical: float = 0
var rod_tip: Vector3
var rod_hand: Vector3
var _previous_heading: Vector3 = Vector3.FORWARD
var power_exhausted: bool = false
@export var power_drain: float = 24
@export var lateral_force: float = 30
@export var propulsion_load_scale: float = 0.85
@export var pressure_endurance_drain: float = 0.18
@export var leverage_endurance_drain: float = 0.65
@export var yield_bonus: float = 2
@export var resistance_fatigue: float = 13
@export var safe_load: float = 35
@export var critical_load: float = 110
@export var jerk_damage: float = 15
@export var jerk_spike: float = 35
@export var jerk_cooldown: float = 1.2
@export var jerk_cost: float = 14
@export var jump_throw_rate: float = 0.10
@export var lowered_rod_reduction: float = 0.12
@export var landing_distance: float = 3
var fisher: FisherActor
var fish: FishPlayer
var bait: BaitActor
var phase: int = Phase.CANDIDATE
var phase_time: float = 0
var meter: float = 0
var quality: int = 0
var line_length: float:
	get: return spool.line_out
	set(value): spool.line_out = value
var tension: float = 0
var condition: float = 1
var rod_direction: Vector3 = Vector3.FORWARD
var power_active: bool = false
var power_locked_sprint: bool = false
var power_preexisting_sprint: bool = false
var jerk_wait: float = 0
var spike: float = 0
var landing_time: float = 0
var _jerk_held: bool = false
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	process_physics_priority = -10
	rng.randomize()
	spool = spool.duplicate()
	update_rod(0.016)
	line_length = fish.position.distance_to(rod_tip)
	fish.endurance = fish.stamina_capacity
	fish.fight_regen_scale = 1
	_previous_heading = fish.heading
	rod_direction = Vector3.FORWARD.rotated(Vector3.UP,fisher.boat_yaw)
	_jerk_held = fisher.command.jerk # Require a fresh deliberate press after the bite.
	fish.feeding._dash_remaining = 0
	fish.feeding.is_charging = false
	fish.feeding.grace_remaining = 0
	fish.feeding.sweep_bite_disabled = true

func change_phase(next: int) -> void:
	if fisher.session.fight_smoke: print("FIGHT PHASE ",next)
	phase = next
	phase_time = 0

func _physics_process(delta: float) -> void:
	if phase == Phase.FINISHED: return
	if not is_instance_valid(fish) or not is_instance_valid(fisher): finish(Outcome.DISCONNECT); return
	phase_time += delta
	update_rod(delta)
	var input: FisherIntent = fisher.command
	var pressed = input.jerk and not _jerk_held
	var released = not input.jerk and _jerk_held
	_jerk_held = input.jerk
	if phase == Phase.CANDIDATE:
		if pressed: change_phase(Phase.METER)
		elif phase_time >= opportunity_window: finish(Outcome.MISSED)
		return
	if phase == Phase.METER:
		meter = 1-absf(1-fmod(phase_time/meter_duration,2))
		if released:
			var error = absf(meter-meter_target)
			quality = 3 if error <= perfect_window else 2 if error <= good_window else 1 if error <= weak_window else 0
			if quality == 0: finish(Outcome.MISSED); return
			fish.velocity += (fisher.position-fish.position).normalized()*yank_speed*(0.65+quality*0.25)
			fish.stamina = maxf(0,fish.stamina-hook_stamina_damage*quality/3.0)
			change_phase(Phase.IMPACT)
		elif phase_time > opportunity_window: finish(Outcome.MISSED)
		return
	if phase == Phase.IMPACT and phase_time >= recovery_time:
		change_phase(Phase.FIGHT if quality == 3 else Phase.OPENING)
	if phase == Phase.OPENING and phase_time >= opening_run_duration*(1.0 if quality == 1 else 0.65): change_phase(Phase.FIGHT)
	fish.free_bursts = phase == Phase.OPENING
	if not input.power: power_exhausted = false
	if fisher.stamina <= 1: power_exhausted = true
	var wanted_power = input.power and phase == Phase.FIGHT and not power_exhausted
	if wanted_power and not power_active:
		power_preexisting_sprint = fish.boosting
		power_locked_sprint = not power_preexisting_sprint
	power_active = wanted_power
	if not power_active: power_locked_sprint = false
	fish.sprint_locked = power_locked_sprint or phase == Phase.IMPACT
	if power_active: fisher.stamina = maxf(0,fisher.stamina-power_drain*delta)
	var outward = (fish.position-rod_tip).normalized()
	var view_forward = BaitMotion.horizontal(fish.position-fisher.position)
	var right = view_forward.cross(Vector3.UP)
	var mass = 3.2*(1+0.35*fish.growth_fraction())
	var radial_speed = fish.velocity.dot(outward)
	var effort = maxf(0,fish.command.throttle)
	# Heading projects propulsion onto the line: sideways swimming keeps its speed,
	# but supplies little outward pull and exposes the flank to counter pressure.
	var alignment = maxf(0,fish.heading.dot(outward))
	var drive = alignment*effort*fish.acceleration*mass*propulsion_load_scale
	if fish.boosting: drive *= fish.fight_boost_multiplier()
	var side_heading = fish.heading.dot(right)
	var counter = maxf(0,-side_heading*rod_horizontal)
	var vertical_counter = maxf(0,-fish.heading.y*rod_vertical)
	var broadside = 1-absf(fish.heading.dot(outward))
	var leverage = counter*(0.35+0.65*broadside)+vertical_counter*0.7
	var movement_load = drive
	jerk_wait = maxf(0,jerk_wait-delta)
	spike = maxf(0,spike-jerk_spike*delta*3)
	var diving = fish.velocity.y < -2 and fish.command.vertical < 0
	var resistance = leverage*effort
	if pressed and not fisher.vision_active and jerk_wait <= 0 and fisher.stamina >= jerk_cost:
		jerk_wait = jerk_cooldown
		fisher.stamina -= jerk_cost
		var dive_counter = diving and rod_vertical > 0.3
		spike = jerk_spike*(1.4 if dive_counter else 1)
		if spool.slack < slack_tolerance:
			fish.stamina = maxf(0,fish.stamina-jerk_damage*(1.4 if dive_counter else resistance))
	spool.step(delta,fish.position.distance_to(rod_tip),radial_speed,movement_load,input.retrieve,fisher.drag_setting,power_active,spike)
	tension = spool.tension
	condition = spool.condition
	var contact = clampf(1-spool.slack/slack_tolerance,0,1)
	var pressure = clampf(tension/spool.strength,0,1.5)*contact
	# Counter pressure adds physical acceleration; it never rewrites heading or aim.
	var lateral = (right*rod_horizontal*counter+Vector3.UP*rod_vertical*vertical_counter*0.7)*lateral_force*(0.35+0.65*broadside)*pressure
	fish.line_force = -outward*minf(tension,critical_load*2)/mass+lateral
	var yielding = maxf(0,-fish.heading.dot(outward))*effort
	fish.line_force += -outward*yielding*yield_bonus*contact
	var exertion = alignment*effort
	fish.fight_regen_scale = clampf(1-(resistance*3+exertion)*pressure*2,0,1)
	fish.stamina = maxf(0,fish.stamina-resistance_fatigue*(resistance+exertion*0.12)*pressure*delta)
	if phase == Phase.FIGHT:
		fish.fatigue((pressure_endurance_drain*exertion+leverage_endurance_drain*resistance)*pressure*delta)
	var turn_activity = fish.heading.angle_to(_previous_heading)/maxf(0.001,delta)
	_previous_heading = fish.heading
	if spool.slack > slack_tolerance:
		slack_time += delta
		if slack_time > 0.6: hook_security = maxf(0,hook_security-security_decay*(1+minf(2,turn_activity)+float(fish.airborne))*delta)
	else:
		slack_time = 0
		if tension > 2 and tension < safe_load: hook_security = minf(1,hook_security+security_recovery*delta)
	var hook_hazard = slack_throw_rate*pow(1-hook_security,2)*(1+minf(2,turn_activity))
	if fish.airborne:
		var lowered = rod_vertical < -0.25
		hook_hazard += jump_throw_rate*(lowered_rod_reduction if lowered else 1)*(1+1-hook_security)
		if not lowered: spool.condition = maxf(0.02,spool.condition-0.008*delta*tension/spool.strength)
	if rng.randf() < 1-exp(-hook_hazard*delta): finish(Outcome.THROWN); return
	if rng.randf() < 1-exp(-spool.break_hazard()*delta): finish(Outcome.LINE_BROKE); return
	if phase == Phase.FIGHT and fish.position.distance_to(fisher.position) < landing_distance and line_length < rod_length+landing_distance:
		landing_time += delta
		if landing_time >= landing_confirmation: finish(Outcome.LANDED)
	else: landing_time = 0

func update_rod(delta: float) -> void:
	if not fisher.vision_active:
		rod_horizontal = lerpf(rod_horizontal,clampf(fisher.command.rod_horizontal,-1,1),1-exp(-rod_response*delta))
		rod_vertical = lerpf(rod_vertical,clampf(fisher.command.rod_vertical,-1,1),1-exp(-rod_response*delta))
	var forward = BaitMotion.horizontal(fish.position-fisher.position)
	var yaw = FishInput.angles(forward).y-deg_to_rad(rod_horizontal_degrees)*rod_horizontal
	var pitch = deg_to_rad(rod_up_degrees if rod_vertical >= 0 else rod_down_degrees)*rod_vertical
	rod_direction = FishInput.from_angles(pitch,yaw)
	rod_hand = fisher.position+Vector3.UP*1.3
	var unloaded_tip = rod_hand+rod_direction*rod_length
	rod_tip = unloaded_tip+(fish.position-unloaded_tip).normalized()*rod_bend*clampf(tension/spool.strength,0,1)

func finish(result: int) -> void:
	if is_instance_valid(fisher) and fisher.session.fight_smoke: print("FIGHT OUTCOME ",result)
	if phase == Phase.FINISHED: return
	phase = Phase.FINISHED
	if is_instance_valid(fish):
		fish.endurance = fish.stamina_capacity
		fish.fight_regen_scale = 1
		fish.sprint_exhausted = false
		fish.line_force = Vector3.ZERO
		fish.free_bursts = false
		fish.sprint_locked = false
		fish.feeding.sweep_bite_disabled = false
		fish.fight = null
		if result == Outcome.LANDED:
			fish.reset_fish()
			fish.stamina = fish.stamina_capacity
	if is_instance_valid(fisher):
		fisher.outcome = result
		fisher.fight = null
		fisher.vision_active = false
		fisher.return_to_setup()
	queue_free()
