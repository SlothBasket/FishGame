class_name BaitProfile
extends RefCounted
static var enabled: bool = false
static var totals: Dictionary = {}
static var counts: Dictionary = {}
static func add_sample(label: String, started: int) -> void:
	if not enabled: return
	totals[label] = totals.get(label,0) + Time.get_ticks_usec()-started
	counts[label] = counts.get(label,0)+1
static func snapshot() -> Dictionary:
	var result = {}
	for key in totals:
		result[key] = {"total_ms":totals[key]/1000.0,"calls":counts[key],"average_us":float(totals[key])/counts[key]}
	return result
