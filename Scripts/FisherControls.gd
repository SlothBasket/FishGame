class_name FisherControls
extends RefCounted
## Independent legal control channels from delayed observable motion/line data.
static func plan(seen: Dictionary, stamina: float) -> Dictionary:
	var risk = float(seen.get("tension",0))/maxf(1,float(seen.get("strength",110)))
	var slack = float(seen.get("slack",0))
	var side = float(seen.get("side",0))
	var urgency = clampf((float(seen.get("line_out",0))/maxf(1,float(seen.get("capacity",150)))-0.5)/0.4,0,1)
	var running = float(seen.get("outward_speed",0)) > 3 or float(seen.get("payout",0)) > 2
	var fall = bool(seen.get("jump_fall",false))
	var ascent = bool(seen.get("ascending",false)) or bool(seen.get("airborne",false))
	var dive = bool(seen.get("descending",false)) and not fall
	var result = {"horizontal":-clampf(side*1.1,-0.85,0.85),"vertical":0.15,"retrieve":0.65,"drag":0.4,"power":false,"jerk":Vector2.ZERO,"pump":false,"vision":false,"label":"REEL / PRESSURE"}
	if risk > 0.85: result.retrieve = 0.15
	if running and urgency > 0 and float(seen.get("condition",1)) > 0.35: result.drag = lerpf(0.4,0.7,urgency)
	if float(seen.get("condition",1)) < 0.6: result.drag = minf(result.drag,0.35)
	if fall:
		result.vertical = -1.0
		result.retrieve = 0.0 if risk > 0.5 or slack < 1 else 0.25
		result.drag = 0.3
		result.label = "ABSORB FALL"
	elif ascent or slack > 0.8:
		result.vertical = 0.1
		result.retrieve = 1.0
		result.power = slack > 1 and risk < 0.65 and stamina > 30
		result.label = "REEL SLACK"
	else:
		if dive or running:
			result.vertical = 0.65 if dive else 0.2
			if risk < 0.9+urgency*0.45:
				result.jerk = Vector2(0,1) if dive or absf(side) < 0.25 else Vector2(-signf(side),0)
			result.label = "COUNTER / REEL"
		else:
			result.pump = float(seen.get("depth",0)) > 10 and risk < 0.65 and float(seen.get("speed",0)) < 4
		result.vision = running and absf(side) < 0.5
	return result
