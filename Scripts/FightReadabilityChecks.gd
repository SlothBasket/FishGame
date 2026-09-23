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
	fish.stamina = 10
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.REST,"Low stamina chooses REST") and ok
	fish.stamina = 100
	fight.rod_horizontal = -0.8
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.LEFT,"Left rod chooses LEFT") and ok
	fight.rod_horizontal = 0.8
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.RIGHT,"Right rod chooses RIGHT") and ok
	fight.rod_horizontal = 0
	fish.motion.swim_drive = 1
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.DIVE,"Depth and Drive opportunity chooses DIVE") and ok
	fish.position.y = 30
	fight.tension = 60
	fight.rod_vertical = 1
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.JUMP,"Near-surface pressure chooses JUMP") and ok
	fish.position.y = 20
	fight.tension = 100
	fight.spool.distance = 30
	ok = check(FightDecisions.fish_choice(fight,0) == FightDecisions.FishAction.CHARGE,"Taut pressured distance chooses CHARGE BOAT") and ok
	ok = check(FightDecisions.fisher_choice(fight) == FightDecisions.FisherAction.LET_RUN,"Dangerous load chooses LET RUN") and ok
	fight.free()
	fish.free()
	fisher.free()
	return ok
static func check(value: bool, description: String) -> bool:
	print("READABILITY ","PASS " if value else "FAIL ",description)
	return value
