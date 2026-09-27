class_name FightCoreChecks
extends RefCounted
## Bounded deterministic contracts, called once by the existing two-peer fight smoke.
static func run(fight: FightSession) -> bool:
	var ok = true
	var rhythm = FishFightMotion.new()
	var mouse = FishFightMotion.new()
	var both = FishFightMotion.new()
	for i in range(12):
		var stroke = FishInput.new(1,1 if i%2 == 0 else -1)
		rhythm.step(0.48,stroke,Vector3.FORWARD,1,100,false,stroke.steering)
		stroke.stroke_axis = stroke.steering
		both.step(0.48,stroke,Vector3.FORWARD,1,100,false,stroke.steering)
		stroke.steering = 0
		mouse.step(0.48,stroke,Vector3.FORWARD,1,100,false,stroke.stroke_axis)
	ok = verify(rhythm.swim_drive > 0.9 and is_equal_approx(mouse.swim_drive,rhythm.swim_drive) and is_equal_approx(both.swim_drive,rhythm.swim_drive),"Ideal keyboard/mouse cadence sustains the same non-stacking Drive") and ok
	var stored = rhythm.swim_drive
	for i in range(3): rhythm.step(0.16,FishInput.new(1,1 if i%2 == 0 else -1,0,Vector3.FORWARD,true),Vector3.FORWARD,1,100,false,1 if i%2 == 0 else -1)
	ok = verify(rhythm.overdrive > 0 and rhythm.overdrive <= rhythm.overdrive_max and rhythm.swim_drive < stored,"Fast cadence gives bounded overdrive and consumes stored Drive") and ok
	var run = FishFightMotion.new()
	run.step(0.1,FishInput.new(1,0,0,Vector3.FORWARD,true),Vector3.FORWARD,1,100,false,1)
	ok = verify(run.run_build > 0 and run.run_build < 0.3,"Sprint builds rather than switching instantly") and ok
	var right = Vector3.RIGHT
	var aligned = FightContest.evaluate(Vector3.LEFT,Vector3.FORWARD,right,-1,0)
	var opposed = FightContest.evaluate(Vector3.LEFT,Vector3.FORWARD,right,1,0)
	ok = verify(aligned.x > 0.9 and aligned.y == 0 and opposed.y > 0.9 and FightContest.best_move(-1,0) == FightContest.Move.LEFT and FightContest.best_counter(Vector3.LEFT,right,false,false) == FightContest.Counter.RIGHT,"Coaching and forces agree on same-side defense / opposite counter") and ok
	var dive = FishFightMotion.new()
	var dive_input = FishInput.new(1,0,-1,Vector3.DOWN,true)
	dive.step(0.4,dive_input,Vector3.DOWN,1,100,false)
	ok = verify(dive.diving and dive.dive_power < dive.dive_counter_window,"Dive commitment has an early counter window") and ok
	dive.interrupt_dive()
	ok = verify(not dive.diving and dive.dive_blocked,"Early counter interrupts until a fresh sprint") and ok
	dive.dive_blocked = false
	dive.step(0.4,dive_input,Vector3.DOWN,1,100,false)
	dive.step(0.5,dive_input,Vector3.DOWN,1,100,false)
	ok = verify(dive.dive_power > dive.dive_counter_window and FightContest.best_counter(Vector3.DOWN,right,true,true) == FightContest.Counter.LET_RUN,"Committed dive coaching changes to let drag work") and ok
	dive.step(0.1,dive_input,Vector3.DOWN,1,100,true)
	ok = verify(not dive.diving,"Bottom contact ends dive") and ok
	# Detailed spool force/efficiency cases live in ReelCorrectionChecks.
	var line = FightLine.new()
	line.line_out = 40
	line.step(0.1,32,-8,0,0,0.4,false)
	line.sync_distance(32,0.1)
	ok = verify(is_equal_approx(line.line_out,40) and line.slack > 7.9,"Inward swim preserves deployed line and creates slack") and ok
	line.step(0.1,32,0,0,1,0.4,false)
	line.sync_distance(32,0.1)
	ok = verify(line.actual_recovery > 0 and line.line_rate < 0,"Retrieve recovers actual slack") and ok
	line.line_out = 40
	line.step(1,40,2,100,1,0.4,false)
	line.sync_distance(42,1)
	ok = verify(is_equal_approx(line.payout,2) and is_equal_approx(line.line_out,42),"Only measured two-metre outward motion pays out") and ok
	line.step(0.1,42,0,100,1,0.4,false)
	line.sync_distance(42,0.1)
	ok = verify(line.payout == 0 and line.actual_recovery == 0,"Failed retrieve cannot create payout") and ok
	var spooled = FightSession.new()
	spooled.spool = FightLine.new()
	spooled.spool.line_out = spooled.spool.maximum_line_out-0.01
	spooled.spool.fish_load = 100
	spooled.spool.step(0.2,spooled.spool.line_out,8,100,0,0.2,false)
	spooled.spool.sync_distance(spooled.spool.maximum_line_out+1,0.2)
	ok = verify(spooled.spool.line_out == spooled.spool.maximum_line_out and spooled.check_spooled() and spooled.phase == FightSession.Phase.FINISHED,"Capacity clamps payout and spool-out ends encounter") and ok
	if fight.fisher.session.fisher_view != null:
		ok = verify(fight.fisher.session.fisher_view.layout_fits(),"Fight HUD inside viewport, hook centered, network text separate") and ok
	var tether = FightLine.new()
	tether.line_out = 5
	tether.step(0.016,50,0,0,1,0.4,true)
	ok = verify(is_equal_approx(tether.line_out,5),"Impossible stored span is not silently converted into extra deployed line") and ok
	var legal = tether.constrain_motion(Vector3(50,0,0),Vector3(1,0.1,0))
	ok = verify((Vector3(50,0,0)+legal).length() <= 50.001 and legal.x > -0.01,"Taut guard limits outward motion without an inward teleport") and ok
	tether.step(1,50,0,0,1,0.4,true)
	ok = verify(tether.line_out >= 5,"Blocked Power cannot shorten an already overextended span") and ok
	var force = fight.controlled_force(Vector3(100,100,100))
	ok = verify(force.length() <= fight.maximum_line_acceleration+0.001 and force.y <= fight.maximum_vertical_acceleration,"Line acceleration and upward pressure are bounded") and ok
	var old_position = fight.fish.position
	var old_line = fight.line_length
	var old_slack = fight.spool.slack
	fight.fish.position = fight.fisher.position+Vector3(1,-2,0)
	fight.line_length = 3
	fight.spool.slack = 0
	ok = verify(fight.landing_ready(),"Fish physically in boat landing zone qualifies") and ok
	fight.fish.position += Vector3(30,0,0)
	ok = verify(not fight.landing_ready(),"Short numerical line cannot land a distant fish") and ok
	fight.fish.position = old_position
	fight.line_length = old_line
	fight.spool.slack = old_slack
	var risk = FightLine.new()
	risk.tension = 86
	var fresh_threshold = risk.break_threshold()
	var fresh_hazard = risk.break_hazard()
	risk.condition = 0.45
	ok = verify(risk.break_threshold() < fresh_threshold and risk.break_hazard() > fresh_hazard,"Damaged line lowers threshold and increases hazard") and ok
	var brief_hazard = risk.break_hazard()
	risk.high_load_exposure = 4
	ok = verify(risk.break_hazard() > brief_hazard,"Sustained exposure compounds break hazard") and ok
	risk.line_out = 40
	risk.step(0.1,30,0,0,0,0.4,false)
	ok = verify(risk.high_load_exposure < 4,"Safe pressure decays exposure") and ok
	var old_endurance = fight.fish.endurance
	var old_stamina = fight.fish.stamina
	fight.fish.fatigue(1000)
	ok = verify(is_equal_approx(fight.fish.endurance,fight.fish.stamina_capacity*fight.fish.endurance_floor) and fight.fish.stamina <= fight.fish.endurance,"Fatigue caps stamina and preserves endurance floor") and ok
	fight.fish.endurance = old_endurance
	fight.fish.stamina = old_stamina
	var intent = FisherIntent.new()
	intent.retrieve = 0.437
	intent.rod_horizontal = 9
	var decoded = FisherIntent.decode(intent.numbers(),0)
	ok = verify(decoded != null and absf(decoded.retrieve-0.437) < 0.0001 and decoded.rod_horizontal == 1,"Continuous validated retrieve and bounded rod intent") and ok
	var values = intent.numbers()
	values[5] = NAN
	ok = verify(FisherIntent.decode(values,0) == null,"Nonfinite input rejected") and ok
	fight.fisher.command.rod_horizontal = 1
	fight.fisher.command.rod_vertical = 1
	fight.update_rod(2)
	var forward = BaitMotion.horizontal(fight.fish.position-fight.fisher.position)
	ok = verify(BaitMotion.horizontal(fight.rod_direction).dot(forward) > 0 and fight.rod_direction.y < sin(deg_to_rad(56)),"Rod stays forward within yaw/pitch envelope") and ok
	return ok

static func verify(condition: bool, label: String) -> bool:
	print("CORE FIGHT ","PASS " if condition else "FAIL ",label)
	return condition
