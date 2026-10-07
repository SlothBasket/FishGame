extends SceneTree
# One deterministic pass; no fight batch/movie. Run with -- --multi-actor --seed=17.
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	for side in [-1.0,1.0]:
		var course = Vector3.RIGHT*side
		assert(is_equal_approx(FightContest.held_leverage(course,Vector3.FORWARD,Vector3.RIGHT,-side,0),1))
		assert(is_equal_approx(FightContest.held_leverage(course,Vector3.FORWARD,Vector3.RIGHT,side,0),-1))
		assert(is_equal_approx(FightContest.held_leverage(course,Vector3.FORWARD,Vector3.RIGHT,-side*0.5,0),0.5))
	assert(FightContest.held_leverage(Vector3.FORWARD,Vector3.FORWARD,Vector3.RIGHT,0,1) == 1)
	assert(FightContest.held_leverage(Vector3.FORWARD,Vector3.FORWARD,Vector3.RIGHT,0,-1) == -1)
	assert(FightContest.held_leverage(Vector3.FORWARD,Vector3.FORWARD,Vector3.RIGHT,0,1,0) == 0)
	assert(FightContest.held_leverage(Vector3(1,0,-1),Vector3.FORWARD,Vector3.RIGHT,-1,1) == 1)
	var tensions: Array[float] = []
	var payout: Array[float] = []
	for leverage in [-1,0,1]:
		var line = FightLine.new()
		line.line_out = 20
		line.step(0.1,20,5,100*FightForceUnits.SCALE,0,0.6,false,0,0,0,leverage)
		tensions.append(line.tension)
		# Same applied load/mass, outward acceleration determined only by actual tension.
		var speed = 5+FightForceUnits.acceleration(100*FightForceUnits.SCALE-line.tension,3.2)*0.1
		line.sync_distance(20+speed*0.1,0.1)
		payout.append(line.payout)
		assert(line.condition < 1)
		line.step(0.1,23,10,600*FightForceUnits.SCALE,1,1,true,400*FightForceUnits.SCALE,0,0,leverage)
		assert(line.break_hazard() > 0)
	assert(tensions[0] < tensions[1] and tensions[1] < tensions[2])
	assert(payout[0] > payout[1] and payout[1] > payout[2])
	var path = FishingPresentation.visual_path(Vector3(0,0,15),Vector3(0,0,-1),0,Vector3.FORWARD,1)
	for point in path:
		assert(absf(point.x) <= 0.061) # Tiny local bend, no body-routing loop.
	assert(FishingPresentation.tension_color(0) == Color.WHITE)
	assert(absf(FishingPresentation.tension_color(0.699).g-FishingPresentation.tension_color(0.701).g) < 0.01)
	var rules = RoundColorRules.new(); rules.configure(17)
	var same = RoundColorRules.new(); same.configure(17)
	assert(rules.speeds == same.speeds)
	same.configure(18); assert(rules.speeds != same.speeds)
	var sorted = rules.speeds.duplicate(); sorted.sort()
	assert(sorted == [0.88,0.92,0.96,1.0,1.04,1.08,1.12])
	rules.set_absent(BaitColors.Tag.BLUE)
	var gold = 0
	for i in range(5000):
		var tag = rules.choose_natural()
		assert(tag != BaitColors.Tag.BLUE)
		if tag == BaitColors.Tag.GOLD: gold += 1
	assert(gold > 30 and gold < 130)
	var world = load("res://Scenes/Reef.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	freeze(world)
	var session: NetworkSession = world.network_session
	world.color_rules.set_absent(BaitColors.Tag.BLUE)
	var animals: Array[BaitActor] = []
	for kind in range(5):
		var actor = session.school._spawn(kind,Vector3(0,20,0),19+kind,20)
		actor.set_physics_process(false)
		assert(actor.color_tag != BaitColors.Tag.BLUE)
		animals.append(actor)
	var base = animals[0].base_color_tag
	var old_id = animals[0].get_instance_id()
	var old_mesh = body_mesh(animals[0])
	var fisher: FisherActor = session.players[-2].entity
	fisher.return_to_setup()
	fisher.command.color_tag = BaitColors.Tag.BLUE
	fisher.cast()
	assert(fisher.lure.color_tag == BaitColors.Tag.BLUE)
	world.color_rules.force_natural(BaitColors.Tag.GOLD)
	for actor in animals:
		assert(actor.color_tag == BaitColors.Tag.GOLD and actor.color_speed == world.color_rules.speed(BaitColors.Tag.GOLD))
	assert(fisher.lure.color_tag == BaitColors.Tag.BLUE)
	assert(animals[0].get_instance_id() == old_id)
	world.color_rules.force_natural(-1)
	assert(animals[0].color_tag == base)
	assert(body_mesh(animals[0]) == old_mesh)
	var first = body_mesh(animals[0])
	fisher.lure.visual.set_color(BaitColors.Tag.PINK)
	assert(body_mesh(animals[0]) == first)
	fisher.lure.refresh_color()
	var intent = FisherIntent.new(); intent.color_tag = BaitColors.Tag.GOLD
	assert(FisherIntent.decode(intent.numbers(),intent.flags()).color_tag == BaitColors.Tag.GOLD)
	# Exercise actual snapshot decoding, including a late-created replica.
	var data = session.bait_state(9000,animals[0]); data.append(0); data.append(0)
	var source: FishPlayer = session.players[-1].entity
	var remote: FishPlayer = session.players[-3].entity
	source.fight_active = true; source.fight_rod_tip = Vector3(2,42,4); source.fight_tension_ratio = 0.9
	var fish_data = session.fish_state(source)
	assert(fish_data.size() == 55 and data.size() == 23)
	session.hosting = false
	session.bait_event(0,9000,animals[0].kind,animals[0].body_size,data)
	assert(session.baits[9000].color_tag == animals[0].color_tag)
	session.fish_snapshot(-3,fish_data)
	assert(remote.fight_tension_ratio == fish_data[54] and remote.fight_rod_tip == source.fight_rod_tip)
	source.camera.make_current()
	for child in remote.get_children():
		if child is FishFightReferences:
			child._process(0.2)
			assert(child.visible and child.material.albedo_color != Color.WHITE)
	var replica_rules = RoundColorRules.new(); replica_rules.apply_state(world.color_rules.state())
	assert(replica_rules.speeds == world.color_rules.speeds and replica_rules.absent_color == BaitColors.Tag.BLUE)
	session.hosting = true
	print("PASS leverage/color: continuous resistance, physical tension/payout/wear/break, flare, gradient, seeded palette, rare Gold=",gold,"/5000, absence, force/restore, cache isolation, Fisher selection and snapshot/remote line roundtrip.")
	quit()
func freeze(node: Node) -> void:
	node.set_physics_process(false); node.set_process(false)
	for child in node.get_children(): freeze(child)

func body_mesh(actor: BaitActor) -> Mesh:
	for child in actor.visual._body.get_children():
		if child is MeshInstance3D: return child.mesh
	return null
