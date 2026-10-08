extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("verify")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func verify() -> void:
	var line = FightLine.new()
	for condition in [1.0,0.5]:
		line.condition = condition
		var values = [110,150,180,200] if condition == 1 else [100,110,120,140,160]
		for load in values:
			line.tension = load; line.high_load_exposure = 0
			var immediate = line.break_hazard()
			for i in range(600): line.update_exposure(1.0/60)
			print("HAZARD condition=",condition," load=",load," threshold=",line.break_threshold()," initial/s=",immediate," after10s/s=",line.break_hazard())
			if condition == 1 and load <= 150: check(immediate < 0.00001,"Fresh ordinary pressure safe")
			if condition == 0.5 and load >= 110: check(immediate > 0.001,"Damaged line has real risk")
	line.condition = 0.5; line.tension = 140; line.high_load_exposure = 5
	var loaded_hazard = line.break_hazard()
	line.tension = 60
	for i in range(300): line.update_exposure(1.0/60)
	check(line.high_load_exposure == 0 and line.break_hazard() == 0,"Yielding clears acute exposure")
	line.tension = 140
	check(line.break_hazard() < loaded_hazard,"Accumulated exposure increases hazard")
	var fish = load("res://Scenes/FishPlayer.tscn").instantiate()
	root.add_child(fish); fish.set_physics_process(false)
	fish.position = Vector3.ZERO; fish.heading = Vector3.FORWARD
	var speeds: Array[float] = []
	for reserve in [0.0,0.5,1.0]:
		fish.motion.swim_drive = reserve
		var velocity = Vector3.ZERO
		for i in range(180):
			velocity = FishInput.next_velocity(velocity,fish.heading,FishInput.new(1),fish.effective_swim_speed()*fish.free_swim_drive_multiplier(),1,fish.reverse_speed_multiplier,fish.acceleration*fish.free_swim_acceleration_multiplier(),fish.reverse_acceleration,fish.water_drag,fish.vertical_speed_multiplier,1.0/60)
		speeds.append(velocity.length())
	print("STEADY SPEEDS 0/50/100% = ",speeds)
	check(is_equal_approx(speeds[1]/speeds[0],1.2) and is_equal_approx(speeds[2]/speeds[0],1.4),"Actual motor reaches stored Drive speed targets")
	var fight = FightSession.new(); fight.fish = fish; fish.fight = fight
	var loads: Array[float] = []
	for reserve in [0.0,0.5,1.0,1.0]:
		var overdrive = loads.size() == 3
		fish.motion = FishFightMotion.new()
		var intent = FishInput.new(1); intent.overdrive = overdrive
		for i in range(180):
			# Controlled reserve levels isolate capability, not an autonomous fight.
			fish.motion.swim_drive = reserve
			fish.motion.step(1.0/60,intent,fish.heading,1,fish.stamina,false,0,fish.power_capacity())
		loads.append(fight.propulsion_force(1,3.2))
	print("FRESH SMALLEST FISH LOADS 0/50/100/100+OD = ",loads)
	check(loads[2]/loads[0] > 1.74 and loads[2]/loads[0] < 1.76,"Stored force 75% at full")
	check(loads[3] > loads[2],"Sustained Overdrive exceeds stored force")
	var safe = FightLine.new(); safe.line_out = 30
	safe.step(1.0/60,30,0,loads[0],1,0.9,false,0,0,0,1)
	var greedy = FightLine.new(); greedy.line_out = 30
	greedy._previous_load = 160; greedy._previous_fish_load = 160
	fight.overdrive_load_time = fight.overdrive_load_duration
	var spike = fight.propulsion_force(1,3.2)
	greedy.step(1.0/60,30,1,spike,1,0.9,true,0,0,0,-1)
	print("LEVERAGE empty/correct tension=",safe.tension," risk=",safe.break_hazard()," vs full OD/wrong tension=",greedy.tension," risk=",greedy.break_hazard()," spike load=",spike," hold=",greedy.holding_threshold)
	check(greedy.slipping and greedy.tension > safe.tension and greedy.break_hazard() > safe.break_hazard(),"Loaded full Drive spike threatens stubborn wrong leverage")
	greedy.sync_distance(30.05,1.0/60)
	check(greedy.payout > 0,"Full Drive load can deploy spool line")
	fish.fight = null; fight.free()
	var course = FisherRodCourse.new()
	for i in range(240): check(course.step([0.15,-0.18,0.20,-0.14][(i/8)%4],1.0/60) == 0,"Stroke wiggle does not chase rod")
	for i in range(30): course.step(0.7,1.0/60)
	check(course.side == 1,"Sustained course establishes opposite rod pressure")
	for i in range(10): course.step(-0.7,1.0/60)
	check(course.side == 1,"Brief reversal preserves commitment")
	for i in range(80): course.step(-0.7,1.0/60)
	check(course.side == -1,"Sustained reversal changes held rod")
	var counter = FisherControls.plan({"side":0.7,"outward_speed":5,"required_jerk":RodGesture.Direction.LEFT},100)
	check(counter.jerk == Vector2(-1,0),"Discrete side counter unaffected")
	var hunt = FishFoodInterest.new()
	var behind = BaitActor.new(); behind.kind = BaitMotion.Kind.MINNOW
	var ahead = BaitActor.new(); ahead.kind = BaitMotion.Kind.SHRIMP
	root.add_child(behind); root.add_child(ahead)
	behind.set_physics_process(false); ahead.set_physics_process(false)
	behind.position = Vector3(0,0,15); ahead.position = Vector3(0,0,-25)
	fish.velocity = Vector3.FORWARD*11; fish.motion = FishFightMotion.new(); fish.motion.swim_drive = 1
	check(hunt.choose(fish,[behind,ahead]) == ahead,"Full Drive prefers valuable forward prey")
	hunt.target = behind; hunt.state = FishFoodInterest.State.APPROACH
	check(not hunt.hunting_overdrive(fish,40,1,0.016),"Routine minnow cruising conserves Drive")
	var presenter = FisherBaitPresentationAI.new(); presenter.rng.seed = 1729
	var species = {}
	for i in range(5):
		var cast = presenter.choose_cast(); species[cast.species] = true
		check(cast.color_tag >= 0 and cast.color_tag <= 6,"Legal blind color")
	check(species.size() == 5,"Shuffled bag includes every species")
	for kind in range(5):
		var bait = BaitActor.new(); bait.kind = kind
		var driver = BaitMotion.PlayerLiveDriver.new(); bait.driver = driver
		root.add_child(bait); bait.set_physics_process(false)
		bait.position = Vector3(0,6,-10); bait.water_height = 15
		presenter.reset()
		var phases = {}; var pulses = 0; var escape_releases = 0; var last_escape = false
		for i in range(2400):
			if kind == BaitMotion.Kind.CRAB and i == 60: bait.position.y = 0.5 # Observable settled fixture.
			var intent = presenter.input(bait,Vector3(0,15,0),1.0/60)
			check(FisherIntent.decode(intent.numbers(),intent.flags()) != null,"Legal serialized intent")
			check(is_equal_approx(intent.retrieve,ReelSpeed.quantize(intent.retrieve)),"Shared reel tiers")
			phases[presenter.phase] = true
			driver.throttle = intent.retrieve; driver.steering = intent.steering
			driver.rise = intent.rise; driver.descend = intent.descend
			driver.escape_held = intent.escape; driver.aim_direction = intent.aim
			var command = driver.sample(bait,1.0/60)
			if command.flee_fraction >= 0: pulses += 1
			if last_escape and not intent.escape: escape_releases += 1
			last_escape = intent.escape
		print("PROFILE ",bait.display_name()," phases=",phases.keys()," motor pulses=",pulses," charged releases=",escape_releases)
		check(phases.has("pause") and escape_releases > 0 and pulses > 0,"Profile rests and legally escapes")
		if kind == BaitMotion.Kind.SQUID: check(phases.has("rise") and phases.has("descend") and pulses < 30,"Squid jets are discrete pulses")
		if kind == BaitMotion.Kind.CRAB: check(phases.has("bottom-seek") and phases.has("settle"),"Crab seeks bottom then settles")
		presenter.reset(); check(presenter.lure_id == 0 and presenter.phase_index == -1,"Lifecycle resets presentation")
		bait.queue_free()
	fish.queue_free(); behind.queue_free(); ahead.queue_free()
	await process_frame
	print("DRIVE/PRESENTATION CHECKS failures=",failures)
	quit(1 if failures else 0)
