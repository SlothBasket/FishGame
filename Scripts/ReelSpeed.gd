class_name ReelSpeed
extends RefCounted
## Persistent fisher preference, independent of any camera or development controller.
const TIERS = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
var selected_tier: int = 3

static func quantize(value: float) -> float:
	return TIERS[clampi(roundi(value * 5.0), 0, 5)]

func step(amount: int) -> void:
	selected_tier = clampi(selected_tier + amount, 0, TIERS.size()-1)

func selected_speed() -> float:
	return TIERS[selected_tier]

func retrieve(keyboard_held: bool, trigger: float) -> float:
	# Trigger travel uses the same capabilities, without overwriting the saved preference.
	return maxf(selected_speed() if keyboard_held else 0.0, quantize(trigger))
