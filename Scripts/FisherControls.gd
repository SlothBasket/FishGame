class_name FisherControls
extends RefCounted
## Independent legal control channels from delayed observable motion/line data.
static func plan(seen: Dictionary, stamina: float) -> Dictionary:
	var risk = float(seen.get("tension",0))/maxf(1,float(seen.get("strength",110)))
	var slack = float(seen.get("slack",0))
	var side = float(seen.get("side",0))
	var distance = float(seen.get("distance",100))
	var urgency = clampf((float(seen.get("line_out",0))/maxf(1,float(seen.get("capacity",150)))-0.5)/0.4,0,1)
	var running = float(seen.get("outward_speed",0)) > 3 or float(seen.get("payout",0)) > 2
	var fall = bool(seen.get("jump_fall",false))
	var ascent = bool(seen.get("ascending",false)) or bool(seen.get("airborne",false))
	var dive = bool(seen.get("descending",false)) and not fall
	var result = {"horizontal":-clampf(side*1.1,-0.85,0.85),"vertical":0.15,"retrieve":0.65,"drag":0.4,"power":false,"jerk":Vector2.ZERO,"pump":false,"vision":false,"label":"REEL / PRESSURE"}
	var danger = float(seen.get("tension",0))/maxf(1,float(seen.get("break_threshold",93.5)))
	var condition = clampf(float(seen.get("condition",1)),0,1)
	# Condition shifts the acute-risk margin, never vetoes the landing goal.
	var acute = danger >= lerpf(0.84,0.92,condition) or float(seen.get("shock",0)) > 35
	var close_pressure = distance <= 30
	result["acute_danger"] = acute
	if acute: result.drag = maxf(0.25,float(seen.get("drag",0.4))-0.2)
	if fall or ascent or slack > 0.8:
		# Slack capture supersedes stale outward-run/efficiency observations. Low
		# rod protects the hook while the motor recovers physically loose line.
		result.vertical = -0.85
		result.retrieve = 1.0 if slack > 0.25 or danger < 0.85 else 0.2
		result.power = slack > 1 and danger < 0.7 and stamina > 30 and not acute
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
	if seen.has("required_jerk"):
		var direction = int(seen.required_jerk)
		result.jerk = Vector2(0,1) if direction == RodGesture.Direction.UP else Vector2(-1,0) if direction == RodGesture.Direction.LEFT else Vector2(1,0) if direction == RodGesture.Direction.RIGHT else Vector2.ZERO
	# Strategic pressure uses delayed line/geometry observations only.
	var outward = float(seen.get("outward_speed",0))
	var payout = float(seen.get("payout",0))
	var line_rate = float(seen.get("line_rate",0))
	var recovery = float(seen.get("actual_recovery",0))
	var efficiency = float(seen.get("retrieve_efficiency",1))
	var strong_run = (outward > 4 or payout > 3) and line_rate > 0.1 and recovery < 0.15 and efficiency < 0.15
	var escaping = line_rate > 0.1 or outward > 1.5 or payout > 0.5
	var stalled = float(seen.get("stalled_seconds",0)) >= 2
	var opportunity = bool(seen.get("opportunity",false)) or bool(seen.get("counter_success",false))
	var wear_margin = (1-condition)*0.06
	result["stage"] = "CLOSEOUT" if close_pressure else "STOP ESCAPE" if escaping else "GAIN LINE" if stalled or opportunity else "TURN FISH"
	result["pressure"] = true
	result["close_pressure"] = close_pressure
	if not acute:
		var pressure = 0.56+0.10*clampf(float(seen.get("stalled_seconds",0))/6,0,1)
		if escaping: pressure = maxf(pressure,lerpf(0.65,0.80,clampf(maxf(outward,payout)/8,0,1)))
		if close_pressure: pressure = maxf(pressure,lerpf(0.70,0.90,clampf((30-distance)/22,0,1)))
		if opportunity: pressure = maxf(pressure,0.70)
		var used_line = float(seen.get("line_out",0))/maxf(1,float(seen.get("capacity",150)))
		if used_line >= 0.65 and escaping:
			pressure = maxf(pressure,lerpf(0.65,0.90,clampf((used_line-0.65)/0.25,0,1)))
			result["spool_pressure"] = true
		result.drag = clampf(pressure-wear_margin,0.5,0.9)
		result.retrieve = 1.0 if close_pressure or opportunity or line_rate < -0.05 else 0.80 if stalled or not escaping else 0.65
		result.pump = not strong_run and not dive and not opportunity and distance >= 8 and recovery < 0.8 and danger < 0.80
		result.vertical = 0.65 if dive else 0.4 if close_pressure else 0.2
		result.power = stamina > 30 and (close_pressure or opportunity) and not strong_run and not dive and danger < 0.78-(1-condition)*0.04
		if result.power: result.pump = false # Don't let pump execution cancel the opening's power push.
		result.label = result.stage
	if strong_run:
		# Save cranking effort only when observed recovery is genuinely negligible.
		result.retrieve = 0.15
		result.power = false
		result.pump = false
		result.label = "ABSORB / STOP RUN"
	if acute:
		result.retrieve = 0.15
		result.power = false
		result.pump = false
		result.jerk = Vector2.ZERO
		result.label = "RELIEVE OVERLOAD"
	return result
