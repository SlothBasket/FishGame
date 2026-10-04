class_name FeedingHotspot
extends Node3D
## One authority-owned finite bait gathering; clients only show the surface cue.
@export var interval_min: float = 55
@export var interval_max: float = 90
var school: BaitSchool
var active: bool = false
var center: Vector3
var remaining: float = 0
var wait: float = 18
var pulse: float = 0
var groups: Array[BaitPod] = []
var rng = RandomNumberGenerator.new()
var visual_only: bool = false

func _ready() -> void:
	if school != null and school.seed_value >= 0: rng.seed = school.seed_value+809
	else: rng.randomize()

func contains(point: Vector3) -> bool:
	return active and point.distance_squared_to(center) < 24*24

func start_event() -> void:
	if school == null or active: return
	var sites = InshoreHabitat.sites(school.arena_half_width)
	var site: Vector3 = sites[rng.randi_range(0,sites.size()-1)]
	center = Vector3(site.x,school.water_depth-3,site.z)
	remaining = rng.randf_range(20,40)
	active = true
	var available = school.pods.filter(func(pod): return pod.habitat != null and pod.habitat.kind == BaitMotion.Kind.MINNOW)
	available.sort_custom(func(a,b): return a.center.distance_squared_to(center) < b.center.distance_squared_to(center))
	for i in range(mini(2,available.size())):
		var pod: BaitPod = available[i]
		groups.append(pod)
		pod.event_destination = center+Vector3(i*5,0,0)
		pod.event_active = true
	# Four finite arrivals, stagger-free small budget, registered by the normal school.
	# No refill during the event: every eaten bait is unavailable to other Fish.
	if not groups.is_empty():
		for i in range(4):
			var offset = Vector3(rng.randf_range(-5,5),0,rng.randf_range(-5,5))
			school._spawn(BaitMotion.Kind.MINNOW,center+offset,rng.randi(),25,groups[0],offset)

func end_event() -> void:
	for pod in groups: pod.event_active = false
	groups.clear()
	active = false
	remaining = 0
	wait = rng.randf_range(interval_min,interval_max)

func _physics_process(delta: float) -> void:
	if not visual_only:
		if active:
			remaining -= delta
			if remaining <= 0: end_event()
		else:
			wait -= delta
			if wait <= 0: start_event()
	if not active: return
	pulse -= delta
	if pulse <= 0:
		pulse = 0.8
		# Reuse the bounded splash pool, never create particles every frame.
		var surface = get_tree().get_first_node_in_group("surface_feedback")
		if surface != null:
			surface.emit_crossing(center+Vector3(sin(remaining*2)*6,0,cos(remaining*3)*6),8)
