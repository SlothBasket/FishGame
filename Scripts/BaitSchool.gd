class_name BaitSchool
extends Node3D
## Eight sparse zones: open minnows, low shrimp, midwater squid, bottom crabs.

@export var respawn_delay: float = 8.0
@export var zone_population: int = 10
@export var individual_spacing: float = 7.0
@export var roam_radius: float = 45.0
@export var arena_half_width: float = 132.0
@export var water_depth: float = 32.0
@export var seed_value: int = -1 # -1 = varied play; explicit seeds for tests
var _rng = RandomNumberGenerator.new()
var _respawns: Array = []
var _entry_baits: Array = []
var _entry_clock: float = 6.0
@export var pod_population: int = 12
@export var midwater_squid_count: int = 10
var pods: Array[BaitPod] = []
@export var initial_spawn_interval: float = 0.10
var _initial_queue: Array = []
var _spawn_clock: float = 0.0
const ZONES = [Vector3(0, 0.45, 0), Vector3(-0.09, 0.13, -0.12),
	Vector3(0.52, 0.58, -0.5), Vector3(0.08, 0.02, -0.15),
	Vector3(0.58, 0.48, 0.48), Vector3(0, 0.15, 0.65),
	Vector3(-0.62, 0.62, 0.05), Vector3(0.35, 0.02, 0.7)]
const ZONE_KINDS = [BaitMotion.Kind.MINNOW, BaitMotion.Kind.SHRIMP, BaitMotion.Kind.SQUID,
	BaitMotion.Kind.CRAB, BaitMotion.Kind.MINNOW, BaitMotion.Kind.SHRIMP,
	BaitMotion.Kind.SQUID, BaitMotion.Kind.CRAB]

func _ready() -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	# Four small schools occupy the middle column, rather than pooling at the floor.
	for center in [Vector3(-28,15,-20), Vector3(24,20,-28), Vector3(-20,22,32), Vector3(35,13,24), Vector3(-45,28,40), Vector3(38,28,-45), Vector3(-35,4,-45), Vector3(40,4,40)]:
		var pod = BaitPod.new(center)
		pods.append(pod)
		for i in range(pod_population):
			var angle = i * TAU / pod_population
			var slot = Vector3(cos(angle)*4.5, _rng.randf_range(-1.8,1.8), sin(angle)*4.5)
			_enqueue(BaitMotion.Kind.MINNOW, center + slot, _rng.randi(), 40, pod, slot)
	for center in [Vector3(-22,31.5,-18), Vector3(35,31.5,20)]:
		var pod = BaitPod.new(center)
		pods.append(pod)
		for i in range(8):
			var slot = Vector3(cos(i*TAU/8)*5, 0, sin(i*TAU/8)*5)
			_enqueue(BaitMotion.Kind.MULLET, center+slot, _rng.randi(), 50, pod, slot)
	for i in range(midwater_squid_count):
		_enqueue(BaitMotion.Kind.SQUID, Vector3(_rng.randf_range(-65,65), _rng.randf_range(14,24), _rng.randf_range(-65,65)), _rng.randi(), 45)
	for i in range(12):
		_enqueue(BaitMotion.Kind.MINNOW if i % 2 == 0 else BaitMotion.Kind.SQUID, Vector3(_rng.randf_range(-60, 60), _rng.randf_range(23, 28), _rng.randf_range(-60, 60)), _rng.randi(), 55.0)
	for i in range(4):
		_enqueue(BaitMotion.Kind.GULL, Vector3(-18 + i * 12, water_depth + 10, -12), _rng.randi(), 60.0)
		_enqueue(BaitMotion.Kind.MINNOW, Vector3(_rng.randf_range(-50, 50), water_depth - 0.45, _rng.randf_range(-50, 50)), _rng.randi(), 50.0)
	for i in range(4):
		_enqueue(BaitMotion.Kind.MULLET, Vector3(-15 + i * 9, water_depth - 0.45, -18), _rng.randi(), 50.0)
	for zone in range(ZONES.size()):
		var fraction: Vector3 = ZONES[zone]
		var center = Vector3(fraction.x * arena_half_width, fraction.y * water_depth, fraction.z * arena_half_width)
		for i in range(zone_population):
			var angle = _rng.randf_range(0.0, TAU)
			var home = center + Vector3(cos(angle) * individual_spacing * _rng.randf_range(0.5, 2.5), _rng.randf_range(-0.5, 0.5), sin(angle) * individual_spacing * _rng.randf_range(0.5, 2.5))
			_enqueue(ZONE_KINDS[zone], home, _rng.randi(), roam_radius * _rng.randf_range(0.75, 1.2))

	# Shuffle using the seeded generator, without touching global RNG state.
	for i in range(_initial_queue.size()-1,0,-1):
		var j = _rng.randi_range(0,i)
		var swap = _initial_queue[i]
		_initial_queue[i] = _initial_queue[j]
		_initial_queue[j] = swap

func _enqueue(kind: int, home: Vector3, seed_id: int, radius: float, pod: BaitPod = null, slot: Vector3 = Vector3.ZERO) -> void:
	_initial_queue.append([kind,home,seed_id,radius,pod,slot])

func _spawn(kind: int, home: Vector3, behavior_seed: int, radius: float, pod: BaitPod = null, slot: Vector3 = Vector3.ZERO, initial: bool = false) -> BaitActor:
	var bait = Seagull.new() if kind == BaitMotion.Kind.GULL else BaitActor.new()
	bait.kind = kind
	bait.randomize_size(_rng)
	bait.water_height = water_depth
	bait.arena_half_width = arena_half_width
	# Start above terrain so small floor prey cannot be embedded in rock/floor colliders.
	var query = PhysicsRayQueryParameters3D.create(Vector3(home.x, water_depth - 0.5, home.z), Vector3(home.x, -2, home.z), 1)
	var ground = get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty():
		home.y = maxf(home.y, ground.position.y + bait.hit_radius() + 0.15)
	if pod == null and kind == BaitMotion.Kind.MINNOW and home.y < 22 and behavior_seed % 2 == 0:
		home.y = water_depth - 2.0
	if kind == BaitMotion.Kind.SHRIMP and not ground.is_empty():
		home.y = ground.position.y + bait.hit_radius() + 0.15
	if kind == BaitMotion.Kind.SQUID: home.y = clampf(home.y, 14, 25)
	# Keep bottom home for navigation, but introduce fresh bottom prey through the water.
	bait.position = Vector3(home.x, water_depth-0.5, home.z) if kind in [BaitMotion.Kind.CRAB, BaitMotion.Kind.SHRIMP] else home
	if kind in [BaitMotion.Kind.CRAB, BaitMotion.Kind.SHRIMP]:
		if initial: bait.position.y = _rng.randf_range(home.y, water_depth-0.5)
		bait.velocity = Vector3.DOWN*4
		bait.entry_remaining = 0.5
	bait.heading = Vector3.FORWARD.rotated(Vector3.UP, _rng.randf_range(-PI, PI))
	bait.driver = BaitMotion.LiveBaitDriver.new(home, behavior_seed, radius, 5.0)
	if pod != null:
		bait.driver.pod = pod
		bait.driver.pod_slot = slot
		pod.add_member(bait)
	bait.bitten.connect(func(_bait, _eater):
		_respawns.append({"remaining": respawn_delay, "kind": kind, "home": home, "radius": radius, "pod": pod, "slot": slot}))
	add_child(bait)
	if kind == BaitMotion.Kind.MINNOW and home.y > water_depth - 0.6:
		_entry_baits.append(weakref(bait))
	return bait

func _process(delta: float) -> void:
	_spawn_clock -= delta
	if not _initial_queue.is_empty() and _spawn_clock <= 0:
		_spawn_clock = initial_spawn_interval
		var entry = _initial_queue.pop_back()
		_spawn(entry[0],entry[1],entry[2],entry[3],entry[4],entry[5],true)
		return # At most one actor construction per frame across both queues.
	_entry_clock -= delta
	if _entry_clock <= 0:
		_entry_clock = _rng.randf_range(5, 9)
		_entry_baits = _entry_baits.filter(func(reference): return is_instance_valid(reference.get_ref()))
		for reference in _entry_baits:
			var entrant = reference.get_ref()
			if is_instance_valid(entrant) and not entrant.claimed and entrant.position.y < water_depth * 0.5:
				entrant.position = Vector3(_rng.randf_range(-50, 50), water_depth - 0.45, _rng.randf_range(-50, 50))
				entrant.clear_actions()
				entrant.velocity = Vector3.DOWN * 4
				entrant.entry_remaining = 0.45
				break
	for i in range(_respawns.size() - 1, -1, -1):
		var entry: Dictionary = _respawns[i]
		entry.remaining -= delta
		if entry.remaining <= 0.0:
			_respawns.remove_at(i)
			_spawn(entry.kind, entry.home, _rng.randi(), entry.radius, entry.pod, entry.slot)
			break # Spread mesh/node creation after multi-bait meals across frames.
