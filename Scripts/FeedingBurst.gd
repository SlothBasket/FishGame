class_name FeedingBurst
extends Node3D
## Short-lived cosmetic bubbles. No collision, scoring, or gameplay state.

var tint: Color = Color.WHITE
var count: int = 8
var _specks: Array = []
var _age: float = 0.0

func _ready() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(count):
		var angle = i * 2.39996
		var drift = Vector3(cos(angle), 0.4 + (i % 3) * 0.35, sin(angle)) * (0.5 + i * 0.05)
		var mesh = Geometry.sphere(self, "Bubble", Vector3.ZERO, Vector3.ONE * (0.035 + i % 3 * 0.012), mat)
		_specks.append({"mesh": mesh, "drift": drift})

func _process(delta: float) -> void:
	_age += delta
	for speck in _specks:
		speck.mesh.position += speck.drift * delta
		speck.mesh.scale *= exp(-3.0 * delta)
	if _age > 0.6:
		queue_free()
