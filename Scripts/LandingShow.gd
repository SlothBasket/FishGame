class_name LandingShow
extends Node
## Short server-owned end-of-fight gag. Uses normal Fish snapshot transforms.
var fish: FishPlayer
var fisher: FisherActor
var session: NetworkSession
## Solo tests use the existing test boat without needing a network session.
var anchor_position: Vector3 = Vector3(90,32,75)
var anchor_yaw: float = 0
var arena_half_width: float = 132
var age: float = 0
var thrown: bool = false
var gravity: bool = true
var flight_velocity: Vector3 = Vector3.ZERO
var rng = RandomNumberGenerator.new()
var previous_layer: int = 2
const HOLD_SECONDS = 2.2
const WINDUP_SECONDS = 0.9
const THROW_GRAVITY = 28.0
var throw_forward = Vector3.FORWARD
const FLIGHT_SECONDS = 4.0

func _ready() -> void:
	if is_instance_valid(session) and session.encounter_seed >= 0: rng.seed = session.encounter_seed+601+int(session.clock*1000)
	else: rng.randomize()
	fish.landing_show = self
	if is_instance_valid(fisher):
		fisher.landing_show = self
		anchor_position = fisher.position
		anchor_yaw = fisher.boat_yaw
	if is_instance_valid(session): arena_half_width = session.world.arena_width*0.5
	fish.cancel_attack()
	previous_layer = fish.collision_layer
	fish.collision_layer = 0
	fish.velocity = Vector3.ZERO
	throw_forward = Vector3.FORWARD.rotated(Vector3.UP,anchor_yaw)
	# Keep outward-facing boats from throwing straight across the nearby boundary.
	var inward = Vector3(-anchor_position.x,0,-anchor_position.z).normalized()
	if inward.length_squared() > 0.1 and throw_forward.dot(inward) < 0.35:
		throw_forward = (throw_forward*0.25+inward).normalized()
	pose_held()

func pose_held() -> void:
	var side = Vector3.RIGHT.rotated(Vector3.UP,anchor_yaw)
	var windup = smoothstep(HOLD_SECONDS-WINDUP_SECONDS,HOLD_SECONDS-0.18,age)
	var release = smoothstep(HOLD_SECONDS-0.18,HOLD_SECONDS,age)
	fish.position = anchor_position+side*1.35+Vector3.UP*(2.8+windup*1.0)-throw_forward*(windup*2.2-release*3.6)
	fish.heading = Vector3.UP
	fish.visual.rotation = Vector3(PI*0.5+windup*1.1-release*2.3,anchor_yaw,windup*0.5)
	fish.visual.swim_intensity = 0.1

func _physics_process(delta: float) -> void:
	if not is_instance_valid(fish):
		queue_free()
		return
	age += delta
	if age < HOLD_SECONDS:
		pose_held()
		return
	if not thrown:
		thrown = true
		gravity = rng.randf() < 0.9 # Rare gravity-free comedy throws remain.
		var direction = throw_forward.rotated(Vector3.UP,rng.randf_range(-0.3,0.3))
		var destination = fish.position+direction*rng.randf_range(35,65)
		var margin = arena_half_width-18
		destination.x = clampf(destination.x,-margin,margin)
		destination.z = clampf(destination.z,-margin,margin)
		destination.y = fish.water_height
		# Solve a real arc to an in-bounds splash instead of random skyward velocity.
		var vertical_speed = sqrt(2*THROW_GRAVITY*rng.randf_range(12,22))
		var flight_time = (vertical_speed+sqrt(vertical_speed*vertical_speed+2*THROW_GRAVITY*maxf(0,fish.position.y-destination.y)))/THROW_GRAVITY
		flight_velocity = (destination-fish.position)/flight_time
		flight_velocity.y = vertical_speed
		if is_instance_valid(session) and session.capture_events != null: session.capture_events.record(session,"landing-launch",{"gravity":gravity})
	var before = fish.position
	if gravity: flight_velocity.y -= THROW_GRAVITY*delta
	fish.position += flight_velocity*delta
	fish.velocity = flight_velocity
	fish.heading = flight_velocity.normalized()
	var angles = FishInput.angles(fish.heading)
	fish.visual.rotation = Vector3(angles.x+(age-HOLD_SECONDS)*15,angles.y,(age-HOLD_SECONDS)*25)
	if before.y > fish.water_height and fish.position.y <= fish.water_height:
		var hit = before.lerp(fish.position,(before.y-fish.water_height)/maxf(0.001,before.y-fish.position.y))
		var edge = arena_half_width-3
		if absf(hit.x) < edge and absf(hit.z) < edge:
			finish_at(hit+Vector3.DOWN*1.5,true)
			return
	if age >= HOLD_SECONDS+FLIGHT_SECONDS:
		finish_at(fish._spawn,false)

func finish_at(where: Vector3, splashed: bool) -> void:
	fish.reset_fish()
	fish.position = where
	# Release the same grown Fish; only transient movement/stamina are restored.
	fish.endurance = fish.stamina_capacity
	fish.stamina = fish.stamina_capacity
	fish.motion = FishFightMotion.new()
	fish.head = FishSteering.new()
	fish.update_growth_collision()
	fish.collision_layer = previous_layer
	fish.landing_show = null
	if is_instance_valid(fisher): fisher.landing_show = null
	if is_instance_valid(session) and session.capture_events != null: session.capture_events.record(session,"landing-splash" if splashed else "landing-new-fish")
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(fish) and fish.landing_show == self:
		fish.collision_layer = previous_layer
		fish.landing_show = null
	if is_instance_valid(fisher) and fisher.landing_show == self: fisher.landing_show = null
