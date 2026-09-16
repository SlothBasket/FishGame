class_name Seagull
extends BaitActor
## 0 level patrol, 1 prey dive, 2 float, 3 climb. Targets are mullet only.
@export var flight_speed: float = 11.0
@export var dive_speed: float = 14.0
@export var flight_height: float = 10.0
@export var hunting_depth: float = 7.0
@export var catch_chance: float = 0.35
var phase: int = 0
var remaining: float = 8.0
var target: Vector3
var rng = RandomNumberGenerator.new()
var prey: WeakRef
var scan_clock: float = 0.0
var alarm_sent: bool = false
var catch_attempted: bool = false

func _ready() -> void:
	kind = BaitMotion.Kind.GULL
	super._ready()
	rng.randomize()
	remaining = rng.randf_range(5, 12)
	target = position + Vector3(12, 0, -12)
	target.y = water_height + flight_height

func mouth_position() -> Vector3:
	return global_position - visual.global_basis.z * 0.65

func climb() -> void:
	phase = 3
	remaining = 4.0
	target = position + BaitMotion.horizontal(heading)*18
	target.y = water_height + flight_height

func alarm_mullet(mullet) -> void:
	alarm_sent = true
	if mullet.driver is BaitMotion.LiveBaitDriver:
		mullet.driver.scatter_remaining = rng.randf_range(5, 9)
		if rng.randf() < 0.5 and mullet.position.y > water_height-2:
			mullet.start_flee(0.9, BaitMotion.horizontal(mullet.heading))
		else:
			mullet.driver._mullet_dive = rng.randf_range(3, 5)
			mullet.driver._mullet_dive_wait = rng.randf_range(12, 22)

func _physics_process(delta: float) -> void:
	if claimed: return
	scan_clock -= delta
	# Keep a dive's target even when it descends; reacquire only while patrolling.
	if phase == 0 and scan_clock <= 0:
		scan_clock = rng.randf_range(0.8, 1.2)
		var nearest: float = INF
		prey = null
		for candidate in get_tree().get_nodes_in_group("bait"):
			if candidate.kind != BaitMotion.Kind.MULLET or candidate.claimed or candidate.position.y < water_height-3: continue
			var distance = position.distance_squared_to(candidate.position)
			if distance < nearest:
				nearest = distance
				prey = weakref(candidate)
	var mullet = prey.get_ref() if prey != null else null
	var valid_prey = is_instance_valid(mullet) and not mullet.claimed
	remaining -= delta
	if phase == 0:
		if valid_prey:
			target = mullet.global_position + mullet.velocity*0.45
			target.y = water_height+flight_height
			if Vector2(target.x-position.x,target.z-position.z).length() < 14:
				phase = 1
				remaining = 5.0
				alarm_sent = false
				catch_attempted = false
		elif remaining <= 0 or position.distance_to(target) < 3:
			remaining = rng.randf_range(7,12)
			target = Vector3(rng.randf_range(-85,85),water_height+flight_height,rng.randf_range(-85,85))
	elif phase == 1:
		if not valid_prey or mullet.airborne or mullet.position.y > water_height+0.3:
			climb() # A jumping mullet breaks the bird's underwater attack.
		else:
			target = mullet.global_position + mullet.velocity*0.2
			target.y = clampf(mullet.position.y-0.5,water_height-hunting_depth,water_height-0.5)
			if not alarm_sent and position.distance_to(mullet.position) < 11:
				alarm_mullet(mullet)
			if not catch_attempted and position.distance_to(mullet.position) < 1.1:
				catch_attempted = true
				if rng.randf() < catch_chance: mullet.caught_by_bird(self)
				climb()
			elif remaining <= 0 or position.y < water_height-hunting_depth:
				climb()
	elif phase == 2:
		if remaining <= 0: climb()
	elif remaining <= 0:
		phase = 2 if rng.randf() < 0.25 else 0
		remaining = rng.randf_range(4,8)
		prey = null
	var desired = (target-global_position).limit_length(dive_speed if phase == 1 else flight_speed)
	if phase == 0: desired.y = clampf((water_height+flight_height-position.y)*2,-2,2)
	if phase == 2: desired = Vector3.UP*clampf((water_height+0.18-position.y)*2,-4,4)
	velocity = velocity.move_toward(desired,(18.0 if phase == 1 else 10.0)*delta)
	move_and_slide()
	if Vector2(velocity.x,velocity.z).length() > 0.3:
		heading = FishInput.turn_toward(heading,BaitMotion.horizontal(velocity),delta*3)
	var facing = FishInput.angles(heading)
	var pitch = 0.0 if phase == 2 else clampf(FishInput.angles(velocity.normalized()).x,-1.4,1.3)
	visual.rotation = Vector3(lerp_angle(visual.rotation.x,pitch,1-exp(-6*delta)),facing.y,0)
	visual.speed = velocity.length()
	visual.bird_pose = 2 if phase == 2 else 1 if phase == 1 else 3 if position.y < water_height else 0
	visual.action = BaitMotion.Action.PAUSE if phase == 2 else BaitMotion.Action.CRUISE
