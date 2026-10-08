extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("verify")
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func verify() -> void:
	var line = FightLine.new()
	check(line.strength == 220 and line.max_drag_force == 220 and line.elasticity == 44,"Rebased force defaults")
	check(is_equal_approx(58.43/44,(58.43*FightForceUnits.SCALE)/(44*FightForceUnits.SCALE)),"Baseline load/hold ratio preserved")
	check(is_equal_approx(FightForceUnits.acceleration(132,3.2),66/3.2),"World acceleration conversion")
	var risks: Array[float] = []
	for ratio in [0.6,0.8,1.0,1.2]:
		line.tension = line.break_threshold()*ratio
		risks.append(line.break_hazard())
	check(risks[0] == 0 and risks[1] == 0 and risks[2] > risks[1] and risks[3] > risks[2]*10,"Conservative warning and overload risk")
	line.tension = 175
	var fresh = line.break_hazard()
	line.condition = 0.75
	check(line.break_hazard() > fresh,"Worn line danger shifts earlier")
	var spike_risks: Array[float] = []
	for prior_ratio in [0.3,0.8]:
		var spike = FightLine.new()
		spike.line_out = 20
		spike._previous_load = spike.break_threshold()*prior_ratio
		spike._previous_fish_load = 300
		spike.step(0.1,20,2,300,0,0.8,false,60)
		spike_risks.append(spike.break_hazard())
	check(spike_risks[1] > spike_risks[0],"Preloaded spike is riskier than unloaded spike")
	var hook = HookRisk.new()
	for i in range(60): hook.step(0.016,0.5,1,false,0,false)
	check(hook.hazard == 0 and hook.looseness == 1,"Headshake and tiny slack cannot throw")
	for i in range(60): hook.step(0.016,1.5,1,false,0,false,-2,4)
	check(hook.hazard == 0,"Active catchup protection")
	for i in range(10): hook.step(0.016,4,1,false,0,false)
	check(hook.hazard == 0,"Slack persistence grace")
	for i in range(30): hook.step(0.016,4,1,false,0,false)
	check(hook.hazard > 0 and hook.hazard < 0.02,"Sustained loose line modest hazard")
	var jumping = HookRisk.new(); var shaking = HookRisk.new()
	jumping.step(0.1,0,0,true,1,false); shaking.step(0.1,0,1,true,1,false)
	check(jumping.hazard > 0 and jumping.hazard == shaking.hazard,"Airborne risk retained, no headshake multiplier")
	var fish = load("res://Scenes/FishPlayer.tscn").instantiate()
	root.add_child(fish)
	fish.set_physics_process(false)
	fish.position = Vector3.ZERO
	fish.heading = Vector3.FORWARD
	fish.visual.rotation = Vector3.ZERO
	var a = fish.fight_mouth_position(Vector3.RIGHT)
	var b = fish.fight_mouth_position(Vector3.LEFT)
	check(a.x > 0 and b.x < 0 and is_equal_approx(a.z,b.z),"Mirrored local mouth corners")
	fish.fight_mouth_position(Vector3.BACK)
	check(fish.fight_mouth_side == -1,"Ambiguous behind direction retains side")
	var path = FishingPresentation.visual_path(Vector3(0,0,30),b,30,fish.heading,fish.size_multiplier(),-1)
	check(path.size() == 10 and path[-1].distance_to(b) < 0.001,"One straight main span and tiny curve")
	for point in path.slice(1): check(point.distance_to(b) <= 0.46*fish.size_multiplier(),"Local curve length bounded independently of slack/span")
	var fight = FightSession.new(); fight.fish = fish
	fish.endurance = 100; fish.motion.power_capacity = 1
	fish.feeding.food = 0
	fish.motion.swim_drive = 0
	fish.motion.propulsion = 1
	var small = fight.propulsion_force(1,3.2)
	check(is_equal_approx(small/(line.max_drag_force*0.4),(38.4/44)*fish.force_capacity()),"Baseline load includes remaining maximum-stamina strength")
	fish.feeding.food = 100000
	var large = fight.propulsion_force(1,3.2*1.35)
	check(is_equal_approx(large/small,1.45),"Largest Fish 1.45x sustained load")
	fish.feeding.food = 0
	fish.motion.swim_drive = 1
	fish.motion.propulsion = 1.22*1.75
	var stored = fight.propulsion_force(1,3.2)
	check(is_equal_approx(stored/small,1.75),"Full stored Drive 75 percent direct force")
	fish.motion.overdrive = 0.35
	fish.motion.propulsion = 1.57*1.75
	var overdrive = fight.propulsion_force(1,3.2)
	fight.overdrive_load_time = fight.overdrive_load_duration
	var pulse = fight.propulsion_force(1,3.2)
	check(overdrive > stored and is_equal_approx(pulse/overdrive,1.25),"Overdrive sustained and short pulse load")
	var fisher = FisherActor.new()
	var session = NetworkSession.new()
	var arena = load("res://Scripts/Reef.gd").new()
	session.world = arena; fisher.session = session; fight.fisher = fisher
	fisher.position = Vector3(0,0,30)
	fight.phase = FightSession.Phase.FIGHT
	fight.tension = 150; fight.spool.slack = 0
	fight.rod_horizontal = -1; fight.rod_vertical = 0
	fish.motion.swim_drive = 0.7
	var pilot = FightTestDriver.new()
	check(pilot.tension_opportunity(fish,fight),"Felt high tension enables Drive commitment")
	var choice = pilot.choose_tension_angle(fish,fight)
	check(choice.x < 0 and choice.z < 0,"Fish exploits yielding side with outward travel")
	fight.spool.condition = 0.1
	check(pilot.tension_opportunity(fish,fight),"AI opportunity does not read hidden condition")
	fish.motion.counter_recovery = 1
	check(not pilot.tension_opportunity(fish,fight),"Counter recovery prevents attack")
	fish.motion.counter_recovery = 0
	fisher.free(); session.free(); arena.free()
	var observer = FishingPresentation.new(); root.add_child(observer)
	fish.fight_active = true
	fish.fight_rod_tip = Vector3(2,0,20)
	observer.update_view(0.016,fish.camera,Vector3.ZERO,Vector3.FORWARD,fish.fight_rod_tip,fish.position,fish,0,0,0,0,true,false)
	check(not observer.line.visible,"Equipment line hidden when Fish reference renderer owns view")
	print("CORRECTION CHECKS risks=",risks," preloaded spikes=",spike_risks," loads small/large/stored/OD/pulse=",[small,large,stored,overdrive,pulse]," failures=",failures)
	fight.free()
	if "--mouth-preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(960,540)
		var sun = DirectionalLight3D.new(); root.add_child(sun); sun.rotation_degrees = Vector3(-40,-30,0)
		var camera = Camera3D.new(); root.add_child(camera)
		camera.position = Vector3(1.7,0.75,-2)
		camera.look_at(Vector3(0,0,-0.35),Vector3.UP)
		fish.camera = camera; camera.make_current()
		fish.fight_rod_tip = Vector3(2,0.2,6)
		fish.fight_tension_ratio = 0.65
		await process_frame; await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../../work/mouth-correction.png")
	observer.queue_free(); fish.queue_free()
	await process_frame
	quit(1 if failures else 0)
