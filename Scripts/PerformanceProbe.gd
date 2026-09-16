class_name PerformanceProbe
extends Node
## F9 writes a bounded diagnostic report in normal play. --perf-check runs a timed capture.
var samples: Array[float] = []
var elapsed: float = 0.0
var previous: int = 0
var started: int = 0
var duration: float = 0.0
var hitches: Array[String] = []
var next_hitch: float = 0.0
var peak_physics: float = 0.0
var recent_frames: Array[String] = []
var notice: Label
var notice_time: float = 0
var tour_camera: Camera3D

func _ready() -> void:
	started = Time.get_ticks_usec()
	var layer = CanvasLayer.new()
	add_child(layer)
	notice = Label.new()
	notice.position = Vector2(40,205)
	layer.add_child(notice)
	if "--perf-check" in OS.get_cmdline_user_args(): duration = 75.0
	if "--perf-tour" in OS.get_cmdline_user_args():
		tour_camera = Camera3D.new()
		add_child(tour_camera)
		tour_camera.make_current()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-duration="): duration = maxf(5, float(arg.get_slice("=", 1)))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		save_report()

func _process(_delta: float) -> void:
	notice_time = maxf(0,notice_time-_delta)
	if notice != null: notice.visible = notice_time > 0
	var now = Time.get_ticks_usec()
	elapsed = (now-started)/1000000.0
	if tour_camera != null:
		var angle = elapsed * 0.16
		tour_camera.global_position = Vector3(sin(angle)*38, 21+sin(elapsed*0.18)*16, cos(angle)*38)
		tour_camera.look_at(Vector3(0, 17+sin(elapsed*0.18)*12, 0))
	var frame = (now-previous)/1000.0 if previous > 0 else 0.0
	previous = now
	var physics = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
	peak_physics = maxf(peak_physics, physics)
	# Keep the latest 1800 frames, including the lead-up to a stall, with bounded memory.
	recent_frames.append("%.3f,%.3f,%.3f,%.3f,%d,%d" % [elapsed,frame,physics,Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if recent_frames.size() > 1800: recent_frames.pop_front()
	if elapsed > 3:
		if duration > 0: samples.append(frame)
		if frame > 50 and elapsed > next_hitch:
			next_hitch = elapsed + 0.5
			var record = "%.2f,%.2f,%.2f,%.2f,%d,%d" % [elapsed,frame,physics,Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
			hitches.append(record)
			if hitches.size() > 240: hitches.pop_front()
	if duration > 0 and elapsed >= duration:
		samples.sort()
		print("FRAME PROBE: duration=%.1fs frames=%d median=%.2fms p95=%.2fms max=%.2fms peak_physics=%.2fms nodes=%d" % [elapsed,samples.size(),samples[samples.size()/2],samples[int(samples.size()*0.95)],samples.back(),peak_physics,Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		save_report()
		get_tree().quit()

func save_report() -> void:
	var folder = "user://hitch-reports"
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp = Time.get_datetime_string_from_system().replace(":","-") + "-" + str(Time.get_ticks_msec())
	var base = folder + "/" + stamp
	var file = FileAccess.open(base+".csv",FileAccess.WRITE)
	if file == null: return
	file.store_line("elapsed_s,frame_ms,physics_ms,process_ms,nodes,draw_calls")
	for record in recent_frames: file.store_line(record)
	var actors: Array = []
	for bait in get_tree().get_nodes_in_group("bait"):
		actors.append({"kind":bait.display_name(),"position":str(bait.global_position),"velocity":str(bait.velocity),"size":bait.body_size,"escaping":bait.flee_remaining,"driver": "AI" if bait.driver is BaitMotion.LiveBaitDriver else "player/test"})
	var report = {"time":Time.get_datetime_string_from_system(),"engine":Engine.get_version_info(),"os":OS.get_name(),"gpu":RenderingServer.get_video_adapter_name(),"elapsed_s":elapsed,"peak_physics_ms":peak_physics,"static_memory_bytes":OS.get_static_memory_usage(),"bait_count":actors.size(),"bait_snapshot":actors,"hitches_over_50ms":hitches,"arena_width":get_parent().arena_width,"physics_ticks_per_second":Engine.physics_ticks_per_second}
	var details = FileAccess.open(base+".json",FileAccess.WRITE)
	if details != null: details.store_string(JSON.stringify(report,"  "))
	var path = ProjectSettings.globalize_path(base)
	print("Performance report: ",path," (.csv and .json)")
	notice.text = "F9 report saved: " + path.get_file() + "\nSee hitch-reports in Godot's user data folder; full path printed in Output."
	notice.visible = true
	notice_time = 8
