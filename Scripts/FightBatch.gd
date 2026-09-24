class_name FightBatch
extends Node
## Development-only runner. Mechanics run in their ordinary nodes at 1/60 simulated s.
var world: Node3D
var session: NetworkSession
var telemetry: FightTelemetry
var count: int = 100
var index: int = 0
var base_seed: int = 12345
var exact_seed: int = -1
var speed: int = 10
var timeout: float = 600
var setup_time: float = 0
var maximum_delta: float = 0
var minimum_delta: float = INF
var pending: bool = false
var rows: Array[Dictionary] = []
var summary_file: FileAccess
var events_file: FileAccess
var summary_path: String
var events_path: String
var old_ticks: int
var old_scale: float
static func requested() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fight-batch="): return true
	return false
func start(level: Node3D, initial: FishPlayer) -> void:
	world = level
	process_physics_priority = 100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fight-batch="): count = clampi(arg.get_slice("=",1).to_int(),1,10000)
		if arg.begins_with("--sim-speed="): speed = clampi(arg.get_slice("=",1).to_int(),1,20)
		if arg.begins_with("--batch-seed="): base_seed = clampi(arg.get_slice("=",1).to_int(),0,2147483646)
		if arg.begins_with("--fight-seed="): exact_seed = clampi(arg.get_slice("=",1).to_int(),0,2147483646); count = 1
		if arg.begins_with("--batch-timeout="): timeout = clampf(arg.get_slice("=",1).to_float(),10,3600)
	if exact_seed >= 0: count = 1
	old_ticks = Engine.physics_ticks_per_second
	old_scale = Engine.time_scale
	Engine.physics_ticks_per_second = 60*speed
	Engine.max_physics_steps_per_frame = maxi(64,60*speed)
	Engine.time_scale = speed
	get_viewport().disable_3d = true
	DirAccess.make_dir_recursive_absolute("user://fight-batch")
	var stamp = Time.get_datetime_string_from_system().replace(":","-")
	var base = ProjectSettings.globalize_path("user://fight-batch/fight_batch_%s_seed%d_%d" % [stamp,base_seed,Time.get_ticks_msec()])
	summary_path = base+".csv"
	events_path = base+"_events.csv"
	summary_file = FileAccess.open(summary_path,FileAccess.WRITE)
	events_file = FileAccess.open(events_path,FileAccess.WRITE)
	if summary_file == null or events_file == null:
		push_error("Could not create fight-batch output")
		get_tree().quit(1)
		return
	events_file.store_csv_line(PackedStringArray(["fight_index","fight_seed","simulated_time","event","state_json"]))
	var metadata = FileAccess.open(base+"_metadata.json",FileAccess.WRITE)
	if metadata == null:
		push_error("Could not create batch metadata")
		get_tree().quit(1)
		return
	metadata.store_string(JSON.stringify({"engine":Engine.get_version_info(),"args":OS.get_cmdline_user_args(),"base_seed":base_seed,"seed_rule":"(base + (index-1)*104729) modulo 2147483647","speed":speed,"physics_ticks_per_real_second":60*speed,"target_simulated_delta":1.0/60,"timeout":timeout,"ambient":false},"  "))
	metadata.close()
	session = NetworkSession.new()
	session.name = "NetworkSession"
	session.batch_runner = self
	session.world = world
	session.hosting = true
	session.spectator_mode = true
	world.add_child(session)
	initial.set_physics_process(false)
	initial.queue_free()
	print("BATCH starting ",count," encounters at ",speed,"x; target physics delta 1/60; timeout ",timeout,"s")
	call_deferred("next_encounter")
func next_encounter() -> void:
	index += 1
	if index > count: finish_batch(); return
	session.encounter_seed = exact_seed if exact_seed >= 0 else posmod(base_seed+(index-1)*104729,2147483647)
	seed(session.encounter_seed)
	session.clock = 0
	session.closed = false
	setup_time = 0
	telemetry = FightTelemetry.new(index,session.encounter_seed)
	session.local_fish = session.make_fish(false,false)
	session.add_server_player(-1,NetworkSession.ROLE_FISH,true)
	session.add_server_player(-2,NetworkSession.ROLE_FISHER,true)
	for id in session.players:
		var actor = session.players[id].entity
		session.players[id].ai.execution_rng.seed = session.encounter_seed+(51 if id == -1 else 67)
		if actor is FishPlayer:
			actor.camera.current = false
			actor.visual.set_process(false)
			for emitter in [actor.dive_particles,actor.overdrive_particles,actor.maneuver_burst]: emitter.process_mode = Node.PROCESS_MODE_DISABLED; emitter.emitting = false
	pending = false
func _physics_process(delta: float) -> void:
	maximum_delta = maxf(maximum_delta,delta)
	minimum_delta = minf(minimum_delta,delta)
	if pending or session == null or not session.players.has(-2): return
	var fisher: FisherActor = session.players[-2].entity
	if is_instance_valid(fisher.fight):
		if telemetry.events.is_empty(): telemetry.event("FIGHT_START",fisher.fight)
		telemetry.sample(fisher.fight,delta)
		if telemetry.elapsed >= timeout: completed(fisher.fight,"TIMEOUT")
	else:
		setup_time += delta
		if setup_time >= minf(timeout,120): completed(null,"TIMEOUT")
func gesture(f: FightSession, direction: int) -> void:
	if pending: return
	var names = ["","JERK_LEFT","JERK_RIGHT","JERK_UP"]
	telemetry.event(names[direction],f,names[direction].to_lower())
	telemetry.record_jerk(f)
func counter(f: FightSession, kind: int) -> void:
	if pending: return
	telemetry.event(["","RUN_STOPPED","OVERDRIVE_STOPPED","DIVE_STOPPED"][kind],f,["","run_interruptions","overdrive_interruptions","dive_cancellations"][kind])
	if kind == 2: telemetry.row.run_interruptions += 1
func completed(f: FightSession, result: String) -> void:
	if pending: return
	pending = true
	var row = telemetry.finish(f,result)
	row["setup_duration"] = setup_time
	row["maximum_physics_delta"] = maximum_delta
	if rows.is_empty(): summary_file.store_csv_line(PackedStringArray(row.keys()))
	var values = PackedStringArray()
	for value in row.values(): values.append(str(value))
	summary_file.store_csv_line(values)
	for item in telemetry.events:
		events_file.store_csv_line(PackedStringArray([str(item.fight_index),str(item.fight_seed),str(item.time),item.event,JSON.stringify(item.state)]))
	summary_file.flush()
	events_file.flush()
	rows.append(row)
	# Stop old actors now; free at the frame boundary before constructing fresh ones.
	session.closed = true
	if is_instance_valid(f): f.set_physics_process(false)
	for record in session.players.values(): record.entity.set_physics_process(false)
	call_deferred("reset_encounter",f)
func reset_encounter(f: FightSession) -> void:
	if is_instance_valid(f): f.free()
	for bait in session.baits.values():
		if is_instance_valid(bait): bait.queue_free()
	for record in session.players.values():
		if is_instance_valid(record.entity): record.entity.queue_free()
	session.players.clear()
	# IDs remain monotonic so exiting old bait cannot erase newly registered bait.
	call_deferred("next_encounter")
func median(values: Array) -> float:
	if values.is_empty(): return 0
	values.sort()
	var middle = values.size()/2
	return values[middle] if values.size()%2 else (values[middle-1]+values[middle])*0.5
func finish_batch() -> void:
	var outcomes: Dictionary = {}
	var durations: Array = []
	var breaks: Array = []
	var tensions: Array = []
	var thresholds: Array = []
	var totals = {"run_starts":0.0,"dive_starts":0.0,"ascent_attempts":0.0,"left_trajectories":0.0,"right_trajectories":0.0}
	for row in rows:
		outcomes[row.result] = int(outcomes.get(row.result,0))+1
		durations.append(row.duration)
		for key in totals: totals[key] += row[key]
		if row.result == "LINE_BROKE": breaks.append(row.break_condition); tensions.append(row.break_tension); thresholds.append(row.break_threshold)
	print(rows.size()," fights complete")
	for result in ["LANDED","LINE_BROKE","SPOOLED","THROWN","TIMEOUT","MISSED","DISCONNECT"]:
		print(result,": ",outcomes.get(result,0)," (%.1f%%)" % (100.0*int(outcomes.get(result,0))/rows.size()))
	print("Duration mean %.2fs / median %.2fs" % [durations.reduce(func(a,b): return a+b,0.0)/rows.size(),median(durations)])
	print("Break medians: condition %.3f tension %.2f threshold %.2f (n=%d)" % [median(breaks),median(tensions),median(thresholds),breaks.size()])
	for key in totals: print("Average ",key,": %.2f" % (totals[key]/rows.size()))
	print("Physics delta range: ",minimum_delta," .. ",maximum_delta)
	print("BATCH SUMMARY SAVED: ",summary_path)
	print("BATCH EVENTS SAVED: ",events_path)
	var valid = rows.size() == count and maximum_delta < 0.017 and summary_file.get_error() == OK and events_file.get_error() == OK
	summary_file.close()
	events_file.close()
	Engine.time_scale = old_scale
	Engine.physics_ticks_per_second = old_ticks
	get_tree().quit(0 if valid else 1)
