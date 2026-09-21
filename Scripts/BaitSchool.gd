class_name BaitSchool
extends Node3D
## Eight sparse zones: open minnows, low shrimp, midwater squid, bottom crabs.

@export var replenishment_interval: float = 3.0
@export var live_floor_fraction: float = 0.95
@export var natural_lifetime_min: float = 240.0
@export var natural_lifetime_max: float = 720.0
@export var carcass_lifetime: float = 150.0
@export var maximum_carcasses: int = 20
@export var anchor_migration_speed: float = 0.65
var anchors: Array[BaitPod] = []
var habitats: Dictionary = {}
var _population: Array = []
var _targets: Dictionary = {}
var _ecosystem_clock: float = 0.0
var _arrival_clock: float = 0.0
@export var zone_population: int = 6
@export var individual_spacing: float = 7.0
@export var roam_radius: float = 45.0
@export var arena_half_width: float = 132.0
@export var water_depth: float = 32.0
@export var seed_value: int = -1 # -1 = varied play; explicit seeds for tests
var _rng = RandomNumberGenerator.new()
@export var pod_population: int = 6
@export var midwater_squid_count: int = 6
var pods: Array[BaitPod] = []
var neighborhood = BaitNeighborhood.new()
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
	for species in range(6):
		var low = 2.0
		var high = water_depth-2
		if species in [BaitMotion.Kind.CRAB,BaitMotion.Kind.SHRIMP]: low = 0.5; high = 1.5
		if species == BaitMotion.Kind.SQUID: low = 14; high = 25
		if species == BaitMotion.Kind.MULLET: low = water_depth-1; high = water_depth-0.4
		if species == BaitMotion.Kind.GULL: low = water_depth+10; high = water_depth+12
		var edge = arena_half_width-10
		habitats[species] = BaitHabitat.new(AABB(Vector3(-edge,low,-edge),Vector3(edge*2,high-low,edge*2)),species,terrain_point)
	# Four small schools occupy the middle column, rather than pooling at the floor.
	for center in [Vector3(-28,15,-20), Vector3(24,20,-28), Vector3(-20,22,32), Vector3(35,13,24), Vector3(-45,28,40), Vector3(38,28,-45), Vector3(-35,4,-45), Vector3(40,4,40)]:
		center.x = _rng.randf_range(-arena_half_width+18,arena_half_width-18)
		center.z = _rng.randf_range(-arena_half_width+18,arena_half_width-18)
		var pod = BaitPod.new(center)
		pods.append(pod)
		for i in range(pod_population):
			var angle = i * TAU / pod_population
			var slot = Vector3(cos(angle)*4.5, _rng.randf_range(-1.8,1.8), sin(angle)*4.5)
			_enqueue(BaitMotion.Kind.MINNOW, center + slot, _rng.randi(), 40, pod, slot)
	for center in [Vector3(-22,31.5,-18), Vector3(35,31.5,20)]:
		center.x = _rng.randf_range(-arena_half_width+18,arena_half_width-18)
		center.z = _rng.randf_range(-arena_half_width+18,arena_half_width-18)
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
	_targets[kind] = _targets.get(kind,0)+1
	_initial_queue.append([kind,home,seed_id,radius,pod,slot])

func _spawn(kind: int, home: Vector3, behavior_seed: int, radius: float, pod: BaitPod = null, slot: Vector3 = Vector3.ZERO, initial: bool = false) -> BaitActor:
	var bait = Seagull.new() if kind == BaitMotion.Kind.GULL else BaitActor.new()
	bait.kind = kind
	if bait is Seagull: bait.rng.seed = behavior_seed
	bait.neighborhood = neighborhood
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
	var anchor = pod if pod != null else BaitPod.new(home)
	if anchor.habitat == null:
		anchor.habitat = habitats[kind]
		anchor.migration_speed = anchor_migration_speed
		anchor.destination_clock = _rng.randf_range(0,20)
		anchors.append(anchor)
	bait.driver.anchor = anchor
	add_child(bait)
	_population.append({"actor":weakref(bait),"life":_rng.randf_range(natural_lifetime_min,natural_lifetime_max),"dead_age":0.0})
	if not initial and kind == BaitMotion.Kind.MINNOW:
		bait.position.y = water_depth-0.45
		bait.velocity = Vector3.DOWN*2.5
		bait.entry_remaining = 0.5

	return bait

func _physics_process(delta: float) -> void:
	# Authority boundary: one population owner advances migration, mortality and arrivals.
	for anchor in anchors: anchor.migrate(delta,_rng,anchors)
	_spawn_clock -= delta
	if not _initial_queue.is_empty() and _spawn_clock <= 0:
		_spawn_clock = initial_spawn_interval
		var entry = _initial_queue.pop_back()
		_spawn(entry[0],entry[1],entry[2],entry[3],entry[4],entry[5],true)
		return
	_ecosystem_clock += delta
	_arrival_clock -= delta
	if _ecosystem_clock < 1.0: return
	var elapsed = _ecosystem_clock
	_ecosystem_clock = 0
	var live: Dictionary = {}
	var dead: Array = []
	var occupied_anchors: Array = []
	for record in _population:
		var actor = record.actor.get_ref()
		if not is_instance_valid(actor): continue
		if actor.driver is BaitMotion.LiveBaitDriver: occupied_anchors.append(actor.driver.anchor)
		if actor.claimed: continue
		if actor.lifecycle == BaitActor.Lifecycle.ALIVE:
			record.life -= elapsed
			if record.life <= 0 and actor.kind != BaitMotion.Kind.GULL: actor.die_naturally()
			else: live[actor.kind] = live.get(actor.kind,0)+1
		if actor.lifecycle in [BaitActor.Lifecycle.DEAD_SINKING,BaitActor.Lifecycle.DEAD_SETTLED]:
			record.dead_age += elapsed
			dead.append(record)
			if record.dead_age >= carcass_lifetime: actor.queue_free()
	dead.sort_custom(func(a,b): return a.dead_age > b.dead_age)
	for i in range(maxi(0,dead.size()-maximum_carcasses)):
		dead[i].actor.get_ref().queue_free()
	_population = _population.filter(func(record): return is_instance_valid(record.actor.get_ref()))
	anchors = anchors.filter(func(anchor): return anchor in occupied_anchors or anchor in pods)
	if not _initial_queue.is_empty() or _arrival_clock > 0: return
	_arrival_clock = replenishment_interval*_rng.randf_range(0.8,1.2)
	var species: int = -1
	var shortage: float = 0.0
	for kind in _targets:
		var missing = 1.0-float(live.get(kind,0))/_targets[kind]
		if live.get(kind,0) < ceili(_targets[kind]*live_floor_fraction) and missing > shortage:
			species = kind
			shortage = missing
	if species < 0: return
	var pod: BaitPod
	var compatible = pods.filter(func(group): return group.habitat != null and group.habitat.kind == species)
	if not compatible.is_empty(): pod = compatible[_rng.randi_range(0,compatible.size()-1)]
	var habitat: BaitHabitat = habitats[species]
	var home = pod.center if pod != null else habitat.destination(habitat.bounds.get_center(),Vector3.FORWARD,_rng,anchors)
	_spawn(species,home,_rng.randi(),roam_radius,pod)

func terrain_point(point: Vector3, species: int) -> Vector3:
	# This level uses a box water volume plus actual terrain height; drivers know neither.
	var ray = PhysicsRayQueryParameters3D.create(Vector3(point.x,water_depth,point.z),Vector3(point.x,-100,point.z),1)
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var clearance = 6.0 if species == BaitMotion.Kind.SQUID else 0.6
		point.y = maxf(point.y,hit.position.y+clearance)
	return point
