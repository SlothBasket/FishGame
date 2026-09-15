class_name BaitSchool
extends Node3D
## Eight sparse zones: open minnows, low shrimp, midwater squid, bottom crabs.

@export var respawn_delay: float = 8.0
@export var zone_population: int = 6
@export var individual_spacing: float = 7.0
@export var roam_radius: float = 45.0
@export var arena_half_width: float = 120.0
@export var water_depth: float = 32.0
@export var seed_value: int = -1 # -1 = varied play; explicit seeds for tests
var _rng = RandomNumberGenerator.new()
var _respawns: Array = []
var _entry_baits: Array = []
var _entry_clock: float = 6.0
var _shelter_candidate_count: int = 0
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
	for i in range(12):
		_spawn(BaitMotion.Kind.MINNOW if i % 2 == 0 else BaitMotion.Kind.SQUID, Vector3(_rng.randf_range(-60, 60), _rng.randf_range(23, 28), _rng.randf_range(-60, 60)), _rng.randi(), 55.0)
	for i in range(4):
		_spawn(BaitMotion.Kind.GULL, Vector3(-18 + i * 12, water_depth + 4, -12), _rng.randi(), 60.0)
		var entrant = _spawn(BaitMotion.Kind.MINNOW, Vector3(_rng.randf_range(-50, 50), water_depth - 0.45, _rng.randf_range(-50, 50)), _rng.randi(), 50.0)
		entrant.velocity = Vector3.DOWN * 4.0
		entrant.entry_remaining = 0.45
	for i in range(4):
		_spawn(BaitMotion.Kind.MULLET, Vector3(-15 + i * 9, water_depth - 0.45, -18), _rng.randi(), 50.0)
	for zone in range(ZONES.size()):
		var fraction: Vector3 = ZONES[zone]
		var center = Vector3(fraction.x * arena_half_width, fraction.y * water_depth, fraction.z * arena_half_width)
		for i in range(zone_population):
			var angle = _rng.randf_range(0.0, TAU)
			var home = center + Vector3(cos(angle) * individual_spacing * _rng.randf_range(0.5, 2.5), _rng.randf_range(-0.5, 0.5), sin(angle) * individual_spacing * _rng.randf_range(0.5, 2.5))
			_spawn(ZONE_KINDS[zone], home, _rng.randi(), roam_radius * _rng.randf_range(0.75, 1.2))

func _spawn(kind: int, home: Vector3, behavior_seed: int, radius: float) -> BaitActor:
	var bait = Seagull.new() if kind == BaitMotion.Kind.GULL else BaitActor.new()
	bait.kind = kind
	bait.water_height = water_depth
	# Start above terrain so small floor prey cannot be embedded in rock/floor colliders.
	var query = PhysicsRayQueryParameters3D.create(Vector3(home.x, water_depth - 0.5, home.z), Vector3(home.x, -2, home.z), 1)
	var ground = get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty():
		home.y = maxf(home.y, ground.position.y + bait.hit_radius() + 0.15)
	if kind == BaitMotion.Kind.MINNOW and home.y < 22 and behavior_seed % 2 == 0:
		home.y = water_depth - 2.0
	if kind == BaitMotion.Kind.SHRIMP and not ground.is_empty():
		home.y = ground.position.y + bait.hit_radius() + 0.15
	bait.position = home
	bait.heading = Vector3.FORWARD.rotated(Vector3.UP, _rng.randf_range(-PI, PI))
	bait.driver = BaitMotion.LiveBaitDriver.new(home, behavior_seed, radius, 5.0)
	if kind in [BaitMotion.Kind.MINNOW, BaitMotion.Kind.SHRIMP, BaitMotion.Kind.CRAB]:
		_shelter_candidate_count += 1
		bait.driver.shelter_enabled = _shelter_candidate_count % 5 == 0
	bait.bitten.connect(func(_bait, _eater):
		_respawns.append({"remaining": respawn_delay, "kind": kind, "home": home, "radius": radius}))
	add_child(bait)
	if kind == BaitMotion.Kind.MINNOW and home.y > water_depth - 0.6:
		_entry_baits.append(weakref(bait))
	return bait

func _process(delta: float) -> void:
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
			_spawn(entry.kind, entry.home, _rng.randi(), entry.radius)
			break # Spread mesh/node creation after multi-bait meals across frames.
