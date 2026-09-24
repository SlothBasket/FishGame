class_name FightSession
extends Node
## Server-only encounter. Drivers supply intent; this node owns outcomes and forces.
enum Phase { CANDIDATE, METER, IMPACT, OPENING, FIGHT, FINISHED }
enum Outcome { NONE, MISSED, LINE_BROKE, THROWN, LANDED, DISCONNECT, SPOOLED }
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
@export var shake_security_drain: float = 0.22
@export var shake_hook_hazard: float = 0.18
var hook_security: float = 1
var slack_time: float = 0
var rod_horizontal: float = 0
var rod_vertical: float = 0
var rod_tip: Vector3
var rod_hand: Vector3
var neutral_tip: Vector3
var rod_pull: float = 0
var _previous_heading: Vector3 = Vector3.FORWARD
var power_exhausted: bool = false
@export var power_drain: float = 24
@export var lateral_force: float = 30
@export var propulsion_load_scale: float = 0.85
@export var pressure_endurance_drain: float = 0.18
@export var leverage_endurance_drain: float = 0.95
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
@export var landing_distance: float = 4
@export var landing_depth: float = 6
@export var maximum_line_acceleration: float = 20
@export var maximum_vertical_acceleration: float = 2
@export var vertical_pull_fraction: float = 0.15
@export var maximum_pull_speed: float = 7
var counter_pressure: float = 0
var best_counter: int = 0
var fish_action: int = 0
var fisher_action: int = 4
var decision_wait: float = 0
var fish_skill: float = 1
var fisher_skill: float = 1
var jump_cooldown: float = 0
var jump_commit: float = 0
@export var directional_wear_scale: float = 0.0015
@export var pressure_dead_zone: float = 0.12
@export var pressure_bank_degrees: float = 27
var previous_pressure: float = 0
var reversal_bank: float = 0
var perception = FisherPerception.new()
@export var directional_load_scale: float = 1.1
@export var turn_shock_scale: float = 18
@export var maximum_turn_shock: float = 36
@export var turn_shock_decay_time: float = 0.18
var directional_load: float = 0
var turn_shock: float = 0
var line_damage_rate: float = 0
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
@export var gesture: RodGesture = RodGesture.new()
@export var jerk_counter_force: float = 65
@export var early_run_window: float = 0.9
@export var late_jerk_spike: float = 65
@export var counter_impulse: float = 4
var jerk_direction: int = 0
var jerk_notice_time: float = 0
var interruption: int = 0 # 1 run, 2 overdrive, 3 dive; authoritative successful counters only.
var recovery_total: float = 0
var jerk_wait: float = 0
var spike: float = 0
var landing_time: float = 0
var _jerk_held: bool = false
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	process_physics_priority = -10
	rng.randomize()
	fish_skill = rng.randf_range(0.6,1.0)
	fisher_skill = rng.randf_range(0.6,1.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fish-skill="): fish_skill = clampf(arg.get_slice("=",1).to_float(),0.6,1)
		if arg.begins_with("--fisher-skill="): fisher_skill = clampf(arg.get_slice("=",1).to_float(),0.6,1)
	perception.reaction_delay = lerpf(0.6,0.24,fisher_skill)
	perception.reaction_jitter = lerpf(0.28,0.06,fisher_skill)
	perception.late_reaction_chance = lerpf(0.5,0.08,fisher_skill)
	spool = spool.duplicate()
	gesture = gesture.duplicate()
	update_rod(0.016)
	line_length = fish.position.distance_to(neutral_tip)
	fish.motion = FishFightMotion.new()
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
	jerk_wait = maxf(0,jerk_wait-delta)
	jerk_notice_time = maxf(0,jerk_notice_time-delta)
	var gesture_direction = gesture.step(delta,Vector2(rod_horizontal,rod_vertical),phase in [Phase.OPENING,Phase.FIGHT] and not fisher.vision_active and jerk_wait <= 0 and fisher.stamina >= jerk_cost)
	perception.tick(delta,self)
	fisher_action = FightDecisions.fisher_choice(perception.observation)
	jump_cooldown = maxf(0,jump_cooldown-delta)
	jump_commit = maxf(0,jump_commit-delta)
	decision_wait -= delta
	if decision_wait <= 0:
		fish_action = FightDecisions.fish_choice(self,fish_action)
		if fish_action == FightDecisions.FishAction.JUMP and jump_commit <= 0:
			jump_commit = clampf((fish.water_height-fish.position.y)/5+1.5,2.2,7)
			jump_cooldown = 12
		decision_wait = lerpf(0.9,0.35,fish_skill)
	fish.fight_best_move = fish_action
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
			var yank = (fisher.position-fish.position).normalized()*yank_speed*(0.65+quality*0.25)
			yank.y = minf(0,yank.y)
			fish.velocity += yank
			fish.receive_impact(yank,quality/3.0)
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
	var outward = (fish.position-neutral_tip).normalized()
	var view_forward = BaitMotion.horizontal(fish.position-fisher.position)
	var right = view_forward.cross(Vector3.UP)
	var mass = 3.2*(1+0.35*fish.growth_fraction())
	var radial_speed = fish.velocity.dot(outward)
	var effort = maxf(0,fish.command.throttle)
	# Heading projects propulsion onto the line: sideways swimming keeps its speed,
	# but supplies little outward pull and exposes the flank to counter pressure.
	var contest = FightContest.evaluate(fish.heading,outward,right,rod_horizontal,rod_vertical)
	var alignment = contest.x
	var drive = alignment*fish.motion.propulsion*fish.acceleration*mass*propulsion_load_scale
	var counter = contest.y
	var vertical_counter = contest.z
	var broadside = 1-absf(fish.heading.dot(outward))
	var leverage = counter*(0.35+0.65*broadside)+vertical_counter*0.7
	var turn_rate = fish.heading.angle_to(_previous_heading)/maxf(0.001,delta)
	var connected_line = clampf(1-spool.slack/slack_tolerance,0,1)
	var struggle = resistance_load(fish.motion.propulsion,effort,leverage,mass,turn_rate,connected_line)
	directional_load = struggle.x
	turn_shock = maxf(turn_shock*exp(-delta/maxf(0.01,turn_shock_decay_time)),struggle.y)
	var movement_load = drive+directional_load+fish.motion.dive_power*35
	spike = maxf(0,spike-jerk_spike*delta*3)
	var diving = fish.motion.diving
	best_counter = FightContest.best_counter(fish.heading,right,diving,fish.motion.dive_power >= fish.motion.dive_counter_window)
	fish.fight_anchor = fisher.position
	var resistance = leverage*effort
	if gesture_direction != RodGesture.Direction.NONE:
		apply_directional_jerk(gesture_direction,outward,right,connected_line)
		# Counter changes physical velocity/effort before this tick's spool accounting.
		radial_speed = fish.velocity.dot(outward)
		movement_load = alignment*fish.motion.propulsion*fish.acceleration*mass*propulsion_load_scale+directional_load+fish.motion.dive_power*35
	var condition_before = spool.condition
	spool.step(delta,fish.position.distance_to(neutral_tip),radial_speed,movement_load,input.retrieve,fisher.drag_setting,power_active,spike+turn_shock,rod_pull)
	recovery_total += maxf(0,-spool.line_rate)*delta
	if check_spooled(): return
	tension = spool.tension
	condition = spool.condition
	var contact = clampf(1-spool.slack/slack_tolerance,0,1)
	var pressure = clampf(tension/spool.strength,0,1.5)*contact
	# Counter pressure adds physical acceleration; it never rewrites heading or aim.
	var lateral = (right*rod_horizontal*counter+Vector3.UP*rod_vertical*vertical_counter*0.7)*lateral_force*(0.35+0.65*broadside)*pressure
	fish.line_force = -outward*minf(tension,critical_load*2)/mass+lateral
	var yielding = maxf(0,-fish.heading.dot(outward))*effort
	fish.line_force += -outward*yielding*yield_bonus*contact
	# Publish the actual lateral acceleration after the same force cap as the body.
	var force_scale = controlled_force(fish.line_force).length()/maxf(0.001,Vector3(fish.line_force.x,clampf(fish.line_force.y*vertical_pull_fraction,-maximum_vertical_acceleration,maximum_vertical_acceleration),fish.line_force.z).length())
	fish.directional_pressure = lateral.dot(right)*force_scale/lateral_force
	var signed_pressure = fish.directional_pressure
	if previous_pressure*signed_pressure < -0.02: reversal_bank = 0.2
	reversal_bank = maxf(0,reversal_bank-delta)
	previous_pressure = signed_pressure
	var bank = pow(clampf((absf(signed_pressure)-pressure_dead_zone)/0.35,0,1),0.7)
	fish.fight_roll = lerpf(fish.fight_roll,-signf(signed_pressure)*deg_to_rad(pressure_bank_degrees)*bank*(1+reversal_bank),1-exp(-delta*7))
	# Additional wear only for built, powered resistance above ordinary wear onset.
	var wear = directional_wear_rate(fish.motion.swim_drive,fish.motion.run_build,fish.motion.propulsion,leverage,pressure)
	spool.condition = maxf(0.02,spool.condition-wear*delta)
	var exertion = alignment*effort
	fish.line_force = controlled_force(fish.line_force)
	counter_pressure = resistance*pressure
	fish.fight_regen_scale = 1
	var drain = resistance_fatigue*(resistance+exertion*0.12)*pressure
	# Resting is optional: ordinary swimming always retains net recovery. Correct
	# rod resistance still taxes endurance and reduces (rather than erases) regen.
	if not fish.boosting: drain = minf(drain,fish.stamina_regen*fish.fight_regen_multiplier*0.5)
	fish.stamina = maxf(0,fish.stamina-drain*delta)
	fish.fight_pressure = tension/spool.strength
	fish.fight_gain = spool.line_rate
	fish.fight_leverage = alignment
	fish.fight_counter = counter_pressure
	fish.fight_slack = spool.slack > slack_tolerance
	fish.fight_active = true
	if phase == Phase.FIGHT:
		fish.fatigue((pressure_endurance_drain*exertion+leverage_endurance_drain*resistance)*pressure*delta)
	var turn_activity = fish.heading.angle_to(_previous_heading)/maxf(0.001,delta)
	_previous_heading = fish.heading
	if spool.slack > slack_tolerance:
		slack_time += delta
		if slack_time > 0.6: hook_security = maxf(0,hook_security-security_decay*(1+minf(2,turn_activity)+float(fish.natural_breach))*delta)
	else:
		slack_time = 0
		if tension > 2 and tension < safe_load: hook_security = minf(1,hook_security+security_recovery*delta)
	var shaking = shake_effect(spool.slack,fish.head.shake_pressure)
	hook_security = maxf(0,hook_security-shaking*shake_security_drain*delta)
	var hook_hazard = shaking*shake_hook_hazard+slack_throw_rate*pow(1-hook_security,2)*(1+minf(2,turn_activity))
	if fish.airborne and fish.natural_breach:
		var lowered = rod_vertical < -0.25
		hook_hazard += jump_throw_rate*(lowered_rod_reduction if lowered else 1)*(2-hook_security+fish.motion.ascent_power+shaking)
		# Breach attacks hook security; line risk still comes from physical tension.
	line_damage_rate = maxf(0,(condition_before-spool.condition)/maxf(0.0001,delta))
	condition = spool.condition
	fish.damaging_line = line_damage_rate > 0.00001
	if rng.randf() < 1-exp(-hook_hazard*delta): finish(Outcome.THROWN); return
	if rng.randf() < 1-exp(-spool.break_hazard()*delta): finish(Outcome.LINE_BROKE); return

func update_rod(delta: float) -> void:
	if not fisher.vision_active:
		rod_horizontal = lerpf(rod_horizontal,clampf(fisher.command.rod_horizontal,-1,1),1-exp(-rod_response*delta))
		rod_vertical = lerpf(rod_vertical,clampf(fisher.command.rod_vertical,-1,1),1-exp(-rod_response*delta))
	var forward = BaitMotion.horizontal(fish.position-fisher.position)
	var yaw = FishInput.angles(forward).y-deg_to_rad(rod_horizontal_degrees)*rod_horizontal
	var pitch = deg_to_rad(rod_up_degrees if rod_vertical >= 0 else rod_down_degrees)*rod_vertical
	rod_direction = FishInput.from_angles(pitch,yaw)
	rod_hand = fisher.position+Vector3.UP*1.3
	neutral_tip = fisher.position # Stable water-level anchor; rod take-up is separate.
	# Lowering below center releases upward pressure; left/right still load the rod.
	rod_pull = minf(1,Vector2(rod_horizontal,maxf(0,rod_vertical)).length())
	var unloaded_tip = rod_hand+rod_direction*rod_length
	rod_tip = unloaded_tip+(fish.position-unloaded_tip).normalized()*rod_bend*clampf(tension/spool.strength,0,1)*(1+minf(1,counter_pressure)*0.65)

func finish(result: int) -> void:
	if is_instance_valid(fisher) and fisher.session.fight_smoke: print("FIGHT OUTCOME ",result)
	if phase == Phase.FINISHED: return
	phase = Phase.FINISHED
	if is_instance_valid(fisher) and is_instance_valid(fish): fisher.session.publish_fight_result(fish,fisher,result)
	if is_instance_valid(fish):
		fish.endurance = fish.stamina_capacity
		fish.fight_regen_scale = 1
		fish.sprint_exhausted = false
		fish.fight_active = false
		fish.line_force = Vector3.ZERO
		fish.directional_pressure = 0
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

func check_spooled() -> bool:
	if spool.line_out < spool.maximum_line_out: return false
	finish(Outcome.SPOOLED)
	return true

func controlled_force(force: Vector3) -> Vector3:
	force.y = clampf(force.y*vertical_pull_fraction,-maximum_vertical_acceleration,maximum_vertical_acceleration)
	# Fade upward rod acceleration before the water surface, including during Power.
	force.y = minf(force.y,maximum_vertical_acceleration*clampf((fish.water_height-fish.position.y-0.3)/2,0,1))
	return force.limit_length(maximum_line_acceleration)

func constrain_velocity(delta: float) -> void:
	if phase < Phase.IMPACT or phase == Phase.FINISHED: return
	fish.velocity = spool.constrain_motion(fish.position-neutral_tip,fish.velocity*delta)/maxf(0.0001,delta)

func landing_ready() -> bool:
	var offset = fish.position-fisher.position
	return Vector2(offset.x,offset.z).length() <= landing_distance and offset.y >= -landing_depth and offset.y <= 1 and line_length <= landing_depth+landing_distance and spool.slack <= 2.5

func after_fish_move(delta: float) -> void:
	if phase < Phase.IMPACT or phase == Phase.FINISHED: return
	spool.sync_distance(fish.position.distance_to(neutral_tip),delta)
	if check_spooled(): return
	if phase == Phase.FIGHT and landing_ready():
		landing_time += delta
		if landing_time >= landing_confirmation: finish(Outcome.LANDED)
	else: landing_time = 0

func resistance_load(propulsion: float, effort: float, leverage: float, mass: float, turn_rate: float, contact: float) -> Vector2:
	var powered = maxf(0,propulsion)*maxf(0,effort)*clampf(contact,0,1)
	var sustained = powered*maxf(0,leverage)*mass*fish.acceleration*propulsion_load_scale*directional_load_scale
	# Ordinary unpowered steering cannot make a shock. Fast hard turns need built
	# propulsion and an opposing rod; the transient is bounded independently.
	var shock_load = minf(maximum_turn_shock,maxf(0,powered-0.9)*maxf(0,leverage)*minf(turn_rate,3)*turn_shock_scale)
	return Vector2(sustained,shock_load)

func directional_wear_rate(drive: float, run: float, propulsion: float, leverage: float, pressure: float) -> float:
	return directional_wear_scale*clampf((drive-0.6)/0.4,0,1)*clampf(run,0,1)*clampf(propulsion-0.9,0,1)*clampf(leverage,0,1)*clampf((pressure-spool.wear_start)/0.35,0,1)

func jerk_contest(direction: int, heading: Vector3, outward: Vector3, right: Vector3, contact: float) -> Vector2:
	# x = line spike, y = control fraction. Wrong direction always loads the line.
	var side = heading.dot(right)
	var matched = false
	var committed = fish.motion.run_build > 0.3 and fish.motion.swim_drive > 0.55
	if fish.motion.diving:
		matched = direction == RodGesture.Direction.UP
	elif committed:
		if absf(side) > 0.25:
			matched = (side < 0 and direction == RodGesture.Direction.RIGHT) or (side > 0 and direction == RodGesture.Direction.LEFT)
		else: matched = direction == RodGesture.Direction.UP and heading.dot(outward) > 0.6
	var late = clampf((fish.motion.run_age-early_run_window)/1.5,0,1)
	if fish.motion.diving: late = clampf(fish.motion.dive_power/maxf(0.01,fish.motion.dive_counter_window),0,1)
	var resistance = 25+fish.motion.propulsion*15+fish.motion.swim_drive*12+fish.motion.overdrive*30+fish.motion.dive_power*20
	var force = jerk_counter_force*(0.65+0.35*rod_pull)
	return Vector2((jerk_spike+late*late_jerk_spike)*contact,clampf(force/(resistance*(1+late*0.65)),0,1)*contact if matched else 0.0)

func apply_directional_jerk(direction: int, outward: Vector3, right: Vector3, contact: float) -> void:
	jerk_wait = jerk_cooldown
	fisher.stamina = maxf(0,fisher.stamina-jerk_cost)
	jerk_direction = direction
	jerk_notice_time = 0.8
	interruption = 0
	var result = jerk_contest(direction,fish.heading,outward,right,contact)
	spike = maxf(spike,result.x)
	if result.y <= 0: return
	var impulse_direction = Vector3.UP if direction == RodGesture.Direction.UP and fish.motion.diving else -outward
	fish.velocity += impulse_direction*counter_impulse*result.y
	fish.stamina = maxf(0,fish.stamina-jerk_damage*result.y)
	if fish.motion.diving:
		if result.y >= 0.65:
			fish.motion.interrupt_dive()
			fish.motion.interrupt_run()
			interruption = 3
		else: fish.motion.dive_power *= 1-result.y*0.5
	else:
		if result.y >= 0.65:
			interruption = 2 if fish.motion.overdrive > 0 else 1
			fish.motion.interrupt_run()
		else:
			fish.motion.overdrive *= 1-result.y*0.5
			fish.motion.run_build *= 1-result.y*0.3
	if interruption > 0:
		fish.receive_impact(impulse_direction+right*(-1 if direction == RodGesture.Direction.LEFT else 1 if direction == RodGesture.Direction.RIGHT else 0),result.y)
		fisher.session.publish_fight_counter(fish,fisher,interruption)

func shake_effect(slack: float, shaking: float) -> float:
	return clampf((slack-slack_tolerance)/2,0,1)*clampf(shaking,0,1)
