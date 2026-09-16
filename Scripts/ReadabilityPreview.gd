class_name ReadabilityPreview
extends Node
## --readability-preview captures the environment, bait motion and boat/cast views.
func _ready() -> void:
	call_deferred("capture_views")

func capture_views() -> void:
	await get_tree().create_timer(16).timeout # Let the staggered population fill before inspection.
	var camera = Camera3D.new()
	get_parent().add_child(camera)
	camera.make_current()
	camera.fov = 65
	var views = [
		["floor", Vector3(0,7,5), Vector3(-14,0,-17)],
		["surface-below", Vector3(0,28,5), Vector3(0,32,-12)],
		["surface-above", Vector3(0,38,5), Vector3(0,32,-12)],
		["midwater", Vector3(-8,19,-3), Vector3(-28,15,-20)]]
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		await get_tree().create_timer(0.8).timeout
		await save_view(view[0])
	var shrimp = BaitActor.new()
	shrimp.kind = BaitMotion.Kind.SHRIMP
	shrimp.position = Vector3(0,12,0)
	shrimp.driver = BaitMotion.ControlledBaitDriver.new()
	get_parent().add_child(shrimp)
	camera.position = Vector3(3,13,3)
	camera.look_at(Vector3(0,13,0))
	shrimp.start_flee(1, Vector3.FORWARD)
	await get_tree().create_timer(0.25).timeout
	await save_view("shrimp-kick")
	await get_tree().create_timer(0.65).timeout
	camera.look_at(shrimp.position)
	await save_view("shrimp-glide")
	var controller = get_parent()._lure_test
	controller.cast_bait()
	await get_tree().create_timer(0.4).timeout
	await save_view("boat-aim")
	controller.cast_bait()
	await get_tree().create_timer(0.8).timeout
	await save_view("cast-flight")
	get_tree().quit()

func save_view(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../FishGame-" + label + ".png"))
