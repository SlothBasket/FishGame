extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1

func _init() -> void:
	var motion = FishFightMotion.new()
	motion.swim_drive = 1
	check(is_equal_approx(motion.stored_force_multiplier(),1.35),"Full reserved Drive supplies 35% extra motor force")
	motion.swim_drive = 0.5
	check(is_equal_approx(motion.stored_force_multiplier(),1.0875),"Half the reserve retains one quarter of its nonlinear bonus")
	motion.power_capacity = 0
	check(is_equal_approx(motion.stored_force_multiplier(),1),"Reserve bonus respects exhausted endurance capacity")
	for state in ["ascending","airborne","jump_fall","slack"]:
		var seen = {"distance":22,"tension":20,"condition":1,"outward_speed":6,"payout":4,"line_rate":4,"requested_retrieve":4.5,"actual_recovery":0,"retrieve_efficiency":0}
		seen[state] = 3.0 if state == "slack" else true
		var plan = FisherControls.plan(seen,80)
		check(plan.retrieve == 1 and plan.vertical < -0.8 and not plan.pump and plan.jerk == Vector2.ZERO,"Jump/slack overrides stale run and efficiency: "+state)
	check(FisherControls.plan({"airborne":true,"tension":100},80).retrieve < 1,"Dangerous taut jump still limits retrieve")
	var actor = FisherActor.new()
	var fish = FishPlayer.new()
	var fight = FightSession.new()
	actor.fight = fight
	fight.fisher = actor
	fight.fish = fish
	fight.phase = FightSession.Phase.FIGHT
	var driver = FightTestDriver.new()
	driver.gesture_phase = 0.1
	driver.pump_clock = 1
	driver.vision_remaining = 1
	driver.steady_rod = Vector2(0,1)
	fight.perception.observation = {"jump_fall":true,"slack":3,"tension":10,"distance":22,"retrieve_efficiency":0,"requested_retrieve":4.5}
	var input
	for i in range(40): input = driver.fisher_input(actor,1.0/60)
	check(input.retrieve == 1 and input.rod_vertical < -0.8 and not input.vision and driver.gesture_phase < 0 and driver.pump_clock == 0,"AI aborts obsolete gestures/pump/Vision and lowers rod within 2/3 second")
	var line = FightLine.new()
	line.line_out = 25
	line.step(0.5,22,0,40,1,0.5,false,0,0,-0.85)
	line.sync_distance(22,0.5)
	check(is_equal_approx(line.line_out,22.75) and line.payout == 0,"Full retrieve captures 2.25 m of real slack in half a second")
	var reserved = pull_trial(1)
	var spent = pull_trial(0)
	print("Half-drag fixture: full reserve distance=",reserved," spent reserve distance=",spent)
	check(reserved > 22 and spent < reserved,"Reserved Drive permits unpowered payout at half drag; spent Drive resists less")
	fight.free()
	fish.free()
	actor.free()
	quit(1 if failures else 0)

# Bounded motor/spool integration, straight outward swimming with no sprint.
# Fixed reserves isolate their contribution; gameplay still builds/spends/decays them.
func pull_trial(reserve: float) -> float:
	var motion = FishFightMotion.new()
	motion.swim_drive = reserve
	var line = FightLine.new()
	line.line_out = 22
	var offset = Vector3.FORWARD*22
	var velocity = Vector3.ZERO
	var factor = motion.multiplier()*motion.stored_force_multiplier()
	for i in range(240):
		var load = (0.35+0.65*clampf(velocity.length()/8,0,1))*factor*12*3.2*0.85
		line.step(1.0/60,offset.length(),velocity.dot(Vector3.FORWARD),load,1,0.5,false)
		velocity = FishInput.next_velocity(velocity,Vector3.FORWARD,FishInput.new(1),8*motion.multiplier(),1,0.4,12*factor,6,4,0.7,1.0/60)
		velocity -= offset.normalized()*line.tension/3.2/60
		var movement = line.constrain_motion(offset,velocity/60)
		offset += movement
		velocity = movement*60
		line.sync_distance(offset.length(),1.0/60)
	return offset.length()
