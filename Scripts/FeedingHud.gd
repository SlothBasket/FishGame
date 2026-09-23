class_name FeedingHud
extends Control
## Reads feeding state; never changes it.

var pressure_alpha: float = 0
var pressure_side: float = 1
var fish

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var right = BaitMotion.horizontal(fish.position-fish.fight_anchor).cross(Vector3.UP)
	var screen_pressure = fish.directional_pressure*right.dot(fish.camera.global_basis.x)
	var target = clampf((absf(screen_pressure)-0.12)/0.35,0,1) if fish.fight_active else 0.0
	if target > 0: pressure_side = signf(screen_pressure)
	pressure_alpha = lerpf(pressure_alpha,target,1-exp(-delta*7))
	queue_redraw()

func _draw() -> void:
	var center = get_viewport_rect().size * 0.5
	var gold = Color("f2ce8a")
	var font = ThemeDB.fallback_font
	var feeding = fish.feeding
	draw_circle(center, 2, gold)
	if pressure_alpha > 0.01:
		var cue = Color(0.7,0.93,1,pressure_alpha*0.85)
		draw_string(font,center+Vector2(pressure_side*155-30,12),"<<<" if pressure_side < 0 else ">>>",HORIZONTAL_ALIGNMENT_LEFT,-1,32,cue)
	if feeding.is_charging:
		var charge = feeding.charge_fraction()
		var text = "FULL CHARGE / RELEASE" if charge >= 0.999 else "RELEASE TO LUNGE  %.1f m" % lerpf(fish.minimum_lunge_distance, fish.maximum_lunge_distance, charge)
		draw_string(font, center + Vector2(-110, 58), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	if feeding.meal_notice_time > 0.0:
		gold.a = minf(1.0, feeding.meal_notice_time * 2.0)
		draw_string(font, Vector2(center.x - 75, 115), feeding.last_meal, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, gold)
