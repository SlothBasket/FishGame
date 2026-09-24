class_name FightSpectator
extends Node3D
## Development observer only. Never submits intent or changes participant transforms.
var session: NetworkSession
var mode: int = 2
var camera: Camera3D
var debug: Label
var boat: Node3D
var rod_mesh: MeshInstance3D
var line_mesh: MeshInstance3D
var art_material: StandardMaterial3D
var jerk_label: Label3D
var damage_label: Label
var yaw: float = 0
var pitch: float = -0.3
func _ready() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,48,85)
	camera.rotation = Vector3(pitch,yaw,0)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	jerk_label = Label3D.new()
	jerk_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	jerk_label.no_depth_test = true
	jerk_label.font_size = 48
	add_child(jerk_label)
	boat = Node3D.new()
	add_child(boat)
	Geometry.sphere(boat,"Hull",Vector3(0,-0.35,0),Vector3(1.8,0.7,3.4),Geometry.material("785d40"))
	Geometry.sphere(boat,"Deck",Vector3(0,0.12,0),Vector3(1.7,0.15,3.2),Geometry.material("e2c797"))
	art_material = Geometry.material("fff1b5")
	art_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rod_mesh = MeshInstance3D.new()
	rod_mesh.mesh = ImmediateMesh.new()
	add_child(rod_mesh)
	line_mesh = MeshInstance3D.new()
	line_mesh.mesh = ImmediateMesh.new()
	add_child(line_mesh)
	var layer = CanvasLayer.new()
	add_child(layer)
	debug = Label.new()
	layer.add_child(debug)
	debug.position = Vector2(24,24)
	debug.add_theme_font_size_override("font_size",18)
	debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label = Label.new()
	layer.add_child(damage_label)
	damage_label.position = Vector2(24,320)
	damage_label.add_theme_font_size_override("font_size",24)
	damage_label.modulate = Color(1,0.35,0.18)
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	boat.position = fisher.position
	boat.rotation.y = fisher.boat_yaw
	draw_equipment(fisher,fish)
	jerk_label.text = RodGesture.caption(fight.jerk_direction) if is_instance_valid(fight) and fight.jerk_notice_time > 0 else ""
	jerk_label.position = fight.rod_tip+Vector3.UP if is_instance_valid(fight) else fisher.position
	damage_label.text = "LINE DAMAGE -%.2f%%/s" % (fight.line_damage_rate*100) if is_instance_valid(fight) and fight.line_damage_rate > 0.00001 else ""
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
		debug.text += "\nREMAINING %.1f m | TAKE-UP %.1f m | REEL RECOVERY %.1f m" % [maxf(0,fight.spool.maximum_line_out-fight.spool.line_out),fight.spool.rod_take_up,fight.recovery_total]
		debug.text += "\nDIVE %.0f%% | ASCENT %.0f%% | SLACK %.2f m | HOOK %.0f%%\nHEAD %.1f° / %.1f° | SHAKE %.0f%% | STROKE %s" % [fish.motion.dive_power*100,fish.motion.ascent_power*100,fight.spool.slack,fight.hook_security*100,rad_to_deg(fish.head.offset.y),rad_to_deg(fish.head.offset.x),fish.head.shake_pressure*100,"LEFT" if fish.head.stroke_side > 0 else "RIGHT" if fish.head.stroke_side < 0 else "NEUTRAL"]
		var age = fight.perception.age()
		var perceived = "CURRENT" if age < 0.18 else "%.2fs OLD" % age
		debug.text += "\nLINE CONDITION: %.1f%%\nVISION: %s | FOCUS: %.0f%% | AI PERCEPTION: %s\nFish Skill: %.0f%% | Fisher Skill: %.0f%%" % [fight.spool.condition*100,"ON" if fisher.vision_active else "OFF",fisher.focus/fisher.focus_capacity*100,perceived,fight.fish_skill*100,fight.fisher_skill*100]
	else: debug.text += "\n%s | Last result: %s" % [FisherActor.State.keys()[fisher.state],FightSession.Outcome.keys()[fisher.outcome]]

func draw_equipment(fisher: FisherActor, fish: FishPlayer) -> void:
	var f = fisher.fight
	var hand = fisher.position+Vector3.UP*1.3
	var direction = Vector3(0,0.6,-0.8).rotated(Vector3.UP,fisher.boat_yaw)
	var tip = hand+direction*3
	var target = fisher.lure.position if is_instance_valid(fisher.lure) else tip
	var slack: float = 0
	if is_instance_valid(f):
		hand = f.rod_hand
		direction = f.rod_direction
		tip = f.rod_tip
		target = fish.position
		slack = f.spool.slack
	var control = hand+direction*2
	var rod: Array = []
	var line: Array = []
	for i in range(13):
		var t = i/12.0
		rod.append(hand*(1-t)*(1-t)+control*2*t*(1-t)+tip*t*t)
		line.append(tip.lerp(target,t)-Vector3.UP*sin(t*PI)*minf(8,slack*0.3))
	draw_ribbon(rod_mesh,rod,0.065)
	draw_ribbon(line_mesh,line,0.018)

func draw_ribbon(node: MeshInstance3D, points: Array, thickness: float) -> void:
	var mesh: ImmediateMesh = node.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,art_material)
	var width = camera.global_basis.x*thickness
	for i in range(points.size()-1):
		for point in [points[i]-width,points[i]+width,points[i+1]+width,points[i]-width,points[i+1]+width,points[i+1]-width]: mesh.surface_add_vertex(point)
	mesh.surface_end()
