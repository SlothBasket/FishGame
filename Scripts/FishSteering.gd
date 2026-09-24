class_name FishSteering
extends Resource
## Physical head intent leads a speed-dependent body turn. No input flags earn strokes.
@export var maximum_yaw: float = 32
@export var maximum_pitch: float = 25
@export var head_response: float = 14
@export var body_response: float = 3.5
@export var idle_authority: float = 0.2
@export var stroke_head_degrees: float = 12
@export var stroke_body_degrees: float = 4
@export var shake_speed: float = 1.2
var offset: Vector2 = Vector2.ZERO # pitch, yaw radians relative to physical body
var stroke: float = 0
var stroke_side: int = 0
var body_travel: float = 0
var shake_pressure: float = 0
@export var shake_maximum_degrees: float = 12
@export var reversal_minimum_degrees: float = 3
var classification: int = 0 # 0 unclassified, 1 head shake, 2 body stroke
var half_peak: float = 0
var shake_side: int = 0
var shake_age: float = 10
var angular_velocity: float = 0
var impact_time: float = 0
var recoil: Vector2 = Vector2.ZERO
func step(delta: float, heading: Vector3, input: FishInput, forward_speed: float) -> Vector3:
	impact_time = maxf(0,impact_time-delta)
	shake_age += delta
	shake_pressure = maxf(0,shake_pressure-delta*1.3)
	stroke = 0
	var body = FishInput.angles(heading)
	var aim = FishInput.angles(input.aim_direction)
	var desired = Vector2(clampf(aim.x-body.x,-deg_to_rad(maximum_pitch),deg_to_rad(maximum_pitch)),clampf(angle_difference(body.y,aim.y)-input.steering*deg_to_rad(24),-deg_to_rad(maximum_yaw),deg_to_rad(maximum_yaw)))
	if impact_time > 0: desired = recoil
	var previous = offset
	offset = offset.lerp(desired,1-exp(-head_response*delta))
	angular_velocity = (offset.y-previous.y)/maxf(0.001,delta)
	var authority = lerpf(idle_authority,1,clampf(forward_speed/6,0,1))*(0.2 if impact_time > 0 else 1.0)
	var turn = offset*body_response*authority*delta
	body.x = clampf(body.x+turn.x,deg_to_rad(-85),deg_to_rad(85))
	body.y += turn.y
	offset -= turn
	body_travel += absf(turn.y)
	half_peak = maxf(half_peak,absf(offset.y))
	var side = int(signf(offset.y)) if absf(offset.y) >= deg_to_rad(reversal_minimum_degrees) else 0
	if impact_time <= 0 and side != 0 and side != shake_side:
		# Classify the completed half-stroke once. Reset travel at EVERY reversal,
		# so many tiny shakes cannot bank enough body travel to become propulsion.
		classification = classify_reversal(half_peak,body_travel,shake_age,absf(angular_velocity)) if shake_side != 0 else 0
		if classification == 1:
			shake_pressure = minf(1,shake_pressure+0.5)
		elif classification == 2:
			stroke = shake_side
			stroke_side = shake_side
			shake_pressure = 0
		body_travel = 0
		half_peak = absf(offset.y)
		shake_side = side
		shake_age = 0
	return FishInput.from_angles(body.x,body.y)
func knock(direction: Vector2, duration: float) -> void:
	recoil = Vector2(clampf(direction.x,-deg_to_rad(maximum_pitch),deg_to_rad(maximum_pitch)),clampf(direction.y,-deg_to_rad(maximum_yaw),deg_to_rad(maximum_yaw)))
	offset = recoil
	impact_time = duration
	shake_pressure = 0
	body_travel = 0
	half_peak = 0
	shake_side = 0

func classify_reversal(amplitude: float, body_turn: float, duration: float, speed: float) -> int:
	if amplitude <= deg_to_rad(shake_maximum_degrees) and amplitude >= deg_to_rad(reversal_minimum_degrees) and body_turn < deg_to_rad(stroke_body_degrees) and duration >= 0.08 and duration <= 0.32 and speed >= shake_speed: return 1
	if amplitude >= deg_to_rad(stroke_head_degrees) and body_turn >= deg_to_rad(stroke_body_degrees): return 2
	return 0
