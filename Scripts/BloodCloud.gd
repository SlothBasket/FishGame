class_name BloodCloud
extends Node3D
## One unlit transparent mesh; no particle physics, decals or persistent nodes.
@export var lifetime: float = 0.65
@export var cloud_size: float = 0.7
var age: float = 0
var material: StandardMaterial3D
var puff: MeshInstance3D

func _ready() -> void:
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.36,0.045,0.065,0.3)
	puff = Geometry.sphere(self,"Cloud",Vector3.ZERO,Vector3.ONE*0.1,material)

func _process(delta: float) -> void:
	age += delta
	var t = clampf(age/lifetime,0,1)
	puff.scale = Vector3.ONE*lerpf(0.15,cloud_size,t)
	material.albedo_color.a = 0.3*(1-t)*(1-t)
	if age >= lifetime: queue_free()
