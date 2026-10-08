class_name FisherRodCourse
extends RefCounted
## Held leverage only. Discrete counter detection keeps its original observations.
var smoothed: float = 0
var side: int = 0
var candidate: int = 0
var persistence: float = 0
var hold: float = 0
@export var response_time: float = 0.15
@export var entry_threshold: float = 0.35
@export var reversal_threshold: float = 0.60
@export var establish_time: float = 0.35
@export var minimum_hold: float = 0.65

func step(lateral: float, delta: float) -> float:
	smoothed = lerpf(smoothed,clampf(lateral,-1,1),1-exp(-delta/response_time))
	hold = maxf(0,hold-delta)
	var wanted = int(signf(smoothed)) if absf(smoothed) >= entry_threshold else 0
	if side != 0 and wanted == -side and absf(smoothed) < reversal_threshold: wanted = side
	if wanted != candidate: candidate = wanted; persistence = 0
	persistence += delta
	if wanted != side and hold <= 0 and persistence >= establish_time:
		side = wanted
		hold = minimum_hold
	return -side*0.75
