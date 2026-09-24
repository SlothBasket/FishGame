extends SceneTree
## Focused, bounded contracts for total-load drag and shared lateral steering.
var failures: int = 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures += 1
func _init() -> void:
	for power in [false,true]:
		var line = FightLine.new()
		line.line_out = 40
		line.step(1.0/60,40,0,20,0.5,0.4,power,100)
		check(line.slipping and line.payout > 0 and line.payout <= 14,"Transient starts finite payout immediately; power=%s payout=%.2f" % [power,line.payout])
	var huge = FightLine.new()
	huge.line_out = 40
	for i in range(30): huge.step(1.0/60,40+(i+1)*0.5,30,200,1,0.4,true,120)
	check(huge.payout <= 14.001 and huge.payout > 13 and huge.tension > huge.break_threshold() and huge.break_hazard() > 0,"30 m/s separation overwhelms finite 14 m/s payout")
	var f = FightSession.new()
	var fish = FishPlayer.new()
	fish.feeding = FishFeeding.new(fish)
	var fisher = FisherActor.new()
	var session = NetworkSession.new()
	var world = load("res://Scripts/Reef.gd").new()
	session.world = world
	fisher.session = session
	f.fish = fish
	f.fisher = fisher
	fish.fight = f
	fish.position = Vector3(0,-10,-40)
	f.phase = FightSession.Phase.METER
	f.update_rod(0)
	f.spool.line_out = 20
	f.sync_pre_hook_line()
	check(is_zero_approx(f.spool.distance+f.spool.rod_take_up-f.spool.line_out) and f.spool.tension == 0,"Pre-hook geometry stays unloaded")
	f.hook_snap_time = 0
	for i in range(12): f.update_rod(1.0/60)
	check(f.rod_direction.y > 0.8 and f.rod_tip.y > f.rod_hand.y+2,"Actual rod geometry snaps upward in 0.2 s")
	# Use the AI's actual input path, seeded once for each chosen legal side.
	var found: Dictionary = {}
	for seed_value in range(12):
		if found.size() == 2: break
		var driver = FightTestDriver.new()
		driver.execution_rng.seed = seed_value
		driver.side_wait = 0
		driver.run_committed = true
		fish.motion = FishFightMotion.new()
		fish.motion.swim_drive = 1
		fish.motion.run_build = 1
		fish.heading = Vector3.FORWARD
		fish.head = FishSteering.new()
		fish.stamina = 100
		fish.endurance = 100
		f.fish_action = FightDecisions.FishAction.RUN
		var emitted: int = 0
		for i in range(65):
			var intent = driver.fish_input(fish,session,1.0/60)
			intent = fish.motion.steer_burst(1.0/60,intent,fish.heading,true)
			fish.heading = fish.head.step(1.0/60,fish.heading,intent,10)
			if fish.motion.side_event != 0: emitted = fish.motion.side_event
		if emitted != 0: found[emitted] = true
	check(found.has(-1) and found.has(1),"AI legal aim produces physical LEFT and RIGHT bursts")
	var observed = {"tension":100,"break_threshold":90,"condition":0.8,"drag":0.4}
	check(FisherControls.plan(observed,100).drag == 0.3,"Observed danger lowers drag target")
	fish.fight = null
	fish.free()
	fisher.free()
	f.free()
	session.free()
	world.free()
	quit(1 if failures else 0)
