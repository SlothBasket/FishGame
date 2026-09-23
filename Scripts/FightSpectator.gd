class_name FightSpectator
extends Node3D
## Development observer only. Never submits intent or changes participant transforms.
var session: NetworkSession
var mode: int = 2
var camera: Camera3D
var debug: Label
var yaw: float = 0
var pitch: float = -0.3
func _ready() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,48,85)
	camera.rotation = Vector3(pitch,yaw,0)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer = CanvasLayer.new()
	add_child(layer)
	debug = Label.new()
	layer.add_child(debug)
	debug.position = Vector2(24,24)
	debug.add_theme_font_size_override("font_size",18)
	debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			mode = event.keycode-KEY_1
			if mode == 2:
				pitch = camera.rotation.x
				yaw = camera.rotation.y
	if event is InputEventMouseMotion and mode == 2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x*0.003
		pitch = clampf(pitch-event.relative.y*0.003,-1.4,1.4)
func _process(delta: float) -> void:
	if not session.players.has(-1) or not session.players.has(-2): return
	var fish: FishPlayer = session.players[-1].entity
	var fisher: FisherActor = session.players[-2].entity
	var fight = fisher.fight
	if mode == 2:
		camera.rotation = Vector3(pitch,yaw,0)
		var move = Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position += (camera.basis*move+Vector3.UP*(float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))))*20*delta
	else:
		var forward = BaitMotion.horizontal(fish.position-fisher.position)
		var target = fish.position if is_instance_valid(fight) or mode == 1 else fisher.lure.position if is_instance_valid(fisher.lure) else fisher.position+forward*10
		var desired = fisher.position+Vector3.UP*3-forward*5 if mode == 0 else fish.position-fish.heading*9+Vector3.UP*2
		camera.position = camera.position.lerp(desired,1-exp(-delta*5))
		if camera.position.distance_to(target) > 0.1: camera.look_at(target,Vector3.UP)
	debug.text = "AI vs AI — OBSERVER ONLY\n1 Fisher | 2 Fish | 3 Overview (WASD, Q/E, RMB look)\nView: %s | Participants: %d\nDrive %.0f%% %s | Stamina %.0f / %.0f" % [["Fisher","Fish","Overview"][mode],session.players.size(),fish.motion.swim_drive*100,"OVERDRIVE" if fish.motion.overdrive > 0 else "",fish.stamina,fish.endurance]
	if is_instance_valid(fight):
		debug.text += "\nFish: %s | Fisher: %s\n%s | Line %.1f / %.0f m | Tension %.1f | Drag %.0f%%" % [FightDecisions.fish_text(fight.fish_action),FightDecisions.fisher_text(fight.fisher_action),FightSession.Phase.keys()[fight.phase],fight.spool.line_out,fight.spool.maximum_line_out,fight.tension,fisher.drag_setting*100]
		debug.text += "\nLINE CONDITION: %.1f%% | DAMAGE -%.3f%%/s\nVision: %s | Perception age %.2fs | Resistance %.1f | Turn shock %.1f" % [fight.spool.condition*100,fight.line_damage_rate*100,"ON" if fisher.vision_active else "OFF",fight.perception.age(),fight.directional_load,fight.turn_shock]
	else: debug.text += "\n%s | Last result: %s" % [FisherActor.State.keys()[fisher.state],FightSession.Outcome.keys()[fisher.outcome]]
