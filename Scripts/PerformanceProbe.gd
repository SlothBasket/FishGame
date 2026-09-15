class_name PerformanceProbe
extends Node
## Optional --perf-check: report real frame intervals after a short warmup.
var samples: Array[float] = []
var elapsed: float = 0.0
var previous: int = 0
func _process(delta: float) -> void:
	elapsed += delta
	var now = Time.get_ticks_usec()
	if elapsed > 3 and previous > 0:
		samples.append((now - previous) / 1000.0)
	previous = now
	if elapsed >= 23:
		samples.sort()
		print("FRAME PROBE: frames=%d median=%.2fms p95=%.2fms max=%.2fms nodes=%d" % [
			samples.size(), samples[samples.size() / 2], samples[int(samples.size() * 0.95)], samples.back(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		get_tree().quit()
