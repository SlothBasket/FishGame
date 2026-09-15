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
	check(fish.position.y >= 0.64 and fish.position.y < 0.8, "Fish collides with seabed")
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
	check(fish.feeding.bait_eaten == 3 and fish.feeding.food - food_before == 6, "One dash eats all three types with correct nutrition")
	check(fish.size_multiplier() > 1, "Food grows fish")
	await frames(20)
	check(get_tree().get_nodes_in_group("bait").is_empty(), "Consumed bait leave edible set")
	reset()
	var single = bait(1, ORIGIN + Vector3.RIGHT * 4)
	food_before = fish.feeding.food
	check(single.try_bite(fish) and not single.try_bite(fish) and fish.feeding.food - food_before == 2, "Single-consumer reward gate")
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
	var population = get_tree().get_nodes_in_group("bait").size()
	get_tree().get_nodes_in_group("bait")[0].try_bite(fish)
	await frames(30)
	check(population == 72 and get_tree().get_nodes_in_group("bait").size() == population, "Expanded bait and gull population replenishes")
	# Fishing driver intent: retrieve is anchor-dominant; jerk alternates laterally;
	# jig rises; pause respects configured buoyancy; idle poses share the command.
	var lure_driver = BaitMotion.FishingBaitDriver.new(Vector3(10, 10, 0))
	lure_driver.retrieve_input = 0.8
	var mock_lure = bait(BaitMotion.Kind.JERKBAIT, Vector3.ZERO, BaitMotion.Source.FISHERMAN)
	var retrieve = lure_driver.sample(mock_lure, 1.0 / 60)
	check(retrieve.action == BaitMotion.Action.CRUISE and retrieve.direction.x > 0.9 and absf(retrieve.direction.y) < 0.01, "Retrieve uses horizontal anchor bearing regardless of rod height")
	lure_driver.retrieve_input = 0
	lure_driver.jerk_pressed = true
	var jerk_a = lure_driver.sample(mock_lure, 1.0 / 60)
	await frames(25)
	lure_driver.jerk_pressed = true
	var jerk_b = lure_driver.sample(mock_lure, 1.0 / 60)
	check(jerk_a.action == BaitMotion.Action.JERK and signf(jerk_a.direction.z) != signf(jerk_b.direction.z), "Repeated jerks alternate lateral sides")
	lure_driver.jig_pressed = true
	var jig = lure_driver.sample(mock_lure, 1.0 / 60)
	check(jig.action == BaitMotion.Action.JIG_UP and jig.effort > 0.5, "Jig command pulls sharply upward")
	lure_driver._impulse_time = 0
	lure_driver.pause_vertical_rate = -0.4
	lure_driver.idle_action = BaitMotion.IdleAction.QUIVER
	var paused = lure_driver.sample(mock_lure, 1.0 / 60)
	check(paused.action == BaitMotion.Action.GLIDE and paused.idle_action == BaitMotion.IdleAction.NONE, "Release uses shared forward glide without idle poses")
	mock_lure.queue_free()
	var crab = bait(BaitMotion.Kind.CRAB, Vector3(0, 3, 0))
	crab.driver.command = BaitMotion.BaitCommand.new(Vector3.RIGHT, 0.8, 0, BaitMotion.Action.CRAWL)
	await frames(300)
	check(crab.global_position.y < 0.6 and absf(crab.velocity.y) < 0.01 and crab.global_position.x > 0.5,
		"Crab settles on bottom and crawls laterally (position=%s velocity=%s)" % [crab.global_position, crab.velocity])
	# Check actual motor results, not just the labels on driver commands.
	var falling = bait(BaitMotion.Kind.SHRIMP, Vector3(20, 8, 0))
	falling.driver.command = BaitMotion.BaitCommand.new(Vector3.DOWN, 0.25, 0, BaitMotion.Action.FALL)
	var old_heading = falling.heading
	await frames(60)
	check(falling.heading.is_equal_approx(old_heading) and falling.velocity.y < -0.1,
		"Passive sinking preserves horizontal facing")
	check(falling.driver.command.direction == Vector3.DOWN, "Motor does not mutate reusable input commands")
	falling.queue_free()
	lure_driver.anchor_position = Vector3(0, 31, 75)
	lure_driver.cast_direction = Vector3.ZERO
	mock_lure = bait(BaitMotion.Kind.MINNOW, Vector3(0, 8, 4), BaitMotion.Source.FISHERMAN)
	lure_driver.retrieve_input = 1.0
	lure_driver._impulse_time = 0.0
	lure_driver.steer_input = -1.0
	var left_pull = lure_driver.sample(mock_lure, 0.016)
	lure_driver.steer_input = 1.0
	var right_pull = lure_driver.sample(mock_lure, 0.016)
	check(absf(left_pull.direction.y) < 0.4 and left_pull.direction.x * right_pull.direction.x < 0.0,
		"Test retrieve is mostly horizontal and steering changes its path")
	mock_lure.queue_free()
	var nearby_shrimp = 0
	var nearby_crabs = 0
	for prey in school.get_children():
		if prey is BaitActor and Vector2(prey.position.x, prey.position.z).length() < 30:
			if prey.kind == BaitMotion.Kind.SHRIMP: nearby_shrimp += 1
			if prey.kind == BaitMotion.Kind.CRAB: nearby_crabs += 1
	check(nearby_shrimp > 0 and nearby_crabs > 0, "Shrimp and crabs are present near the starting area")
	var moving_lure = bait(BaitMotion.Kind.MINNOW, Vector3(0, 12, 0), BaitMotion.Source.FISHERMAN)
	var movement_driver = BaitMotion.FishingBaitDriver.new(Vector3(0, 100, -75))
	moving_lure.driver = movement_driver
	movement_driver.retrieve_input = 1.0
	var begin = moving_lure.global_position
	await frames(120)
	var travel = moving_lure.global_position - begin
	check(-travel.z > 4.0 and travel.y > 0.3 and travel.y < -travel.z * 0.3, "Two-second retrieve travels forward with shallow rise")
	movement_driver.retrieve_input = 0.0
	begin = moving_lure.global_position
	await frames(120)
	travel = moving_lure.global_position - begin
	check(-travel.z > 1.0 and travel.y < -0.5, "Two-second release keeps forward glide and visibly sinks")
	movement_driver.jerk_pressed = true
	begin = moving_lure.global_position
	await frames(12)
	var jerk_travel = moving_lure.global_position - begin
	await frames(40)
	movement_driver.jig_pressed = true
	begin = moving_lure.global_position
	await frames(12)
	var jig_travel = moving_lure.global_position - begin
	check(absf(jerk_travel.x) > 0.3 and jig_travel.y > 0.3 and absf(jerk_travel.y) < jig_travel.y,
		"Jerk moves sideways while jig hops upward")
	moving_lure.queue_free()
	var tester = LureTestController.new()
	get_parent().add_child(tester)
	tester.setup(fish, get_parent(), Vector3(0, 31, 12))
	tester.set_active(true)
	check(tester.bait_camera.current and not fish.camera.current, "Bait mode selects its angled camera")
	var reset_consistent = true
	for index in range(6):
		tester.switch_lure()
		reset_consistent = reset_consistent and tester.lure.heading.is_equal_approx(BaitMotion.horizontal(tester.anchor_position - tester.spawn_position)) and tester.driver._impulse_time == 0.0
	check(reset_consistent, "All species switches start with the same cast bearing and cleared impulses")
	tester.toggle_camera()
	check(fish.camera.current and fish.external_input, "Fish camera can observe bait while bait controls remain active")
	tester.toggle_camera()
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(100, 30)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var old_yaw = tester.orbit_yaw
	tester.orbit_mouse(motion.relative)
	check(tester.orbit_yaw != old_yaw, "Mouse motion changes bait camera orbit")
	tester.set_active(false)
	check(fish.camera.current and not fish.external_input, "Leaving bait mode restores fish camera and controls")
	tester.lure.queue_free()
	tester.bait_camera.queue_free()
	tester.queue_free()
	var profile = bait(BaitMotion.Kind.SQUID, Vector3(0, 15, 0))
	profile.driver.command = BaitMotion.swimming(Vector3.FORWARD, 1.0)
	var profile_start = profile.position
	await frames(60)
	check(profile.position.y > profile_start.y + 1.0 and absf(profile.position.z - profile_start.z) < 0.5, "Squid retrieve is predominantly vertical")
	profile.driver.command = BaitMotion.gliding(Vector3.FORWARD)
	profile_start = profile.position
	await frames(90)
	check(profile.position.y < profile_start.y - 0.5, "Squid drops when released")
	profile.queue_free()
	profile = bait(BaitMotion.Kind.SHRIMP, Vector3(0, 0.4, 0))
	profile.driver.command = BaitMotion.BaitCommand.new(Vector3.FORWARD, 1, 1, BaitMotion.Action.JIG_UP)
	await frames(20)
	check(profile.position.y > 1.5, "Shrimp jig produces a fast vertical escape")
	profile.queue_free()
	profile = bait(BaitMotion.Kind.CRAB, Vector3(0, 5, 0))
	await frames(90)
	check(profile.position.y < 0.6, "Crab sinks quickly to bottom")
	profile.driver.command = BaitMotion.BaitCommand.new(Vector3.FORWARD, 1, 1, BaitMotion.Action.JIG_UP)
	profile_start = profile.position
	await frames(20)
	check(absf(profile.position.x - profile_start.x) > 0.7 and profile.position.y < 0.6, "Crab jig dashes sideways without lifting off")
	var bounded = BaitMotion.FishingBaitDriver.new(Vector3(0, 30, -75))
	bounded.cast_direction = Vector3.FORWARD
	bounded.steer_input = 1
	var limited = true
	for i in range(1000):
		var intent = bounded.sample(profile, 0.016)
		limited = limited and intent.direction.dot(Vector3.FORWARD) >= cos(deg_to_rad(40.1))
	check(limited, "Held glide steering stays inside the cast cone without accumulating a U-turn")
	profile.queue_free()
	# Shared escape strength, recovery and presentation regressions.
	var escape_actor = bait(BaitMotion.Kind.SHRIMP, Vector3(0, 6, 0))
	var heights: Array[float] = []
	for strength in [0.0, 0.5, 1.0]:
		escape_actor.clear_actions()
		escape_actor.position = Vector3(0, 6, 0)
		escape_actor.start_flee(strength, Vector3.UP)
		heights.append(escape_actor.flee_velocity.y)
	check(heights[0] < heights[1] and heights[1] < heights[2] and heights[2] < 5.5, "Shrimp weak/medium/full kicks vary and full kick is reduced")
	check(not escape_actor.start_flee(1.0, Vector3.UP), "Escape cooldown rejects repeated triggers")
	var player_driver = BaitMotion.PlayerLiveDriver.new()
	escape_actor.clear_actions()
	player_driver.escape_held = true
	var charging = player_driver.sample(escape_actor, 0.5)
	player_driver.escape_held = false
	var released = player_driver.sample(escape_actor, 0.016)
	check(charging.flee_fraction < 0 and is_equal_approx(released.flee_fraction, 0.5), "Hold charges without firing; release submits fractional escape")
	escape_actor.queue_free()
	escape_actor = bait(BaitMotion.Kind.CRAB, Vector3(0, 0.4, 0))
	var crab_heading = escape_actor.heading
	escape_actor.start_flee(1.0, Vector3.RIGHT)
	var crab_start = escape_actor.position
	await frames(20)
	check(escape_actor.position.x > crab_start.x + 1 and escape_actor.heading.is_equal_approx(crab_heading), "Crab escape translates laterally without rotating body")
	escape_actor.queue_free()
	escape_actor = bait(BaitMotion.Kind.SQUID, Vector3(0, 12, 0))
	escape_actor.driver.command = BaitMotion.swimming(Vector3.FORWARD, 1.0)
	await frames(45)
	check(escape_actor.visual.rotation.x > 0.7 and escape_actor.visual.rotation.z == 0, "Squid pitches up from actual velocity without roll")
	escape_actor.driver.command = BaitMotion.gliding(Vector3.FORWARD)
	escape_actor.driver.command.descend = true
	await frames(60)
	check(escape_actor.visual.rotation.x < -0.7 and escape_actor.velocity.y < -2.0, "Squid powered descent pitches downward")
	escape_actor.queue_free()
	escape_actor = bait(BaitMotion.Kind.MULLET, Vector3(0, 31.6, 0))
	escape_actor.start_flee(1.0, Vector3.FORWARD)
	var highest = escape_actor.position.y
	var saw_air = false
	for i in range(240):
		await frames(1)
		highest = maxf(highest, escape_actor.position.y)
		saw_air = saw_air or escape_actor.airborne
	check(saw_air and highest > 33 and not escape_actor.airborne and escape_actor.position.y < 32, "Mullet breaches through surface, arcs under gravity and re-enters")
	escape_actor.queue_free()
	reset()
	fish.external_input = true
	await dash(1)
	var late = bait(BaitMotion.Kind.MINNOW, fish.global_position)
	var before_late = fish.feeding.food
	await frames(2)
	check(late.claimed and fish.feeding.food == before_late + 1, "Brief post-lunge grace catches contacted bait")
	await frames(25)
	var ordinary = bait(BaitMotion.Kind.MINNOW, fish.global_position)
	await frames(1)
	check(not ordinary.claimed, "Grace expires without enabling ordinary swimming bites")
	ordinary.queue_free()
	var cast_test = LureTestController.new()
	get_parent().add_child(cast_test)
	cast_test.setup(fish, get_parent(), Vector3(0, 31, 12))
	cast_test.set_active(true)
	cast_test.move_origin(Vector3.RIGHT, 0.5)
	check(cast_test.boat.position.is_equal_approx(cast_test.anchor_position) and cast_test.driver.anchor_position.is_equal_approx(cast_test.anchor_position) and cast_test.anchor_position.y == 32,
		"Boat and lure anchor track horizontal origin movement at surface")
	cast_test.cast_bait()
	check(cast_test.lure.position.distance_to(cast_test.anchor_position) < 1 and cast_test.lure.cast_remaining > 0, "Cast starts at boat with a flight phase")
	var destination = cast_test.lure.cast_destination
	check(Vector2(destination.x, destination.z).length() < Vector2(cast_test.anchor_position.x, cast_test.anchor_position.z).length(), "Cast aims toward arena center")
	await frames(50)
	check(cast_test.lure.position.y > 34, "Cast follows an airborne arc")
	await frames(60)
	check(cast_test.lure.cast_remaining == 0 and cast_test.lure.velocity.y < 0, "Cast lands and enters downward")
	cast_test.lure.queue_free()
	cast_test._spawn_lure(BaitMotion.Kind.SQUID)
	cast_test.lure.start_flee(1, Vector3.UP)
	await frames(30)
	check(Vector2(cast_test.lure.position.x - cast_test.anchor_position.x, cast_test.lure.position.z - cast_test.anchor_position.z).length() < 0.1, "Player squid stays directly below boat during escape")
	cast_test.set_active(false)
	cast_test.lure.queue_free()
	cast_test.boat.queue_free()
	cast_test.bait_camera.queue_free()
	cast_test.queue_free()
	var threat_bait = bait(BaitMotion.Kind.MINNOW, fish.position + Vector3.RIGHT * 2)
	fish.add_to_group("fish_predators")
	var threat_driver = BaitMotion.LiveBaitDriver.new(threat_bait.position, 913)
	var observed_strengths = {}
	for i in range(20):
		threat_driver.choose_behavior(threat_bait)
		var ai_escape = threat_driver.sample(threat_bait, 0.016)
		if ai_escape.flee_fraction >= 0:
			observed_strengths[snappedf(ai_escape.flee_fraction, 0.02)] = true
	check(observed_strengths.size() > 3, "Nearby threat selects continuously varied AI escape strengths")
	threat_bait.queue_free()
	# Ambient escape timer must fire for every live species without any predator.
	fish.remove_from_group("fish_predators")
	var ambient_ok = true
	for species in [BaitMotion.Kind.MINNOW, BaitMotion.Kind.SHRIMP, BaitMotion.Kind.SQUID, BaitMotion.Kind.CRAB, BaitMotion.Kind.MULLET]:
		var ambient = bait(species, Vector3(0, 10, 0))
		ambient.set_physics_process(false)
		var ai = BaitMotion.LiveBaitDriver.new(ambient.position, 200 + species)
		var count = 0
		var fractions = {}
		for tick in range(2400):
			var cmd = ai.sample(ambient, 1.0 / 60)
			if cmd.flee_fraction >= 0:
				count += 1
				fractions[snappedf(cmd.flee_fraction, 0.01)] = true
		ambient_ok = ambient_ok and count >= 3 and fractions.size() >= 2
		ambient.queue_free()
	check(ambient_ok, "All five live species escape at random intervals and strengths without threats")
	var docked = bait(BaitMotion.Kind.JERKBAIT, Vector3(0, 27, 3))
	var dock_driver = BaitMotion.FishingBaitDriver.new(Vector3(0, 32, 0))
	dock_driver.retrieve_input = 1
	docked.driver = dock_driver
	await frames(360)
	check(Vector2(docked.position.x, docked.position.z).length() < 0.2 and docked.position.y > 30.8, "Retrieve arrives beneath boat without passing its origin")
	docked.queue_free()
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
		bounded_live = bounded_live and intent.direction.dot(bearing) >= cos(deg_to_rad(40.1))
	check(bounded_live, "Live bait steering stays within rod deflection limit on release")
	straight.queue_free()
	fish.velocity = Vector3(22, 22, -10)
	fish.limit_breach_velocity()
	check(Vector2(fish.velocity.x, fish.velocity.z).length() <= 8.01 and fish.velocity.y <= 8.01, "Player breach velocity is capped horizontally and vertically")
	var bird = Seagull.new()
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
	await check_readability_and_shared_motion()
	print("SELF-TEST COMPLETE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func check_readability_and_shared_motion() -> void:
	reset()
	var ai_shrimp = bait(BaitMotion.Kind.SHRIMP, Vector3(-60, 10, 15))
	var human_shrimp = bait(BaitMotion.Kind.SHRIMP, Vector3(-57, 10, 15))
	var ai = BaitMotion.LiveBaitDriver.new(ai_shrimp.position, 812)
	ai._charging_escape = true
	ai._escape_clock = 0
	ai._random_charge = 0.75
	ai_shrimp.driver = ai
	var human = BaitMotion.PlayerLiveDriver.new()
	human.escape_held = true
	human.sample(human_shrimp, 0.75)
	human.escape_held = false
	human_shrimp.driver = human
	await frames(14)
	check(ai_shrimp.velocity.y > 2 and ai_shrimp.visual.rotation.x < -0.7, "Shrimp kick rises with nose pointed down")
	check(ai_shrimp.velocity.z > 0, "Shrimp kick has a small backward component")
	await frames(42)
	check(ai_shrimp.velocity.z < -1.5 and absf(ai_shrimp.visual.rotation.x) < 0.15, "Shrimp transitions into a level forward glide")
	check((human_shrimp.position - ai_shrimp.position - Vector3(3,0,0)).length() < 0.01, "Matching AI and human charges produce the same shrimp trajectory")
	await frames(34)
	check(ai_shrimp.position.z < 13.5 and ai_shrimp.velocity.y < 0, "Shrimp glide advances out of its column and starts sinking")
	check(not ai_shrimp.start_flee(1, Vector3.UP), "Shrimp cannot chain another kick before glide recovery")
	ai_shrimp.queue_free()
	human_shrimp.queue_free()
	var steer_actor = bait(BaitMotion.Kind.MINNOW, Vector3(65, 12, 0))
	var intent = BaitMotion.swimming(Vector3.BACK, 1)
	var legal = ai.player_reproducible_command(steer_actor, intent, 0.016)
	check(rad_to_deg(steer_actor.heading.angle_to(legal.direction)) <= 40.01, "AI destination steering respects the player input cone")
	steer_actor.queue_free()
	var cover = RockShelter.new()
	cover.position = Vector3(84, 0, 0)
	cover.radius = 2.5
	cover.max_guests = 1
	get_parent().add_child(cover)
	var second_cover = RockShelter.new()
	second_cover.position = Vector3(84, 0, 10)
	second_cover.max_guests = 1
	get_parent().add_child(second_cover)
	var guest = bait(BaitMotion.Kind.SHRIMP, Vector3(78, 0.4, 0))
	guest.heading = Vector3.RIGHT
	var other = bait(BaitMotion.Kind.CRAB, Vector3(78, 0.4, 10))
	check(cover.reserve(guest) and not cover.reserve(other), "A shelter reserves only one bait")
	check(not second_cover.reserve(other), "Shelter reservations respect the global guest cap")
	var seeking = BaitMotion.LiveBaitDriver.new(guest.position, 81)
	seeking.shelter_enabled = true
	seeking.shelter = cover
	seeking.shelter_remaining = 16
	seeking._escape_clock = 20
	guest.driver = seeking
	var start_distance = guest.position.distance_to(cover.spot)
	await frames(120)
	check(guest.position.distance_to(cover.spot) < start_distance - 1, "Shelter bait approaches cover using the shared swimming motor")
	seeking._sense_time = 1
	seeking._threat = true
	seeking.sample(guest, 0.016)
	check(not cover.occupied() and seeking.shelter == null, "Nearby predator interrupts shelter behavior and releases occupancy")
	guest.queue_free()
	other.queue_free()
	cover.queue_free()
	second_cover.queue_free()
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
	check(feedback.effects.is_empty(), "Splash effects expire and release their nodes")
	crossing.queue_free()
	feedback.queue_free()
