extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func _init() -> void: call_deferred("run")
func run() -> void:
	for trial in [[50,1,20],[50,0.5,10],[50,0,0],[60,0,10]]:
		var line = FightLine.new()
		line.max_drag_force = 10
		line.base_outward_capacity = 30
		line.line_out = 50
		line.step(0.1,50,0,trial[0],0,trial[1],false)
		check(is_equal_approx(line.tension,trial[2]),"Force example %s yields %.1f tension" % [trial,line.tension])
	var stationary = FightLine.new()
	stationary.line_out = 40
	for i in range(60):
		stationary.step(1.0/60,40,0,200,1,0.4,false)
		stationary.sync_distance(40,1.0/60)
	check(stationary.line_out <= 40 and stationary.payout == 0 and stationary.retrieve_efficiency == 0,"Blocked over-retrieve never deploys line")
	var moving = FightLine.new()
	moving.line_out = 40
	moving.step(1,40,2,150,0,0.5,false)
	moving.sync_distance(42,1)
	check(is_equal_approx(moving.line_out,42) and is_equal_approx(moving.payout,2),"Two metres of real separation deploys two metres")
	var full = FightLine.new()
	full.line_out = 40
	full.step(0.1,40,0,500,0,1,false)
	var free = FightLine.new()
	free.line_out = 40
	free.step(0.1,40,0,500,0,0,false)
	check(free.tension < full.tension and free.payout_speed_limit > full.payout_speed_limit,"Looser drag lowers load and raises finite speed capacity")
	var recover = FightLine.new()
	recover.line_out = 40
	recover.step(0.1,40,0,20,1,0.5,false)
	recover.sync_distance(40,0.1)
	check(recover.actual_recovery > 0 and recover.actual_recovery < recover.requested_retrieve and recover.payout == 0 and recover.line_rate < 0,"Useful recovery and failed retrieve remain separate")
	var seen = {"distance":18,"tension":20,"condition":1,"payout":0,"outward_speed":0,"requested_retrieve":4.5,"actual_recovery":0.5,"retrieve_efficiency":0.11}
	var plan = FisherControls.plan(seen,80)
	check(plan.retrieve < 0.2 and not plan.power,"AI backs off ineffective cranking")
	seen.retrieve_efficiency = 1
	seen.requested_retrieve = 1
	seen.actual_recovery = 1
	plan = FisherControls.plan(seen,80)
	check(plan.retrieve > 1.0/4.5 and plan.drag > 0.4,"AI probes faster useful recovery and applies finish pressure")
	seen.payout = 4
	seen.outward_speed = 5
	seen.line_rate = 4
	check(FisherControls.plan(seen,80).retrieve <= 0.15,"Hard run stops useless high retrieve")
	for axis in [Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
		# Godot Vector2.UP is negative Y; rod UP is positive Y.
		var direction = Vector2(0,1) if axis == Vector2.UP else axis
		var gesture = RodGesture.new()
		gesture.step(0.01,Vector2.ZERO,true)
		check(gesture.step(0.1,direction*0.4,true) != RodGesture.Direction.NONE,"Compact intentional %s flick registers" % direction)
	var slow = RodGesture.new()
	var unintended = false
	for i in range(120): unintended = unintended or slow.step(1.0/60,Vector2(0,i/120.0),true) != RodGesture.Direction.NONE
	check(not unintended,"Slow pump is not a jerk")
	var ascent = FishFightMotion.new()
	var up = FishInput.new(1,0,1,Vector3.UP,true)
	ascent.step(0.2,up,Vector3.UP,1,100,false,1,1,2)
	var initial = ascent.ascent_power
	for i in range(5): ascent.step(0.2,up,Vector3.UP,0,100,false,1 if i%2 else -1,1,0)
	check(ascent.ascent_power > initial and ascent.ascent_power > 0.8,"Ascent retains and builds effort through temporary zero vertical speed")
	ascent.track_jump(0.016,true,0.1,8)
	var launch = ascent.jump_launch_power
	ascent.ascent_power = 0
	ascent.track_jump(0.1,true,1,2)
	check(launch > 0.8 and ascent.jump_launch_power == launch and ascent.jump_severity > 0,"Breach retains launch power independently of airborne ascent reset")
	var view = FishingPresentation.edge_camera(Vector3.ZERO,Vector3.FORWARD)
	var target = FishingPresentation.boat_view_target(Vector3.ZERO,Vector3.FORWARD,Vector3.DOWN,Vector3.DOWN*30)
	check((target-view).normalized().dot(Vector3.DOWN) < sin(deg_to_rad(55)),"Under-boat Fish cannot tip main camera vertically down")
	var fish = FishPlayer.new()
	var fisher = FisherActor.new()
	var f = FightSession.new()
	f.fish = fish
	f.fisher = fisher
	fish.motion.powered_active = true
	fish.motion.run_build = 1
	fish.motion.overdrive = 0.3
	for heading in [Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
		var expected = RodGesture.Direction.UP if heading == Vector3.FORWARD else RodGesture.Direction.RIGHT if heading == Vector3.LEFT else RodGesture.Direction.LEFT
		check(f.required_jerk(heading,Vector3.FORWARD,Vector3.RIGHT) == expected,"Overdrive counter follows actual direction %s" % heading)
	fish.motion.diving = true
	check(f.required_jerk(Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT) == RodGesture.Direction.UP,"Powered Dive has one UP rule")
	f.apply_counter_recovery("DIVE",0.7,Vector3.UP,0)
	check(f.last_counter.maneuver == "DIVE" and f.last_counter.overdrive_powered and not fish.motion.diving and fish.motion.overdrive == 0,"Single Dive recovery records intensity and interrupts both outputs")
	f.update_rod(0.016)
	check(f.rod_vertical < 0 and f.rod_horizontal == 0,"Pre-hook rod starts low and centered")
	check(f.hook_snap_weight(0.02) == 0 and f.hook_snap_weight(0.15) > 0 and f.hook_snap_weight(0.24) > 0.9,"Hook snap has anticipation and continuous upward stroke")
	var points = FishingPresentation.visual_path(Vector3(0,5,10),Vector3.ZERO,0,Vector3.FORWARD,1)
	check(points[-1] == Vector3.ZERO and points[-2].z < 0,"Curved line exits forward from exact mouth")
	f.free()
	fish.free()
	fisher.free()
	var audio = ReelDragAudio.new()
	root.add_child(audio)
	audio.update_reel_cues(0.016,4,0.2,FightSession.Phase.IMPACT,true)
	check(audio.strain.playing and audio.hook_whiss.playing and not audio.sustain.playing,"Slip and hook cues use separate voices without drag scream")
	audio.update_reel_cues(0.4,0,1,FightSession.Phase.IMPACT,true)
	check(not audio.hook_whiss.playing,"Hook whiss is a bounded one-shot")
	audio.update_reel_cues(0.1,4,0.1,-1,false)
	check(not audio.strain.playing,"Leaving audible view silences strain")
	audio.queue_free()
	await process_frame
	quit(1 if failures else 0)
