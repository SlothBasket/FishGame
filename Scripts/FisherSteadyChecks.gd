extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func _init() -> void:
	var actor = FisherActor.new()
	var fish = FishPlayer.new()
	var f = FightSession.new()
	actor.fight = f
	f.fisher = actor
	f.fish = fish
	f.phase = FightSession.Phase.FIGHT
	f.fisher_skill = 1
	var driver = FightTestDriver.new()
	driver.gesture_wait = 100
	var detector = RodGesture.new()
	var unwanted = 0
	for i in range(240):
		f.perception.observation = {"distance":22,"tension":30,"condition":1,"side":1 if i%30 < 15 else -1,"actual_recovery":1,"requested_retrieve":1,"retrieve_efficiency":1}
		var input = driver.fisher_input(actor,1.0/60)
		if detector.step(1.0/60,Vector2(input.rod_horizontal,input.rod_vertical),true) != RodGesture.Direction.NONE: unwanted += 1
	check(unwanted == 0,"Alternating observed pressure never produces accidental rod jerks")
	driver = FightTestDriver.new()
	detector = RodGesture.new()
	var jerks = 0
	var detector_wait = 0.0
	for i in range(180):
		f.perception.observation = {"distance":22,"tension":30,"condition":1,"side":-1,"outward_speed":5,"payout":4,"line_rate":4,"maneuver_id":1}
		var input = driver.fisher_input(actor,1.0/60)
		detector_wait = maxf(0,detector_wait-1.0/60)
		var event = detector.step(1.0/60,Vector2(input.rod_horizontal,input.rod_vertical),detector_wait <= 0)
		if event != RodGesture.Direction.NONE:
			jerks += 1
			detector_wait = f.jerk_cooldown
			check(event == RodGesture.Direction.RIGHT,"Intentional counter flick has correct direction")
	check(jerks == 1,"Preparation and return do not generate extra counter flicks")
	var slow = {"distance":22,"tension":30,"condition":1,"outward_speed":0,"actual_recovery":0.2,"requested_retrieve":2,"retrieve_efficiency":0.1}
	check(FisherControls.plan(slow,80).pump,"Weak close-range recovery permits a safe pump")
	for axis in [Vector3.FORWARD,Vector3(0,-0.9,-0.435).normalized()]:
		var distance = pull_trial(axis,false)
		check(distance < 19,"Pumping gains real ground against ordinary swimming: %.2f m from 22 m" % distance)
	var powered = pull_trial(Vector3.FORWARD,true)
	check(powered >= 21,"Strong powered resistance still prevents free recovery: %.2f m" % powered)
	f.free()
	fish.free()
	actor.free()
	quit(1 if failures else 0)

func pull_trial(axis: Vector3, powered: bool) -> float:
	var line = FightLine.new()
	line.line_out = 22
	var offset = axis*22
	var velocity = Vector3.ZERO
	for i in range(480):
		var phase = fmod(i/60.0,3.8)
		var lift = minf(1,phase/1.6) if phase < 2 else maxf(0,1-(phase-2)/1.4)
		line.step(1.0/60,offset.length(),velocity.dot(axis),150 if powered else 40,0.65,0.6,false,0,lift,lift)
		velocity = FishInput.next_velocity(velocity,axis,FishInput.new(1),9.76,1,0.4,24 if powered else 14.64,6,4,0.7,1.0/60)
		var force = -offset.normalized()*line.tension/3.2
		force.y = clampf(force.y*0.15,-2,2) # Existing FightSession vertical pull caps.
		velocity += force.limit_length(20)/60
		velocity = line.rod_pull_velocity(offset,velocity,1.0/60,7)
		var movement = line.constrain_motion(offset,velocity/60)
		offset += movement
		velocity = movement*60
		line.sync_distance(offset.length(),1.0/60)
	return offset.length()
