class_name BaitPod
extends RefCounted
## A loose minnow or mullet gathering point, not a second movement system.
var center: Vector3
var members: Array[WeakRef] = []
var separation_distance: float = 2.4

func _init(where: Vector3) -> void:
	center = where

func add_member(bait: BaitActor) -> void:
	members = members.filter(func(reference): return is_instance_valid(reference.get_ref()))
	members.append(weakref(bait))

func separation_from(bait: BaitActor) -> Vector3:
	var away = Vector3.ZERO
	# Called on the driver's staggered sensing tick, only across its own small pod.
	for reference in members:
		var other = reference.get_ref()
		if not is_instance_valid(other) or other == bait or other.claimed: continue
		var offset: Vector3 = bait.global_position - other.global_position
		if offset.length_squared() > 0.01 and offset.length_squared() < separation_distance * separation_distance:
			away += offset.normalized() * (1.0 - offset.length() / separation_distance)
	return away.limit_length(0.8)
