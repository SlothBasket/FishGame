class_name FightLine
extends Resource
## Spool accounting in metres; force values are prototype Newton-like units.
@export var strength: float = 110
@export var elasticity: float = 22
@export var maximum_retrieve: float = 4.5
@export var power_retrieve: float = 7
@export var drag_curve: float = 1.3
@export var payout_response: float = 6
@export var maximum_payout: float = 22
@export var tension_response: float = 12
@export var contact_tolerance: float = 0.25
@export var shock_retention: float = 0.18
@export var load_wear: float = 0.009
@export var slipping_reel_wear: float = 0.022
@export var shock_wear: float = 0.003
@export var power_wear: float = 0.018
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
var _previous_load: float = 0

func step(delta: float, required_distance: float, outward_speed: float, movement_load: float, retrieve: float, drag: float, power: bool) -> void:
	distance = maxf(0,required_distance)
	drag_threshold = strength*pow(clampf(drag,0,1),drag_curve)
	var before = line_out
	var old_slack = maxf(0,line_out-distance)
	var recovery = (power_retrieve if power else maximum_retrieve*clampf(retrieve,0,1))
	if old_slack < contact_tolerance and not power:
		recovery *= lerpf(1,0.25,clampf(tension/maxf(1,drag_threshold),0,1))
	line_out = maxf(0.2,line_out-recovery*delta)
	var extension = maxf(0,distance-line_out)
	var contact = clampf(1-maxf(0,line_out-distance)/contact_tolerance,0,1)
	requested_load = maxf(0,extension*elasticity+movement_load+maxf(0,outward_speed)*3+recovery*2)*contact
	# Load derivative catches real slack-to-taut reversals without a scripted combo.
	shock = maxf(0,requested_load-_previous_load)
	_previous_load = requested_load
	slipping = not power and requested_load > drag_threshold+0.5 and contact > 0
	var payout_target = 0.0
	if slipping:
		payout_target = minf(maximum_payout,maxf(0,outward_speed)+recovery+maxf(0,extension-drag_threshold/elasticity)*payout_response)
	payout = lerpf(payout,payout_target,1-exp(-payout_response*delta)) if slipping else 0.0
	# Only release line actually demanded by separation; never manufacture slack
	# ahead of the fish using a predicted velocity. Power mode never pays out.
	var released_line = minf(payout*delta,maxf(0,distance-line_out))
	line_out += released_line
	payout = released_line/maxf(0.0001,delta)
	slack = maxf(0,line_out-distance)
	line_rate = (line_out-before)/maxf(0.0001,delta)
	var target_tension = requested_load if power else minf(requested_load,drag_threshold+shock*shock_retention)
	if slack > contact_tolerance: target_tension = 0
	tension = lerpf(tension,target_tension,1-exp(-tension_response*delta))
	var stress = maxf(0,tension/strength-0.5)
	var wear = load_wear*stress*stress
	if slipping: wear += slipping_reel_wear*retrieve*retrieve*(tension/strength)
	if power: wear += power_wear*stress*stress
	condition = maxf(0.02,condition-wear*delta-shock_wear*pow(shock/strength,2)*(0.25+retrieve))
