extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var fish = load("res://Scenes/FishPlayer.tscn").instantiate()
	root.add_child(fish); fish.set_physics_process(false)
	var bait = BaitActor.new(); bait.position = Vector3(0,0,-40)
	root.add_child(bait); bait.set_physics_process(false)
	var driver = FishFoodInterest.new()
	driver.target = bait; driver.state = FishFoodInterest.State.APPROACH
	fish.motion.swim_drive = 0.25
	assert(not driver.hunting_overdrive(fish,40,1,0.016))
	fish.motion.swim_drive = 1
	bait.velocity = Vector3.FORWARD*20
	assert(not driver.hunting_overdrive(fish,40,0.5,0.016))
	assert(not driver.hunting_overdrive(fish,18,1,0.016))
	var ticks = 0
	while driver.hunting_overdrive(fish,40,1,1.0/60):
		var intent = FishInput.new(1); intent.overdrive = true
		fish.motion.step(1.0/60,intent,fish.heading,1,100,false,0,1,0,false)
		ticks += 1
		assert(ticks < 90)
	assert(ticks >= 40 and fish.motion.drive_spent >= driver.hunting_drive_budget)
	fish.motion.swim_drive = 1
	assert(not driver.hunting_overdrive(fish,40,1,0.016)) # Cooldown blocks immediate restart.
	driver.hunting_drive_wait = 0
	assert(driver.hunting_overdrive(fish,40,1,0.016))
	assert(not driver.hunting_overdrive(fish,13,1,0.016))
	driver.hunting_drive_wait = 0
	assert(driver.hunting_overdrive(fish,40,1,0.016))
	driver.state = FishFoodInterest.State.COMMIT
	assert(not driver.hunting_overdrive(fish,40,1,0.016))
	# Pursuit cannot abort an already released dash when prey is alongside.
	fish.feeding._dash_remaining = 5
	bait.position = Vector3.RIGHT
	var during_dash = driver.input(fish,[bait],200,100,0.016)
	assert(not during_dash.cancel_bite)
	fish.feeding.update_attack(during_dash,0.016)
	assert(fish.feeding.is_dashing())
	# Full maximum stamina adds strength, with a steeply diminishing bonus.
	fish.endurance = fish.stamina_capacity
	var full = fish.force_capacity()
	fish.endurance = fish.stamina_capacity*0.5
	var half = fish.force_capacity()
	var original_bonus = fish.fresh_force_bonus
	fish.fresh_force_bonus = 0
	assert(is_equal_approx(half-fish.force_capacity(),original_bonus/16))
	fish.fresh_force_bonus = original_bonus
	assert(full > 2.3 and half < 0.7)
	var pilot = FightTestDriver.new()
	pilot.update_closeout(25)
	assert(pilot.closeout_escape and not pilot.closeout_sprint(25,-0.3,100,true))
	assert(pilot.closeout_sprint(25,-0.3,10,false))
	assert(pilot.closeout_sprint(12,0,10,true))
	pilot.update_closeout(33); assert(pilot.closeout_escape)
	pilot.update_closeout(40); assert(not pilot.closeout_escape)
	print("PASS restored hunting Drive; active dash protected; committed chase ",ticks," ticks; endurance bonus and closeout escalation.")
	fish.queue_free(); bait.queue_free(); await process_frame
	quit()
