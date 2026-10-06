extends SceneTree
## Focused no-batch check: --headless --path <project> --script res://Scripts/HuntingChecks.gd -- --multi-actor --seed=17
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	# Fuel channels must remain independent even with no measured stroke.
	for sprint in [false,true]:
		for overdrive in [false,true]:
			var motion = FishFightMotion.new()
			motion.swim_drive = 1
			motion.drive_decay = 0
			var intent = FishInput.new(1,0,0,Vector3.FORWARD,sprint)
			intent.overdrive = overdrive
			motion.step(0.1,intent,Vector3.FORWARD,1,100,false)
			assert((motion.stamina_share > 0) == sprint)
			assert((motion.overdrive > 0) == overdrive)
			assert((motion.swim_drive < 1) == overdrive)
			assert(motion.stamina_cost == 0)
			assert(is_equal_approx(motion.powered_output,1.2 if sprint and overdrive else 1.0 if sprint else 0.8 if overdrive else 0.0))
	var empty = FishFightMotion.new()
	empty.swim_drive = 0
	var renewable = FishInput.new(1)
	renewable.overdrive = true
	empty.step(0.1,renewable,Vector3.FORWARD,1,100,false)
	assert(not empty.powered_active and empty.stamina_share == 0)
	empty.swim_drive = 1
	empty.step(0.1,renewable,Vector3.FORWARD,1,0,false)
	assert(empty.overdrive > 0 and empty.stamina_share == 0)
	var world = load("res://Scenes/Reef.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	freeze(world)
	var session: NetworkSession = world.network_session
	assert(session.players.size() == 5)
	var fish: FishPlayer = session.players[-1].entity
	var fisher: FisherActor = session.players[-2].entity
	var fresh_force = fish.reserve_force_capacity()
	for i in range(3): fish.fatigue(7)
	var countered_force = fish.reserve_force_capacity()
	assert(countered_force < fresh_force*0.8)
	fish.endurance = 40
	assert(fish.reserve_force_capacity() < fresh_force*0.4)
	fish.endurance = fish.stamina_capacity
	print("PASS independent sprint/Overdrive fuel channels; fresh/countered force: ",fresh_force," / ",countered_force)
	assert(is_equal_approx(fish.length_inches(),8))
	fish.feeding.food = 10000
	assert(absf(fish.length_inches()-46) < 0.01)
	fish.feeding.food = 26
	assert(fish.length_inches() < 12)
	var crab = BaitActor.new()
	crab.kind = BaitMotion.Kind.CRAB
	crab.minimum_eater_scale = 0.72
	assert(not fish.can_eat(crab))
	fish.feeding.food = 27
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
	fish.command = FishInput.new(1,0,0,Vector3.FORWARD)
	fish.command.overdrive = true
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
	assert(school._targets == {0:51,1:7,2:16,3:7,4:18,5:2})
	assert(is_equal_approx(fish.growth_rate,0.0042))
	fish.feeding.food = 100
	assert(is_equal_approx(fish.growth_fraction(),1-exp(-0.42)))
	var speeds: Array[float] = []
	for reserve in [0.0,0.5,1.0,1.0]:
		fish.motion = FishFightMotion.new()
		fish.motion.swim_drive = reserve
		fish.motion.drive_decay = 0 # Isolate the speed curve, not timed decay.
		fish.position = Vector3(0,15,0)
		fish.heading = Vector3.FORWARD
		fish.velocity = Vector3.ZERO
		fish.head = FishSteering.new()
		fish.command = FishInput.new(1,0,0,Vector3.FORWARD,speeds.size() == 3)
		for tick in range(120): fish._physics_process(1.0/60)
		speeds.append(fish.velocity.length())
	assert(speeds[1] > speeds[0]*1.1 and speeds[2] > speeds[1] and speeds[3] > speeds[2])
	var seen = {"condition":0.65,"tension":50.0,"strength":110.0,"break_threshold":80.0,"distance":20.0,"drag":0.35,"line_out":22.0,"capacity":150.0,"line_rate":0.2,"outward_speed":1.0,"payout":0.4,"actual_recovery":0.1,"retrieve_efficiency":0.1,"stalled_seconds":5.0}
	var plan = FisherControls.plan(seen,80)
	assert(plan.drag >= 0.7 and plan.retrieve >= 0.8 and plan.power)
	var driver = FightTestDriver.new()
	for tick in range(240):
		plan = driver.persist_settings(FisherControls.plan(seen,80),seen,1.0/60)
		seen.drag = plan.drag
	assert(plan.drag >= 0.7)
	var line = FightLine.new()
	line.line_out = 20
	line.condition = 0.65
	line.step(0.1,20,0,70,plan.retrieve,plan.drag,plan.power)
	assert(line.actual_recovery > 0 and line.condition < 0.65)
	seen.tension = 85
	plan = FisherControls.plan(seen,80)
	assert(plan.drag < seen.drag and not plan.power and plan.retrieve <= 0.2)
	seen.tension = 45
	seen.outward_speed = 8
	seen.payout = 5
	seen.actual_recovery = 0
	seen.retrieve_efficiency = 0
	plan = FisherControls.plan(seen,80)
	assert(plan.drag >= 0.7 and plan.retrieve <= 0.15 and not plan.power)
	seen.outward_speed = 0
	seen.payout = 0
	seen.line_rate = -0.2
	plan = FisherControls.plan(seen,80)
	assert(plan.retrieve == 1 and plan.power)
	line.step(0.1,20,5,500,1,0.9,true,400)
	assert(line.break_hazard() > 0)
	print("PASS corrections: 99 live prey + 2 gulls; growth 0.0042; free-swim speeds zero/half/full/active=",speeds,"; worn-line closeout, pressure escalation, progress with wear, overload protection, run recovery and physical break hazard.")
	print("PASS hunting: inches/crab gate, squid eligibility, once-only landing score, retained growth, actual boosted motor speed, five actors/hotkeys, Director cut limit, bounded hotspot lifecycle.")
	quit()

func freeze(node: Node) -> void:
	node.set_physics_process(false)
	node.set_process(false)
	for child in node.get_children(): freeze(child)
