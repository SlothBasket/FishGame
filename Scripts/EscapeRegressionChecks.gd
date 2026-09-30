extends SceneTree
class TestFish extends FishPlayer:
 func _ready() -> void: pass
 func _physics_process(_delta: float) -> void: pass
var failures: int = 0
func check(ok: bool, label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures += 1
func _init() -> void: call_deferred("run")
func run() -> void:
 var fish = load("res://Scenes/FishPlayer.tscn").instantiate()
 fish.set_script(TestFish)
 fish.feeding = FishFeeding.new(fish)
 fish.set_process(false)
 root.add_child(fish)
 var fisher = FisherActor.new()
 var fight = FightSession.new()
 fight.fish = fish
 fight.fisher = fisher
 fish.fight = fight
 var p = Vector3(30,-20,40)
 check(FightDecisions.escape_distance(p,Vector3.ZERO) == 50 and FightDecisions.escape_distance(p+Vector3.DOWN*100,Vector3.ZERO) == 50,"Depth cannot increase escape ground")
 fish.position = p
 for action in [FightDecisions.FishAction.RUN,FightDecisions.FishAction.REST]:
  check(is_zero_approx(FightDecisions.heading_for(fight,action).y),"RUN/REST remain horizontal at depth")
 check(FightDecisions.heading_for(fight,FightDecisions.FishAction.DIVE).y < -0.5 and FightDecisions.heading_for(fight,FightDecisions.FishAction.JUMP).y > 0.5,"Explicit Dive and Jump keep their vertical aim")
 var pilot = FightTestDriver.new()
 fish.motion.swim_drive = 0
 var intent = pilot.avoid_bottom(FishInput.new(1,0,0,Vector3.DOWN,true),fish,1)
 check(intent.aim_direction.y > 0.5 and intent.vertical == 1 and not intent.boost,"Zero-Drive bottom recovery uses upward basic swimming")
 pilot.avoid_bottom(FishInput.new(),fish,4)
 check(pilot.bottom_recovery,"Bottom recovery holds until sufficient clearance")
 pilot.avoid_bottom(FishInput.new(),fish,5)
 check(not pilot.bottom_recovery,"Ordinary control resumes after clearing bottom")
 var floor = StaticBody3D.new()
 var shape = CollisionShape3D.new()
 shape.shape = BoxShape3D.new()
 shape.shape.size = Vector3(20,1,20)
 floor.add_child(shape)
 floor.position = Vector3(0,9.5,0)
 root.add_child(floor)
 fish.position = Vector3(0,12,0)
 await physics_frame
 await physics_frame
 check(absf(FightDecisions.bottom_clearance(fish)-2) < 0.01,"Terrain probe sees raised floor rather than world-zero floor")
 fish.motion.diving = true
 fish.motion.run_age = 0
 check(FightDecisions.fish_choice(fight,FightDecisions.FishAction.DIVE) != FightDecisions.FishAction.DIVE,"Near-floor selection cannot continue or start Dive")
 var seen = {"distance":30,"tension":44,"break_threshold":93.5,"condition":1,"outward_speed":4,"payout":3,"line_rate":2,"drag":0.4,"line_out":30,"capacity":150}
 pilot = FightTestDriver.new()
 var plan = pilot.persist_settings(FisherControls.plan(seen,80),seen,0.016)
 check(plan.drag >= 0.5,"30m run escapes ignored 40-to-45-percent drag request")
 plan = pilot.persist_settings(FisherControls.plan(seen,80),seen,3)
 check(plan.drag >= 0.59,"Persistent close run builds 60-percent pressure")
 seen.distance = 15
 plan = pilot.persist_settings(FisherControls.plan(seen,80),seen,3)
 check(plan.drag >= 0.64,"Final close-pressure step to 65-percent is not discarded")
 seen.tension = 100
 plan = pilot.persist_settings(FisherControls.plan(seen,80),seen,0.016)
 check(plan.drag < 0.65,"Danger immediately reduces stopping pressure")
 seen.tension = 30
 seen.outward_speed = 0
 seen.payout = 0
 seen.line_rate = -1
 plan = FisherControls.plan(seen,80)
 check(plan.retrieve > 0.15,"Useful retrieve resumes when the run stops")
 fish.fight = null
 fish.queue_free()
 floor.queue_free()
 fight.free()
 fisher.free()
 quit(1 if failures else 0)

