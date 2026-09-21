class_name FeedingHud
extends Control
## Reads feeding state; never changes it.

var fish

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center = get_viewport_rect().size * 0.5
	var gold = Color("f2ce8a")
	var font = ThemeDB.fallback_font
	var feeding = fish.feeding
	draw_circle(center, 2, gold)
	if feeding.is_charging:
		var charge = feeding.charge_fraction()
		var text = "FULL CHARGE / RELEASE" if charge >= 0.999 else "RELEASE TO LUNGE  %.1f m" % lerpf(fish.minimum_lunge_distance, fish.maximum_lunge_distance, charge)
		draw_string(font, center + Vector2(-110, 58), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	if feeding.meal_notice_time > 0.0:
		gold.a = minf(1.0, feeding.meal_notice_time * 2.0)
		draw_string(font, Vector2(center.x - 75, 115), feeding.last_meal, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, gold)
