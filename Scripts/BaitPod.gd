class_name BaitPod
extends RefCounted
## A loose minnow or mullet gathering point, not a second movement system.
var center: Vector3
var members: Array[WeakRef] = []
var separation_distance: float = 2.4
var habitat: BaitHabitat
var destination: Vector3
var heading: Vector3 = Vector3.FORWARD
var migration_speed: float = 0.65
var destination_clock: float = 0.0

func _init(where: Vector3) -> void:
	center = where
	destination = where

func migrate(delta: float, rng: RandomNumberGenerator, anchors: Array) -> void:
	if habitat == null: return
	destination_clock -= delta
	if destination_clock <= 0 or center.distance_to(destination) < 2:
		destination = habitat.destination(center,heading,rng,anchors)
		destination_clock = rng.randf_range(25,55)
	var offset = destination-center
	if offset.length_squared() > 0.01:
		heading = FishInput.turn_toward(heading,BaitMotion.horizontal(offset),delta*0.18)
		center = center.move_toward(destination,migration_speed*delta)

func add_member(bait: BaitActor) -> void:
	members = members.filter(func(reference): return is_instance_valid(reference.get_ref()))
	members.append(weakref(bait))

func separation_from(bait: BaitActor) -> Vector3:
	var away = Vector3.ZERO
	# Called on the driver's staggered sensing tick, only across its own small pod.
	for reference in members:
		var other = reference.get_ref()
		if not is_instance_valid(other) or other == bait or other.lifecycle != BaitActor.Lifecycle.ALIVE: continue
		var offset: Vector3 = bait.global_position - other.global_position
		if offset.length_squared() > 0.01 and offset.length_squared() < separation_distance * separation_distance:
			away += offset.normalized() * (1.0 - offset.length() / separation_distance)
	return away.limit_length(0.8)
