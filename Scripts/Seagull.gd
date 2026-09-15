class_name Seagull
extends BaitActor
## Scan once a second, approach surface mullet, then swoop and rest upright.
var phase: int = 0
var remaining: float = 8.0
var target: Vector3
var rng = RandomNumberGenerator.new()
var prey: WeakRef
var scan_clock: float = 0.0

func _ready() -> void:
	kind = BaitMotion.Kind.GULL
	super._ready()
	rng.randomize()
	remaining = rng.randf_range(5, 12)
	target = position + Vector3(12, 2, -12)

func _physics_process(delta: float) -> void:
	if claimed: return
	scan_clock -= delta
	if scan_clock <= 0:
		scan_clock = rng.randf_range(0.8, 1.2)
		var nearest: float = INF
		prey = null
		for candidate in get_tree().get_nodes_in_group("bait"):
			if candidate.kind != BaitMotion.Kind.MULLET or candidate.claimed or candidate.position.y < water_height - 3: continue
			var distance = position.distance_squared_to(candidate.position)
			if distance < nearest:
				nearest = distance
				prey = weakref(candidate)
	var mullet = prey.get_ref() if prey != null else null
	if is_instance_valid(mullet) and phase in [0, 1]:
		target = mullet.global_position + mullet.velocity * 0.45
		target.y = water_height + (5.0 if phase == 0 else 0.18)
	remaining -= delta
	if phase == 0 and is_instance_valid(mullet) and Vector2(target.x - position.x, target.z - position.z).length() < 9:
		phase = 1
		remaining = 4.0
	elif remaining <= 0:
		phase = (phase + 1) % 4
		remaining = [rng.randf_range(7, 12), 5.0, rng.randf_range(3, 6), 4.0][phase]
		if phase == 0:
			target = Vector3(rng.randf_range(-75, 75), water_height + 5, rng.randf_range(-75, 75))
		elif phase == 1:
			target.y = water_height + 0.18
		elif phase == 3:
			target = position + BaitMotion.horizontal(heading) * 16 + Vector3.UP * 6
	var desired = (target - global_position).limit_length(8.0)
	if phase == 2:
		desired = Vector3.UP * clampf((water_height + 0.18 - position.y) * 2, -4, 4)
	velocity = velocity.move_toward(desired, 8.0 * delta)
	move_and_slide()
	if Vector2(velocity.x, velocity.z).length() > 0.3:
		heading = FishInput.turn_toward(heading, BaitMotion.horizontal(velocity), delta * 3)
	var facing = FishInput.angles(heading)
	# Body remains level while floating; vertical settling never pitches the beak down.
	var pitch = 0.0 if phase == 2 else clampf(FishInput.angles(velocity.normalized()).x, -0.6, 0.6)
	visual.rotation = Vector3(lerp_angle(visual.rotation.x, pitch, 1-exp(-6*delta)), facing.y, 0)
	visual.speed = velocity.length()
	visual.action = BaitMotion.Action.PAUSE if phase == 2 else BaitMotion.Action.CRUISE
