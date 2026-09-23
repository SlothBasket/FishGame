class_name FightDecisions
extends RefCounted
## One state-based policy for AI intent and development coaching; no random action cycling.
enum FishAction { RUN, LEFT, RIGHT, DIVE, JUMP, REST, CHARGE }
enum FisherAction { LEFT, RIGHT, UP, LOWER, REEL, LET_RUN }
static func fish_choice(f: FightSession, previous: int) -> int:
	var fish = f.fish
	var energy = fish.stamina/maxf(1,fish.endurance)
	var depth = fish.water_height-fish.position.y
	var pressure = f.tension/f.spool.strength
	if fish.motion.diving: return FishAction.DIVE
	if energy < 0.22 or (previous == FishAction.REST and energy < 0.7): return FishAction.REST
	var scores = [2.0+energy+fish.motion.swim_drive,0.0,0.0,-10.0,-10.0,0.0,-10.0]
	if f.rod_horizontal < -0.2: scores[FishAction.LEFT] = 3+absf(f.rod_horizontal)*3
	if f.rod_horizontal > 0.2: scores[FishAction.RIGHT] = 3+absf(f.rod_horizontal)*3
	if fish.position.y > 7 and energy > 0.55 and f.rod_vertical < 0.5 and not fish.motion.dive_blocked:
		scores[FishAction.DIVE] = 2.5+fish.motion.swim_drive*2+pressure
	if depth < 5 and depth > 0 and energy > 0.45 and f.rod_vertical >= 0:
		scores[FishAction.JUMP] = 3+pressure*3
	if f.spool.distance > 15 and f.spool.slack < 0.5 and pressure > 0.6 and energy > 0.3:
		scores[FishAction.CHARGE] = 3+pressure*2
	# A central rod plus strong pressure rewards changing the current side.
	if absf(f.rod_horizontal) < 0.2 and pressure > 0.55:
		var right = BaitMotion.horizontal(fish.position-f.fisher.position).cross(Vector3.UP)
		scores[FishAction.LEFT if fish.heading.dot(right) >= 0 else FishAction.RIGHT] = 3.8
	var best = FishAction.RUN
	for i in range(scores.size()):
		if scores[i] > scores[best]: best = i
	return best

static func fisher_choice(f: FightSession) -> int:
	if f.fish.airborne: return FisherAction.LOWER
	if f.fish.motion.diving:
		return FisherAction.UP if f.fish.motion.dive_power < f.fish.motion.dive_counter_window else FisherAction.LET_RUN
	if f.tension > f.spool.break_threshold()*0.9: return FisherAction.LET_RUN
	if f.spool.slack > 0.5: return FisherAction.REEL
	var right = BaitMotion.horizontal(f.fish.position-f.fisher.position).cross(Vector3.UP)
	var contest = FightContest.best_counter(f.fish.heading,right,false,false)
	if contest == FightContest.Counter.LEFT: return FisherAction.LEFT
	if contest == FightContest.Counter.RIGHT: return FisherAction.RIGHT
	return FisherAction.LET_RUN if f.spool.slipping else FisherAction.REEL

static func fish_text(action: int) -> String:
	return ["RUN","← LEFT","RIGHT →","↓ DIVE","↑ JUMP","REST","CHARGE BOAT"][clampi(action,0,6)]
static func fisher_text(action: int) -> String:
	return ["← PULL LEFT","PULL RIGHT →","↑ PULL UP","↓ LOWER ROD","REEL","LET RUN"][clampi(action,0,5)]
