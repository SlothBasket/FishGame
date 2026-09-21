class_name FightLine
extends Resource
## Spool accounting in metres; force values are prototype Newton-like units.
const DEFAULT_CAPACITY: float = 250
@export var maximum_extension: float = 2.5
@export var maximum_line_out: float = DEFAULT_CAPACITY
@export var maximum_rod_take_up: float = 2.0
@export var maximum_rod_buffer: float = 15.0
@export var ordinary_response_time: float = 0.25
@export var strength: float = 110
@export var elasticity: float = 22
@export var maximum_retrieve: float = 4.5
@export var power_retrieve: float = 7
@export var drag_curve: float = 1.0
@export var payout_response: float = 6
@export var maximum_payout: float = 22
@export var tension_response: float = 12
@export var contact_tolerance: float = 0.25
@export var shock_retention: float = 0.18
@export var load_wear: float = 0.035
@export var slipping_reel_wear: float = 0.022
@export var shock_wear: float = 0.003
@export var power_wear: float = 0.035
# Wear starts below break risk. Thresholds are fractions of full line strength.
@export var reel_pressure: float = 20
@export var wear_start: float = 0.545
@export var fresh_risk_threshold: float = 0.773
@export var damaged_risk_threshold: float = 0.55
@export var risk_curve: float = 1.1
@export var base_break_hazard: float = 0.012
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
var holding_threshold: float = 0
var _previous_outward_speed: float = 0
var _previous_load: float = 0

func step(delta: float, required_distance: float, outward_speed: float, movement_load: float, retrieve: float, drag: float, power: bool, transient_load: float = 0, rod_pull: float = 0) -> void:
	distance = maxf(0,required_distance)
	drag_threshold = strength*pow(clampf(drag,0,1),drag_curve)
	rod_take_up = maximum_rod_take_up*clampf(rod_pull,0,1)
	holding_threshold = drag_threshold+maximum_rod_buffer*clampf(rod_pull,0,1)
	# Temporary rod take-up changes working span, never spool accounting. Use a
	# neutral-tip distance from FightSession so rod geometry is not counted twice.
	var loaded_distance = distance+rod_take_up
	var before = line_out
	var old_slack = slack
	var new_contact = loaded_distance >= line_out-contact_tolerance
	var sharp = power or transient_load > 0 or (old_slack > contact_tolerance and new_contact) or (outward_speed-_previous_outward_speed > 4)
	_previous_outward_speed = outward_speed
	var load_target = maxf(0,movement_load+maxf(0,outward_speed)*0.7)
	fish_load = load_target if sharp else lerpf(fish_load,load_target,1-exp(-delta/maxf(0.01,ordinary_response_time)))
	var recovery = (power_retrieve if power else maximum_retrieve*clampf(retrieve,0,1))
	if old_slack < contact_tolerance and not power:
		recovery *= lerpf(1,0.15,clampf(fish_load/maxf(1,holding_threshold),0,1))
	# A blocked fish cannot be reeled into a numerically short, infinitely stretched line.
	line_out = maxf(minf(line_out,maxf(0.2,loaded_distance-maximum_extension)),line_out-recovery*delta)
	var extension = maxf(0,loaded_distance-line_out)
	var contact = clampf(1-maxf(0,line_out-loaded_distance)/contact_tolerance,0,1)
	requested_load = maxf(0,extension*elasticity+fish_load+reel_pressure*(1.5 if power else retrieve)+transient_load)*contact
	# Load derivative catches real slack-to-taut reversals without a scripted combo.
	shock = maxf(0,requested_load-_previous_load)
	_previous_load = requested_load
	slipping = not power and (fish_load > holding_threshold+0.5 or extension*elasticity > holding_threshold) and contact > 0
	var payout_target = 0.0
	if slipping:
		payout_target = minf(maximum_payout,maxf(0,outward_speed)+recovery+maxf(0,extension-holding_threshold/elasticity)*payout_response)
	payout = lerpf(payout,payout_target,1-exp(-payout_response*delta)) if slipping else 0.0
	# Only release line actually demanded by separation; never manufacture slack
	# ahead of the fish using a predicted velocity. Power mode never pays out.
	var released_line = minf(payout*delta,maxf(0,loaded_distance-line_out))
	# Resolve unexpected initial/moving-anchor separation by paying real line now,
	# even under Power; never store impossible extension for a future snap.
	released_line = maxf(released_line,loaded_distance-line_out-maximum_extension)
	line_out = minf(maximum_line_out,line_out+released_line)
	payout = released_line/maxf(0.0001,delta)
	slack = maxf(0,line_out-loaded_distance)
	line_rate = (line_out-before)/maxf(0.0001,delta)
	var target_tension = requested_load if power else minf(requested_load,holding_threshold+shock*shock_retention)
	if slack > contact_tolerance: target_tension = 0
	var response = tension_response if sharp else 1/maxf(0.01,ordinary_response_time)
	tension = lerpf(tension,target_tension,1-exp(-response*delta))
	var stress = maxf(0,tension/strength-wear_start)
	var wear = load_wear*stress*stress
	if slipping and payout > 0.05: wear += slipping_reel_wear*retrieve*retrieve*(tension/strength)
	if power: wear += power_wear*stress*stress
	condition = maxf(0.02,condition-wear*delta-shock_wear*pow(shock/strength,2)*(0.25+retrieve))

	# Exposure remembers sustained danger but decays during safer pressure windows.
	if tension > break_threshold(): high_load_exposure += delta*exposure_gain
	else: high_load_exposure = maxf(0,high_load_exposure-delta*exposure_decay)

func break_threshold() -> float:
	return strength*lerpf(damaged_risk_threshold,fresh_risk_threshold,pow(condition,risk_curve))

func break_hazard() -> float:
	var excess = maxf(0,(tension-break_threshold())/maxf(1,strength-break_threshold()))
	return base_break_hazard*excess*excess*(1+damage_hazard_multiplier*pow(1-condition,2))*(1+minf(12,high_load_exposure)*exposure_multiplier)

func sync_distance(required_distance: float, delta: float) -> void:
	# Post-move safety reconciliation pays line, never teleports the fish. Usually
	# the pre-move constraint already keeps this within the elastic allowance.
	distance = maxf(0,required_distance)
	var needed = maxf(0.2,distance+rod_take_up-maximum_extension)
	var released = maxf(0,minf(maximum_line_out,needed)-line_out)
	line_out = minf(maximum_line_out,line_out+released)
	payout += released/maxf(0.0001,delta)
	line_rate += released/maxf(0.0001,delta)
	slack = maxf(0,line_out-distance-rod_take_up)

func constrain_motion(offset: Vector3, motion: Vector3) -> Vector3:
	# Unilateral velocity constraint at maximum elastic stretch. Keep tangential
	# movement and never generate a large inward correction for an existing error.
	var radius = maxf(offset.length(),maxf(0.2,line_out-rod_take_up+maximum_extension))
	var target = offset+motion
	return target.limit_length(radius)-offset if target.length() > radius else motion
