extends SceneTree
## Focused no-batch check: --headless --path <project> --script res://Scripts/HuntingChecks.gd -- --multi-actor --seed=17
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var world = load("res://Scenes/Reef.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	freeze(world)
	var session: NetworkSession = world.network_session
	assert(session.players.size() == 5)
	var fish: FishPlayer = session.players[-1].entity
	var fisher: FisherActor = session.players[-2].entity
	assert(is_equal_approx(fish.length_inches(),8))
	fish.feeding.food = 10000
	assert(absf(fish.length_inches()-46) < 0.01)
	fish.feeding.food = 18
	assert(fish.length_inches() < 12)
	var crab = BaitActor.new()
	crab.kind = BaitMotion.Kind.CRAB
	crab.minimum_eater_scale = 0.72
	assert(not fish.can_eat(crab))
	fish.feeding.food = 19
	assert(fish.can_eat(crab))
	var squid = BaitActor.new()
	squid.kind = BaitMotion.Kind.SQUID
	var interest = FishFoodInterest.new()
	assert(interest.eligible(crab,fish) and interest.eligible(squid,fish))
	crab.position = fish.position+Vector3(3,0,0)
	squid.position = fish.position+Vector3(4,0,0)
	assert(interest.choose(fish,[crab]) == crab and interest.choose(fish,[squid]) == squid)
	crab.free(); squid.free()
	var before = fish.length_inches()
	var food = fish.feeding.food
	var fight = FightSession.new()
	fight.fish = fish
	fight.fisher = fisher
	fisher.fight = fight
	fish.fight = fight
	world.add_child(fight)
	fight.finish(FightSession.Outcome.LANDED)
	fight.finish(FightSession.Outcome.LANDED)
	assert(is_equal_approx(fisher.score_inches,before))
	assert(is_instance_valid(fish.landing_show))
	fish.landing_show.finish_at(fish._spawn,false)
	assert(fish.feeding.food == food and is_equal_approx(fish.length_inches(),before))
	fish.motion = FishFightMotion.new()
	fish.motion.swim_drive = 0.6
	fish.command = FishInput.new(1,0,0,Vector3.FORWARD,true)
	fish.position = Vector3(0,15,0)
	fish.velocity = Vector3.ZERO
	for i in range(30): fish._physics_process(1.0/60)
	assert(fish.boosting and fish.velocity.length() > fish.effective_swim_speed()*1.25)
	assert(fish.motion.swim_drive < 0.6)
	var observer: FightSpectator
	for child in world.get_children():
		if child is FightSpectator: observer = child
	assert(observer != null)
	for i in range(5):
		var event = InputEventKey.new()
		event.keycode = KEY_1+i
		event.pressed = true
		observer._unhandled_input(event)
		assert(observer.focus_peer == [-1,-3,-4,-2,-5][i])
		observer._process(0.016)
	var director = CinematicDirector.new(observer,17)
	director.shot_age = 1
	director.hold_time = 8
	director.request_shot("fish-pov")
	var mode = observer.mode
	director.select_pending(fish)
	assert(observer.mode == mode)
	var school: BaitSchool = session.school
	# Initialize two ordinary pods without waiting for the staggered initial queue.
	for i in range(2): school._spawn(BaitMotion.Kind.MINNOW,school.pods[i].center,50+i,40,school.pods[i])
	var count = school._population.size()
	school.hotspot.start_event()
	assert(school.hotspot.active and school.hotspot.remaining >= 20 and school.hotspot.remaining <= 40)
	assert(school._population.size() == count+4)
	school.hotspot.start_event()
	assert(school._population.size() == count+4)
	school.hotspot.end_event()
	assert(not school.hotspot.active and not school.pods[0].event_active)
	assert(session.fisher_state(fisher).size() == 73)
	print("PASS hunting: inches/crab gate, squid eligibility, once-only landing score, retained growth, actual boosted motor speed, five actors/hotkeys, Director cut limit, bounded hotspot lifecycle.")
	quit()

func freeze(node: Node) -> void:
	node.set_physics_process(false)
	node.set_process(false)
	for child in node.get_children(): freeze(child)
