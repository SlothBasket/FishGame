class_name FishFightMotion
extends Resource
## Server-owned fight effort. Keyboard, mouse and AI share one alternating stroke clock.
@export var sustainable_max: float = 1
@export var overdrive_max: float = 0.35
@export var ideal_stroke_interval: float = 0.48
@export var timing_tolerance: float = 0.16
@export var fast_cadence_scaling: float = 0.8
@export var drive_gain: float = 0.18
@export var drive_decay: float = 0.07
@export var overdrive_consumption: float = 0.65
@export var minimum_stroke_interval: float = 0.08
@export var run_build_time: float = 0.6
@export var dive_angle: float = 35
@export var dive_commit_time: float = 0.4
@export var dive_build_time: float = 1.0
@export var dive_counter_window: float = 0.55
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
var fast_cost: float = 0
var dive_hold: float = 0

func step(delta: float, input: FishInput, heading: Vector3, speed_fraction: float, stamina: float, bottom: bool) -> void:
	stroke_age += delta
	var axis = input.steering if absf(input.steering) > 0.25 else input.stroke_axis
	var side = int(signf(axis)) if absf(axis) > 0.25 else 0
	if input.throttle > 0 and side != 0 and side != last_side and stroke_age >= minimum_stroke_interval:
		if last_side != 0:
			var fast = clampf((ideal_stroke_interval-timing_tolerance-stroke_age)/ideal_stroke_interval,0,1)
			if fast > 0:
				overdrive = minf(overdrive_max,fast*fast_cadence_scaling)
				fast_cost = minf(3,ideal_stroke_interval/maxf(minimum_stroke_interval,stroke_age)-1)
			else:
				var quality = clampf(1-absf(stroke_age-ideal_stroke_interval)/maxf(0.01,timing_tolerance*2),0,1)
				swim_drive = minf(sustainable_max,swim_drive+drive_gain*quality)
				fast_cost = 0
		last_side = side
		stroke_age = 0
	if stroke_age > ideal_stroke_interval: fast_cost = 0
	swim_drive = maxf(0,swim_drive-(drive_decay+overdrive_consumption*fast_cost)*delta)
	overdrive = move_toward(overdrive,0,delta*0.2)
	run_build = move_toward(run_build,1 if input.boost and input.throttle > 0 and stamina > 0 else 0,delta/maxf(0.05,run_build_time))
	if not input.boost: dive_blocked = false
	if not input.boost or stamina <= 1 or bottom:
		diving = false
		dive_power = 0
		dive_hold = 0
	elif not diving and not dive_blocked:
		dive_hold = dive_hold+delta if heading.y < -sin(deg_to_rad(dive_angle)) and input.throttle > 0 else 0
		if dive_hold >= dive_commit_time: diving = true
	if diving: dive_power = minf(1,dive_power+delta/maxf(0.1,dive_build_time))
	# Built speed and motor effort share a bounded budget; speed is not added twice.
	var target = maxf(0,input.throttle)*(0.35+0.65*clampf(speed_fraction,0,1))*multiplier()*(1+run_build*0.6)
	propulsion = lerpf(propulsion,target,1-exp(-delta/0.25))

func multiplier() -> float:
	return 1+0.22*swim_drive/maxf(0.01,sustainable_max)+overdrive*swim_drive/maxf(0.01,sustainable_max)

func interrupt_dive() -> void:
	diving = false
	dive_power = 0
	dive_hold = 0
	dive_blocked = true # Require a new sprint commitment, not repeated instant dives.
