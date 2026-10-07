class_name HookRisk
extends Resource
@export var slack_base_hazard: float = 0.006
@export var airborne_base_hazard: float = 0.008
@export var meaningful_slack: float = 1.25
@export var slack_grace: float = 0.35
@export var catchup_slack_limit: float = 2.0
@export var maximum_looseness: float = 1.4
var looseness: float = 1
var hazard: float = 0
var slack_hazard: float = 0
var airborne_hazard: float = 0
var event_wait: float = 0 # Telemetry compatibility; headshake no longer changes looseness.
var loose_time: float = 0
var previous_slack: float = 0
func step(delta: float, slack: float, _shake: float, airborne: bool, severity: float, lowered: bool, radial_speed: float = 0, recovery: float = 0) -> void:
	var catching_up = radial_speed < -0.1 and recovery > 0.1 and slack <= catchup_slack_limit and slack <= previous_slack+0.1
	loose_time = loose_time+delta if slack > meaningful_slack and not catching_up else 0.0
	var slack_factor = clampf((slack-meaningful_slack)/2,0,2)
	slack_hazard = slack_base_hazard*slack_factor*looseness if loose_time >= slack_grace else 0.0
	airborne_hazard = airborne_base_hazard*clampf(severity,0,2)*looseness*(0.4 if lowered else 1.0) if airborne else 0.0
	hazard = slack_hazard+airborne_hazard
	previous_slack = slack
func violent_landing(severity: float) -> void:
	looseness = minf(maximum_looseness,looseness+0.06*clampf(severity,0,1))
