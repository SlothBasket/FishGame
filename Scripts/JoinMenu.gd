extends Control
## Friend-facing join-only entry point. Never launches external processes.
const SETTINGS = "user://join-settings.cfg"
var address: LineEdit
var port: SpinBox
var role: OptionButton
var status: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var backdrop = ColorRect.new()
	backdrop.color = Color("10242d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = VBoxContainer.new()
	panel.custom_minimum_size.x = 650
	panel.add_theme_constant_override("separation",14)
	center.add_child(panel)
	caption(panel,"PELAGIC — JOIN A MATCH",32)
	caption(panel,"Multiplayer playtest • "+str(ProjectSettings.get_setting("application/config/version","development")),18)
	caption(panel,"Host address (IPv4)",18)
	address = LineEdit.new()
	address.placeholder_text = "Example: 192.168.1.25"
	panel.add_child(address)
	caption(panel,"UDP port",18)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 24567
	panel.add_child(port)
	role = OptionButton.new()
	role.add_item("Play as Fish")
	role.add_item("Play as Fisher")
	panel.add_child(role)
	var join = Button.new()
	join.text = "JOIN MATCH"
	join.custom_minimum_size.y = 50
	join.pressed.connect(connect_to_host)
	panel.add_child(join)
	var exit_button = Button.new()
	exit_button.text = "Quit"
	exit_button.pressed.connect(func(): get_tree().quit())
	panel.add_child(exit_button)
	status = caption(panel,JoinClient.notice,18)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption(panel,"F10 leaves a match. Esc releases the mouse. See START HERE.txt for controls.",16)
	var config = ConfigFile.new()
	config.load(SETTINGS)
	address.text = str(config.get_value("join","address",""))
	port.value = float(config.get_value("join","port",24567))
	role.selected = clampi(int(config.get_value("join","role",0)),0,1)

func caption(parent: Node, text: String, size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func connect_to_host() -> void:
	if not JoinClient.configure(address.text.strip_edges(),int(port.value),"fish" if role.selected == 0 else "fisher"):
		status.text = "Enter a valid IPv4 address and port from the host."
		return
	var config = ConfigFile.new()
	config.set_value("join","address",address.text.strip_edges())
	config.set_value("join","port",port.value)
	config.set_value("join","role",role.selected)
	config.save(SETTINGS)
	get_tree().change_scene_to_file("res://Scenes/Reef.tscn")
