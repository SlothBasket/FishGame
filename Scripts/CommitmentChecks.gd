extends SceneTree
var failures = 0
func check(ok: bool, text: String) -> void:
 print("PASS " if ok else "FAIL ",text)
 if not ok: failures += 1
func _init() -> void:
 var driver = FightTestDriver.new()
 driver.execution_rng.seed = 44
 var seen = {"distance":22,"tension":30,"break_threshold":100,"actual_recovery":0.3,"requested_retrieve":4.5,"retrieve_efficiency":0.067,"line_rate":-0.3}
 var plan = driver.persist_settings(FisherControls.plan(seen,80),seen,0.016)
 check(plan.retrieve <= 0.07,"Close-out drops wasted cranking to measured recovery")
 var saved = plan.retrieve
 seen.actual_recovery = 3
 seen.retrieve_efficiency = 1
 for i in range(60): plan = driver.persist_settings(FisherControls.plan(seen,80),seen,1.0/60)
 check(plan.retrieve == saved,"Ordinary settings held for at least one second")
 seen.slack = 3
 plan = driver.persist_settings(FisherControls.plan(seen,80),seen,0.016)
 check(plan.retrieve == 1,"Slack immediately overrides ordinary hold")
 var m = FishFightMotion.new()
 m.side_time = 1.8
 m.side_sign = 1
 m.side_frame = Vector3.FORWARD
 var heading = Vector3(0.85,0,-0.5).normalized()
 for i in range(72): m.measure_side(1.0/60,heading,heading*8,Vector3.FORWARD)
 check(m.side_reported and m.side_quality > 0.9 and m.side_lateral_displacement > 6,"Sustained side builds quality and displacement")
 m.side_time = 0.001
 m.side_visible_age = 1.6
 m.measure_side(1.0/60,heading,heading*8,Vector3.FORWARD)
 check(m.side_time > 0.001,"Counter classification follows still-visible lateral motion beyond initial window")
 for i in range(20): m.measure_side(1.0/60,Vector3.FORWARD,Vector3.FORWARD*8,Vector3.FORWARD)
 check(m.side_time == 0 and m.side_quality == 0,"Abandoned lateral course loses benefit")
 var fish = FishPlayer.new()
 var actor = FisherActor.new()
 var f = FightSession.new()
 f.fish = fish
 f.fisher = actor
 f.visible_maneuver = "RIGHT DASH"
 fish.motion.run_build = 1
 fish.motion.powered_active = true
 fish.motion.side_time = 2
 fish.motion.side_reported = true
 check(f.required_jerk(Vector3.RIGHT,Vector3.FORWARD,Vector3.RIGHT) == RodGesture.Direction.LEFT,"Right dash uses LEFT")
 check(f.required_jerk(Vector3.LEFT,Vector3.FORWARD,Vector3.RIGHT) == RodGesture.Direction.RIGHT,"Left dash uses RIGHT")
 fish.motion.run_build = 0
 fish.motion.powered_active = false
 check(f.required_jerk(Vector3.LEFT,Vector3.FORWARD,Vector3.RIGHT) == RodGesture.Direction.RIGHT,"Still-visible coast keeps its counter after powered output fades")
 fish.motion.run_build = 1
 fish.motion.powered_active = true
 fish.motion.side_time = 0
 fish.motion.overdrive = 1
 check(f.required_jerk(Vector3.FORWARD,Vector3.FORWARD,Vector3.RIGHT) == RodGesture.Direction.UP,"Straight Overdrive uses UP")
 fish.motion.diving = true
 check(f.required_jerk(Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT) == RodGesture.Direction.UP,"Powered Dive still uses only UP")
 var previous = 2.0
 for delay in [0.4,0.8,1.1,1.5]:
  f.event_clock = delay
  var strength = f.jerk_contest(RodGesture.Direction.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT,1).y
  check(strength < previous,"Reaction %.1fs has descending control %.3f" % [delay,strength])
  previous = strength
 var camera = FishingPresentation.edge_camera(Vector3.ZERO,Vector3.FORWARD)
 var target = FishingPresentation.boat_view_target(Vector3.ZERO,Vector3.FORWARD,Vector3.DOWN,Vector3.DOWN*30)
 check(absf((target-camera).normalized().y) < 0.7 and camera.y == 4,"Under-boat fish cannot cause vertical camera")
 var build = FishFightMotion.new()
 build.swim_drive = 0
 var elapsed = 0.0
 while build.swim_drive < 0.95 and elapsed < 30:
  elapsed += 1.0/60
  var stroke = 1 if int(elapsed/build.ideal_stroke_interval)%2 == 0 else -1
  build.step(1.0/60,FishInput.new(1),Vector3.FORWARD,1,100,false,stroke)
 print("Ideal full Drive rebuild seconds: ",elapsed)
 check(elapsed > 4,"Major Drive rebuild requires sustained strokes")
 var tired = FishFightMotion.new()
 tired.swim_drive = 0
 tired.last_side = 1
 tired.stroke_age = 0
 tired.step(0.016,FishInput.new(1,0,0,Vector3.FORWARD,true),Vector3.FORWARD,1,2,false,1,0.2)
 check(tired.powered_output < 0.2 and tired.drive_gained == 0,"Exhausted fallback cannot supply or rebuild full-strength power")
 f.free()
 actor.free()
 fish.free()
 quit(1 if failures else 0)
