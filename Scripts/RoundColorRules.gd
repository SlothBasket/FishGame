class_name RoundColorRules
extends RefCounted
## Authority-owned rule seam. No scheduler; rewards remain metadata only.
signal changed
var speeds: Array = [1.0,1.0,1.0,1.0,1.0,1.0,1.0]
var rewards: Array = [1.0,1.0,1.0,1.0,1.0,1.0,1.0]
var absent_color: int = -1
var forced_color: int = -1
var gold_chance: float = 0.015
var rng = RandomNumberGenerator.new()
func configure(seed_value: int) -> void:
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value+7219
	speeds = [0.88,0.92,0.96,1.0,1.04,1.08,1.12]
	for i in range(6,0,-1):
		var j = rng.randi_range(0,i)
		var old = speeds[i]; speeds[i] = speeds[j]; speeds[j] = old
	changed.emit()
func choose_natural() -> int:
	if absent_color != BaitColors.Tag.GOLD and rng.randf() < gold_chance: return BaitColors.Tag.GOLD
	var choices: Array[int] = []
	for tag in range(6):
		if tag != absent_color: choices.append(tag)
	return choices[rng.randi_range(0,choices.size()-1)]
func effective(base: int, natural: bool) -> int:
	return forced_color if natural and forced_color >= 0 else base
func speed(tag: int) -> float: return float(speeds[clampi(tag,0,6)])
func value(tag: int) -> float: return float(rewards[clampi(tag,0,6)])
func set_absent(tag: int) -> void:
	absent_color = clampi(tag,-1,6)
	if forced_color == absent_color: forced_color = -1
	changed.emit()
func force_natural(tag: int) -> void:
	# Absence wins a conflicting request. -1 ends the event and restores base tags.
	forced_color = clampi(tag,-1,6) if tag != absent_color else -1
	changed.emit()
func state() -> Dictionary:
	return {"speeds":speeds.duplicate(),"rewards":rewards.duplicate(),"absent":absent_color,"forced":forced_color}
func apply_state(data: Dictionary) -> void:
	if data.get("speeds",[]).size() != 7 or data.get("rewards",[]).size() != 7: return
	speeds = data.speeds.duplicate(); rewards = data.rewards.duplicate()
	absent_color = int(data.absent); forced_color = int(data.forced)
	changed.emit()
func caption() -> String:
	var text = "COLOR INTEL  "
	for tag in range(7): text += "%s %.2fx  " % [BaitColors.NAMES[tag],speeds[tag]]
	if absent_color >= 0: text += "\nAbsent: "+BaitColors.NAMES[absent_color]
	if forced_color >= 0: text += "\nNatural event: "+BaitColors.NAMES[forced_color]
	return text

func set_speed(tag: int, multiplier: float) -> void:
	speeds[clampi(tag,0,6)] = clampf(multiplier,0.5,1.5)
	changed.emit()
func set_reward(tag: int, multiplier: float) -> void:
	rewards[clampi(tag,0,6)] = maxf(0,multiplier)
	changed.emit() # Reserved metadata; feeding does not apply this yet.
