extends SceneTree
## Bounded progression contracts, not a balance simulation.
var failures: int = 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures += 1
func _init() -> void:
	var fisher = FisherActor.new()
	var driver = FightTestDriver.new()
	driver.fisher_input(fisher,0.016)
	check(fisher.cast_distance == 65,"AI uses unchanged human cast setting: 65 m")
	var line = FightLine.new()
	line.line_out = 40
	var pos = Vector3(40,0,0)
	var velocity = Vector3.ZERO
	for i in range(120):
		line.step(1.0/60,pos.length(),velocity.x,0,0,0.4,false,0,minf(1,i/60.0),1)
		velocity = line.rod_pull_velocity(pos,velocity,1.0/60,7)
		pos += line.constrain_motion(pos,velocity/60)
	check(pos.length() < 39 and is_equal_approx(line.line_out,40),"Rod lift physically closes controlled fish without reeling: distance %.2f line %.2f" % [pos.length(),line.line_out])
	line.step(1.0/60,pos.length(),0,0,0,0.4,false,0,0,0)
	check(line.slack > 1 and is_equal_approx(line.line_out,40),"Lowering without reel returns temporary gain as slack")
	for i in range(40): line.step(1.0/60,pos.length(),0,0,1,0.4,false,0,0,0)
	check(line.line_out < 39,"Lowering plus retrieve makes recovery permanent")
	var fish = FishPlayer.new()
	var fight = FightSession.new()
	fight.fish = fish
	fight.fisher = fisher
	fish.position = Vector3(40,-10,0)
	fight.spool.line_out = fish.position.length()
	fish.motion.overdrive = 0.3
	fish.motion.swim_drive = 1
	fish.motion.run_build = 1
	fight.apply_counter_recovery("OVERDRIVE",1,Vector3.LEFT,0)
	check(fish.motion.swim_drive == 0 and fish.motion.overdrive == 0 and fish.motion.run_build == 0 and fish.endurance < 92,"Overdrive counter clears Drive and costs meaningful endurance")
	for i in range(20): fish.motion.step(0.1,FishInput.new(1,0,0,Vector3.FORWARD,true),Vector3.FORWARD,1,100,false,1 if i%2 == 0 else -1)
	check(fish.motion.drive_lockout > 0 and fish.motion.swim_drive == 0 and fish.motion.overdrive == 0,"Alternating strokes cannot build Drive during 2.25 s lockout")
	fish.motion.step(0.3,FishInput.new(1),Vector3.FORWARD,1,100,false)
	check(fish.motion.drive_lockout == 0,"Drive lockout expires normally")
	fish.endurance = 100
	fish.stamina = 100
	fight.apply_counter_recovery("RUN",1,Vector3.LEFT,0)
	var run_loss = 100-fish.endurance
	fish.endurance = 100
	fish.stamina = 100
	fish.motion.diving = true
	fish.motion.dive_power = 1
	fight.apply_counter_recovery("DIVE",1,Vector3.UP,0)
	check(100-fish.endurance > run_loss and not fish.motion.diving and fish.motion.dive_power == 0 and fish.motion.counter_recovery >= 1.2,"Dive counter has stronger fatigue, interruption and recovery")
	fish.endurance = 100
	var high = fish.fatigue_multiplier()
	fish.endurance = 60
	var mid = fish.fatigue_multiplier()
	fish.endurance = 25
	var low = fish.fatigue_multiplier()
	check(high > mid and mid > low and high > 1.3 and low < 0.5,"Nonlinear endurance fatigue: %.2f / %.2f / %.2f" % [high,mid,low])
	fisher.fight = fight
	fisher.state = FisherActor.State.FIGHT
	fight.phase = FightSession.Phase.FIGHT
	fight.fisher_skill = 1
	fight.perception.observation = {"maneuver_id":1,"outward_speed":6,"payout":3,"side":0.5,"tension":30,"condition":1,"strength":110,"break_threshold":93.5,"line_out":50,"capacity":150}
	var attempts = 0
	var was_preparing = false
	for i in range(600):
		driver.fisher_input(fisher,1.0/60)
		var preparing = driver.gesture_phase >= 0
		if preparing and not was_preparing: attempts += 1
		was_preparing = preparing
	check(attempts == 1,"One unchanged perceived maneuver gets one counter attempt")
	check(is_equal_approx(fight.perception.reaction_delay,0.45) and fight.perception.vision_reaction_delay >= 0.2,"Normal and Vision perception retain human-scale delay")
	var vision_driver = FightTestDriver.new()
	fight.perception.observation.side = 0
	fight.perception.uncertainty = true
	vision_driver.gesture_wait = 100
	# Exercise eligible windows without injecting raw fish state into the policy.
	vision_driver.gesture_phase = -1
	vision_driver.gesture_wait = 0
	fight.perception.observation.outward_speed = 6
	var vision_starts = 0
	var prior = false
	for i in range(660):
		# Prevent a jerk from obscuring the independent Vision cooldown contract.
		vision_driver.attempted_maneuver = 1
		var intent = vision_driver.fisher_input(fisher,1.0/60)
		if intent.vision and not prior: vision_starts += 1
		prior = intent.vision
	check(vision_starts <= 1 and vision_driver.vision_cooldown > 0,"Vision cannot repeatedly flash within 11 seconds")
	fish.free()
	fisher.free()
	fight.free()
	quit(1 if failures else 0)
