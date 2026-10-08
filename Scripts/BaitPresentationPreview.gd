extends SceneTree
## Optional 30-second graphical control-path check, not a movie or fight batch.
class PreviewWorld extends Node3D:
	var water_depth: float = 12
	var arena_width: float = 200
	var color_rules = RoundColorRules.new()
class PreviewSession extends RefCounted:
	var world: Node3D
	var encounter_seed: int = 1729
	func register_bait(_bait: BaitActor) -> void: pass

func _initialize() -> void: call_deferred("preview")
func preview() -> void:
	root.size = Vector2i(960,540)
	var world = PreviewWorld.new(); root.add_child(world)
	var session = PreviewSession.new(); session.world = world
	var floor_body = StaticBody3D.new(); world.add_child(floor_body)
	var shape = CollisionShape3D.new(); shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(100,1,100); shape.position.y = -0.5; floor_body.add_child(shape)
	var mesh = MeshInstance3D.new(); mesh.mesh = BoxMesh.new(); mesh.mesh.size = shape.shape.size
	mesh.position = shape.position; floor_body.add_child(mesh)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("244957")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var sun = DirectionalLight3D.new(); world.add_child(sun); sun.rotation_degrees = Vector3(-45,-30,0)
	var camera = Camera3D.new(); world.add_child(camera); camera.make_current()
	var label = Label.new(); root.add_child(label); label.position = Vector2(24,24)
	var actor = FisherActor.new(); actor.session = session; world.add_child(actor)
	actor.set_physics_process(false); actor.position = Vector3(0,12,0)
	var pilot = FightTestDriver.new(); pilot.execution_rng.seed = 1729
	for kind in range(5):
		actor.return_to_setup()
		actor.kind = kind; actor.command.species = kind
		actor.cast() # Real cast creates the normal PlayerLiveDriver.
		for i in range(360):
			await physics_frame
			actor.command = pilot.fisher_input(actor,1.0/60)
			actor._physics_process(1.0/60)
			if not is_instance_valid(actor.lure): break
			var lure = actor.lure
			label.text = "%s / %s / reel %.0f%% / escape %s" % [lure.display_name(),pilot.presentation.phase,actor.command.retrieve*100,actor.command.escape]
			camera.position = lure.position+Vector3(4,2,5)
			camera.look_at(lure.position)
			if i == 300:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../../work/bait-presentation-%s.png" % kind)
		print("PREVIEW ",kind," completed via FisherActor -> PlayerLiveDriver")
	actor.return_to_setup(); world.queue_free(); label.queue_free()
	await process_frame
	quit()
