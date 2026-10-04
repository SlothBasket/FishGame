class_name JoinClient
extends RefCounted
## Only the join menu supplies game intent in the distributed client.
static var connection_args = PackedStringArray()
static var notice: String = "Ask the host for their address and UDP port."

static func enabled() -> bool:
	return OS.has_feature("join_only") or bool(ProjectSettings.get_setting("application/join_only",false))

static func arguments() -> PackedStringArray:
	return connection_args.duplicate() if enabled() else OS.get_cmdline_user_args()

static func configure(address: String, port: int, role: String) -> bool:
	if not address.is_valid_ip_address() or port < 1024 or port > 65535 or role not in ["fish","fisher"]: return false
	connection_args = PackedStringArray(["--join="+address,"--port=%d" % port,"--role="+role])
	return true

static func return_to_menu(tree: SceneTree, message: String) -> void:
	notice = message
	connection_args.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree.change_scene_to_file.call_deferred("res://Scenes/JoinMenu.tscn")
