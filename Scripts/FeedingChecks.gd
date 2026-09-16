class_name FeedingChecks
extends Node
## Drives actual physics with intent, not synthetic keyboard events.
var fish
var failures: int = 0
var checks: int = 0
var _hook_notified: bool = false
const ORIGIN = Vector3(-25, 15, 25)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS " if condition else "FAIL ") + label)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func reset() -> void:
	fish.reset_fish()
	fish.position = ORIGIN
	fish.pivot.rotation = Vector3.ZERO
	fish.command = FishInput.new()

func bait(kind: int, where: Vector3, source: int = BaitMotion.Source.LIVE):
	var actor = BaitActor.new()
	actor.kind = kind
	actor.minimum_eater_scale = 0 # Collision/reward tests isolate progression; gate tests are separate.
	actor.position = where
	actor.source = source
	actor.driver = BaitMotion.ControlledBaitDriver.new()
	get_parent().add_child(actor)
	return actor

func dash(charge_frames: int, aim: Vector3 = Vector3.FORWARD) -> float:
	fish.command = FishInput.new(0, 0, 0, aim, false, true)
	await frames(charge_frames + 1)
	var start: Vector3 = fish.position
	fish.command = FishInput.new(0, 0, 0, aim)
	await frames(2)
	var timeout = 180
	while fish.feeding.is_dashing() and timeout > 0:
		timeout -= 1
		await frames(1)
	check(timeout > 0, "Dash terminates")
	return start.distance_to(fish.position)

func simulate(hz: int, intent: FishInput) -> Vector3:
	var velocity = Vector3.ZERO
	for i in range(hz * 3):
		velocity = FishInput.next_velocity(velocity, Vector3.FORWARD, intent, 8, 1.85, 0.4, 12, 6, 4, 0.7, 1.0 / hz)
	return velocity

func steering_simulation(hz: int) -> Vector3:
	var heading = Vector3.FORWARD
	for i in range(hz):
		heading = FishInput.steer_heading(heading, FishInput.new(1, 0, 0, Vector3.RIGHT), 60, 50, 125, 0.45, 1.0 / hz)
	return heading

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func():
		push_error("Self-test watchdog expired")
		get_tree().quit(1))
	check(is_equal_approx(simulate(60, FishInput.new(1)).length(), 8), "Cruise speed")
	check(is_equal_approx(simulate(60, FishInput.new(1, 0, 0, Vector3.FORWARD, true)).length(), 14.8), "Boost speed")
	check(simulate(60, FishInput.new(1, 0, 1)).length() <= 8.001, "Vertical combination speed cap")
	check(simulate(30, FishInput.new(1)).distance_to(simulate(120, FishInput.new(1))) < 0.001
		and steering_simulation(30).distance_to(steering_simulation(120)) < 0.001, "Frame-rate independent speed and turn rate")
	check(FishInput.next_velocity(Vector3.FORWARD * 8, Vector3.FORWARD, FishInput.new(), 8, 1.85, 0.4, 12, 6, 4, 0.7, 0.1).length() < 8, "Water drag")
	reset()
	fish.command = FishInput.new(-1, 0, 0, Vector3.RIGHT, true)
	await frames(120)
	check(fish.heading.distance_to(Vector3.FORWARD) < 0.001 and fish.velocity.z > 3.1
		and fish.velocity.length() < 3.21, "S reverses slowly without flipping heading or reverse boost")
	reset()
	fish.command = FishInput.new(0, 1)
	await frames(30)
	check(fish.position.distance_to(ORIGIN) < 0.001 and fish.heading.x > 0.2, "D pivots without lateral strafe")
	reset()
	fish.command = FishInput.new(1, 0, 0, Vector3.RIGHT)
	await frames(3)
	check(fish.heading.x > 0 and fish.heading.x < 0.2 and fish.velocity.z < 0, "Forward curves toward aim instead of snapping")
	var heading = FishInput.steer_heading(Vector3.FORWARD, FishInput.new(1, 0, 0, Vector3(1, 0.5, -1).normalized()), 85, 65, 125, 0.45, 0.2)
	check(heading.y > 0 and heading.x > 0, "Forward steering follows yaw and pitch intent")
	reset()
	fish.position = Vector3(0, 6, 12)
	fish.command = FishInput.new(0, 0, -1)
	await frames(150)
	check(absf(fish.position.y - fish.get_node("CollisionShape3D").shape.radius) < 0.08, "Fish collides with seabed")
	check(absf(fish.visual.rotation.z) < 0.001, "No gameplay roll")
	fish.command = FishInput.new(0, 0, 1)
	var fish_breached = false
	for i in range(450):
		await frames(1)
		fish_breached = fish_breached or fish.position.y > fish.water_height
	check(fish_breached, "Fish can swim through the surface into a gravity-driven breach")
	fish.reset_fish()
	check(fish.position.distance_to(Vector3(0, 6, 12)) < 0.001 and fish.velocity == Vector3.ZERO, "Reset restores spawn and clears momentum")
	fish.command = FishInput.new()
	fish.position = Vector3(get_parent().arena_width * 0.5 - 2.5, 12, 12)
	fish.pivot.rotation = Vector3(0, PI / 2, 0)
	await frames(20)
	check(fish.get_node("CameraPivot/SpringArm3D").get_hit_length() < 2, "Spring arm retracts at enlarged arena wall")
	reset()
	var touching = bait(0, ORIGIN)
	await frames(3)
	check(not touching.claimed and fish.feeding.bait_eaten == 0, "Ordinary swimming does not eat")
	touching.queue_free()
	await frames(2)
	reset()
	var short_distance = await dash(1)
	check(short_distance >= 3 and short_distance < 3.6, "Tap produces short lunge")
	reset()
	var long_distance = await dash(100)
	check(long_distance > 14.8 and long_distance < 15.2, "Full charge reaches 15 m straight ahead")
	reset()
	fish.command = FishInput.new(0, 0, 0, Vector3.BACK, false, true)
	await frames(20)
	var cancel = FishInput.new()
	cancel.cancel_bite = true
	fish.command = cancel
	await frames(3)
	check(not fish.feeding.is_charging and not fish.feeding.is_dashing() and fish.position.distance_to(ORIGIN) < 0.01, "Cancel does not fire charged dash")
	reset()
	fish.command = FishInput.new(0, 0, 0, Vector3.BACK, false, true)
	await frames(90)
	fish.command = FishInput.new(0, 0, 0, Vector3.BACK)
	await frames(2)
	check(rad_to_deg(Vector3.FORWARD.angle_to(fish.feeding.dash_target)) <= fish.maximum_lunge_turn_angle + 0.01
		and rad_to_deg(Vector3.FORWARD.angle_to(fish.heading)) < 10, "Release cone is clamped and first tick cannot snap")
	await frames(45)
	check(rad_to_deg(Vector3.FORWARD.angle_to(fish.heading)) <= fish.maximum_lunge_turn_angle + 0.01
		and fish.position.x < ORIGIN.x - 1, "Lunge follows physical curve inside release cone")
	reset()
	for i in range(3):
		bait(i, ORIGIN + Vector3.FORWARD * (3 + i * 3)).set_physics_process(false)
	var food_before = fish.feeding.food
	await dash(90)
	check(fish.feeding.bait_eaten == 3 and fish.feeding.food - food_before == 8, "One dash eats all three types with correct nutrition")
	check(fish.size_multiplier() > fish.starting_size, "Food grows fish")
	await frames(20)
	check(get_tree().get_nodes_in_group("bait").is_empty(), "Consumed bait leave edible set")
	reset()
	var single = bait(1, ORIGIN + Vector3.RIGHT * 4)
	food_before = fish.feeding.food
	check(single.try_bite(fish) and not single.try_bite(fish) and fish.feeding.food - food_before == 4, "Single-consumer reward gate")
	reset()
	var fake = bait(0, ORIGIN + Vector3.FORWARD * 3, BaitMotion.Source.FISHERMAN)
	fake.bitten.connect(func(_bait, _eater): _hook_notified = true)
	food_before = fish.feeding.food
	await dash(20)
	check(_hook_notified and fish.feeding.food == food_before, "Fisherman bite callback without nutrition")
	reset()
	var live = bait(2, Vector3(-38, 15, 20))
	var controlled = bait(2, Vector3(-34, 15, 20), BaitMotion.Source.FISHERMAN)
	var same_command = BaitMotion.BaitCommand.new(Vector3.RIGHT, 0.7, 0.6)
	live.driver.command = same_command
	controlled.driver.command = same_command
	var live_start: Vector3 = live.position
	var controlled_start: Vector3 = controlled.position
	await frames(35)
	check((live.position - live_start).distance_to(controlled.position - controlled_start) < 0.001
		and live.visual.twitch == controlled.visual.twitch, "Live and controlled bait share limits, motor and presentation")
	var driver_a = BaitMotion.LiveBaitDriver.new(live.position, 42)
	var driver_b = BaitMotion.LiveBaitDriver.new(live.position, 42)
	var deterministic = true
	var states = {}
	for i in range(600):
		var a = driver_a.sample(live, 1.0 / 60)
		var b = driver_b.sample(live, 1.0 / 60)
		deterministic = deterministic and a.direction.is_equal_approx(b.direction) and a.effort >= 0 and a.effort <= 1
		states[driver_a.state] = true
	check(deterministic and states.size() > 1, "Seeded AI varies behavior through legal reproducible commands")
	live.queue_free()
	controlled.queue_free()
	reset()
	var barrier = Node3D.new()
	get_parent().add_child(barrier)
	Geometry.box(barrier, "TestWall", ORIGIN + Vector3.FORWARD * 4, Vector3(12, 12, 0.25), Geometry.material("334455"))
	var hidden = bait(2, ORIGIN + Vector3.FORWARD * 4.6)
	await frames(2)
	food_before = fish.feeding.food
	var blocked_distance = await dash(90)
	check(blocked_distance < 3.5 and fish.feeding.food == food_before and not hidden.claimed, "Walls stop dash and block bites through cover")
	hidden.queue_free()
	barrier.queue_free()
	await frames(3)
	reset()
	bait(0, ORIGIN + Vector3.FORWARD * 2.2)
	fish.lunge_speed = 300
	food_before = fish.feeding.food
	await dash(1)
	check(fish.feeding.food == food_before + 1, "High-speed sweep catches small bait")
	fish.lunge_speed = 26
	check(FishFeeding.closest_point(Vector3.ZERO, Vector3.ZERO, Vector3.ONE) == Vector3.ZERO, "Zero-length sweep remains finite")
	await frames(20)
	reset()
	var school = BaitSchool.new()
	school.respawn_delay = 0.12
	school.seed_value = 23
	get_parent().add_child(school)
	check(school.get_child_count() == 0, "Initial bait is queued, not built on the first frame")
	while not school._initial_queue.is_empty(): school._process(0.11)
	var population = get_tree().get_nodes_in_group("bait").size()
	get_tree().get_nodes_in_group("bait")[0].try_bite(fish)
	await frames(30)
	check(population == 142 and get_tree().get_nodes_in_group("bait").size() == population, "Expanded bait and gull population replenishes")
	var mid_squid = 0
	var pod_members = 0
	var only_minnows = true
	for actor in school.get_children():
		if actor.kind == BaitMotion.Kind.SQUID and actor.position.y >= 14: mid_squid += 1
		if actor.driver is BaitMotion.LiveBaitDriver and actor.driver.pod != null:
			pod_members += 1
			only_minnows = only_minnows and actor.kind in [BaitMotion.Kind.MINNOW, BaitMotion.Kind.MULLET]
	check(mid_squid >= 24, "Squid are dispersed through the middle and upper water")
	check(pod_members == 64 and only_minnows, "Only minnows and mullet belong to the ten loose pods")
	school.queue_free()
	await frames(3)
	await check_growth_and_casting()
	await check_schooling_and_depth()
	await check_free_squid_and_tail_shrimp()
	await check_retained_motion_regressions()
	await check_density_and_hunting()
	await check_round_pacing()
	await check_optimization_contracts()
	print("SELF-TEST COMPLETE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func check_growth_and_casting() -> void:
	var saved_food = fish.feeding.food
	fish.feeding.food = 0
	var small = fish.size_multiplier()
	fish.feeding.food = 10
	var ten = fish.size_multiplier()
	fish.feeding.food = 20
	var twenty = fish.size_multiplier()
	fish.feeding.food = 10000
	check(small < 0.65 and ten > small and ten < small*1.2, "Fish starts small and ten food adds less than twenty percent size")
	check(twenty-ten < ten-small and fish.size_multiplier() <= fish.maximum_size, "Growth has diminishing gains and a finite cap")
	fish.feeding.food = saved_food
	fish.update_growth_collision()
	var controller = LureTestController.new()
	get_parent().add_child(controller)
	controller.setup(fish,get_parent(),Vector3(0,31,0))
	controller.cast_bait()
	check(controller.boat_aiming and controller.active and not is_instance_valid(controller.lure), "First cast press enters boat setup without launching bait")
	var old_origin = controller.anchor_position
	controller.move_origin(Vector3.LEFT,0.5)
	check(controller.anchor_position.x < old_origin.x and controller.boat.position == controller.anchor_position, "Boat setup can reposition the cast origin")
	controller.boat_yaw = PI*0.5
	controller.cast_bait()
	check(not controller.boat_aiming and controller.lure.cast_windup > 0, "Second cast press starts the backswing and flight")
	check(BaitMotion.horizontal(controller.spawn_position-controller.anchor_position).dot(Vector3.LEFT) > 0.98, "Cast follows the chosen view heading instead of forcing center aim")
	await frames(130)
	check(controller.lure.cast_remaining == 0 and controller.lure.velocity.y < 0, "Cast lands and starts its sinking entry")
	var species = {}
	for i in range(5):
		species[controller.selected_kind] = true
		controller.switch_lure()
	check(species.size() == 5 and species.has(BaitMotion.Kind.MULLET) and not species.has(BaitMotion.Kind.GULL), "Test menu contains exactly five live species")
	controller.toggle_camera()
	check(fish.camera.current, "Fish camera can still observe controlled bait")
	controller.set_active(false)
	controller.lure.queue_free()
	controller.boat.queue_free()
	controller.bait_camera.queue_free()
	controller.queue_free()

func check_schooling_and_depth() -> void:
	reset()
	fish.remove_from_group("fish_predators")
	var pod = BaitPod.new(Vector3(60,16,30))
	var minnow = bait(BaitMotion.Kind.MINNOW,Vector3(80,16,30))
	minnow.heading = Vector3.LEFT
	var ai = BaitMotion.LiveBaitDriver.new(pod.center,182,45)
	ai.pod = pod
	ai._escape_clock = 100
	ai.scatter_remaining = 2
	minnow.driver = ai
	pod.add_member(minnow)
	ai._sense_time = 10
	ai._remaining = 10
	ai._direction = Vector3.RIGHT
	ai._turn_clock = 10
	var scattering = ai.sample(minnow,0.01)
	check(ai.scatter_remaining > 0 and scattering.direction.x > -0.9, "Scattered minnows postpone reunion steering")
	ai.scatter_remaining = 0
	ai._direction = Vector3.LEFT
	var start_distance = minnow.position.distance_to(pod.center)
	await frames(300)
	check(minnow.position.distance_to(pod.center) < start_distance-2, "Calm minnows slowly swim back toward their pod")
	var neighbor = bait(BaitMotion.Kind.MINNOW,minnow.position+Vector3.RIGHT)
	pod.add_member(neighbor)
	check(pod.separation_from(minnow).x < 0, "Pod separation keeps nearby members from piling together")
	neighbor.queue_free()
	minnow.queue_free()
	var squid = bait(BaitMotion.Kind.SQUID,Vector3(85,2,0))
	var squid_ai = BaitMotion.LiveBaitDriver.new(Vector3(85,19,0),6)
	squid_ai._escape_clock = 100
	squid_ai.state = "drop"
	squid_ai._action = BaitMotion.Action.GLIDE
	squid_ai._remaining = 30
	squid.driver = squid_ai
	await frames(360)
	check(squid.position.y > 10 and squid.velocity.y > 0, "Low AI squid swims back into its middle-water depth band")
	squid.queue_free()
	var mullet = bait(BaitMotion.Kind.MULLET,Vector3(0,30,0))
	mullet.set_physics_process(false)
	var gull = Seagull.new()
	gull.position = Vector3(0,35,0)
	get_parent().add_child(gull)
	gull.phase = 0
	gull.catch_chance = 0
	gull.scan_clock = 0
	var minimum_y = gull.position.y
	for i in range(160):
		await frames(1)
		minimum_y = minf(minimum_y,gull.position.y)
	check(minimum_y < gull.water_height-0.4, "Gull dives through the surface toward a mullet before pulling out")
	gull.queue_free()
	if is_instance_valid(mullet): mullet.queue_free()

func check_free_squid_and_tail_shrimp() -> void:
	reset()
	var squid = bait(BaitMotion.Kind.SQUID, Vector3(85,15,0))
	squid.set_physics_process(false)
	var controls = BaitMotion.PlayerLiveDriver.new()
	controls.use_anchor = true
	controls.anchor_position = Vector3(85,32,0)
	var unrestricted = true
	for aim in [Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3(1,0.7,1).normalized()]:
		controls.aim_direction = aim
		controls.escape_held = true
		controls.sample(squid, squid.flee_charge_time*0.7)
		controls.escape_held = false
		var jet = controls.sample(squid, 0.016)
		unrestricted = unrestricted and jet.direction.dot(aim) > 0.999 and jet.flee_fraction > 0
	check(unrestricted, "Squid charge release accepts any 3D aim without a rod turn cone")
	controls.rise = true
	var up = controls.sample(squid, 0.016)
	var held = controls.sample(squid, 0.016)
	controls.rise = false
	controls.descend = true
	var down = controls.sample(squid, 0.016)
	check(up.direction == Vector3.UP and up.flee_fraction > 0 and down.direction == Vector3.DOWN and down.flee_fraction > 0, "Squid vertical keys submit distinct up/down jets without mouse charge")
	check(held.flee_fraction < 0, "Holding a vertical jet key does not spam repeated escapes")
	controls.descend = false
	controls.throttle = 1
	controls.anchor_position = Vector3(85,32,-20)
	var reel = controls.sample(squid, 0.016)
	check(reel.flee_fraction < 0 and reel.effort <= 0.31 and not reel.descend, "Slow squid reeling remains separate from vertical jets")
	controls.throttle = 0
	var slack = controls.sample(squid, 0.016)
	check(slack.action == BaitMotion.Action.GLIDE and slack.flee_fraction < 0, "Releasing squid reel leaves ordinary sinking")
	controls.anchor_position = Vector3(85,32,0)
	squid.driver = controls
	squid.set_physics_process(true)
	squid.position = Vector3(91.3,15,0)
	squid.start_flee(1, Vector3.RIGHT)
	await frames(30)
	check(is_equal_approx(squid.squid_roam_radius, 8.4) and squid.position.x > 92.5 and squid.position.x <= 93.5, "Squid can dash beyond the old six-metre radius within the reduced 8.4-metre range")
	squid.queue_free()
	var shrimp = bait(BaitMotion.Kind.SHRIMP, Vector3(80,10,30))
	var prey_ai = BaitMotion.LiveBaitDriver.new(shrimp.position, 79)
	prey_ai._threat = true
	prey_ai._threat_direction = Vector3.RIGHT
	prey_ai._sense_time = 10
	prey_ai._remaining = 10
	var response = prey_ai.sample(shrimp, 0.016)
	shrimp.start_flee(response.flee_fraction, response.direction)
	await frames(10)
	check(shrimp.velocity.z < -1 and shrimp.velocity.y > 1, "Threatened shrimp keeps its tail-first heading while kicking upward")
	check(BaitMotion.horizontal(shrimp.visual.global_basis.z).dot(BaitMotion.horizontal(shrimp.velocity)) > 0.99, "Shrimp tail leads its escape while its nose trails behind")
	check(shrimp.flee_cooldown >= 0.9 and shrimp.swim_speed < 3, "Bait pace and recovery are calmer than the previous pass")
	shrimp.queue_free()

func check_retained_motion_regressions() -> void:
	reset()
	fish.external_input = true
	fish.position = Vector3(0, 1.5, 10)
	fish.heading = Vector3(0, -0.3, -1).normalized()
	var floor_start = fish.position
	await dash(60, fish.heading)
	check(fish.position.z < floor_start.z - 6.0 and fish.velocity.length() > 4.0, "Floor strike skims forward and keeps exit momentum")
	reset()
	fish.position = Vector3(0, 31, 0)
	fish.heading = Vector3(0, 0.8, -0.6)
	var air_food = bait(BaitMotion.Kind.MULLET, Vector3(0, 34.2, -2.4))
	air_food.set_physics_process(false)
	var food_before_air = fish.feeding.food
	await dash(60, fish.heading)
	check(fish.feeding.food == food_before_air + 3 and fish.position.y > 32, "Breaching fish strike eats airborne mullet")
	var straight = bait(BaitMotion.Kind.MINNOW, Vector3(0, 12, 0))
	straight.start_flee(1, Vector3.FORWARD)
	var max_side = 0.0
	for i in range(25):
		await frames(1)
		max_side = maxf(max_side, absf(straight.position.x))
	check(straight.position.z < -2 and max_side < 0.45, "Minnow darts forward with bounded wiggle instead of turning sideways")
	var rod = BaitMotion.PlayerLiveDriver.new()
	rod.use_anchor = true
	rod.anchor_position = Vector3(0, 32, -60)
	rod.steering = 1
	var bounded_live = true
	for i in range(1000):
		var intent = rod.sample(straight, 0.016)
		var bearing = BaitMotion.horizontal(rod.anchor_position - straight.position)
		bounded_live = bounded_live and intent.direction.dot(bearing) >= cos(deg_to_rad(45.1))
	check(bounded_live, "Live bait steering stays within rod deflection limit on release")
	straight.queue_free()
	fish.velocity = Vector3(22, 22, -10)
	fish.limit_breach_velocity()
	check(Vector2(fish.velocity.x, fish.velocity.z).length() <= 8.01 and fish.velocity.y <= 9.51, "Player breach velocity is capped horizontally and vertically")
	var bird = Seagull.new()
	bird.minimum_eater_scale = 0
	bird.position = Vector3(0, 33, 0)
	get_parent().add_child(bird)
	bird.phase = 2
	bird.remaining = 6.0
	await frames(120)
	check(absf(bird.position.y - 32.15) < 0.3, "Gull can settle onto the surface")
	check(absf(bird.visual.rotation.x) < 0.05, "Resting gull stays upright")
	var surface_mullet = bait(BaitMotion.Kind.MULLET, Vector3(2, 31, 0))
	bird.phase = 0
	bird.scan_clock = 0
	await frames(2)
	check(bird.prey != null and bird.prey.get_ref() == surface_mullet and bird.phase == 1, "Gull aims a swoop at nearby surface mullet")
	surface_mullet.position = Vector3(40, 31, 40)
	var diving = BaitMotion.LiveBaitDriver.new(surface_mullet.position, 18)
	diving._mullet_dive_wait = 0
	surface_mullet.driver = diving
	await frames(180)
	check(surface_mullet.position.y < 27, "Mullet occasionally dives away from surface")
	surface_mullet.queue_free()
	var before_bird = fish.feeding.food
	check(bird.try_bite(fish) and fish.feeding.food == before_bird + 5, "Seagull uses ordinary catch and nutrition gate")
	bird.queue_free()
	var minnow = bait(BaitMotion.Kind.MINNOW, Vector3(80,12,30))
	minnow.set_physics_process(false)
	var sequence = BaitMotion.LiveBaitDriver.new(minnow.position, 51)
	sequence.minnow_sequence_chance = 1
	sequence._charging_escape = true
	sequence._random_charge = 0.5
	sequence._escape_clock = 0
	var first = sequence.sample(minnow, 0.016)
	minnow.heading = first.direction
	var second = sequence.sample(minnow, sequence._escape_clock + 0.01)
	check(first.flee_fraction >= 0.35 and first.flee_fraction <= 0.6 and is_equal_approx(first.flee_fraction, second.flee_fraction), "AI minnow can schedule a paired half-strength escape")
	check(absf(first.direction.dot(second.direction)) < 0.01 and first.direction.z < -0.7 and second.direction.z < -0.7, "Minnow pair alternates 45 degrees each side of a stable forward bearing")
	var buffering = BaitMotion.PlayerLiveDriver.new()
	minnow.flee_recovery = 0.4
	buffering.escape_held = true
	buffering.sample(minnow, minnow.flee_charge_time * 0.5)
	buffering.escape_held = false
	var waiting = buffering.sample(minnow, 0.016)
	minnow.flee_recovery = 0
	var queued = buffering.sample(minnow, 0.016)
	var consumed = buffering.sample(minnow, 0.016)
	check(waiting.flee_fraction < 0 and is_equal_approx(queued.flee_fraction, 0.5) and consumed.flee_fraction < 0, "A player follow-up released during recovery is buffered and fires once")
	minnow.queue_free()
	var feedback = SurfaceFeedback.new()
	feedback.water_height = 1000
	feedback.max_effects = 3
	get_parent().add_child(feedback)
	feedback.set_physics_process(false)
	var crossing = bait(BaitMotion.Kind.MULLET, Vector3(0, 999, 0))
	crossing.set_physics_process(false)
	feedback._physics_process(0.016)
	crossing.position.y = 1001
	feedback._physics_process(0.016)
	check(feedback.effects.size() == 1, "Crossing the surface creates a splash and ripple")
	crossing.position.y = 1000.02
	feedback._physics_process(0.016)
	check(feedback.effects.size() == 1, "Small waterline fluctuations do not repeat splashes")
	for i in range(8): feedback.emit_crossing(Vector3.ZERO, 6)
	check(feedback.effects.size() == 3, "Simultaneous water effects stay bounded")
	feedback._physics_process(1.5)
	check(feedback.effects.is_empty() and feedback.pool.size() == 3, "Splash effects expire and return to their reusable pool")
	crossing.queue_free()
	feedback.queue_free()

func check_density_and_hunting() -> void:
	reset()
	var school = BaitSchool.new()
	school.seed_value = 77
	get_parent().add_child(school)
	check(school.get_child_count() == 0, "Initial bait is queued, not built on the first frame")
	while not school._initial_queue.is_empty(): school._process(0.11)
	var bottom_entries = 0
	var sizes = {}
	for actor in school.get_children():
		sizes[snappedf(actor.body_size,0.01)] = true
		if actor.kind in [BaitMotion.Kind.SHRIMP,BaitMotion.Kind.CRAB] and actor.position.y > 30 and actor.velocity.y < 0: bottom_entries += 1
	check(bottom_entries < 20 and sizes.size() > 10, "Initial bottom bait is spread through the column and sizes vary")
	school.queue_free()
	await frames(2)
	var minnow = bait(BaitMotion.Kind.MINNOW,Vector3(80,16,0))
	var driver = BaitMotion.LiveBaitDriver.new(minnow.position,72)
	driver.pause_clock = 0
	driver._sense_time = 10
	var paused = driver.sample(minnow,0.016)
	check(driver.pause_remaining >= 0.5 and driver.pause_remaining <= 1.5 and paused.action == BaitMotion.Action.GLIDE, "AI hands-off pause lasts 0.5-1.5 seconds and uses player glide")
	driver._threat = true
	driver.sample(minnow,0.016)
	check(driver.pause_remaining == 0, "Danger interrupts an idle pause")
	minnow.queue_free()
	var controller = LureTestController.new()
	get_parent().add_child(controller)
	controller.setup(fish,get_parent(),Vector3(0,31,0))
	controller.set_active(true)
	controller.lure.position = controller.anchor_position-Vector3.UP*0.65
	Input.action_press("forward")
	controller._physics_process(0.016)
	Input.action_release("forward")
	check(controller.boat_aiming and not is_instance_valid(controller.lure), "Reeling to the boat automatically enters cast setup")
	controller.set_active(false)
	controller.boat.queue_free()
	controller.bait_camera.queue_free()
	controller.queue_free()
	var mullet = bait(BaitMotion.Kind.MULLET,Vector3(70,30,0))
	mullet.set_physics_process(false)
	var bird = Seagull.new()
	bird.minimum_eater_scale = 0
	bird.position = Vector3(70,30.4,0)
	get_parent().add_child(bird)
	bird.set_physics_process(false)
	bird.prey = weakref(mullet)
	bird.phase = 1
	bird.remaining = 5
	bird.catch_chance = 1
	bird.alarm_sent = true
	var before = fish.feeding.food
	bird._physics_process(0.016)
	check(mullet.claimed and fish.feeding.food == before and bird.phase == 3, "Bird contact can catch mullet without awarding player food and then climbs")
	var jumper = bait(BaitMotion.Kind.MULLET,Vector3(70,34,0))
	jumper.set_physics_process(false)
	jumper.airborne = true
	bird.prey = weakref(jumper)
	bird.phase = 1
	bird._physics_process(0.016)
	check(bird.phase == 3 and not jumper.claimed, "Jumping mullet breaks off the bird dive")
	jumper.queue_free()
	bird.queue_free()

func check_round_pacing() -> void:
	reset()
	var prey = bait(BaitMotion.Kind.MINNOW,Vector3(80,16,0))
	prey.set_physics_process(false)
	var ai = BaitMotion.LiveBaitDriver.new(prey.position,67)
	ai._sense_time = 10
	ai._threat = true
	ai._threat_direction = Vector3.RIGHT
	ai.minnow_sequence_chance = 0
	var escape = ai.sample(prey,0.016)
	check(escape.direction.dot(prey.heading) > 0.99, "Side threats do not make bait turn away from its travel axis")
	ai._threat_direction = -prey.heading
	var oncoming = ai.sample(prey,0.016)
	check(oncoming.direction.dot(prey.heading) >= cos(deg_to_rad(45)) and oncoming.direction.dot(prey.heading) < 0.99, "Head-on threats use a bounded turn instead of reversing")
	prey.queue_free()
	var mullet = bait(BaitMotion.Kind.MULLET,Vector3(80,31.8,0))
	mullet.set_physics_process(false)
	var three = true
	for i in range(3):
		mullet.airborne = false
		mullet._breaching = false
		mullet.flee_recovery = 0
		three = three and mullet.start_flee(0.7,Vector3.FORWARD)
	mullet.airborne = true
	mullet.velocity = Vector3.DOWN*2
	mullet._physics_process(0.016)
	check(three and mullet.jump_chain == 3 and mullet.forced_dive_remaining > 0 and not mullet.start_flee(1,Vector3.FORWARD), "Third mullet landing forces a dive and rejects another jump")
	mullet.driver.command = BaitMotion.gliding(Vector3.FORWARD)
	mullet.set_physics_process(true)
	await frames(280)
	check(mullet.position.y < 27 and mullet.jump_chain == 0, "Jump chain resets only after a sustained deep retreat")
	mullet.queue_free()
	var saved = fish.feeding.food
	fish.feeding.food = 0
	var crab = bait(BaitMotion.Kind.CRAB,Vector3(80,2,0))
	crab.minimum_eater_scale = 0.72
	check(not crab.try_bite(fish) and not crab.claimed, "Starting fish cannot eat size-gated crab")
	fish.feeding.food = 50
	check(crab.try_bite(fish), "Accumulated round growth unlocks crab")
	var bird = bait(BaitMotion.Kind.GULL,Vector3(80,35,0))
	bird.minimum_eater_scale = 1.05
	check(not bird.try_bite(fish), "Bird remains gated beyond early crab unlock")
	fish.feeding.food = 100
	check(bird.try_bite(fish), "Later round growth unlocks birds")
	fish.feeding.food = saved
	fish.update_growth_collision()

func check_optimization_contracts() -> void:
	var left = bait(BaitMotion.Kind.MINNOW,Vector3(7.9,16,70))
	var right = bait(BaitMotion.Kind.MINNOW,Vector3(8.1,16,70))
	var distant = bait(BaitMotion.Kind.MINNOW,Vector3(80,16,70))
	left.set_physics_process(false)
	right.set_physics_process(false)
	distant.set_physics_process(false)
	right.flee_remaining = 1
	distant.flee_remaining = 1
	var lookup = BaitNeighborhood.new()
	var near = lookup.nearby_fleeing(left)
	check(right in near and not distant in near, "Spatial lookup includes escaping neighbors across cell boundaries but excludes distant bait")
	right.queue_free()
	await frames(2)
	check(lookup.nearby_fleeing(left).is_empty(), "Spatial cache tolerates prey removed between rebuilds")
	var meshes = left.visual._body.get_children().filter(func(node): return node is MeshInstance3D)
	check(meshes.size() == 1 and meshes[0].mesh.get_surface_count() == 1 and left.visual._appendages.size() > 0, "Rigid bait body is one cached draw surface while animated joints remain separate")
	var ai = BaitMotion.LiveBaitDriver.new(left.position,123)
	ai._sense_time = 10
	ai._threat = true
	ai.minnow_sequence_chance = 0
	left.driver = ai
	left._physics_process(1.0/60)
	var recovery = left.flee_recovery
	left._physics_process(1.0/60)
	check(left._ai_command.flee_fraction < 0 and left.flee_recovery < recovery, "Cached AI escape is consumed once between decision updates")
	left.queue_free()
	distant.queue_free()
