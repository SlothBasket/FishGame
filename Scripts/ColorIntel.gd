class_name ColorIntel
extends CanvasLayer
var fish: FishPlayer
var label: Label
var rules: RoundColorRules
func _ready() -> void:
	label = Label.new()
	label.position = Vector2(22,100)
	label.add_theme_font_size_override("font_size",14)
	add_child(label)
func _process(_delta: float) -> void:
	label.visible = fish.locally_owned and fish.camera.current and not "--capture" in JoinClient.arguments()
	if not label.visible: return
	if rules == null:
		var node = fish.get_parent()
		while node != null:
			if "color_rules" in node: rules = node.color_rules; break
			node = node.get_parent()
	if rules != null: label.text = rules.caption()
