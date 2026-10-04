class_name LandingShow
extends Node
## Short server-owned end-of-fight gag. Uses normal Fish snapshot transforms.
var fish: FishPlayer
var fisher: FisherActor
var session: NetworkSession
var age: float = 0
var thrown: bool = false
var gravity: bool = true
var flight_velocity: Vector3 = Vector3.ZERO
var rng = RandomNumberGenerator.new()
var previous_layer: int = 2
const HOLD_SECONDS = 1.5
const FLIGHT_SECONDS = 4.0

func _ready() -> void:
	if session.encounter_seed >= 0: rng.seed = session.encounter_seed+601+int(session.clock*1000)
	else: rng.randomize()
	fish.landing_show = self
	fisher.landing_show = self
	fish.cancel_attack()
	previous_layer = fish.collision_layer
	fish.collision_layer = 0
	fish.velocity = Vector3.ZERO
	pose_held()

func pose_held() -> void:
	var side = Vector3.RIGHT.rotated(Vector3.UP,fisher.boat_yaw)
	fish.position = fisher.position+side*1.35+Vector3.UP*2.8
	fish.heading = Vector3.UP
	fish.visual.rotation = Vector3(PI*0.5,fisher.boat_yaw,0)
	fish.visual.swim_intensity = 0.1

func _physics_process(delta: float) -> void:
	if not is_instance_valid(fish) or not is_instance_valid(fisher):
		queue_free()
		return
	age += delta
	if age < HOLD_SECONDS:
		pose_held()
		return
	if not thrown:
		thrown = true
		gravity = rng.randf() < 0.5
		var pitch = rng.randf_range(0.25,0.85) if gravity else rng.randf_range(-0.3,0.7)
		flight_velocity = FishInput.from_angles(pitch,rng.randf_range(-PI,PI))*rng.randf_range(55,85)
		if session.capture_events != null: session.capture_events.record(session,"landing-launch",{"gravity":gravity})
	var before = fish.position
	if gravity: flight_velocity.y -= 28*delta
	fish.position += flight_velocity*delta
	fish.velocity = flight_velocity
	fish.heading = flight_velocity.normalized()
	var angles = FishInput.angles(fish.heading)
	fish.visual.rotation = Vector3(angles.x,angles.y,(age-HOLD_SECONDS)*12)
	if before.y > fish.water_height and fish.position.y <= fish.water_height:
		var hit = before.lerp(fish.position,(before.y-fish.water_height)/maxf(0.001,before.y-fish.position.y))
		var edge = session.world.arena_width*0.5-3
		if absf(hit.x) < edge and absf(hit.z) < edge:
			finish_at(hit+Vector3.DOWN*1.5,true)
			return
	if age >= HOLD_SECONDS+FLIGHT_SECONDS:
		finish_at(fish._spawn,false)

func finish_at(where: Vector3, splashed: bool) -> void:
	fish.reset_fish()
	fish.position = where
	fish.feeding.food = 0
	fish.feeding.bait_eaten = 0
	fish.endurance = fish.stamina_capacity
	fish.stamina = fish.stamina_capacity
	fish.motion = FishFightMotion.new()
	fish.head = FishSteering.new()
	fish.update_growth_collision()
	fish.collision_layer = previous_layer
	fish.landing_show = null
	fisher.landing_show = null
	if session.capture_events != null: session.capture_events.record(session,"landing-splash" if splashed else "landing-new-fish")
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(fish) and fish.landing_show == self:
		fish.collision_layer = previous_layer
		fish.landing_show = null
	if is_instance_valid(fisher) and fisher.landing_show == self: fisher.landing_show = null
