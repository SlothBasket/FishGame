class_name FishSteering
extends Resource
## Physical head intent leads a speed-dependent body turn. No input flags earn strokes.
@export var maximum_yaw: float = 32
@export var maximum_pitch: float = 25
@export var head_response: float = 14
@export var body_response: float = 3.5
@export var idle_authority: float = 0.2
@export var stroke_head_degrees: float = 8
@export var stroke_body_degrees: float = 1.2
@export var shake_speed: float = 1.2
var offset: Vector2 = Vector2.ZERO # pitch, yaw radians relative to physical body
var stroke: float = 0
var stroke_side: int = 0
var body_travel: float = 0
var shake_pressure: float = 0
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
	var side = int(signf(offset.y)) if absf(offset.y) >= deg_to_rad(stroke_head_degrees) else 0
	if impact_time <= 0 and side != 0 and side != stroke_side and body_travel >= deg_to_rad(stroke_body_degrees):
		stroke = side
		stroke_side = side
		body_travel = 0
	if impact_time <= 0 and side != 0 and side != shake_side and absf(angular_velocity) >= shake_speed:
		if shake_side != 0 and shake_age >= 0.1 and shake_age <= 0.65:
			shake_pressure = minf(1,shake_pressure+0.45*clampf(absf(angular_velocity)/3,0,1))
		shake_side = side
		shake_age = 0
	return FishInput.from_angles(body.x,body.y)
func knock(direction: Vector2, duration: float) -> void:
	recoil = Vector2(clampf(direction.x,-deg_to_rad(maximum_pitch),deg_to_rad(maximum_pitch)),clampf(direction.y,-deg_to_rad(maximum_yaw),deg_to_rad(maximum_yaw)))
	offset = recoil
	impact_time = duration
	shake_pressure = 0
