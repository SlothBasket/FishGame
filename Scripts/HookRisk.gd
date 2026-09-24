class_name HookRisk
extends Resource
@export var slack_base_hazard: float = 0.006
@export var slack_shake_multiplier: float = 8
@export var airborne_base_hazard: float = 0.008
@export var airborne_shake_multiplier: float = 16
@export var maximum_looseness: float = 1.4
var looseness: float = 1
var hazard: float = 0
var slack_hazard: float = 0
var airborne_hazard: float = 0
var event_wait: float = 0
func step(delta: float, slack: float, shake: float, airborne: bool, severity: float, lowered: bool) -> void:
	event_wait = maxf(0,event_wait-delta)
	var slack_factor = clampf((slack-0.5)/2,0,2)
	slack_hazard = slack_base_hazard*slack_factor*looseness*(1+slack_shake_multiplier*shake)
	airborne_hazard = 0
	if airborne:
		airborne_hazard = airborne_base_hazard*clampf(severity,0,2)*looseness*(1+airborne_shake_multiplier*shake)*(0.4 if lowered else 1.0)
	hazard = slack_hazard+airborne_hazard
	if shake > 0.5 and event_wait <= 0 and (slack_factor > 0 or airborne):
		looseness = minf(maximum_looseness,looseness+0.02*shake)
		event_wait = 1
func violent_landing(severity: float) -> void:
	looseness = minf(maximum_looseness,looseness+0.06*clampf(severity,0,1))
