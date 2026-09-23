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
	print("FORCE RANGE hard=",hard," tension=",threatened.tension," exceptional=",exceptional.tension," fresh risk=",exceptional.break_threshold())
	fight.free()
	fish.free()
	fisher.free()
	return ok
static func check(value: bool, description: String) -> bool:
	print("READABILITY ","PASS " if value else "FAIL ",description)
	return value
