class_name FightDecisions
extends RefCounted
## One state-based policy for AI intent and development coaching; no random action cycling.
enum FishAction { RUN, LEFT, RIGHT, DIVE, JUMP, REST }
enum FisherAction { LEFT, RIGHT, UP, LOWER, REEL, LET_RUN }
static func fish_choice(f: FightSession, previous: int) -> int:
	var fish = f.fish
	var energy = fish.stamina/maxf(1,fish.endurance)
	var depth = fish.water_height-fish.position.y
	var pressure = f.tension/f.spool.strength
	if fish.motion.diving: return FishAction.DIVE
	if energy < 0.22 or (previous == FishAction.REST and energy < 0.7): return FishAction.REST
	var scores = [2.0+energy+fish.motion.swim_drive,0.0,0.0,-10.0,-10.0,0.0]
	if f.rod_horizontal < -0.2: scores[FishAction.LEFT] = 3+absf(f.rod_horizontal)*3
	if f.rod_horizontal > 0.2: scores[FishAction.RIGHT] = 3+absf(f.rod_horizontal)*3
	if fish.position.y > 7 and energy > 0.55 and f.rod_vertical < 0.5 and not fish.motion.dive_blocked:
		scores[FishAction.DIVE] = 2.5+fish.motion.swim_drive*2+pressure+(0.6 if f.spool.payout < 0.5 else 0)
	if depth < 5 and depth > 0 and energy > 0.45 and f.rod_vertical >= 0:
		scores[FishAction.JUMP] = 3+pressure*3+(0.6 if f.rod_vertical > 0.3 else 0)
	# A central rod plus strong pressure rewards changing the current side.
	if absf(f.rod_horizontal) < 0.2 and pressure > 0.55:
		var right = BaitMotion.horizontal(fish.position-f.fisher.position).cross(Vector3.UP)
		scores[FishAction.LEFT if fish.heading.dot(right) >= 0 else FishAction.RIGHT] = 3.8+fish.motion.swim_drive*0.8
	var best = FishAction.RUN
	for i in range(scores.size()):
		if scores[i] > scores[best]: best = i
	return best

static func fisher_choice(observed: Dictionary) -> int:
	# Deliberately no FightSession argument: AI/coaching can only use delayed observations.
	if observed.is_empty(): return FisherAction.REEL
	if observed.get("airborne",false): return FisherAction.LOWER
	var strength = float(observed.get("strength",110))
	var condition = float(observed.get("condition",1))
	# Approximate risk tolerance, not the exact condition-dependent break threshold.
	if float(observed.get("tension",0)) > strength*(0.88 if condition > 0.7 else 0.72): return FisherAction.LET_RUN
	if observed.get("descending",false):
		return FisherAction.UP if float(observed.get("descending_time",0)) < 0.65 else FisherAction.LET_RUN
	if float(observed.get("slack",0)) > 0.5: return FisherAction.REEL
	var side = float(observed.get("side",0))
	if side < -0.2: return FisherAction.RIGHT
	if side > 0.2: return FisherAction.LEFT
	return FisherAction.LET_RUN if float(observed.get("payout",0)) > 1 else FisherAction.REEL

static func fish_text(action: int) -> String:
	return ["RUN","← LEFT","RIGHT →","↓ DIVE","↑ JUMP","REST"][clampi(action,0,5)]
static func fisher_text(action: int) -> String:
	return ["← PULL LEFT","PULL RIGHT →","↑ PULL UP","↓ LOWER ROD","REEL","LET RUN"][clampi(action,0,5)]
