class_name BaitVisual
extends Node3D
## Only species, speed and twitch affect presentation; bait source is never inspected.

var kind: BaitMotion.Kind = BaitMotion.Kind.MINNOW
var bird_pose: int = 0 # 0 flight, 1 tucked dive, 2 floating, 3 underwater paddle
var speed: float = 0.0
var twitch: float = 0.0
var action: BaitMotion.Action = BaitMotion.Action.PAUSE
var _appendages: Array[Node3D] = []
var _body: Node3D
var _phase: float = 0.0

func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var dark = Geometry.bait_material("112e3b")
	if kind in [BaitMotion.Kind.MINNOW, BaitMotion.Kind.MULLET]:
		var silver = Geometry.bait_material("ccdfd3", 0.45)
		var blue = Geometry.bait_material("537f9a" if kind == BaitMotion.Kind.MINNOW else "728967", 0.3)
		Geometry.sphere(_body, "SilverBody", Vector3.ZERO, Vector3(0.16, 0.22, 0.55), silver)
		Geometry.sphere(_body, "BlueBack", Vector3(0, 0.1, 0.03), Vector3(0.14, 0.14, 0.45), blue)
		var tail = Node3D.new()
		tail.position = Vector3(0, 0, 0.42)
		_body.add_child(tail)
		_appendages.append(tail)
		Geometry.triangle(tail, Vector3.ZERO, Vector3(0, 0.29, 0.43), Vector3(0, -0.29, 0.43), silver)
		Geometry.triangle(_body, Vector3(0, 0.13, -0.1), Vector3(0, 0.4, 0.18), Vector3(0, 0.13, 0.32), blue)
		_eyes(dark, 0.13, 0.06, -0.36, 0.055)
	elif kind == BaitMotion.Kind.SHRIMP:
		var shell = Geometry.bait_material("e8a788", 0.15)
		var light = Geometry.bait_material("f3d4ae")
		for i in range(5):
			Geometry.sphere(_body, "ShellSegment", Vector3(0, sin(i * 0.65) * 0.11, (i - 2) * 0.15),
				Vector3(0.16 - i * 0.014, 0.15 - i * 0.012, 0.14), shell)
		for side in [-1, 1]:
			for i in range(3):
				var leg = Node3D.new()
				leg.position = Vector3(side * 0.1, -0.07, i * 0.12 - 0.2)
				_body.add_child(leg)
				_appendages.append(leg)
				Geometry.triangle(leg, Vector3.ZERO, Vector3(side * 0.23, -0.2, 0.1), Vector3(side * 0.08, -0.06, 0.12), light)
			Geometry.triangle(_body, Vector3(side * 0.06, 0.03, -0.3), Vector3(side * 0.34, 0.1, -1), Vector3(side * 0.08, 0.04, -0.33), light)
		Geometry.triangle(_body, Vector3(0, 0.04, 0.3), Vector3(-0.25, 0, 0.58), Vector3(0.25, 0, 0.58), shell)
		_eyes(dark, 0.12, 0.1, -0.35, 0.055)
	elif kind == BaitMotion.Kind.SQUID:
		var mantle = Geometry.bait_material("d3a8d7", 0.2)
		var fins = Geometry.bait_material("ae81bd")
		Geometry.sphere(_body, "Mantle", Vector3(0, 0, -0.2), Vector3(0.29, 0.3, 0.6), mantle)
		for side in [-1, 1]:
			Geometry.triangle(_body, Vector3(0, 0, -0.7), Vector3(side * 0.56, 0, -0.15), Vector3(0, 0, 0.2), fins)
		_eyes(dark, 0.26, 0.04, 0.14, 0.08)
		for i in range(6):
			var angle = i * TAU / 6.0
			var arm = Node3D.new()
			arm.position = Vector3(cos(angle) * 0.17, sin(angle) * 0.17, 0.25)
			_body.add_child(arm)
			_appendages.append(arm)
			Geometry.sphere(arm, "Tentacle", Vector3(0, 0, 0.33), Vector3(0.045, 0.045, 0.5 if i % 2 == 0 else 0.36), mantle)
	elif kind == BaitMotion.Kind.CRAB:
		var shell = Geometry.bait_material("b65f45", 0.2)
		Geometry.sphere(_body, "Shell", Vector3.ZERO, Vector3(0.46, 0.18, 0.36), shell)
		_eyes(dark, 0.20, 0.16, -0.16, 0.055)
		for side in [-1, 1]:
			var claw = Node3D.new()
			claw.position = Vector3(side * 0.38, 0, -0.24)
			_body.add_child(claw)
			_appendages.append(claw)
			Geometry.sphere(claw, "Claw", Vector3(side * 0.16, 0, -0.08), Vector3(0.18, 0.09, 0.14), shell)
			for i in range(3):
				var leg = Node3D.new()
				leg.position = Vector3(side * 0.32, -0.06, (i - 1) * 0.18)
				_body.add_child(leg)
				_appendages.append(leg)
				Geometry.triangle(leg, Vector3.ZERO, Vector3(side * 0.35, -0.12, 0.04), Vector3(side * 0.1, -0.04, 0.09), shell)
	elif kind == BaitMotion.Kind.GULL:
		var white = Geometry.bait_material("eee9d9")
		var tips = Geometry.bait_material("454d59")
		Geometry.sphere(_body, "Body", Vector3.ZERO, Vector3(0.25, 0.26, 0.6), white)
		Geometry.sphere(_body, "Head", Vector3(0, 0.15, -0.5), Vector3.ONE * 0.21, white)
		Geometry.sphere(_body, "Beak", Vector3(0, 0.12, -0.76), Vector3(0.08, 0.07, 0.18), Geometry.bait_material("dfb652"))
		for side in [-1, 1]:
			var wing = Node3D.new()
			_body.add_child(wing)
			_appendages.append(wing)
			Geometry.triangle(wing, Vector3(0, 0.1, -0.25), Vector3(side * 1.2, 0, 0.25), Vector3(0, 0.1, 0.35), white)
			Geometry.triangle(wing, Vector3(side * 0.9, 0, 0.1), Vector3(side * 1.5, 0, 0.42), Vector3(side * 1.1, 0, 0.3), tips)

	BaitMeshCache.combine(_body,str(kind)+":body")
	for i in range(_appendages.size()):
		BaitMeshCache.combine(_appendages[i],str(kind)+":"+str(i))

func _eyes(mat: Material, x: float, y: float, z: float, radius: float) -> void:
	for side in [-1, 1]:
		Geometry.sphere(_body, "Eye", Vector3(side * x, y, z), Vector3.ONE * radius, mat)

var _animation_wait: float = 0.0
var _animation_delta: float = 0.0
func _process(delta: float) -> void:
	_animation_wait -= delta
	_animation_delta += delta
	if _animation_wait > 0: return
	var camera = get_viewport().get_camera_3d()
	var distance = global_position.distance_squared_to(camera.global_position) if camera != null else 0.0
	visible = distance < 100.0 * 100.0
	_animation_wait = 0.12 if distance > 60.0 * 60.0 else 0.06 if distance > 30.0 * 30.0 else 0.0
	if not visible:
		_animation_delta = 0
		return
	delta = _animation_delta
	_animation_delta = 0
	_phase += delta * (4.0 + speed * 6.0)
	for i in range(_appendages.size()):
		var wave = sin(_phase + i * 0.8)
		match kind:
			BaitMotion.Kind.MINNOW, BaitMotion.Kind.MULLET:
				_appendages[i].rotation = Vector3(0, wave * 0.4, 0)
			BaitMotion.Kind.SHRIMP:
				_appendages[i].rotation = Vector3(wave * 0.4, 0, wave * 0.2)
			BaitMotion.Kind.SQUID:
				_appendages[i].rotation = Vector3(wave * 0.25, cos(_phase + i) * 0.25, 0)
			BaitMotion.Kind.CRAB:
				_appendages[i].rotation.z = wave * (0.35 if speed > 0.1 else 0.08)
			BaitMotion.Kind.GULL:
				var fold = 1.15 if bird_pose == 1 else 0.7 if bird_pose == 2 else 0.55 + sin(_phase*0.25)*0.45 if bird_pose == 3 else sin(_phase*0.18)*0.35
				_appendages[i].rotation.z = lerp_angle(_appendages[i].rotation.z, fold * (-1 if i == 0 else 1), 1-exp(-10*delta))
				_appendages[i].rotation.y = lerp_angle(_appendages[i].rotation.y, (0.6 if bird_pose == 1 else 0.0) * (-1 if i == 0 else 1), 1-exp(-10*delta))
			_:
				_appendages[i].rotation.y = wave * 0.12
	_body.scale = Vector3(1 - twitch * 0.16, 1 - twitch * 0.16, 1 + twitch * 0.12) if kind == BaitMotion.Kind.SQUID else Vector3.ONE
	_body.rotation = Vector3(0, sin(_phase * 1.4) * twitch * 0.22, 0) if kind == BaitMotion.Kind.MINNOW else Vector3.ZERO
