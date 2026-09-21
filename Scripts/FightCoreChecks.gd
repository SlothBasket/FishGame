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
