extends SceneTree
## No processes/movies are launched by this check.
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var launcher_script = load("res://Scripts/DevLauncher.gd")
	assert(launcher_script.parse_seeds("11,22,11") == [11,22,11])
	assert(launcher_script.parse_seeds("1,nope").is_empty())
	var launcher = launcher_script.new()
	launcher.seeds_field = LineEdit.new()
	launcher.seeds_field.text = "11,22,11"
	launcher.seed_field = LineEdit.new()
	launcher.parallel_count = SpinBox.new()
	launcher.parallel_count.value = 2
	launcher.record_multi = CheckBox.new()
	launcher.record_multi.button_pressed = true
	launcher.status = Label.new()
	for control in [launcher.seeds_field,launcher.seed_field,launcher.parallel_count,launcher.record_multi,launcher.status]: launcher.add_child(control)
	launcher.enqueue_recordings(PackedStringArray(["--ai-vs-ai","--capture","--director","--seed=11","--capture-one-fight","--capture-max-seconds=30"]),ProjectSettings.globalize_path("user://captures/check.avi"))
	assert(launcher.jobs.size() == 3 and launcher.queue_limit == 2)
	assert(launcher.jobs[0].movie != launcher.jobs[2].movie)
	for job in launcher.jobs:
		assert("--multi-actor" in job.args and not "--ai-vs-ai" in job.args)
		var args = launcher_script.process_arguments("C:/project with spaces",job.args,job.movie)
		assert("--write-movie" in args and "--fixed-fps" in args and "--quit-after" in args)
		assert(args[1] == "C:/project with spaces")
	var first_port = launcher.available_recording_port()
	assert(first_port > 0 and launcher.available_recording_port() != first_port)
	launcher.free()
	var world = load("res://Scenes/Reef.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var session: NetworkSession = world.network_session
	var view: FightSpectator
	for child in world.get_children():
		if child is FightSpectator: view = child
	assert(view != null and view.director != null)
	var director = view.director
	var fish: FishPlayer = session.players[-3].entity
	var fisher: FisherActor = session.players[-5].entity
	var fight = FightSession.new()
	fight.fish = fish
	fight.fisher = fisher
	fight.phase = FightSession.Phase.IMPACT
	fish.fight = fight
	fisher.fight = fight
	director.subject_age = 9
	director.shot_age = 9
	director.subject_wait = 0
	director.manual_focus_until = 0
	director.choose_subject(1)
	assert(view.focus_peer == -3 and view.subjects()[1] == fisher)
	view.set_shot("wide")
	director.preferred_subject = "fish"
	var composition = director.compose(fish,fisher,fish.position,fish.position+Vector3.ONE*300)
	assert(composition.position.distance_to(fish.position) < 45)
	for shot in ["surface-down","breach-side"]:
		view.set_shot(shot)
		view._process(0.016)
		assert(view.camera.position.is_finite())
	view.focus_actor(-4)
	assert(director.manual_focus_until > session.clock)
	fish.fight = null
	fisher.fight = null
	fight.free()
	var cast = BaitActor.new()
	cast.cast_remaining = 1
	fisher.lure = cast
	director.subject_age = 9
	director.shot_age = 9
	director.subject_wait = 0
	director.manual_focus_until = 0
	director.choose_subject(1)
	assert(session.players[view.focus_peer].entity is FisherActor)
	fisher.lure = null
	cast.free()
	print("PASS: seed validation, duplicate-safe jobs, worker arguments/unique ports, multi-actor subject pairing, bounded wide, surface shots, manual focus hold. No movies launched.")
	quit()
