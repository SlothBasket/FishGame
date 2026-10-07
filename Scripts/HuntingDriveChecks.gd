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
	fish.motion.swim_drive = 0.8
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
	print("PASS hunting Drive: low reserve/poor aim/short approach rejected; committed ",ticks," ticks; budget, cooldown and feeding handoff work.")
	fish.queue_free(); bait.queue_free(); await process_frame
	quit()
