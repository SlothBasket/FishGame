class_name ReelSpeed
extends RefCounted
## Persistent fisher preference, independent of any camera or development controller.
const KEYBOARD_STEP = 0.05
const STEPS = 20
var selected_tier: int = 12

static func quantize(value: float) -> float:
	return clampf(roundf(value / KEYBOARD_STEP)*KEYBOARD_STEP,0,1)

func step(amount: int) -> void:
	selected_tier = clampi(selected_tier + amount, 0, STEPS)

func selected_speed() -> float:
	return clampi(selected_tier,0,STEPS)*KEYBOARD_STEP

func retrieve(keyboard_held: bool, trigger: float) -> float:
	# Analog trigger remains continuous without overwriting the keyboard preference.
	return maxf(selected_speed() if keyboard_held else 0.0, clampf(trigger,0,1))
