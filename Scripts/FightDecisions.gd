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
	if f.jump_commit > 0: return FishAction.JUMP
	if fish.motion.diving: return FishAction.DIVE
	if energy < 0.22 or (previous == FishAction.REST and energy < 0.7): return FishAction.REST
	var scores = [2.0+energy+fish.motion.swim_drive,1.0,1.0,-10.0,-10.0,-10.0]
	# Same signed acceleration supplied to the human's chevrons and body bank.
	var pull = fish.directional_pressure
	if absf(pull) > f.pressure_dead_zone:
		scores[FishAction.LEFT if pull < 0 else FishAction.RIGHT] = 4+absf(pull)*5
	if fish.position.y > 7 and energy > 0.55 and not fish.motion.dive_blocked:
		scores[FishAction.DIVE] = 2.5+fish.motion.swim_drive*2+pressure
	if depth < 5 and depth > -0.5 and energy > 0.5 and f.jump_cooldown <= 0:
		scores[FishAction.JUMP] = 4+pressure*4+maxf(0,fish.line_force.y)*0.4
	var outward = (fish.position-f.fisher.position).normalized()
	for i in range(5):
		var heading = heading_for(f,i)
		var point = fish.position+heading*12
		var gain = point.distance_to(f.fisher.position)-fish.position.distance_to(f.fisher.position)
		scores[i] += gain*0.06+heading.dot(outward)*0.2
		if is_instance_valid(f.fisher.session):
			var edge = f.fisher.session.world.arena_width*0.5-4
			scores[i] -= maxf(0,absf(point.x)-edge)+maxf(0,absf(point.z)-edge)
	var order = [0,1,2,3,4,5]
	order.sort_custom(func(a,b): return scores[a] > scores[b])
	if f.rng.randf() < (1-f.fish_skill)*0.35 and scores[order[1]] > scores[order[0]]-1: return order[1]
	return order[0]

static func heading_for(f: FightSession, action: int) -> Vector3:
	var away = BaitMotion.horizontal(f.fish.position-f.fisher.position)
	var right = away.cross(Vector3.UP)
	var aim = away
	if action == FishAction.LEFT: aim = (away-right*1.3).normalized()
	if action == FishAction.RIGHT: aim = (away+right*1.3).normalized()
	if action == FishAction.DIVE: aim = (away+Vector3.DOWN*1.5).normalized()
	if action == FishAction.JUMP: aim = (away+Vector3.UP*2.5).normalized()
	# Project ahead, bend along a wall, and resolve corners toward open water.
	if is_instance_valid(f.fisher.session):
		var edge = f.fisher.session.world.arena_width*0.5-lerpf(5,12,f.fish_skill)
		var projected = f.fish.position+aim*18
		for axis in [0,2]:
			if absf(projected[axis]) > edge:
				aim[axis] = -signf(projected[axis])*0.35
	return aim.normalized()

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
