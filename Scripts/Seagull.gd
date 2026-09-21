class_name Seagull
extends BaitActor
## 0 patrol, 1 hunt, 2 rest, 3 climb, 4 landing, 5 underwater recovery. Mullet only.
@export var flight_speed: float = 11.0
@export var dive_speed: float = 14.0
@export var flight_height: float = 10.0
@export var hunting_depth: float = 7.0
@export var catch_chance: float = 0.6
@export var aerial_catch_bonus: float = 0.2
@export var interception_limit: float = 0.85
@export var landing_speed: float = 4.0
var landing_heading: Vector3
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
	# Population owner supplies this generator seed.
	remaining = rng.randf_range(5, 12)
	target = position + Vector3(12, 0, -12)
	target.y = water_height + flight_height

func mouth_position() -> Vector3:
	return global_position - visual.global_basis.z * 0.65

func climb() -> void:
	phase = 5 if position.y < water_height-0.2 else 3
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
	if lifecycle != Lifecycle.ALIVE:
		dead_motion(delta)
		return
	if position.y < water_height-0.4 and phase not in [1,5]: climb()
	scan_clock -= delta
	# Keep a dive's target even when it descends; reacquire only while patrolling.
	if phase == 0 and scan_clock <= 0:
		scan_clock = rng.randf_range(0.8, 1.2)
		var nearest: float = INF
		prey = null
		for candidate in get_tree().get_nodes_in_group("bait"):
			if candidate.kind != BaitMotion.Kind.MULLET or candidate.lifecycle != Lifecycle.ALIVE or candidate.position.y < water_height-3: continue
			var vulnerability = 3.0 if candidate.airborne or candidate._breaching else 1.0
			if candidate.driver is BaitMotion.LiveBaitDriver and candidate.driver.scatter_remaining > 0: vulnerability += 1
			var distance = position.distance_squared_to(candidate.position)/vulnerability
			if distance < nearest:
				nearest = distance
				prey = weakref(candidate)
	var mullet = prey.get_ref() if prey != null else null
	var valid_prey = is_instance_valid(mullet) and mullet.lifecycle == Lifecycle.ALIVE
	remaining -= delta
	if phase == 0:
		if valid_prey:
			target = intercept(mullet)
			target.y = water_height+flight_height
			if Vector2(target.x-position.x,target.z-position.z).length() < 20:
				phase = 1
				remaining = 5.0
				alarm_sent = false
				catch_attempted = false
		elif remaining <= 0 or position.distance_to(target) < 3:
			remaining = rng.randf_range(7,12)
			target = Vector3(rng.randf_range(-arena_half_width+15,arena_half_width-15),water_height+flight_height,rng.randf_range(-arena_half_width+15,arena_half_width-15))
	elif phase == 1:
		if not valid_prey or (position.y < water_height-0.4 and mullet.position.y > water_height):
			climb() # Surface recovery precedes reacquiring an aerial target.
		else:
			target = intercept(mullet)
			if not alarm_sent and position.distance_to(mullet.position) < 11:
				alarm_mullet(mullet)
			if remaining <= 0 or position.y < water_height-hunting_depth: climb()

	elif phase == 2:
		if remaining <= 0: climb()
	elif phase == 3 and remaining <= 0 and position.y > water_height+flight_height*0.7:
		phase = 0
		remaining = rng.randf_range(4,8)
		prey = null
		if rng.randf() < 0.25: begin_landing()
	elif phase == 4:
		if position.y <= water_height+0.3:
			phase = 2
			remaining = rng.randf_range(4,8)
		elif remaining <= 0: climb()
	elif phase == 5 and position.y > water_height+0.25:
		phase = 3
		remaining = 4
		velocity += Vector3.UP*4

	var desired = (target-global_position).limit_length(dive_speed if phase == 1 else flight_speed)
	if phase == 0: desired.y = clampf((water_height+flight_height-position.y)*2,-2,2)
	if phase == 2: desired = BaitMotion.horizontal(heading)*0.25+Vector3.UP*clampf((water_height+0.18-position.y)*3,-1,1)
	if phase == 4:
		var height = maxf(0,position.y-water_height-0.18)
		var distance = Vector2(target.x-position.x,target.z-position.z).length()
		desired = landing_heading*lerpf(1.5,landing_speed,clampf(height/2,0,1))
		desired.y = -minf(2.0,maxf(0.18,height)*landing_speed/maxf(2,distance))
	if phase == 5: desired = BaitMotion.horizontal(heading)*3+Vector3.UP*5
	if phase == 3 and position.y < water_height+flight_height*0.7: desired.y = maxf(desired.y,2.5)
	var start = global_position
	velocity = velocity.move_toward(desired,(18.0 if phase == 1 else 10.0)*delta)
	move_and_slide()
	if phase == 1 and valid_prey and not catch_attempted:
		var near = FishFeeding.closest_point(start,global_position,mullet.global_position)
		if near.distance_to(mullet.global_position) < 0.85+hit_radius()+mullet.hit_radius():
			catch_attempted = true
			var chance = catch_chance+aerial_catch_bonus if mullet.airborne or mullet._breaching else catch_chance
			if rng.randf() < chance: mullet.caught_by_bird(self)
			climb()
	if Vector2(velocity.x,velocity.z).length() > 0.3:
		heading = FishInput.turn_toward(heading,BaitMotion.horizontal(velocity),delta*3)
	var facing = FishInput.angles(heading)
	var pitch = 0.0 if phase == 2 else clampf(FishInput.angles(velocity.normalized()).x,-1.4,1.3)
	if phase == 4 and position.y < water_height+1: pitch = 0.18 # Landing flare.
	visual.rotation = Vector3(lerp_angle(visual.rotation.x,pitch,1-exp(-6*delta)),facing.y,0)
	visual.speed = velocity.length()
	visual.bird_pose = 3 if phase == 5 else 2 if phase == 2 else 1 if phase == 1 and velocity.y < -2 else 0
	visual.bird_powered = phase not in [2,4] and (phase != 1 or velocity.y > -2)
	visual.action = BaitMotion.Action.PAUSE if phase == 2 else BaitMotion.Action.CRUISE

func intercept(mullet) -> Vector3:
	var lead = clampf(position.distance_to(mullet.position)/dive_speed,0.05,interception_limit)
	var point: Vector3 = mullet.global_position+mullet.velocity*lead
	if mullet.airborne or mullet._breaching: point.y -= 0.5*mullet.airborne_gravity*lead*lead
	point.y = maxf(water_height-hunting_depth,point.y)
	return point

func begin_landing() -> void:
	phase = 4
	remaining = 18
	landing_heading = BaitMotion.horizontal(heading)
	target = position+landing_heading*maxf(18,(position.y-water_height)*3.5)
	target.x = clampf(target.x,-arena_half_width+5,arena_half_width-5)
	target.z = clampf(target.z,-arena_half_width+5,arena_half_width-5)
	target.y = water_height+0.18
	landing_heading = BaitMotion.horizontal(target-position)
