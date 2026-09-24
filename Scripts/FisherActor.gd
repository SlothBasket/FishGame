class_name FisherActor
extends Node3D
## Server-owned boat/bait controller. No cameras, device reads, HUD or local art.
enum State { SETUP, BAIT, FIGHT }
@export var boat_speed: float = 12
@export var ai_cast_distance: float = 95
@export var cast_distance: float = 65
@export var cast_variation: float = 0.22
@export var cast_angle_variation: float = 0.12
@export var stamina_capacity: float = 100
@export var stamina_regen: float = 9
@export var focus_capacity: float = 100
@export var focus_drain: float = 22
@export var focus_regen: float = 8
@export var default_drag: float = 0.4
var drag_setting: float = 0.4
var focus_exhausted: bool = false
var stamina: float = 100
var focus: float = 100
var vision_active: bool = false
var state: int = State.SETUP
var peer_id: int
var session
var command = FisherIntent.new()
var reel = ReelSpeed.new()
var kind: int = 0
var boat_yaw: float = 0
var lure: BaitActor
var fight
var last_cast: int = 0
var cast_cooldown: float = 0
var outcome: int = 0
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	drag_setting = default_drag
	command.drag = default_drag
	if session.encounter_seed >= 0: rng.seed = session.encounter_seed+11
	else: rng.randomize()
	position = Vector3(90,session.world.water_depth,75)
	boat_yaw = FishInput.angles(BaitMotion.horizontal(-position)).y

func _physics_process(delta: float) -> void:
	stamina = minf(stamina_capacity,stamina+stamina_regen*delta)
	if not command.vision: focus_exhausted = false
	if focus <= 0: focus_exhausted = true
	vision_active = state == State.FIGHT and command.vision and not focus_exhausted
	focus = clampf(focus+(-focus_drain if vision_active else focus_regen)*delta,0,focus_capacity)
	drag_setting = clampf(command.drag,0,1)
	reel.selected_tier = command.tier
	cast_cooldown = maxf(0,cast_cooldown-delta)
	if state == State.FIGHT: return
	kind = command.species if state == State.SETUP else kind
	if state == State.SETUP:
		boat_yaw = FishInput.approach_angle(boat_yaw,FishInput.angles(BaitMotion.horizontal(command.aim)).y,delta*2.5)
		var forward = Vector3.FORWARD.rotated(Vector3.UP,boat_yaw)
		position += (forward*command.move_forward+forward.cross(Vector3.UP)*command.move_side).limit_length()*boat_speed*delta
		var edge = session.world.arena_width*0.5-15
		position.x = clampf(position.x,-edge,edge)
		position.z = clampf(position.z,-edge,edge)
	if command.cast_serial > last_cast:
		last_cast = command.cast_serial
		if cast_cooldown <= 0:
			cast_cooldown = 0.5
			if state == State.SETUP: cast()
			else: return_to_setup()
	if state != State.BAIT or not is_instance_valid(lure): return
	if lure.cast_remaining > 0 or lure.cast_windup > 0: return
	if command.retrieve > 0 and lure.position.distance_to(position-Vector3.UP*0.65) < 1.2:
		return_to_setup()
		return
	var driver: BaitMotion.PlayerLiveDriver = lure.driver
	driver.throttle = command.retrieve
	driver.steering = command.steering
	driver.rise = command.rise
	driver.descend = command.descend
	driver.escape_held = command.escape
	driver.aim_direction = command.aim

func cast() -> void:
	if state != State.SETUP: return
	outcome = 0
	lure = BaitActor.new()
	lure.kind = kind
	lure.source = BaitMotion.Source.FISHERMAN
	lure.fisher_owner = self
	lure.randomize_size(rng)
	lure.water_height = session.world.water_depth
	lure.arena_half_width = session.world.arena_width*0.5
	var driver = BaitMotion.PlayerLiveDriver.new()
	driver.use_anchor = true
	driver.anchor_position = position
	driver.squid_axis = Vector3.FORWARD.rotated(Vector3.UP,boat_yaw)
	lure.driver = driver
	var destination = BaitCasting.destination(position,driver.squid_axis,lure.arena_half_width,cast_distance*rng.randf_range(1-cast_variation,1+cast_variation),rng.randf_range(-cast_angle_variation,cast_angle_variation))
	if kind == BaitMotion.Kind.SQUID: destination = position-Vector3.UP
	lure.position = position
	lure.heading = BaitMotion.horizontal(position-destination)
	session.world.add_child(lure)
	session.register_bait(lure)
	lure.launch_cast(position+Vector3.UP*0.7,destination,0.55 if kind == BaitMotion.Kind.SQUID else 1.8)
	state = State.BAIT

func take_bait(fish: FishPlayer) -> bool:
	if state != State.BAIT or is_instance_valid(fight) or is_instance_valid(fish.fight) or not is_instance_valid(lure) or lure.claimed: return false
	fight = FightSession.new()
	fight.fisher = self
	fight.fish = fish
	fight.bait = lure
	fish.fight = fight
	state = State.FIGHT
	session.world.add_child(fight)
	return true

func return_to_setup() -> void:
	if is_instance_valid(lure): lure.queue_free()
	lure = null
	state = State.SETUP
	last_cast = command.cast_serial

func cleanup() -> void:
	if is_instance_valid(fight): fight.finish(FightSession.Outcome.DISCONNECT)
	return_to_setup()
