class_name FightTelemetry
extends RefCounted
## Observational only: one row plus debounced transitions; never changes actors.
var row: Dictionary = {}
var events: Array[Dictionary] = []
var elapsed: float = 0
var tension_sum: float = 0
var depth_sum: float = 0
var sampled_time: float = 0
var states: Dictionary = {}
var waits: Dictionary = {}
var last_lateral: int = 0
var last_course: float = 0
var previous_looseness: float = 1
var off_waits: Dictionary = {}
var pump_loaded: bool = false
var ascent_depth_sum: float = 0
const COUNTS = ["run_starts","overdrive_starts","overdrive_interruptions","dive_starts","dive_cancellations","ascent_attempts","breaches","jump_landings","lateral_course_changes","left_trajectories","right_trajectories","direction_reversals","head_shake_attempts","hook_loosening_events","jerk_up","jerk_left","jerk_right","run_interruptions","vision_activations","power_activations","pump_cycles"]
const BREAK_KEYS = ["condition","tension","threshold","ratio","exposure","drag","rod_vertical","rod_horizontal","requested_load","shock","payout","depth","velocity_x","velocity_y","velocity_z","action","following_jerk","falling","dive_power","overdrive"]
func _init(index: int, seed_value: int) -> void:
	row = {"fight_index":index,"fight_seed":seed_value,"fish_skill":0.0,"fisher_skill":0.0,"result":"","duration":0.0,"combat_duration":0.0,
		"final_condition":1.0,"minimum_condition":1.0,"maximum_tension":0.0,"average_tension":0.0,"maximum_break_ratio":0.0,"maximum_line_out":0.0,"final_line_out":0.0,"maximum_payout":0.0,"total_line_recovered":0.0,"maximum_slack":0.0,"slack_time":0.0,
		"minimum_endurance":100.0,"final_endurance":100.0,"minimum_stamina":100.0,"average_depth":0.0,"maximum_depth":-INF,"minimum_depth":INF,"final_depth":0.0,"minimum_horizontal_distance":INF,"final_horizontal_distance":0.0,"final_distance_3d":0.0,
		"reeling_time":0.0,"lowering_time":0.0,"high_rod_time":0.0,"lateral_rod_time":0.0,"straight_time":0.0,"left_time":0.0,"right_time":0.0,"maximum_looseness":1.0,"maximum_hook_hazard":0.0,"hook_hazard_time":0.0,"maximum_airborne_hazard":0.0,"maximum_slack_hazard":0.0,"average_ascent_start_depth":0.0,"maximum_ascent_power":0.0}
	for key in COUNTS: row[key] = 0
	for key in BREAK_KEYS: row["break_"+key] = ""
	for key in ["slack","airborne","shake","looseness","hazard","jump_severity"]: row["throw_"+key] = ""
func state(f: FightSession) -> Dictionary:
	var p = f.fish
	return {"phase":FightSession.Phase.keys()[f.phase],"distance_3d":p.position.distance_to(f.fisher.position),"rod_take_up":f.spool.rod_take_up,"elastic_extension":maxf(0,p.position.distance_to(f.fisher.position)+f.spool.rod_take_up-f.spool.line_out),"fish_load":f.spool.fish_load,"condition":f.spool.condition,"tension":f.spool.tension,"threshold":f.spool.break_threshold(),"ratio":f.spool.tension/maxf(0.01,f.spool.break_threshold()),"exposure":f.spool.high_load_exposure,"drag":f.fisher.drag_setting,"rod_vertical":f.rod_vertical,"rod_horizontal":f.rod_horizontal,"requested_load":f.spool.requested_load,"shock":f.spool.shock,"payout":f.spool.payout,"depth":p.water_height-p.position.y,"velocity_x":p.velocity.x,"velocity_y":p.velocity.y,"velocity_z":p.velocity.z,"action":FightDecisions.fish_text(f.fish_action),"following_jerk":f.jerk_notice_time > 0,"falling":p.motion.falling,"dive_power":p.motion.dive_power,"overdrive":p.motion.overdrive,"line_out":f.spool.line_out,"slack":f.spool.slack,"endurance":p.endurance,"stamina":p.stamina,"airborne":p.airborne,"shake":p.head.shake_pressure,"looseness":f.hook.looseness,"hazard":f.hook.hazard,"jump_severity":p.motion.jump_severity}
func event(name: String, f: FightSession, count: String = "") -> void:
	if not count.is_empty(): row[count] += 1
	events.append({"fight_index":row.fight_index,"fight_seed":row.fight_seed,"time":elapsed,"event":name,"state":state(f)})
func edge(name: String, active: bool, f: FightSession, count: String = "", hold: float = 0.15, delta: float = 0) -> bool:
	waits[name] = float(waits.get(name,0))+delta if active else 0.0
	if active and waits[name] >= hold and not states.get(name,false):
		states[name] = true
		event(name,f,count)
		return true
	off_waits[name] = 0.0 if active else float(off_waits.get(name,0))+delta
	if off_waits[name] >= 0.35: states[name] = false
	return false
func sample(f: FightSession, delta: float) -> void:
	elapsed += delta
	if f.phase >= FightSession.Phase.IMPACT and f.phase < FightSession.Phase.FINISHED: row.combat_duration += delta
	sampled_time += delta
	var s = state(f)
	var p = f.fish
	row.fish_skill = f.fish_skill
	row.fisher_skill = f.fisher_skill
	tension_sum += s.tension*delta
	depth_sum += s.depth*delta
	row.minimum_condition = minf(row.minimum_condition,s.condition)
	row.maximum_tension = maxf(row.maximum_tension,s.tension)
	row.maximum_break_ratio = maxf(row.maximum_break_ratio,s.ratio)
	row.maximum_line_out = maxf(row.maximum_line_out,s.line_out)
	row.maximum_payout = maxf(row.maximum_payout,s.payout)
	row.total_line_recovered = f.recovery_total
	row.maximum_slack = maxf(row.maximum_slack,s.slack)
	row.slack_time += delta if s.slack > 0.5 else 0
	row.minimum_endurance = minf(row.minimum_endurance,p.endurance)
	row.minimum_stamina = minf(row.minimum_stamina,p.stamina)
	row.maximum_depth = maxf(row.maximum_depth,s.depth)
	row.minimum_depth = minf(row.minimum_depth,s.depth)
	var horizontal = Vector2(p.position.x-f.fisher.position.x,p.position.z-f.fisher.position.z).length()
	row.minimum_horizontal_distance = minf(row.minimum_horizontal_distance,horizontal)
	row.final_horizontal_distance = horizontal
	row.final_distance_3d = p.position.distance_to(f.fisher.position)
	row.final_endurance = p.endurance
	row.final_depth = s.depth
	row.final_condition = s.condition
	row.final_line_out = s.line_out
	row.reeling_time += delta if f.fisher.command.retrieve > 0.1 else 0
	row.lowering_time += delta if f.rod_vertical < -0.3 else 0
	row.high_rod_time += delta if f.rod_vertical > 0.6 else 0
	row.lateral_rod_time += delta if absf(f.rod_horizontal) > 0.4 else 0
	row.maximum_looseness = maxf(row.maximum_looseness,f.hook.looseness)
	row.maximum_hook_hazard = maxf(row.maximum_hook_hazard,f.hook.hazard)
	row.hook_hazard_time += delta if f.hook.hazard > 0.001 else 0
	row.maximum_airborne_hazard = maxf(row.maximum_airborne_hazard,f.hook.airborne_hazard)
	row.maximum_slack_hazard = maxf(row.maximum_slack_hazard,f.hook.slack_hazard)
	row.maximum_ascent_power = maxf(row.maximum_ascent_power,p.motion.ascent_power)
	var right = BaitMotion.horizontal(p.position-f.fisher.position).cross(Vector3.UP)
	var side = BaitMotion.horizontal(p.heading).dot(right)
	var lateral = -1 if side < -sin(deg_to_rad(20)) else 1 if side > sin(deg_to_rad(20)) else 0
	row.left_time += delta if lateral < 0 else 0
	row.right_time += delta if lateral > 0 else 0
	row.straight_time += delta if lateral == 0 and p.heading.dot((p.position-f.fisher.position).normalized()) > 0 else 0
	for sign_side in [-1,1]:
		if edge("LATERAL_LEFT" if sign_side < 0 else "LATERAL_RIGHT",lateral == sign_side,f,"left_trajectories" if sign_side < 0 else "right_trajectories",0.5,delta):
			if last_lateral != 0 and last_lateral != sign_side: row.direction_reversals += 1
			last_lateral = sign_side
	if absf(f.course_offset-last_course) > deg_to_rad(10):
		event("COURSE_CHANGE",f,"lateral_course_changes")
		last_course = f.course_offset
	edge("RUN_START",p.boosting and p.motion.run_build > 0.6,f,"run_starts",0.3,delta)
	edge("OVERDRIVE_START",p.motion.overdrive > 0,f,"overdrive_starts",0.1,delta)
	edge("DIVE_START",p.motion.diving,f,"dive_starts",0.15,delta)
	if edge("ASCENT_START",p.motion.ascent_power > 0.15,f,"ascent_attempts",0.2,delta): ascent_depth_sum += s.depth
	edge("BREACH",p.airborne,f,"breaches",0,delta)
	edge("LANDING",p.motion.landed_event,f,"jump_landings",0,delta)
	edge("HEAD_SHAKE",p.head.shake_pressure > 0.35,f,"head_shake_attempts",0.1,delta)
	edge("VISION_ON",f.fisher.vision_active,f,"vision_activations",0,delta)
	edge("POWER_ON",f.power_active,f,"power_activations",0,delta)
	edge("LINE_DAMAGE_SPIKE",f.line_damage_rate > 0.005,f,"",0.1,delta)
	edge("HIGH_BREAK_RISK",s.ratio > 1.2,f,"",0.2,delta)
	if f.hook.looseness > previous_looseness+0.0001:
		event("HOOK_LOOSENED",f,"hook_loosening_events")
		previous_looseness = f.hook.looseness
	if f.rod_vertical > 0.8: pump_loaded = true
	if pump_loaded and f.rod_vertical < 0.2 and f.fisher.command.retrieve > 0.5:
		event("PUMP_RECOVERY",f,"pump_cycles")
		pump_loaded = false
	edge("DEEP_UNDER_BOAT",horizontal < 6 and s.depth > 12,f,"",5,delta)
func finish(f: FightSession, result: String) -> Dictionary:
	if is_instance_valid(f):
		sample(f,0) # Exact terminal values before stamina/reset/cleanup.
		var s = state(f)
		if result == "LINE_BROKE":
			for key in BREAK_KEYS: row["break_"+key] = s[key]
		if result == "THROWN":
			for key in ["slack","airborne","shake","looseness","hazard","jump_severity"]: row["throw_"+key] = s[key]
		event("LINE_BREAK" if result == "LINE_BROKE" else "HOOK_THROW" if result == "THROWN" else result,f)
	row.result = result
	row.duration = elapsed
	row.average_tension = tension_sum/maxf(0.001,sampled_time)
	row.average_depth = depth_sum/maxf(0.001,sampled_time)
	row.average_ascent_start_depth = ascent_depth_sum/maxi(1,row.ascent_attempts)
	for key in row:
		if row[key] is float and not is_finite(row[key]): row[key] = 0.0
	return row.duplicate()
