extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures += 1
func _init() -> void:
 var fish = FishPlayer.new()
 fish.feeding = FishFeeding.new(fish)
 check(fish.stamina == 130 and fish.endurance == 130,"Fresh stamina and endurance start at 130")
 for e in [130,100,75,50,25]:
  fish.endurance = e
  print("CAPACITY endurance=",e," force=",fish.force_capacity()," fatigue=",fish.fatigue_multiplier())
  check(is_equal_approx(fish.force_capacity(),pow(e/100.0,1.1 if e > 100 else 0.8)),"Fixed 100 force reference at %s" % e)
 fish.endurance = 130
 fish.fatigue(1)
 check(fish.endurance < 128.6 and fish.endurance > 128.4 and fish.stamina <= fish.endurance,"Fresh exertion burns faster and caps stamina")
 var kept = fish.endurance
 fish.fatigue(0)
 check(fish.endurance == kept,"No exertion means no endurance loss")
 fish.motion.power_capacity = 1
 fish.motion.swim_drive = 1
 check(is_equal_approx(fish.motion.stored_force_multiplier(),1.35),"Full Drive adds 35% force")
 fish.motion.swim_drive = 0.5
 check(is_equal_approx(fish.motion.stored_force_multiplier(),1.0875),"Half Drive adds 8.75%, rewarding the top of the bar")
 fish.motion.side_time = 1
 fish.motion.side_quality = 1
 check(is_equal_approx(fish.motion.side_force_multiplier(),1.5),"Committed side receives 50% force efficiency")
 fish.motion.interrupt_run()
 check(fish.motion.side_force_multiplier() == 1,"Counter removes side advantage")
 var results: Array[Dictionary] = []
 for drag in [0.35,0.5,0.7,1.0]:
  var result = trial(130,drag,false)
  results.append(result)
  print("FRESH drag=",drag," ",result)
 check(results[1].distance > 30.5,"Healthy powered swimming pulls working drag")
 check(results[2].distance < results[1].distance and results[3].distance < results[2].distance,"Higher drag increasingly restricts the same run")
 check(results[3].tension > results[1].tension and results[3].tension > 93.5,"Maximum drag puts fresh runs into line-risk territory")
 var tired = trial(25,1,false)
 print("TIRED max drag ",tired)
 check(tired.distance < results[3].distance and tired.distance <= 30,"Tired fish contained at maximum drag")
 var side = trial(130,0.5,true)
 print("SIDE working drag ",side)
 check(side.distance >= 30 and side.lateral > 2,"Uncountered quality side gains ground through force")
 fish.free()
 quit(1 if failures else 0)
func trial(endurance: float, drag: float, side: bool) -> Dictionary:
 var fish = FishPlayer.new()
 fish.feeding = FishFeeding.new(fish)
 var fight = FightSession.new()
 fish.fight = fight
 fight.fish = fish
 fish.endurance = endurance
 fish.stamina = endurance
 fish.motion.swim_drive = 1
 var line = FightLine.new()
 line.line_out = 30
 var offset = Vector3.FORWARD*30
 var velocity = Vector3.ZERO
 var max_tension = 0.0
 for i in range(120):
  var axis = offset.normalized()
  var heading = axis.rotated(Vector3.UP,deg_to_rad(55)) if side else axis
  var input = FishInput.new(1,0,0,heading,true)
  var stroke = 1 if int(i/22)%2 == 0 else -1
  fish.motion.step(1.0/60,input,heading,velocity.length()/8,endurance,false,stroke,fish.power_capacity())
  fish.motion.side_time = 1 if side else 0
  fish.motion.side_quality = 1 if side else 0
  var load = fight.propulsion_force(maxf(0,heading.dot(axis)),3.2)
  line.step(1.0/60,offset.length(),velocity.dot(axis),load,1,drag,false)
  velocity = FishInput.next_velocity(velocity,heading,input,fish.effective_swim_speed()*fish.motion.multiplier(),fish.fight_boost_multiplier(),0.4,12*fish.motion.multiplier()*fish.motion.stored_force_multiplier()*fish.fight_force_multiplier(),6,4,0.7,1.0/60)
  velocity += fight.controlled_force(-axis*line.tension/3.2)/60
  velocity = line.rod_pull_velocity(offset,velocity,1.0/60,7)
  var displacement = line.constrain_motion(offset,velocity/60)
  offset += displacement
  velocity = displacement*60
  line.sync_distance(offset.length(),1.0/60)
  max_tension = maxf(max_tension,line.tension)
 var result = {"distance":offset.length(),"lateral":absf(offset.x),"tension":max_tension,"line_out":line.line_out}
 fish.free()
 fight.free()
 return result
