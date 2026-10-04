extends Control
## Development frontend only. All modes run their existing command-line paths.
const SETTINGS = "user://dev-launcher.cfg"
const GAME = "res://Scenes/Reef.tscn"
const CAPTURES = "user://captures/"
var filename: LineEdit
var seed_field: LineEdit
var fish_skill: LineEdit
var fisher_skill: LineEdit
var status: Label
var launching: bool = false

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
	if explicit_mode(OS.get_cmdline_user_args()) or "--write-movie" in OS.get_cmdline_args():
		get_tree().change_scene_to_file.call_deferred(GAME)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background = ColorRect.new()
	background.color = Color("10242d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
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
	mode_button(panel,"AI VS AI DIRECTOR PREVIEW","Clean realtime Director preview — no movie recorded",["--ai-vs-ai","--capture","--director"])
	panel.add_child(HSeparator.new())
	label(panel,"Options (blank keeps existing defaults)",20)
	seed_field = field(panel,"Seed (optional)","Random")
	fish_skill = field(panel,"Fish skill (0.6–1.0)","Default")
	fisher_skill = field(panel,"Fisher skill (0.6–1.0)","Default")
	label(panel,"RECORD DIRECTOR FIGHT — 1920×1080, 60 fps",22)
	filename = field(panel,"Filename","fight_capture")
	filename.text = "fight_capture"
	mode_button(panel,"RECORD","AI vs AI + Capture + Director → AVI",["--ai-vs-ai","--capture","--director"],true)
	label(panel,"Movies: "+ProjectSettings.globalize_path(CAPTURES),15)
	status = label(panel,"Close the recorded game normally to finish the movie.",16)
	load_settings()

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
	config.set_value("launcher","filename",filename.text)
	config.set_value("launcher","seed",seed_field.text)
	config.set_value("launcher","fish_skill",fish_skill.text)
	config.set_value("launcher","fisher_skill",fisher_skill.text)
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
	args.append("--")
	args.append_array(user_args)
	return args

func launch(mode_args: PackedStringArray, record: bool) -> void:
	if launching: return
	save_settings()
	var args = mode_args.duplicate()
	var seed_text = seed_field.text.strip_edges()
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
	var engine_args = process_arguments(ProjectSettings.globalize_path("res://"),args,movie)
	launching = true
	var pid = OS.create_process(OS.get_executable_path(),engine_args)
	if pid <= 0:
		launching = false
		status.text = "Godot could not start the selected mode. Check the executable/project path."
		return
	get_tree().quit()
