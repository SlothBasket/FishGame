class_name FightLine
extends Resource
## Spool accounting in metres; force values are prototype Newton-like units.
const DEFAULT_CAPACITY: float = 150
@export var maximum_extension: float = 2.5
@export var maximum_line_out: float = DEFAULT_CAPACITY
@export var maximum_rod_take_up: float = 2.0
@export var maximum_rod_buffer: float = 15.0
@export var strength: float = 110
@export var elasticity: float = 22
@export var maximum_retrieve: float = 4.5
@export var power_retrieve: float = 7
@export var max_drag_force: float = 110
@export var base_outward_capacity: float = 330
@export var capacity_per_released_drag: float = 2
@export var force_per_payout_speed: float = 40 # force-equivalent units per m/s
var outward_capacity: float = 0
var payout_speed_limit: float = 0
var requested_retrieve: float = 0
var actual_recovery: float = 0
var retrieve_efficiency: float = 1
var reel_slip: float = 0
var outward_movement: float = 0
var extension: float = 0
var _step_distance: float = 0
var _step_line: float = 0
var _payout_allowance: float = 0
@export var maximum_payout: float = 14
@export var contact_tolerance: float = 0.25
@export var load_wear: float = 0.035
@export var slipping_reel_wear: float = 0.022
@export var shock_wear: float = 0.003
@export var power_wear: float = 0.035
# Wear starts below break risk. Thresholds are fractions of full line strength.
@export var wear_start: float = 0.545
@export var fresh_risk_threshold: float = 0.85
@export var damaged_risk_threshold: float = 0.60
@export var risk_curve: float = 1.1
@export var base_break_hazard: float = 0.008
@export var damage_hazard_multiplier: float = 16
@export var exposure_gain: float = 1
@export var exposure_decay: float = 1.5
@export var exposure_multiplier: float = 0.6
var high_load_exposure: float = 0
var fish_load: float = 0
var line_out: float = 0
var distance: float = 0
var slack: float = 0
var requested_load: float = 0
var tension: float = 0
var drag_threshold: float = 0
var line_rate: float = 0 # Positive = spool paying out, negative = recovery.
var payout: float = 0
var slipping: bool = false
var shock: float = 0
var condition: float = 1
var rod_take_up: float = 0
@export var low_rod_multiplier: float = 0.65
@export var high_rod_multiplier: float = 1.3
var pressure_multiplier: float = 1
var holding_threshold: float = 0
var _previous_load: float = 0

func step(delta: float, required_distance: float, outward_speed: float, movement_load: float, retrieve: float, drag: float, power: bool, transient_load: float = 0, rod_pull: float = 0, rod_elevation: float = 0) -> void:
	distance = maxf(0,required_distance)
	_step_distance = distance
	_step_line = line_out
	drag_threshold = max_drag_force*clampf(drag,0,1)
	outward_capacity = base_outward_capacity+capacity_per_released_drag*(max_drag_force-drag_threshold)
	payout_speed_limit = minf(maximum_payout,outward_capacity/maxf(0.01,force_per_payout_speed))
	_payout_allowance = payout_speed_limit*delta
	rod_take_up = maximum_rod_take_up*clampf(rod_pull,0,1)
	pressure_multiplier = lerpf(1,high_rod_multiplier,maxf(0,rod_elevation)) if rod_elevation >= 0 else lerpf(1,low_rod_multiplier,-rod_elevation)
	holding_threshold = (drag_threshold+maximum_rod_buffer*clampf(rod_pull,0,1))*pressure_multiplier
	var loaded_distance = distance+rod_take_up
	slack = maxf(0,line_out-loaded_distance)
	fish_load = maxf(0,movement_load)
	requested_retrieve = (power_retrieve if power else maximum_retrieve*clampf(retrieve,0,1))
	# The motor has a useful recovery ceiling. Excess cranking fails; it is never payout.
	var authority = maxf(1,holding_threshold*(1.5 if power else 1.0))
	var useful_speed = (power_retrieve if power else maximum_retrieve)*clampf(1-fish_load/authority,0,1)
	if slack > contact_tolerance: useful_speed = requested_retrieve
	var recovery = minf(requested_retrieve,useful_speed)*delta
	recovery = minf(recovery,maxf(0,line_out-maxf(0.2,loaded_distance-maximum_extension)))
	line_out -= recovery
	actual_recovery = recovery/maxf(0.0001,delta)
	retrieve_efficiency = actual_recovery/requested_retrieve if requested_retrieve > 0.001 else 1.0
	reel_slip = 1-retrieve_efficiency if requested_retrieve > 0.001 else 0.0
	payout = 0
	outward_movement = 0
	line_rate = -actual_recovery
	extension = maxf(0,loaded_distance-line_out)
	var contact = clampf(1-maxf(0,line_out-loaded_distance)/contact_tolerance,0,1)
	# Drag opposes load. It is not added to the Fish's whole force a second time.
	requested_load = maxf(fish_load,extension*elasticity)+maxf(0,transient_load)
	var excess = maxf(0,requested_load-drag_threshold-outward_capacity)
	var transmitted = minf(requested_load,drag_threshold)+excess
	# Moving a taut line outward must meet spool drag even when the smoothed
	# propulsion estimate lags the motor. Otherwise small force bonuses run away.
	if outward_speed > 0 and contact > 0:
		transmitted = maxf(transmitted,drag_threshold)
	# Stretch beyond the safety allowance is genuine unaccommodated separation.
	transmitted = maxf(transmitted,maxf(0,extension-maximum_extension)*elasticity)
	tension = transmitted*contact
	shock = maxf(0,tension-_previous_load)
	_previous_load = tension
	slipping = fish_load > drag_threshold and contact > 0
	slack = maxf(0,line_out-loaded_distance)
	var stress = maxf(0,tension/strength-wear_start)
	var wear = load_wear*stress*stress
	if reel_slip > 0: wear += slipping_reel_wear*reel_slip*retrieve*retrieve*(tension/strength)
	if power: wear += power_wear*stress*stress
	condition = maxf(0.02,condition-wear*delta-shock_wear*pow(shock/strength,2)*(0.25+retrieve))
	if tension > break_threshold(): high_load_exposure += delta*exposure_gain
	else: high_load_exposure = maxf(0,high_load_exposure-delta*exposure_decay)

func break_threshold() -> float:
	return strength*lerpf(damaged_risk_threshold,fresh_risk_threshold,pow(condition,risk_curve))

func break_hazard() -> float:
	var excess = maxf(0,(tension-break_threshold())/maxf(1,strength-break_threshold()))
	return base_break_hazard*excess*excess*(1+damage_hazard_multiplier*pow(1-condition,2))*(1+minf(12,high_load_exposure)*exposure_multiplier)

func sync_distance(required_distance: float, delta: float) -> void:
	# Only actual outward path growth may deploy new line. Called once after movement.
	var next_distance = maxf(0,required_distance)
	outward_movement = maxf(0,next_distance-_step_distance)
	var release = minf(outward_movement,_payout_allowance)
	release = minf(release,maxf(0,next_distance+rod_take_up-line_out))
	release = minf(release,maxf(0,maximum_line_out-line_out))
	line_out += release
	payout = release/maxf(0.0001,delta)
	line_rate = (line_out-_step_line)/maxf(0.0001,delta)
	distance = next_distance
	extension = maxf(0,distance+rod_take_up-line_out)
	slack = maxf(0,line_out-distance-rod_take_up)
	tension = maxf(tension,maxf(0,extension-maximum_extension)*elasticity)
	_payout_allowance = 0

@export var rod_pull_acceleration: float = 12
@export var rod_pull_response: float = 4
func rod_pull_velocity(offset: Vector3, velocity: Vector3, delta: float, maximum_speed: float) -> Vector3:
	if rod_take_up <= 0 or slack > contact_tolerance or offset.length() < 0.001: return velocity
	var available = clampf((holding_threshold-fish_load)/maxf(1,holding_threshold),0,1)
	var error = maxf(0,offset.length()-(line_out-rod_take_up))
	if error <= 0 or available <= 0: return velocity
	var outward = offset.normalized()
	var radial = velocity.dot(outward)
	var wanted = -minf(maximum_speed,error*rod_pull_response)*available
	if radial <= wanted: return velocity
	return velocity+outward*(move_toward(radial,wanted,rod_pull_acceleration*available*delta)-radial)

func constrain_motion(offset: Vector3, motion: Vector3) -> Vector3:
	# Unilateral velocity constraint at maximum elastic stretch. Keep tangential
	# movement and never generate a large inward correction for an existing error.
	var radius = maxf(0.2,line_out-rod_take_up+maximum_extension+_payout_allowance)
	var target = offset+motion
	if target.length() <= radius: return motion
	# Outside a shrinking radius, allow only the inward distance supplied by
	# physical velocity this tick. No positional teleport or protected old radius.
	var inward = maxf(0,-motion.dot(offset.normalized()))
	var reachable = maxf(radius,offset.length()-inward)
	return target.limit_length(reachable)-offset
