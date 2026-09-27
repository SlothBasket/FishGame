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
	var danger = float(seen.get("tension",0))/maxf(1,float(seen.get("break_threshold",93.5)))
	var condition = float(seen.get("condition",1))
	if danger > 0.85 or condition < 0.7 or dive or float(seen.get("shock",0)) > 35:
		result.drag = 0.30 if danger > 1 or condition < 0.5 else 0.35
	elif danger < 0.65 and condition > 0.8 and running:
		result.drag = 0.50 if urgency > 0.65 else 0.45
	elif danger >= 0.65:
		result.drag = float(seen.get("drag",0.4)) # Hysteresis between safe and danger bands.
	if fall or ascent or slack > 0.8:
		# Slack capture supersedes stale outward-run/efficiency observations. Low
		# rod protects the hook while the motor recovers physically loose line.
		result.vertical = -0.85
		result.retrieve = 1.0 if slack > 0.25 or danger < 0.85 else 0.2
		result.power = slack > 1 and danger < 0.7 and stamina > 30
		result.drag = 0.3 if fall else minf(result.drag,0.4)
		result.label = "REEL SLACK"
		result["stage"] = "JUMP / SLACK CAPTURE"
		result["capture_slack"] = true
		return result
	else:
		if dive or running:
			result.vertical = 0.65 if dive else 0.2
			if risk < 0.9+urgency*0.45:
				result.jerk = Vector2(0,1) if dive or absf(side) < 0.25 else Vector2(-signf(side),0)
			result.label = "COUNTER / REEL"
		else:
			result.pump = risk < 0.65 and float(seen.get("outward_speed",0)) < 2 and slack < 0.8
		result.vision = running and absf(side) < 0.5
	# Strategic progress uses delayed geometry/line observations, never Fish energy.
	var distance = float(seen.get("distance",100))
	var safe = danger < 0.65 and condition > 0.8 and not running and not dive and not fall and not ascent
	var opportunity = bool(seen.get("opportunity",false)) or bool(seen.get("counter_success",false))
	result["stage"] = "LANDING PUSH" if distance < 20 else "CLOSE" if distance < 40 else "MID" if distance < 70 else "FAR"
	if safe:
		result.retrieve = 1.0 if distance < 40 or opportunity else 0.8
		result.drag = 0.65 if distance < 20 and danger < 0.45 else 0.55 if distance < 40 or opportunity else 0.4
		result.pump = distance >= 8 and slack < 0.8 and not opportunity and (distance >= 40 or float(seen.get("actual_recovery",0)) < 0.8)
		result.vertical = 0.4 if distance < 40 else result.vertical
		result.power = stamina > 25 and (distance < 20 or opportunity) and danger < 0.55
		result.label = result.stage if not opportunity else "CAPTURE OPENING"
	# Observable efficiency sets a ceiling on useful cranking, not a hidden AI advantage.
	var requested = float(seen.get("requested_retrieve",0))
	var efficiency = float(seen.get("retrieve_efficiency",1))
	if running and float(seen.get("line_rate",0)) > 0.1:
		result.retrieve = minf(result.retrieve,0.15)
		result.power = false
		result.pump = false
	elif requested > 0.05 and efficiency < 0.8:
		var useful = float(seen.get("actual_recovery",0))/4.5
		result.retrieve = minf(result.retrieve,maxf(0.1,useful+0.05))
		result.power = false
		# Weak recovery is a reason to improve rod leverage, not disable a safe pump.
		result.pump = result.pump and safe
	elif requested > 0.05:
		result.retrieve = minf(result.retrieve,requested/4.5+0.10)
	return result
