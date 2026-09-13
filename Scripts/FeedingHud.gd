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
	var muted = Color("9dc6c8")
	var font = ThemeDB.fallback_font
	var feeding = fish.feeding
	draw_arc(center, 16, 0, TAU, 48, Color(0.7, 0.88, 0.85, 0.4), 1.5, true)
	draw_circle(center, 2, gold)
	if feeding.is_charging:
		var charge = feeding.charge_fraction()
		draw_arc(center, 22, -PI / 2, -PI / 2 + TAU * charge, 64, gold, 4, true)
		var text = "FULL CHARGE / RELEASE" if charge >= 0.999 else "RELEASE TO LUNGE  %.1f m" % lerpf(fish.minimum_lunge_distance, fish.maximum_lunge_distance, charge)
		draw_string(font, center + Vector2(-110, 58), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	elif feeding.cooldown_remaining > 0.0:
		var recovered = 1.0 - feeding.cooldown_remaining / maxf(0.01, fish.bite_cooldown)
		draw_arc(center, 22, -PI / 2, -PI / 2 + TAU * recovered, 48, muted, 2, true)
	if feeding.meal_notice_time > 0.0:
		gold.a = minf(1.0, feeding.meal_notice_time * 2.0)
		draw_string(font, Vector2(center.x - 75, 115), feeding.last_meal, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, gold)
