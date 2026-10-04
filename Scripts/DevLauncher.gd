extends Control
## Development frontend only. All modes run their existing command-line paths.
const SETTINGS = "user://dev-launcher.cfg"
const GAME = "res://Scenes/Reef.tscn"
const CAPTURES = "user://captures/"
var filename: LineEdit
var seed_field: LineEdit
var fish_skill: LineEdit
var fisher_skill: LineEdit
var target_bait: CheckBox
var bait_delay: SpinBox
var max_seconds: SpinBox
var status: Label
var launching: bool = false
var seeds_field: LineEdit
var parallel_count: SpinBox
var record_multi: CheckBox
var host_address: LineEdit
var network_port: SpinBox
var network_role: OptionButton
var jobs: Array[Dictionary] = []
var running: Dictionary = {}
var finished_jobs: int = 0
var failed_jobs: int = 0
var queue_limit: int = 2
var poll_wait: float = 0
var reserved_movies: Dictionary = {}
var used_ports: Dictionary = {}

static func explicit_mode(args: PackedStringArray) -> bool:
	# Treat all existing/future flags as explicit workflows except plain options.
	# This includes test, batch, preview, network and capture flags without a
	# duplicate list that could silently send a new test mode into the menu.
	for arg in args:
		if arg == "--" or arg.is_empty(): continue
		if arg.begins_with("--seed=") or arg.begins_with("--fight-seed=") or arg.begins_with("--fish-skill=") or arg.begins_with("--fisher-skill=") or arg.begins_with("--shot="): continue
		return true
	return false

func _ready() -> void:
	if JoinClient.enabled():
		get_tree().change_scene_to_file.call_deferred("res://Scenes/JoinMenu.tscn")
		return
	if explicit_mode(OS.get_cmdline_user_args()) or "--write-movie" in OS.get_cmdline_args():
		get_tree().change_scene_to_file.call_deferred(GAME)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background = ColorRect.new()
	background.color = Color("10242d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel = VBoxContainer.new()
	panel.custom_minimum_size.x = 820
	panel.add_theme_constant_override("separation",10)
	center.add_child(panel)
	label(panel,"PELAGIC — DEV LAUNCHER",30)
	label(panel,"Choose a mode. Recording opens a separate Godot Movie Maker process.",17)
	mode_button(panel,"PLAY FISH","Normal single-player Fish",["--play-fish"])
	mode_button(panel,"FISH VS AI FISHER","Host as Fish against an AI Fisher",["--host","--role=fish","--ai=fisher"])
	mode_button(panel,"FISHER VS AI FISH","Host as Fisher against an AI Fish",["--host","--role=fisher","--ai=fish"])
	mode_button(panel,"AI VS AI","Observer with normal development overlays",["--ai-vs-ai"])
	mode_button(panel,"3 FISH / 2 FISHERS TEST","1–3 Fish | 4–5 Fishers | 6 wide | 7 free",["--multi-actor"])
	mode_button(panel,"AI VS AI DIRECTOR PREVIEW","Clean realtime Director preview — no movie recorded",["--ai-vs-ai","--capture","--director"])
	mode_button(panel,"MULTI-ACTOR DIRECTOR PREVIEW","Director follows all 3 Fish / 2 Fishers",["--multi-actor","--capture","--director"])
	panel.add_child(HSeparator.new())
	label(panel,"MULTIPLAYER TESTING",22)
	host_address = field(panel,"Host IPv4 address","127.0.0.1 for same PC")
	host_address.text = "127.0.0.1"
	network_port = number_field(panel,"UDP port",1024,65535,24567)
	network_role = OptionButton.new()
	network_role.add_item("Play as Fish")
	network_role.add_item("Play as Fisher")
	panel.add_child(network_role)
	var network_buttons = HBoxContainer.new()
	panel.add_child(network_buttons)
	for action in ["Host","Join","Local two-player test"]:
		var button = Button.new()
		button.text = action
		button.pressed.connect(func(): launch_network(action))
		network_buttons.add_child(button)
	label(panel,"LAN: host first, then join its IPv4 + matching port. Same project version on both PCs.",16)
	panel.add_child(HSeparator.new())
	label(panel,"Options (blank keeps existing defaults)",20)
	seed_field = field(panel,"Seed (optional)","Random")
	fish_skill = field(panel,"Fish skill (0.6–1.0)","Default")
	fisher_skill = field(panel,"Fisher skill (0.6–1.0)","Default")
	label(panel,"RECORD DIRECTOR FIGHT — 1920×1080, 60 fps",22)
	filename = field(panel,"Filename","fight_capture")
	filename.text = "fight_capture"
	seeds_field = field(panel,"Recording seeds (comma-separated)","Blank uses Seed above; e.g. 101, 202, 303")
	parallel_count = number_field(panel,"Simultaneous recordings",1,4,2)
	record_multi = CheckBox.new()
	record_multi.text = "Record 3 Fish / 2 Fishers with automatic subject selection"
	panel.add_child(record_multi)
	target_bait = CheckBox.new()
	target_bait.text = "Target test bait, then stop after the fight"
	target_bait.button_pressed = true
	panel.add_child(target_bait)
	var delay_row = HBoxContainer.new()
	panel.add_child(delay_row)
	label(delay_row,"Seconds before targeting",17).custom_minimum_size.x = 260
	bait_delay = SpinBox.new()
	bait_delay.min_value = 0
	bait_delay.max_value = 3600
	bait_delay.value = 3
	bait_delay.step = 1
	delay_row.add_child(bait_delay)
	target_bait.toggled.connect(func(enabled): bait_delay.editable = enabled)
	var limit_row = HBoxContainer.new()
	panel.add_child(limit_row)
	label(limit_row,"Maximum recording seconds",17).custom_minimum_size.x = 260
	max_seconds = SpinBox.new()
	max_seconds.min_value = 30
	max_seconds.max_value = 3600
	max_seconds.value = 300
	max_seconds.step = 30
	limit_row.add_child(max_seconds)
	mode_button(panel,"RECORD","Selected targeting options → AVI; always bounded by time limit",["--ai-vs-ai","--capture","--director"],true)
	label(panel,"Movies: "+ProjectSettings.globalize_path(CAPTURES),15)
	status = label(panel,"Targeting OFF: live bait only. Record stops after any fight or at the time limit.",16)
	var stop_queue = Button.new()
	stop_queue.text = "Cancel waiting recordings (running takes finish normally)"
	stop_queue.pressed.connect(func(): jobs.clear())
	panel.add_child(stop_queue)
	label(panel,"Keep this menu open while recording. Start with 2 workers; GPU and disk are shared.",16)
	load_settings()

func number_field(parent: Node, title: String, minimum: float, maximum: float, value: float) -> SpinBox:
	var row = HBoxContainer.new()
	parent.add_child(row)
	label(row,title,17).custom_minimum_size.x = 260
	var number = SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.value = value
	row.add_child(number)
	return number

func label(parent: Node, text: String, size: int) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	parent.add_child(node)
	return node

func field(parent: Node, title: String, placeholder: String) -> LineEdit:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var caption = label(row,title,17)
	caption.custom_minimum_size.x = 260
	var edit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit

func mode_button(parent: Node, title: String, description: String, args: PackedStringArray, record: bool = false) -> void:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(340,42)
	row.add_child(button)
	label(row,description,16)
	button.pressed.connect(func(): launch(args,record))

func load_settings() -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS)
	seeds_field.text = str(config.get_value("launcher","seeds",""))
	parallel_count.value = float(config.get_value("launcher","parallel",2))
	record_multi.button_pressed = bool(config.get_value("launcher","multi",false))
	host_address.text = str(config.get_value("network","address","127.0.0.1"))
	network_port.value = float(config.get_value("network","port",24567))
	network_role.selected = clampi(int(config.get_value("network","role",0)),0,1)
	target_bait.button_pressed = bool(config.get_value("launcher","target_bait",true))
	bait_delay.value = float(config.get_value("launcher","bait_delay",3))
	bait_delay.editable = target_bait.button_pressed
	max_seconds.value = float(config.get_value("launcher","max_seconds",300))
	filename.text = str(config.get_value("launcher","filename","fight_capture"))
	seed_field.text = str(config.get_value("launcher","seed",""))
	fish_skill.text = str(config.get_value("launcher","fish_skill",""))
	fisher_skill.text = str(config.get_value("launcher","fisher_skill",""))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed=") or arg.begins_with("--fight-seed="): seed_field.text = arg.get_slice("=",1)
		if arg.begins_with("--fish-skill="): fish_skill.text = arg.get_slice("=",1)
		if arg.begins_with("--fisher-skill="): fisher_skill.text = arg.get_slice("=",1)

func save_settings() -> void:
	if filename == null: return
	var config = ConfigFile.new()
	config.set_value("launcher","target_bait",target_bait.button_pressed)
	config.set_value("launcher","bait_delay",bait_delay.value)
	config.set_value("launcher","max_seconds",max_seconds.value)
	config.set_value("launcher","filename",filename.text)
	config.set_value("launcher","seed",seed_field.text)
	config.set_value("launcher","fish_skill",fish_skill.text)
	config.set_value("launcher","fisher_skill",fisher_skill.text)
	config.set_value("launcher","seeds",seeds_field.text)
	config.set_value("launcher","parallel",parallel_count.value)
	config.set_value("launcher","multi",record_multi.button_pressed)
	config.set_value("network","address",host_address.text)
	config.set_value("network","port",network_port.value)
	config.set_value("network","role",network_role.selected)
	config.save(SETTINGS)

func _exit_tree() -> void:
	save_settings()

static func safe_filename(raw: String) -> String:
	var clean = ""
	for character in raw.strip_edges():
		clean += "_" if character.unicode_at(0) < 32 or character in '<>:"/\\|?*' else character
	clean = clean.strip_edges().trim_suffix(".")
	if clean.to_lower().ends_with(".avi"): clean = clean.left(-4)
	while clean.ends_with(".") or clean.ends_with(" "): clean = clean.left(-1)
	clean = clean.left(80)
	if clean.is_empty(): clean = "fight_capture"
	var base = clean.get_slice(".",0).to_upper()
	if base in ["CON","PRN","AUX","NUL"] or (base.length() == 4 and (base.begins_with("COM") or base.begins_with("LPT")) and base.right(1) in ["1","2","3","4","5","6","7","8","9"]): clean = "capture_"+clean
	return clean+".avi"

static func unused_movie_path(directory: String, raw: String) -> String:
	var name = safe_filename(raw)
	var candidate = directory.path_join(name)
	var number = 2
	while FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
		candidate = directory.path_join(name.get_basename()+"_%03d.avi" % number)
		number += 1
	return candidate

static func process_arguments(project_path: String, user_args: PackedStringArray, movie: String = "") -> PackedStringArray:
	# OS.create_process takes argument elements, not shell text: no manual quotes.
	var args = PackedStringArray(["--path",project_path])
	if not movie.is_empty():
		args.append_array(["--resolution","1920x1080","--write-movie",movie,"--fixed-fps","60"])
		# Engine-level frame cap also bounds a startup/connection failure.
		for option in user_args:
			if option.begins_with("--capture-max-seconds="):
				args.append_array(["--quit-after",str((option.get_slice("=",1).to_int()+5)*60)])
	args.append("--")
	args.append_array(user_args)
	return args

func launch(mode_args: PackedStringArray, record: bool) -> void:
	if launching or not running.is_empty() or not jobs.is_empty(): return
	save_settings()
	var args = mode_args.duplicate()
	if "--capture" in args:
		args.append("--capture-bait-delay=%d" % int(bait_delay.value))
		if not target_bait.button_pressed: args.append("--capture-natural")
	if record:
		args.append("--capture-one-fight")
		args.append("--capture-max-seconds=%d" % int(max_seconds.value))
	var seed_text = seed_field.text.strip_edges()
	if record and not seeds_field.text.strip_edges().is_empty():
		var selected = parse_seeds(seeds_field.text)
		if selected.is_empty() or selected.size() > 50:
			status.text = "Enter 1–50 valid comma-separated seeds."
			return
		seed_text = str(selected[0])
	if record and seed_text.is_empty():
		var random = RandomNumberGenerator.new()
		random.randomize()
		seed_text = str(random.randi_range(0,2147483646))
		seed_field.text = seed_text
		save_settings()
	if not seed_text.is_empty():
		if not seed_text.is_valid_int() or seed_text.to_int() < 0 or seed_text.to_int() > 2147483646:
			status.text = "Seed must be blank or a whole number from 0 to 2147483646."
			return
		args.append("--seed="+seed_text)
	for pair in [[fish_skill,"--fish-skill="],[fisher_skill,"--fisher-skill="]]:
		var value = pair[0].text.strip_edges()
		if value.is_empty(): continue
		if not value.is_valid_float() or not is_finite(value.to_float()) or value.to_float() < 0.6 or value.to_float() > 1:
			status.text = "AI skills must be blank or a number from 0.6 to 1.0."
			return
		args.append(pair[1]+value)
	var movie = ""
	if record:
		var directory = ProjectSettings.globalize_path(CAPTURES)
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			status.text = "Could not create captures folder: "+directory
			return
		movie = unused_movie_path(directory,filename.text)
	if record:
		enqueue_recordings(args,movie)
		return
	var engine_args = process_arguments(ProjectSettings.globalize_path("res://"),args,movie)
	launching = true
	var pid = OS.create_process(OS.get_executable_path(),engine_args)
	if pid <= 0:
		launching = false
		status.text = "Godot could not start the selected mode. Check the executable/project path."
		return
	get_tree().quit()

## No shell commands or custom encoder: each job is a bounded Movie Maker process.
static func parse_seeds(raw: String) -> Array[int]:
	var values: Array[int] = []
	for part in raw.split(",",false):
		var value = part.strip_edges()
		if not value.is_valid_int() or value.to_int() < 0 or value.to_int() > 2147483646: return []
		values.append(value.to_int())
	return values

func enqueue_recordings(base_args: PackedStringArray, movie: String) -> void:
	var raw = seeds_field.text.strip_edges()
	var seeds = parse_seeds(raw if not raw.is_empty() else seed_field.text)
	if seeds.is_empty() or seeds.size() > 50:
		status.text = "Enter 1–50 comma-separated whole-number seeds (0–2147483646)."
		return
	queue_limit = int(parallel_count.value)
	finished_jobs = 0
	failed_jobs = 0
	reserved_movies.clear()
	used_ports.clear()
	for seed_value in seeds:
		var args = PackedStringArray()
		for option in base_args:
			if not option.begins_with("--seed="): args.append(option)
		if record_multi.button_pressed:
			args.remove_at(args.find("--ai-vs-ai"))
			args.append("--multi-actor")
		args.append("--seed=%d" % seed_value)
		var name = movie.get_file().get_basename()+"_seed%d" % seed_value
		var path = unused_movie_path(movie.get_base_dir(),name)
		var duplicate = 2
		while reserved_movies.has(path):
			path = unused_movie_path(movie.get_base_dir(),name+"_%03d" % duplicate)
			duplicate += 1
		reserved_movies[path] = true
		jobs.append({"seed":seed_value,"args":args,"movie":path})
	status.text = "Queued %d recordings." % jobs.size()

func available_recording_port() -> int:
	# Probe ephemeral-range UDP ports; each job retains a unique port in this queue.
	for port in range(32000,32100):
		if used_ports.has(port): continue
		var socket = PacketPeerUDP.new()
		var result = socket.bind(port)
		socket.close()
		if result == OK:
			used_ports[port] = true
			return port
	return -1

func _process(delta: float) -> void:
	if status == null: return
	poll_wait -= delta
	if poll_wait > 0: return
	poll_wait = 0.5
	var was_busy = not running.is_empty() or not jobs.is_empty()
	for pid in running.keys():
		if not OS.is_process_running(pid):
			# File presence is not a guarantee of a complete take; preserve each log.
			if not FileAccess.file_exists(running[pid].movie): failed_jobs += 1
			finished_jobs += 1
			running.erase(pid)
	while running.size() < queue_limit and not jobs.is_empty():
		var job: Dictionary = jobs.pop_front()
		var port = available_recording_port()
		if port < 0: failed_jobs += 1; finished_jobs += 1; continue
		job.args.append("--port=%d" % port)
		var arguments = process_arguments(ProjectSettings.globalize_path("res://"),job.args,job.movie)
		arguments.insert(0,"--log-file")
		arguments.insert(1,job.movie.get_basename()+".log")
		var pid = OS.create_process(OS.get_executable_path(),arguments)
		if pid <= 0: failed_jobs += 1; finished_jobs += 1
		else: running[pid] = job
	if was_busy:
		status.text = "Recording: %d active | %d waiting | %d exited | %d launch/missing-file failures. Check per-take logs." % [running.size(),jobs.size(),finished_jobs,failed_jobs]

func launch_network(action: String) -> void:
	if launching or not running.is_empty() or not jobs.is_empty(): return
	var address = host_address.text.strip_edges()
	if action == "Join" and not address.is_valid_ip_address():
		status.text = "Enter the host's IPv4 address (127.0.0.1 for this PC)."
		return
	save_settings()
	var role = "fish" if network_role.selected == 0 else "fisher"
	var port = "--port=%d" % int(network_port.value)
	var args = PackedStringArray(["--join="+address if action == "Join" else "--host","--role="+role,port])
	var pid = OS.create_process(OS.get_executable_path(),process_arguments(ProjectSettings.globalize_path("res://"),args))
	if pid <= 0: status.text = "Could not launch network game."; return
	if action == "Local two-player test":
		launching = true
		await get_tree().create_timer(1.5).timeout
		var other = "fisher" if role == "fish" else "fish"
		var client = OS.create_process(OS.get_executable_path(),process_arguments(ProjectSettings.globalize_path("res://"),PackedStringArray(["--join=127.0.0.1","--role="+other,port])))
		launching = false
		status.text = "Host and client launched. F10 disconnects; close their windows after testing." if client > 0 else "Host launched, but client failed to start."
	else: status.text = action+" launched as "+role+". This menu remains available."
