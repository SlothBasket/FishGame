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
@export var line_spring: float = 7
@export var velocity_load: float = 2
@export var reel_rate: float = 2.2
@export var power_reel_rate: float = 7
@export var power_drain: float = 24
@export var lateral_force: float = 12
@export var yield_bonus: float = 2
@export var resistance_fatigue: float = 8
@export var safe_load: float = 35
@export var stressed_load: float = 70
@export var critical_load: float = 110
@export var condition_damage_rate: float = 0.012
@export var healthy_break_rate: float = 0.00015
@export var damaged_break_rate: float = 0.035
@export var jerk_damage: float = 15
@export var jerk_spike: float = 35
@export var jerk_cooldown: float = 1.2
@export var jerk_cost: float = 14
@export var jump_throw_rate: float = 0.10
@export var lowered_rod_reduction: float = 0.12
@export var landing_distance: float = 3
@export var landing_stamina: float = 15
var fisher: FisherActor
var fish: FishPlayer
var bait: BaitActor
var phase: int = Phase.CANDIDATE
var phase_time: float = 0
var meter: float = 0
var quality: int = 0
var line_length: float = 0
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
	line_length = maxf(2,fish.position.distance_to(fisher.position))
	rod_direction = Vector3.FORWARD.rotated(Vector3.UP,fisher.boat_yaw)
	_jerk_held = fisher.command.jerk # Require a fresh deliberate press after the bite.
	fish.feeding._dash_remaining = 0
	fish.feeding.is_charging = false
	fish.feeding.grace_remaining = 0
	fish.feeding.sweep_bite_disabled = true

func change_phase(next: int) -> void:
	phase = next
	phase_time = 0

func _physics_process(delta: float) -> void:
	if phase == Phase.FINISHED: return
	if not is_instance_valid(fish) or not is_instance_valid(fisher): finish(Outcome.DISCONNECT); return
	phase_time += delta
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
	if not fisher.vision_active: rod_direction = FishInput.turn_toward(rod_direction,input.rod,delta*3)
	var wanted_power = input.power and phase == Phase.FIGHT and fisher.stamina > 1
	if wanted_power and not power_active:
		power_preexisting_sprint = fish.boosting
		power_locked_sprint = not power_preexisting_sprint
	power_active = wanted_power
	if not power_active: power_locked_sprint = false; power_preexisting_sprint = false
	fish.sprint_locked = power_locked_sprint or phase == Phase.IMPACT
	if power_active: fisher.stamina = maxf(0,fisher.stamina-power_drain*delta)
	var to_boat = fisher.position-fish.position
	var distance = to_boat.length()
	var inward = to_boat.normalized()
	var mass = maxf(0.65,pow(fish.size_multiplier(),2)*2)
	var outward_speed = maxf(0,-fish.velocity.dot(inward))
	var retrieve = power_reel_rate if power_active else reel_rate*input.retrieve
	line_length = maxf(1,line_length-retrieve*delta)
	var stretch = maxf(0,distance-line_length)
	var taut = clampf(stretch/0.6,0,1)
	var boat_right = Vector3.RIGHT.rotated(Vector3.UP,fisher.boat_yaw)
	var lateral = boat_right*clampf(rod_direction.dot(boat_right),-1,1)*lateral_force*taut
	var vertical = Vector3.UP*rod_direction.y*lateral_force*taut
	tension = (stretch*line_spring+outward_speed*velocity_load*mass+retrieve*2)*taut+lateral.length()+absf(vertical.y)
	if power_active and power_preexisting_sprint: tension += outward_speed*mass*3
	jerk_wait = maxf(0,jerk_wait-delta)
	spike = maxf(0,spike-jerk_spike*delta*2)
	var force = inward*tension+lateral+vertical
	var commitment = maxf(0,-fish.heading.dot(force.normalized()))*maxf(0,fish.command.throttle)
	var diving = fish.velocity.y < -2 and fish.command.vertical < 0
	if pressed and not fisher.vision_active and jerk_wait <= 0 and fisher.stamina >= jerk_cost:
		jerk_wait = jerk_cooldown
		fisher.stamina -= jerk_cost
		var dive_counter = diving and rod_direction.y > 0.3
		fish.stamina = maxf(0,fish.stamina-jerk_damage*(1.5 if dive_counter else commitment))
		fish.velocity += (Vector3.UP if dive_counter else rod_direction)*3*taut
		spike += jerk_spike*(1.5 if dive_counter else 1.0)
	tension += spike
	force += inward*spike
	if fish.airborne:
		var lowered = rod_direction.y < -0.2
		if not lowered: tension += safe_load*0.6; force += inward*safe_load*0.3
		if rng.randf() < 1-exp(-jump_throw_rate*(lowered_rod_reduction if lowered else 1.0)*delta): finish(Outcome.THROWN); return
	# Drag pays out under load. It is not an infinite-radius position constraint.
	if tension > stressed_load or (power_active and power_preexisting_sprint):
		line_length += (outward_speed+maxf(0,tension-stressed_load)*0.045)*delta
	var stress = maxf(0,(tension-safe_load)/maxf(1,critical_load-safe_load))
	condition = maxf(0.02,condition-condition_damage_rate*stress*(1+commitment+float(diving))*delta)
	var hazard = healthy_break_rate*pow(stress,3)+damaged_break_rate*pow(1-condition,2)*stress
	if rng.randf() < 1-exp(-hazard*delta): finish(Outcome.LINE_BROKE); return
	fish.stamina = maxf(0,fish.stamina-resistance_fatigue*commitment*taut*(tension/safe_load)*(1.4 if diving else 1.0)*delta)
	var yielding = maxf(0,fish.heading.dot(force.normalized()))*maxf(0,fish.command.throttle)
	fish.line_force = force.limit_length(critical_load*2)/mass+force.normalized()*yielding*yield_bonus*taut
	if phase == Phase.FIGHT and distance < landing_distance and line_length < landing_distance+1 and fish.stamina < landing_stamina:
		landing_time += delta
		if landing_time >= 1.0: finish(Outcome.LANDED)
	else: landing_time = 0

func finish(result: int) -> void:
	if phase == Phase.FINISHED: return
	phase = Phase.FINISHED
	if is_instance_valid(fish):
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
