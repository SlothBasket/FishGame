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
	await frames(400)
	check(fish.position.y <= get_parent().water_depth - 0.64 and fish.position.y > get_parent().water_depth - 0.8, "Fish stays under enlarged surface")
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
		bait(i, ORIGIN + Vector3.FORWARD * (3 + i * 3))
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
	check(population == 32 and get_tree().get_nodes_in_group("bait").size() == population, "Sparse four-species population replenishes")
	# Fishing driver intent: retrieve is anchor-dominant; jerk alternates laterally;
	# jig rises; pause respects configured buoyancy; idle poses share the command.
	var lure_driver = BaitMotion.FishingBaitDriver.new(Vector3(10, 10, 0))
	lure_driver.retrieve_input = 0.8
	var mock_lure = bait(BaitMotion.Kind.JERKBAIT, Vector3.ZERO, BaitMotion.Source.FISHERMAN)
	var retrieve = lure_driver.sample(mock_lure, 1.0 / 60)
	check(retrieve.action == BaitMotion.Action.CRUISE and retrieve.direction.x > 0.6 and retrieve.direction.y > 0.6, "Retrieve pulls toward world-space anchor")
	lure_driver.retrieve_input = 0
	lure_driver.jerk_pressed = true
	var jerk_a = lure_driver.sample(mock_lure, 1.0 / 60)
	await frames(25)
	lure_driver.jerk_pressed = true
	var jerk_b = lure_driver.sample(mock_lure, 1.0 / 60)
	check(jerk_a.action == BaitMotion.Action.JERK and signf(jerk_a.direction.z) != signf(jerk_b.direction.z), "Repeated jerks alternate lateral sides")
	lure_driver.jig_pressed = true
	var jig = lure_driver.sample(mock_lure, 1.0 / 60)
	check(jig.action == BaitMotion.Action.JIG_UP and jig.direction.y > 0.5, "Jig command pulls sharply upward")
	lure_driver._impulse_time = 0
	lure_driver.pause_vertical_rate = -0.4
	lure_driver.idle_action = BaitMotion.IdleAction.QUIVER
	var paused = lure_driver.sample(mock_lure, 1.0 / 60)
	check(paused.action == BaitMotion.Action.FALL and paused.idle_action == BaitMotion.IdleAction.QUIVER, "Pause buoyancy and player idle action use shared command")
	mock_lure.queue_free()
	var crab = bait(BaitMotion.Kind.CRAB, Vector3(0, 3, 0))
	crab.driver.command = BaitMotion.BaitCommand.new(Vector3.RIGHT, 0.8, 0, BaitMotion.Action.CRAWL)
	await frames(300)
	check(crab.global_position.y < 0.6 and absf(crab.velocity.y) < 0.01 and crab.global_position.x > 0.5,
		"Crab settles on bottom and crawls laterally (position=%s velocity=%s)" % [crab.global_position, crab.velocity])
	print("SELF-TEST COMPLETE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
