class_name BaitSchool
extends Node3D
## Six separated zones, four spaced individuals each. Positions are fractions of arena half-width.

@export var respawn_delay: float = 8.0
@export var zone_population: int = 4
@export var individual_spacing: float = 4.0
@export var roam_radius: float = 12.0
@export var arena_half_width: float = 90.0
@export var water_depth: float = 32.0
@export var seed_value: int = -1 # -1 = varied play; explicit seeds for tests
var _rng = RandomNumberGenerator.new()
var _respawns: Array = []
const ZONES = [Vector3(0, 0.24, 0), Vector3(-0.52, 0.12, 0.38),
	Vector3(0.52, 0.5, -0.5), Vector3(-0.5, 0.38, -0.5),
	Vector3(0.58, 0.12, 0.48), Vector3(0, 0.57, 0.65)]

func _ready() -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	for zone in range(ZONES.size()):
		var fraction: Vector3 = ZONES[zone]
		var center = Vector3(fraction.x * arena_half_width, fraction.y * water_depth, fraction.z * arena_half_width)
		for i in range(zone_population):
			var angle = TAU * i / maxf(1.0, zone_population)
			var home = center + Vector3(cos(angle) * individual_spacing, _rng.randf_range(-0.5, 0.5), sin(angle) * individual_spacing)
			_spawn(zone % 3, home, _rng.randi(), roam_radius * _rng.randf_range(0.75, 1.2))

func _spawn(kind: int, home: Vector3, behavior_seed: int, radius: float) -> void:
	var bait = BaitActor.new()
	bait.kind = kind
	bait.position = home
	bait.driver = BaitMotion.LiveBaitDriver.new(home, behavior_seed, radius)
	bait.bitten.connect(func(_bait, _eater):
		_respawns.append({"remaining": respawn_delay, "kind": kind, "home": home, "radius": radius}))
	add_child(bait)

func _process(delta: float) -> void:
	for i in range(_respawns.size() - 1, -1, -1):
		var entry: Dictionary = _respawns[i]
		entry.remaining -= delta
		if entry.remaining <= 0.0:
			_respawns.remove_at(i)
			_spawn(entry.kind, entry.home, _rng.randi(), entry.radius)
