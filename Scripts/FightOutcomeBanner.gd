class_name FightOutcomeBanner
extends CanvasLayer
## Local presentation of reliable authoritative results; survives encounter cleanup.
@export var duration: float = 2.5
var remaining: float = 0
var label: Label
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
func show_result(result: int, fish_role: bool) -> void:
	var fish_messages = ["","BAIT RELEASED","LINE BROKE — YOU'RE FREE!","YOU SHOOK THE HOOK!","CAUGHT","FIGHT ENDED","FISHERMAN SPOOLED!"]
	var fisher_messages = ["","HOOK MISSED","LINE BROKE","FISH GOT LOOSE","FISH LANDED","FIGHT ENDED","SPOOLED"]
	label.text = (fish_messages if fish_role else fisher_messages)[clampi(result,0,6)]
	remaining = duration
	label.show()
func _process(delta: float) -> void:
	remaining = maxf(0,remaining-delta)
	label.visible = remaining > 0
