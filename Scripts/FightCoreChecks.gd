class_name FightCoreChecks
extends RefCounted
## Bounded deterministic contracts, called once by the existing two-peer fight smoke.
static func run(fight: FightSession) -> bool:
	var ok = true
	var line = FightLine.new()
	line.line_out = 40
	line.step(0.1,32,-8,0,0,0.4,false)
	ok = verify(is_equal_approx(line.line_out,40) and line.slack > 7.9,"Inward swim preserves spool line and creates slack") and ok
	line.step(0.1,32,0,0,1,0.4,false)
	ok = verify(line.line_out < 40 and line.line_rate < 0,"Retrieve recovers slack continuously") and ok
	line.line_out = 40
	for i in range(12): line.step(0.05,40+(i+1)*0.3,6,60,0,0.4,false)
	ok = verify(line.line_out > 40 and line.payout > 0 and line.tension < line.drag_threshold*1.1,"Normal drag pays out and limits sustained tension") and ok
	var before = line.line_out
	for i in range(6): line.step(0.05,45,8,80,1,0.4,true)
	ok = verify(line.line_out < before and line.payout == 0 and line.tension > line.drag_threshold,"Power recovers line above drag without payout") and ok
	ok = verify(line.condition < 1,"Loaded power/reversal wears line") and ok
	var cruise = FightLine.new()
	cruise.line_out = 40
	cruise.step(0.1,40,0,35,0.5,0.4,false)
	ok = verify(is_equal_approx(cruise.drag_threshold,44) and not cruise.slipping and cruise.line_rate < 0 and cruise.requested_load > 35,"40% drag = 44; reel pressure gains line without fish payout") and ok
	cruise.step(0.1,40,0,35,1,0.4,false)
	ok = verify(not cruise.slipping and cruise.requested_load > 44 and cruise.line_rate < 0,"Hard retrieve may reach drag without falsely classifying fish-driven slip") and ok
	cruise.step(0.1,41,6,60,0,0.4,false)
	ok = verify(cruise.slipping and cruise.payout > 0,"Sprint output takes line") and ok
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
