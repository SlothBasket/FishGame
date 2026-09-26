class_name FishVisual
extends Node3D
## This root follows physical heading. Only the internal Body wiggles during charge.

@export var charge_wiggle_degrees: float = 3.0
@export var charge_tail_amplitude: float = 0.3
@export var charge_frequency: float = 24.0
var side_bank: float = 0
var drive: float = 0
var overdrive: float = 0
var swim_intensity: float = 0.0
var charge_intensity: float = 0.0
var biting: bool = false
@export var visual_head_fraction: float = 0.78
var head_offset: Vector2 = Vector2.ZERO
var impact: float = 0
var _head: Node3D
var _body: Node3D
var _tail: Node3D
var _left_fin: Node3D
var _right_fin: Node3D
var _jaw: MeshInstance3D
var _mouth: MeshInstance3D
var _phase: float = 0.0
var tail_follow: float = 0

func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var silver = Geometry.material("86c9ce", 0.35)
	var blue = Geometry.material("23758c", 0.3)
	var gold = Geometry.material("edc97e", 0.4)
	Geometry.sphere(_body, "BodyForm", Vector3.ZERO, Vector3(0.46, 0.58, 0.90), silver)
	Geometry.sphere(_body, "Back", Vector3(0, 0.22, 0.05), Vector3(0.4, 0.34, 1.02), blue)
	_head = Node3D.new()
	_head.position.z = -0.43
	_body.add_child(_head)
	Geometry.sphere(_head,"Head",Vector3(0,0,-0.25),Vector3(0.36,0.41,0.48),silver)
	# Fixed-size dark opening; the small jaw lowers only when actually biting.
	_mouth = Geometry.sphere(_head, "Mouth", Vector3(0, -0.04, -0.73), Vector3(0.13, 0.085, 0.018), Geometry.material("08252e"))
	_mouth.visible = false
	_jaw = Geometry.sphere(_head, "Jaw", Vector3(0, -0.13, -0.65), Vector3(0.15, 0.06, 0.13), silver)
	for side in [-1, 1]:
		Geometry.sphere(_head, "Eye", Vector3(side * 0.31, 0.12, -0.43), Vector3.ONE * 0.085, Geometry.material("112e3b"))
		var fin = Node3D.new()
		fin.position = Vector3(side * 0.34, -0.12, -0.1)
		_body.add_child(fin)
		Geometry.triangle(fin, Vector3.ZERO, Vector3(side * 0.58, -0.16, 0.52), Vector3(0, 0, 0.45), gold)
		if side == -1:
			_left_fin = fin
		else:
			_right_fin = fin
	Geometry.triangle(_body, Vector3(0, 0.4, -0.4), Vector3(0, 0.91, 0.25), Vector3(0, 0.38, 0.8), blue)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0, 1.0)
	_body.add_child(_tail)
	Geometry.triangle(_tail, Vector3.ZERO, Vector3(0, 0.7, 0.95), Vector3(0, 0, 0.65), gold)
	Geometry.triangle(_tail, Vector3.ZERO, Vector3(0, 0, 0.65), Vector3(0, -0.7, 0.95), gold)

func _process(delta: float) -> void:
	_phase += delta * (3.0 + swim_intensity * 8.0 + charge_intensity * charge_frequency + drive*7 + overdrive*20)
	_head.rotation = Vector3(head_offset.x,head_offset.y,0)*visual_head_fraction
	_body.rotation.y = lerpf(_body.rotation.y,head_offset.y*0.18+sin(_phase)*deg_to_rad(charge_wiggle_degrees)*charge_intensity,1-exp(-delta*5))
	_body.rotation.z = lerpf(_body.rotation.z,head_offset.y*impact+side_bank,1-exp(-delta*10))
	tail_follow = lerpf(tail_follow,-head_offset.y*0.35,1-exp(-delta*4))
	_tail.rotation.y = tail_follow+sin(_phase) * (0.14 + swim_intensity * 0.18 + charge_intensity * charge_tail_amplitude + drive*0.35 + overdrive*0.5)
	_left_fin.rotation.z = sin(_phase * 0.6) * 0.18
	_right_fin.rotation.z = -_left_fin.rotation.z
	_mouth.visible = biting
	_jaw.position.y = -0.2 if biting else -0.13
