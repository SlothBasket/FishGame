class_name FightContest
extends RefCounted
## One boat-relative directional contest for physics, coaching and both AI pilots.
enum Move { AWAY, LEFT, RIGHT, DIVE }
enum Counter { CENTER, LEFT, RIGHT, UP, LET_RUN }
static func evaluate(heading: Vector3, outward: Vector3, right: Vector3, rod_x: float, rod_y: float) -> Vector3:
	var side = heading.dot(right)
	var following = maxf(0,side*rod_x)
	var displacement = maxf(absf(rod_x),maxf(0,-rod_y))
	var efficiency = maxf(maxf(0,heading.dot(outward))*(1-0.3*displacement),maxf(following,maxf(0,heading.y*minf(0,rod_y)))*0.95)
	var lateral_counter = maxf(0,-side*rod_x)
	var vertical_counter = maxf(0,-heading.y*rod_y)
	return Vector3(efficiency,lateral_counter,vertical_counter)

static func best_move(rod_x: float, rod_y: float) -> int:
	var choices = [Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3.DOWN]
	var best = Move.AWAY
	var score = -INF
	for i in range(choices.size()):
		var result = evaluate(choices[i],Vector3.FORWARD,Vector3.RIGHT,rod_x,rod_y)
		var value = result.x-result.y-result.z
		if value > score: score = value; best = i
	return best

static func best_counter(heading: Vector3, right: Vector3, diving: bool, late: bool) -> int:
	if diving: return Counter.LET_RUN if late else Counter.UP
	# Select the side with greatest counter coefficient using the exact force rule.
	var left = evaluate(heading,Vector3.ZERO,right,-1,0).y
	var right_score = evaluate(heading,Vector3.ZERO,right,1,0).y
	if maxf(left,right_score) < 0.15: return Counter.CENTER
	return Counter.LEFT if left > right_score else Counter.RIGHT

static func move_text(choice: int) -> String:
	return ["RUN AWAY","LEFT","RIGHT","DIVE"][clampi(choice,0,3)]
static func counter_text(choice: int) -> String:
	return ["HOLD / PUMP","PULL LEFT","PULL RIGHT","PULL UP","LET DRAG WORK"][clampi(choice,0,4)]
