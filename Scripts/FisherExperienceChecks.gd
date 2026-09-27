extends SceneTree
var failures: int = 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = Node3D.new()
	root.add_child(world)
	var fish = load("res://Scenes/FishPlayer.tscn").instantiate() as FishPlayer
	world.add_child(fish)
	fish.set_physics_process(false)
	var bait = BaitActor.new()
	bait.position = fish.position+fish.heading*4
	world.add_child(bait)
	bait.set_physics_process(false)
	var other = BaitActor.new()
	other.position = fish.position+Vector3.RIGHT*7
	world.add_child(other)
	other.set_physics_process(false)
	var food = FishFoodInterest.new()
	food.rng.seed = 17
	var intent = food.input(fish,[bait,other],132,32,0.016)
	check(food.state == FishFoodInterest.State.NOTICE and not intent.bite_held,"Natural prey enters delayed NOTICE rather than instant bite")
	for i in range(100): intent = food.input(fish,[bait,other],132,32,0.016)
	check(food.target == bait and intent.bite_held,"AI selects nearby live prey and reaches legal bite commitment")
	fish.feeding.grace_remaining = 0.1
	check(fish.feeding.sweep_bite(fish.position,bait.position) == 1 and bait.claimed,"Existing feeding sweep eats selected live ecosystem bait")
	other.claimed = true
	check(food.choose(fish,[bait,other]) == null,"Claimed/multiple candidates are safely filtered")
	var owner = FisherActor.new()
	var lure = BaitActor.new()
	lure.fisher_owner = owner
	lure.minimum_eater_scale = 0
	lure.position = fish.position+Vector3.RIGHT*5
	food.disengage()
	check(not food.eligible(lure,fish),"Post-fight reset ignores new lure without disabling natural prey")
	food.lure_reset = 0
	var approach = food.input(fish,[lure],132,32,0.016)
	check(food.state == FishFoodInterest.State.NOTICE and not approach.bite_held,"Lure has the same local awareness delay")
	food.set_lure_priority(true)
	lure.position = fish.position+fish.heading*80
	check(food.choose(fish,[lure]) == lure,"Test priority reaches lure beyond natural awareness radius")
	lure.position = fish.position+fish.heading*10
	lure.velocity = fish.heading.cross(Vector3.UP)*4
	var lead = food.intercept_direction(fish,lure,0.8)
	check(lead.dot(lure.velocity.normalized()) > 0.2,"Feeding aim leads lateral target through charge and travel")
	lure.velocity = Vector3.ZERO
	food.target = lure
	food.state = FishFoodInterest.State.COMMIT
	food.charge_goal = 0.75
	fish.feeding.is_charging = true
	fish.feeding._charge_time = fish.full_charge_time*0.3
	var charge = food.input(fish,[lure],132,32,0.016)
	check(charge.bite_held and not charge.cancel_bite and charge.throttle >= 0.65,"Charge continues beyond old quarter-power release")
	fish.feeding._charge_time = fish.full_charge_time*0.8
	charge = food.input(fish,[lure],132,32,0.016)
	check(not charge.bite_held and not charge.cancel_bite,"Aligned charged attack releases")
	fish.feeding.cancel_attack()
	lure.position = fish.position+fish.heading.cross(Vector3.UP)*3
	food.state = FishFoodInterest.State.APPROACH
	var turn = food.input(fish,[lure],132,32,0.016)
	check(turn.throttle >= 0.65,"Imperfect alignment keeps meaningful approach propulsion")
	food.set_lure_priority(false)
	lure.position = fish.position+fish.heading*80
	check(food.choose(fish,[lure]) == null,"Toggle off restores natural awareness limit")
	var driver = FightTestDriver.new()
	driver.execution_rng.seed = 17
	driver.fisher_was_fighting = true
	var first = driver.fisher_input(owner,0.016)
	var delay = driver.recast_wait
	check(delay >= 5.98 and delay <= 9 and first.cast_serial == 0,"AI recast pause %.2f simulated seconds" % delay)
	for i in range(int(delay/0.1)): driver.fisher_input(owner,0.1)
	check(driver.cast_serial == 0,"No early cast during pause")
	driver.fisher_input(owner,0.2)
	check(driver.cast_serial == 1,"AI casts after pause expires")
	var points = FishingPresentation.visual_path(Vector3(0,0,10),Vector3(0,0,-1.25),0)
	check(points[-1].is_equal_approx(Vector3(0,0,-1.25)) and points.size() > 17,"Smooth mouth attachment without angular flank corners")
	var gear = FishingPresentation.new()
	world.add_child(gear)
	var cam = Camera3D.new()
	world.add_child(cam)
	gear.update_view(0.1,cam,Vector3.ZERO,Vector3.FORWARD,Vector3.FORWARD*3,Vector3.FORWARD*10,null,0,-2,0,2,true,false)
	var slow = gear.crank.rotation.x
	check(gear.travel < 0 and gear.spool.rotation.x > 0,"Retrieve pattern travels rodward and spool winds inward")
	gear.update_view(0.1,cam,Vector3.ZERO,Vector3.FORWARD,Vector3.FORWARD*3,Vector3.FORWARD*10,null,0,8,8,7,true,false)
	check(gear.travel > 0 and gear.spool.rotation.x < 0 and gear.crank.rotation.x-slow > slow,"Payout reverses spool/stripes; stronger retrieve cranks faster")
	check(gear.audio.sustain.stream != null and not gear.audio.sustain.playing,"Bundled drag recording stays silent without audible payout")
	lure.free()
	owner.free()
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
