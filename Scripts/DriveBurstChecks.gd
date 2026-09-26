extends SceneTree
var failures: int = 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures += 1
func _init() -> void:
	var m = FishFightMotion.new()
	for i in range(12): m.step(0.48,FishInput.new(1),Vector3.FORWARD,1,100,false,1 if i%2 == 0 else -1,1,0,false)
	check(m.swim_drive > 0.9 and m.drive_gained > 0.7,"Rhythm builds Drive outside a FightSession")
	m.step(1.0/60,FishInput.new(1,0,0,Vector3.FORWARD,true),Vector3.FORWARD,1,100,false)
	check(m.drive_burst_time > 0 and m.swim_drive >= 0.1 and m.swim_drive <= 0.3 and m.stamina_cost == 0,"Normal burst spends most Drive, no direct stamina: remaining %.3f" % m.swim_drive)
	var od = FishFightMotion.new()
	od.swim_drive = 1
	od.last_side = -1
	od.stroke_age = 0.15
	od.boost_was_held = true
	od.step(0.05,FishInput.new(1,0,0,Vector3.FORWARD,true),Vector3.FORWARD,1,100,false,1)
	check(od.overdrive > 0 and od.drive_spent >= 0.65 and od.stamina_cost >= 12,"Deliberate fast sprint cadence spends Drive plus stamina for Overdrive")
	var f = FightSession.new()
	var fish = FishPlayer.new()
	var fisher = FisherActor.new()
	var session = NetworkSession.new()
	fisher.session = session
	f.fish = fish
	f.fisher = fisher
	f.phase = FightSession.Phase.FIGHT
	fish.motion = od
	f.power_active = true
	f.power_age = 0.5
	f.update_power_punish(0.016)
	check(f.power_recovery > 1 and not f.power_active,"New Overdrive interrupts already-committed Power")
	f.power_recovery = 0
	f.seen_overdrive = 0
	f.power_active = false
	f.update_power_punish(0.016)
	f.power_active = true
	f.power_age = 0.5
	f.update_power_punish(0.016)
	check(f.power_recovery == 0,"Overdrive first cannot retroactively punish later Power")
	var straight = FishFightMotion.opposition_cost(Vector3.FORWARD,Vector3.FORWARD,1)
	var diagonal = FishFightMotion.opposition_cost(Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(60)),Vector3.FORWARD,1)
	check(straight > diagonal and is_equal_approx(straight,2) and is_equal_approx(diagonal,1.25),"Equal powered duration costs more against radial line: %.2f vs %.2f" % [straight,diagonal])
	var tap = FishFightMotion.new()
	tap.swim_drive = 1
	tap.run_build = 1
	tap.steer_burst(1.0/60,FishInput.new(1,1,0,Vector3.RIGHT,true),Vector3.FORWARD,true)
	tap.steer_burst(1.0/60,FishInput.new(1,0,0,Vector3.FORWARD,true),Vector3.FORWARD,true)
	check(tap.side_time == 0,"One-frame side intent does not commit")
	for side in [-1,1]:
		var motion = FishFightMotion.new()
		motion.swim_drive = 1
		motion.run_build = 1
		var head = FishSteering.new()
		var heading = Vector3.FORWARD
		var velocity = heading*10
		var position = Vector3.ZERO
		var detected = false
		var peak = 0.0
		for i in range(72):
			var held = i < 25
			var aim = FightTestDriver.side_burst_aim(Vector3.FORWARD,side) if held else heading
			var input = FishInput.new(1,side if held else 0,0,aim,held)
			input = motion.steer_burst(1.0/60,input,heading,true,Vector3.FORWARD)
			heading = head.step(1.0/60,heading,input,velocity.length())
			velocity = FishInput.next_velocity(velocity,heading,input,10,1.3,0.5,30,20,3,1,1.0/60)
			position += velocity/60
			motion.measure_side(1.0/60,heading,velocity)
			detected = detected or motion.side_event == side
			peak = maxf(peak,velocity.x*side)
		check(detected and position.x*side > 3 and peak > 6,"Committed side %d: lateral displacement %.2f m, peak %.2f m/s" % [side,position.x,peak])
	var turn = FishFightMotion.new()
	turn.measure_side(1,Vector3.RIGHT,Vector3.RIGHT*12)
	check(turn.side_event == 0,"Ordinary lateral swim cannot emit a burst event")
	fish.free()
	fisher.free()
	f.free()
	session.free()
	quit(1 if failures else 0)
