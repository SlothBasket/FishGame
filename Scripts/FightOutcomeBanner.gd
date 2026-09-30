class_name FightOutcomeBanner
extends CanvasLayer
## Local presentation of reliable authoritative results; survives encounter cleanup.
@export var duration: float = 2.5
var remaining: float = 0
var label: Label
var notices: Label
@export var notice_duration: float = 2.0
@export var notice_fade: float = 0.3
var notice_time: float = 0
var recent_notices: Array[String] = []
func _ready() -> void:
	layer = 20
	label = Label.new()
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",42)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",3)
	label.add_theme_constant_override("shadow_offset_y",3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.hide()
	notices = Label.new()
	add_child(notices)
	notices.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notices.anchor_top = 0.28
	notices.anchor_bottom = 0.28
	notices.offset_left = -520
	notices.offset_right = -32
	notices.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notices.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices.add_theme_font_size_override("font_size",22)
	notices.add_theme_color_override("font_shadow_color",Color.BLACK)
	notices.add_theme_constant_override("shadow_offset_x",2)
	notices.add_theme_constant_override("shadow_offset_y",2)
func show_result(result: int, fish_role: bool) -> void:
	var fish_messages = ["","BAIT RELEASED","LINE BROKE — YOU'RE FREE!","YOU SHOOK THE HOOK!","CAUGHT","FIGHT ENDED","FISHERMAN SPOOLED!"]
	var fisher_messages = ["","HOOK MISSED","LINE BROKE","FISH GOT LOOSE","FISH LANDED","FIGHT ENDED","SPOOLED"]
	label.text = (fish_messages if fish_role else fisher_messages)[clampi(result,0,6)]
	remaining = duration
	label.show()
func show_counter(kind: int) -> void:
	show_notice(["","RUN STOPPED!","OVERDRIVE BROKEN!","DIVE STOPPED!"][clampi(kind,0,3)])
func _process(delta: float) -> void:
	notice_time = maxf(0,notice_time-delta)
	notices.visible = notice_time > 0
	notices.modulate.a = clampf(notice_time/maxf(0.01,notice_fade),0,1)
	if notice_time <= 0: recent_notices.clear()
	remaining = maxf(0,remaining-delta)
	label.visible = remaining > 0

func show_notice(text: String) -> void:
	if notice_time > 0 and not recent_notices.is_empty() and recent_notices[-1] == text: return
	recent_notices.append(text)
	if recent_notices.size() > 3: recent_notices.pop_front()
	notices.text = "\n".join(recent_notices)
	notice_time = notice_duration
