class_name GameControls
extends RefCounted
## The only device binding table. Drivers/motors consume actions and intent.
static func install() -> void:
	var keys = {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,
		"rise":KEY_SPACE,"dive":KEY_CTRL,"boost":KEY_SHIFT,"reset":KEY_R,
		"cast":KEY_G,"bait_mode":KEY_TAB,"bait_camera":KEY_C,"bait_reset":KEY_F,"bait_species":KEY_X}
	for action in keys:
		var event = InputEventKey.new()
		event.physical_keycode = keys[action]
		bind(action,event)
	var buttons = {"bite":JOY_BUTTON_RIGHT_SHOULDER,"rise":JOY_BUTTON_A,"dive":JOY_BUTTON_B,
		"boost":JOY_BUTTON_LEFT_STICK,"cast":JOY_BUTTON_X,"bait_species":JOY_BUTTON_Y,
		"bait_mode":JOY_BUTTON_BACK,"bait_camera":JOY_BUTTON_RIGHT_STICK,
		"reel_up":JOY_BUTTON_DPAD_UP,"reel_down":JOY_BUTTON_DPAD_DOWN,"reset":JOY_BUTTON_START}
	for action in buttons:
		var event = InputEventJoypadButton.new()
		event.button_index = buttons[action]
		bind(action,event)
	var axes = {"forward":[JOY_AXIS_LEFT_Y,-1],"back":[JOY_AXIS_LEFT_Y,1],
		"left":[JOY_AXIS_LEFT_X,-1],"right":[JOY_AXIS_LEFT_X,1],
		"look_left":[JOY_AXIS_RIGHT_X,-1],"look_right":[JOY_AXIS_RIGHT_X,1],
		"look_up":[JOY_AXIS_RIGHT_Y,-1],"look_down":[JOY_AXIS_RIGHT_Y,1],
		"retrieve_trigger":[JOY_AXIS_TRIGGER_RIGHT,1]}
	for action in axes:
		var event = InputEventJoypadMotion.new()
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		bind(action,event)
	for action in {"bite":MOUSE_BUTTON_LEFT,"reel_up":MOUSE_BUTTON_WHEEL_UP,"reel_down":MOUSE_BUTTON_WHEEL_DOWN}:
		var event = InputEventMouseButton.new()
		event.button_index = {"bite":MOUSE_BUTTON_LEFT,"reel_up":MOUSE_BUTTON_WHEEL_UP,"reel_down":MOUSE_BUTTON_WHEEL_DOWN}[action]
		bind(action,event)
	for action in {"power_reel":KEY_SHIFT,"rod_jerk":KEY_Q,"fish_vision":KEY_V}:
		var event = InputEventKey.new()
		event.physical_keycode = {"power_reel":KEY_SHIFT,"rod_jerk":KEY_Q,"fish_vision":KEY_V}[action]
		bind(action,event)
	for action in {"power_reel":JOY_BUTTON_LEFT_SHOULDER,"rod_jerk":JOY_BUTTON_RIGHT_SHOULDER,"fish_vision":JOY_BUTTON_LEFT_STICK}:
		var event = InputEventJoypadButton.new()
		event.button_index = {"power_reel":JOY_BUTTON_LEFT_SHOULDER,"rod_jerk":JOY_BUTTON_RIGHT_SHOULDER,"fish_vision":JOY_BUTTON_LEFT_STICK}[action]
		bind(action,event)
	for action in {"drag_down":KEY_BRACKETLEFT,"drag_up":KEY_BRACKETRIGHT}:
		var key = InputEventKey.new()
		key.physical_keycode = KEY_BRACKETLEFT if action == "drag_down" else KEY_BRACKETRIGHT
		bind(action,key)
		var button = InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_DPAD_LEFT if action == "drag_down" else JOY_BUTTON_DPAD_RIGHT
		bind(action,button)
	# Retrieve is distinct from boat/fish forward movement; the stick only steers bait.
	var retrieve = InputEventKey.new()
	retrieve.physical_keycode = KEY_W
	bind("retrieve",retrieve)

static func bind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action,0.15)
	if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

static func look() -> Vector2:
	return Input.get_vector("look_left","look_right","look_up","look_down")
