class_name FightReadabilityChecks
extends RefCounted
## Small pure-state checks, run once before the natural spectator validation.
static func run() -> bool:
	var ok = true
	var drive = FishFightMotion.new()
	drive.swim_drive = 0.8
	drive.last_side = -1
	drive.stroke_age = 0
	drive.step(0.75,FishInput.new(1,1),Vector3.FORWARD,1,100,false)
	ok = check(drive.swim_drive > 0.8,"Late stroke earns partial credit") and ok
	var before = drive.swim_drive
	drive.step(0.5,FishInput.new(),Vector3.FORWARD,1,100,false)
	ok = check(is_equal_approx(before,drive.swim_drive),"Missed stroke retains Drive during decay delay") and ok
	drive.step(1,FishInput.new(),Vector3.FORWARD,1,100,false)
	ok = check(drive.swim_drive < before and drive.swim_drive > before-0.1,"Idle Drive decays gradually") and ok
	drive.swim_drive = 1
	for i in range(10): drive.step(0.2,FishInput.new(1,1 if i%2 == 0 else -1),Vector3.FORWARD,1,100,false)
	ok = check(drive.swim_drive > 0.25 and drive.overdrive > 0 and drive.multiplier() > 1.22,"Overdrive lasts seconds, spends Drive and exceeds full normal propulsion") and ok
	var fish = FishPlayer.new()
	var fisher = FisherActor.new()
	var fight = FightSession.new()
	fight.fish = fish
	fight.fisher = fisher
	fish.position = Vector3(20,20,0)
	fisher.position.y = fish.water_height
	fish.stamina = 10
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.REST,"Low stamina chooses REST") and ok
	fish.stamina = 100
	fish.directional_pressure = -0.8
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.LEFT,"Left physical pressure chooses LEFT") and ok
	fish.directional_pressure = 0.8
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.RIGHT,"Right physical pressure chooses RIGHT") and ok
	fish.directional_pressure = 0
	fish.motion.swim_drive = 1
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.DIVE,"Depth and Drive opportunity chooses DIVE") and ok
	fish.position.y = 30
	fight.tension = 60
	fight.rod_vertical = 1
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.JUMP,"Near-surface pressure chooses JUMP") and ok
	fish.position.y = 20
	fight.tension = 100
	fish.motion.dive_blocked = true
	fight.spool.distance = 30
	ok = check(FightDecisions.fish_choice(fight,0) in [FightDecisions.FishAction.RUN,FightDecisions.FishAction.LEFT,FightDecisions.FishAction.RIGHT],"Taut pressured distance stays in outward strategies") and ok
	ok = check(FightDecisions.fisher_choice(fight.perception.capture(fight)) == FightDecisions.FisherAction.LET_RUN,"Dangerous load chooses LET RUN") and ok
	ok = check(FightLine.DEFAULT_CAPACITY == 150,"Spool defaults to 150m") and ok
	ok = check(fight.directional_wear_rate(0.4,1,2,1,1) == 0 and fight.directional_wear_rate(1,1,2,1,1) > 0.001,"Extra directional wear requires high Drive and powered pressure") and ok
	fight.rod_horizontal = -1
	var physical_choice = FightDecisions.fish_choice(fight,0)
	fight.rod_horizontal = 1
	ok = check(FightDecisions.fish_choice(fight,0) == physical_choice,"Raw rod side cannot change fish choice") and ok
	var passive = fight.resistance_load(0,0,1,3.2,3,1)
	var hard = fight.resistance_load(2.2,1,1,3.2,1.5,1)
	ok = check(passive == Vector2.ZERO and hard.x > 70 and hard.y > 25,"Only powered resistance/turns create meaningful extra load") and ok
	var threatened = FightLine.new()
	threatened.line_out = 40
	threatened.fish_load = hard.x
	threatened.step(0.4,42,12,hard.x,0,0.4,false,hard.y,1)
	ok = check(threatened.tension > threatened.strength*threatened.wear_start and threatened.condition < 1,"Achievable hard run/turn enters wear range") and ok
	var exceptional = FightLine.new()
	exceptional.line_out = 40
	exceptional.fish_load = hard.x+35
	exceptional.step(0.4,42.4,18,hard.x+35,0,0.4,false,hard.y+50,1)
	ok = check(exceptional.tension > exceptional.break_threshold() and exceptional.break_hazard() > 0,"Exceptional powered turn/dive crosses probabilistic risk threshold") and ok
	var ordinary = FightLine.new()
	ordinary.line_out = 40
	ordinary.step(0.1,40,1,20,0,0.4,false)
	ok = check(ordinary.tension < ordinary.strength*ordinary.wear_start and ordinary.condition > 0.999,"Ordinary swim remains below meaningful wear") and ok
	var perception = FisherPerception.new()
	perception.reaction_jitter = 0
	perception.late_reaction_chance = 0
	perception.tick(0.1,fight)
	ok = check(perception.observation.is_empty(),"Fisher cannot act on a fresh observation immediately") and ok
	perception.tick(0.31,fight)
	ok = check(not perception.observation.is_empty() and perception.age() >= 0.3 and not perception.observation.has("stamina") and not perception.observation.has("drive") and not perception.observation.has("dive_power"),"Delivered perception is delayed and contains no hidden fish resources") and ok
	ok = gesture_and_pump_checks(fight) and ok
	print("FORCE RANGE hard=",hard," tension=",threatened.tension," exceptional=",exceptional.tension," fresh risk=",exceptional.break_threshold())
	fight.free()
	fish.free()
	fisher.free()
	return ok
static func check(value: bool, description: String) -> bool:
	print("READABILITY ","PASS " if value else "FAIL ",description)
	return value

static func gesture_and_pump_checks(f: FightSession) -> bool:
	var ok = true
	var g = RodGesture.new()
	g.step(0.016,Vector2.ZERO,false)
	var detected = 0
	for i in range(60): detected = maxi(detected,g.step(1.0/60,Vector2(i/60.0,0),true))
	ok = check(detected == 0,"Slow pump/reposition never jerks") and ok
	for axis in [Vector2.LEFT,Vector2.RIGHT,Vector2(0,1)]:
		g = RodGesture.new()
		g.step(0.016,Vector2.ZERO,false)
		detected = g.step(0.15,axis*0.8,true)
		ok = check(detected == (1 if axis.x < 0 else 2 if axis.x > 0 else 3),"Rapid rod gesture registers correct direction") and ok
	f.fish.motion.run_build = 1
	f.fish.motion.swim_drive = 1
	f.fish.motion.propulsion = 1.6
	f.fish.motion.overdrive = 0.25
	f.fish.motion.run_age = 0.4
	f.rod_pull = 1
	var heading = Vector3(-0.7,0,-0.7).normalized()
	var correct = f.jerk_contest(RodGesture.Direction.RIGHT,heading,Vector3.FORWARD,Vector3.RIGHT,1)
	var wrong = f.jerk_contest(RodGesture.Direction.LEFT,heading,Vector3.FORWARD,Vector3.RIGHT,1)
	ok = check(correct.y >= 0.65 and wrong.y == 0 and wrong.x > 0,"Matching early lateral jerk controls; wrong jerk only loads") and ok
	f.fish.motion.run_age = 4
	var late = f.jerk_contest(RodGesture.Direction.RIGHT,heading,Vector3.FORWARD,Vector3.RIGHT,1)
	ok = check(late.x > correct.x*2 and late.y < correct.y,"Late counters carry substantially more risk and less control") and ok
	f.fish.motion.diving = true
	f.fish.motion.dive_power = 0.1
	ok = check(f.jerk_contest(RodGesture.Direction.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT,1).y >= 0.65,"Early Dive responds to UP jerk") and ok
	f.fish.motion.diving = false
	f.fish.motion.run_age = 0
	ok = check(f.jerk_contest(RodGesture.Direction.UP,Vector3.FORWARD,Vector3.FORWARD,Vector3.RIGHT,1).y >= 0.65 and f.jerk_contest(RodGesture.Direction.LEFT,Vector3.FORWARD,Vector3.FORWARD,Vector3.RIGHT,1).y == 0,"Straight run requires UP rather than arbitrary lateral jerk") and ok
	ok = check(f.jerk_contest(RodGesture.Direction.UP,Vector3.FORWARD,Vector3.FORWARD,Vector3.RIGHT,0) == Vector2.ZERO,"Slack defeats jerk control") and ok
	var line = FightLine.new()
	line.line_out = 50
	line.step(0.1,50,0,10,0,0.4,false,0,1)
	ok = check(is_equal_approx(line.line_out,50) and line.rod_take_up == 2,"Pump creates temporary take-up, not permanent recovery") and ok
	line.step(0.1,50,0,10,0,0.4,false,0,0)
	ok = check(is_equal_approx(line.line_out,50) and line.rod_take_up == 0,"Lowering without reel returns temporary span") and ok
	# Integrate a yielding fish under measured line force, rather than granting a teleport.
	var distance: float = 50
	var speed: float = 0
	for i in range(90):
		line.step(1.0/60,distance,speed,10,0,0.4,false,0,1)
		speed += (3-line.tension/3.2-speed*2)/60
		distance += speed/60
	var before = line.line_out
	for i in range(90):
		line.step(1.0/60,distance,0,10,1,0.4,false,0,maxf(0,1-i/60.0))
	ok = check(before-line.line_out > 1 and line.line_out >= distance-line.maximum_extension,"Controlled pump/reel recovers meaningful metres within real separation") and ok
	line = FightLine.new()
	line.line_out = 50
	line.step(0.1,51,10,200,1,0.4,false,0,1)
	ok = check(line.line_out >= 50,"Reeling cannot win free line against overpowering payout") and ok
	var observed = {"tension":100,"strength":110,"condition":1,"outward_speed":7,"payout":5,"line_out":40,"capacity":150}
	ok = check(FightDecisions.fisher_choice(observed) == FightDecisions.FisherAction.LET_RUN,"Early spool allows conservative response") and ok
	observed.line_out = 140
	ok = check(FightDecisions.fisher_choice(observed) == FightDecisions.FisherAction.UP,"Near spool loss prioritizes active counter") and ok
	return ok
