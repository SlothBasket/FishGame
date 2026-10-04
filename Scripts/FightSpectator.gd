class_name FightSpectator
extends Node3D
## Development observer only. Never submits intent or changes participant transforms.
var session: NetworkSession
# Existing keys 1/2/3 stay Fisher/Fish/free. Presets only affect this local camera.
const SHOTS = ["fisher","fish","free","wide","fish-side","fish-rear","fish-front","fish-shoulder","fish-pov","fish-high","surface-down","breach-side"]
var mode: int = 2
var snap_shot: bool = true
var director: CinematicDirector
var framed_target: Vector3 = Vector3.ZERO
var boat_transition: float = 0
var focus_peer: int = -1
var tracking_heading: Vector3 = Vector3.FORWARD
var extra_boats: Dictionary = {}
var observer_panel: Label
var shot_changed: bool = false

func focus_actor(peer: int) -> void:
	if not session.players.has(peer): return
	focus_peer = peer
	if director != null:
		director.pending.clear()
		director.shot_age = 0
		director.manual_focus_until = session.clock+15
	set_shot("fish-rear" if session.players[peer].role == NetworkSession.ROLE_FISH else "fisher",true)

func subjects() -> Array:
	var fish: FishPlayer = session.players[-1].entity
	var fisher: FisherActor = session.players[-2].entity
	if session.players.has(focus_peer):
		var actor = session.players[focus_peer].entity
		if actor is FishPlayer:
			fish = actor
			if is_instance_valid(fish.fight): fisher = fish.fight.fisher
			else:
				var best = INF
				for record in session.players.values():
					if record.entity is FisherActor and not is_instance_valid(record.entity.fight):
						var distance = fish.position.distance_squared_to(record.entity.position)
						if distance < best: best = distance; fisher = record.entity
		else:
			fisher = actor
			if is_instance_valid(fisher.fight): fish = fisher.fight.fish
			else:
				var best = INF
				for record in session.players.values():
					if record.entity is FishPlayer and not is_instance_valid(record.entity.fight):
						var distance = record.entity.position.distance_squared_to(fisher.position)
						if distance < best: best = distance; fish = record.entity
	return [fish,fisher]

func driver_for(actor: Node):
	for record in session.players.values():
		if record.entity == actor: return record.ai
	return null

func set_shot(preset: String, instant: bool = true) -> bool:
	var index = SHOTS.find(preset)
	if index < 0:
		push_warning("Unknown spectator shot: "+preset)
		return false
	var entering_boat = index == 0 and mode != 0 and is_instance_valid(camera)
	boat_transition = 3.0 if entering_boat else 0
	shot_changed = index != mode
	mode = index
	snap_shot = instant and not entering_boat
	if is_instance_valid(camera) and mode == 2:
		pitch = camera.rotation.x
		yaw = camera.rotation.y
	return true

var camera: Camera3D
var debug: Label
var boat: Node3D
var rod_mesh: MeshInstance3D
var equipment: FishingPresentation
var art_material: StandardMaterial3D
var jerk_label: Label3D
var damage_label: Label
var yaw: float = 0
var pitch: float = -0.3
func _ready() -> void:
	if session.director_mode: director = CinematicDirector.new(self,session.encounter_seed)
	equipment = FishingPresentation.new()
	add_child(equipment)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,48,85)
	camera.rotation = Vector3(pitch,yaw,0)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if session.capture_mode else Input.MOUSE_MODE_VISIBLE
	jerk_label = Label3D.new()
	jerk_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	jerk_label.no_depth_test = true
	jerk_label.font_size = 48
	add_child(jerk_label)
	jerk_label.visible = not session.capture_mode
	boat = Node3D.new()
	add_child(boat)
	Geometry.sphere(boat,"Hull",Vector3(0,-0.35,0),Vector3(1.8,0.7,3.4),Geometry.material("785d40"))
	Geometry.sphere(boat,"Deck",Vector3(0,0.12,0),Vector3(1.7,0.15,3.2),Geometry.material("e2c797"))
	art_material = Geometry.material("fff1b5")
	art_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rod_mesh = MeshInstance3D.new()
	rod_mesh.mesh = ImmediateMesh.new()
	add_child(rod_mesh)
	var layer = CanvasLayer.new()
	add_child(layer)
	layer.visible = not session.capture_mode
	debug = Label.new()
	layer.add_child(debug)
	debug.position = Vector2(24,24)
	debug.add_theme_font_size_override("font_size",18)
	debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	observer_panel = Label.new()
	layer.add_child(observer_panel)
	observer_panel.position = Vector2(1450,24)
	observer_panel.add_theme_font_size_override("font_size",19)
	observer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unfocused boats remain visible; only the selected pair needs detailed rod art.
	if session.multi_actor_mode:
		for id in [-2,-5]:
			var hull = Node3D.new()
			add_child(hull)
			Geometry.sphere(hull,"Hull",Vector3(0,-0.35,0),Vector3(1.8,0.7,3.4),Geometry.material("785d40"))
			Geometry.sphere(hull,"Deck",Vector3(0,0.12,0),Vector3(1.7,0.15,3.2),Geometry.material("e2c797"))
			extra_boats[id] = hull
	damage_label = Label.new()
	layer.add_child(damage_label)
	damage_label.position = Vector2(24,365)
	damage_label.add_theme_font_size_override("font_size",24)
	damage_label.modulate = Color(1,0.35,0.18)
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
func _unhandled_input(event: InputEvent) -> void:
	if session.multi_actor_mode and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5]:
			focus_actor([-1,-3,-4,-2,-5][event.keycode-KEY_1])
			return
		if event.keycode == KEY_6: set_shot("wide"); return
		if event.keycode == KEY_7: set_shot("free"); return
	if director != null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9]:
			set_shot(SHOTS[event.keycode-KEY_1])
		if event.keycode == KEY_0: set_shot("fish-high")
	if event is InputEventMouseMotion and mode == 2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x*0.003
		pitch = clampf(pitch-event.relative.y*0.003,-1.4,1.4)
func _process(delta: float) -> void:
	if not session.players.has(-1) or not session.players.has(-2): return
	if director != null: director.choose_subject(delta)
	var pair = subjects()
	var fish: FishPlayer = pair[0]
	var fisher: FisherActor = pair[1]
	var fight = fish.fight
	tracking_heading = FishInput.turn_toward(tracking_heading,BaitMotion.horizontal(fish.heading),delta*0.7)
	for id in extra_boats:
		extra_boats[id].position = session.players[id].entity.position
		extra_boats[id].rotation.y = session.players[id].entity.boat_yaw
		extra_boats[id].visible = session.players[id].entity != fisher
	boat_transition = maxf(0,boat_transition-delta)
	if director != null: director.update(delta,fish,fisher)
	boat.position = fisher.position
	boat.rotation.y = fisher.boat_yaw
	draw_equipment(fisher,fish,delta)
	jerk_label.text = RodGesture.caption(fight.jerk_direction) if is_instance_valid(fight) and fight.jerk_notice_time > 0 else ""
	jerk_label.position = fight.rod_tip+Vector3.UP if is_instance_valid(fight) else fisher.position
	damage_label.text = "LINE DAMAGE -%.2f%%/s" % (fight.line_damage_rate*100) if is_instance_valid(fight) and fight.line_damage_rate > 0.00001 else ""
	if mode == 2:
		camera.rotation = Vector3(pitch,yaw,0)
		var move = Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position += (camera.basis*move+Vector3.UP*(float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))))*20*delta
	else:
		var forward = Vector3.FORWARD.rotated(Vector3.UP,fisher.boat_yaw)
		var target = fish.position if is_instance_valid(fight) or mode == 1 else fisher.lure.position if is_instance_valid(fisher.lure) else fisher.position+forward*10
		var desired = FishingPresentation.edge_camera(fisher.position,forward) if mode == 0 else fish.position-tracking_heading*9+Vector3.UP*2
		var flat_heading = tracking_heading
		if mode == 3: # Frame both participants with room around their separation.
			target = fish.position
			var span = clampf(fish.position.distance_to(fisher.position),20,38)
			desired = target+Vector3(0,0.55,1.0)*span
		elif mode == 4:
			target = fish.position+fish.heading*2
			desired = fish.position+flat_heading.cross(Vector3.UP)*10-flat_heading*2+Vector3.UP*2
		elif mode == 5:
			target = fish.position+fish.heading*3
			desired = fish.position-flat_heading*13+Vector3.UP*3
		elif mode == 6:
			target = fish.position+fish.heading*2
			desired = fish.position+flat_heading*8+flat_heading.cross(Vector3.UP)*7+Vector3.UP*3
		elif mode == 7: # Close over-shoulder, above/behind the model.
			target = fish.position+flat_heading*10
			desired = fish.position-flat_heading*4*fish.size_multiplier()+flat_heading.cross(Vector3.UP)*1.5+Vector3.UP*1.5
		elif mode == 8: # Near first person, just above the nose.
			target = fish.position+flat_heading*15
			desired = fish.position+flat_heading*1.8*fish.size_multiplier()+Vector3.UP*0.7
		elif mode in [10,11]:
			var seconds = clampf((fish.water_height-fish.position.y)/maxf(2,fish.velocity.y),0,1.5)
			var breach = fish.position+fish.velocity*seconds
			breach.y = fish.water_height
			target = breach
			desired = breach+Vector3.UP*16-flat_heading*3 if mode == 10 else breach+flat_heading.cross(Vector3.UP)*14+Vector3.UP*1.8
		elif mode == 9:
			target = fish.position+flat_heading*3
			desired = fish.position-flat_heading*6+Vector3.UP*12
		var shot_fov = 60.0 if mode == 0 else 70.0
		var surface_shot = mode in [0,10,11]
		if director != null:
			var composition = director.compose(fish,fisher,target,desired)
			target = composition.target
			desired = composition.position
			shot_fov = composition.fov
			surface_shot = composition.surface
		# Large perspective changes are clean cuts, not orbiting through the subject.
		# Boat approaches from below/very far cut straight to the safe final framing.
		var look = target-desired
		var turn = (-camera.basis.z).angle_to(look.normalized()) if look.length_squared() > 0.01 else 0.0
		if shot_changed and (turn > deg_to_rad(70) or (mode == 0 and (camera.position.y < fisher.position.y+2 or camera.position.distance_to(desired) > 45))):
			snap_shot = true
			boat_transition = 0
		shot_changed = false
		var cut = snap_shot
		camera.position = desired if snap_shot else camera.position.lerp(desired,1-exp(-delta*(0.9 if boat_transition > 0 else 2.5 if director != null else 5)))
		snap_shot = false
		camera.fov = lerpf(camera.fov,shot_fov,1-exp(-delta*4))
		if mode == 0: target = FishingPresentation.boat_view_target(fisher.position,forward,fight.rod_direction if is_instance_valid(fight) else forward,target)
		if director != null:
			target = director.protect_camera(fish,fisher,target,surface_shot)
			framed_target = target if cut else framed_target.lerp(target,1-exp(-delta*4))
			target = framed_target
		if camera.position.distance_to(target) > 0.1:
			var old_rotation = camera.quaternion
			camera.look_at(target,Vector3.UP)
			if not cut:
				# Keep the old continuous retreat, but bound shortest-path rotation.
				# Continue after arrival so the last frame cannot snap to the target.
				var angle = old_rotation.angle_to(camera.quaternion)
				var blend = minf(1-exp(-delta*1.8),deg_to_rad(55)*delta/maxf(angle,0.0001))
				camera.quaternion = old_rotation.slerp(camera.quaternion,blend)
	if session.multi_actor_mode:
		observer_panel.text = "1–3 Fish | 4–5 Fishers | 6 wide | 7 free\n"
		for id in [-1,-3,-4]: observer_panel.text += "Fish %d: %.1f inches\n" % [[-1,-3,-4].find(id)+1,session.players[id].entity.length_inches()]
		for id in [-2,-5]: observer_panel.text += "Fisher %d: %.1f inches caught\n" % [[-2,-5].find(id)+1,session.players[id].entity.score_inches]
	if session.capture_mode: return # Camera/equipment keep updating; no debug work.
	debug.text = "AI vs AI — OBSERVER ONLY\n1 Fisher | 2 Fish | 3 Free (WASD, Q/E, RMB look) | 4 Wide | 5 Side | 6 Rear | 7 Front | 8 Shoulder | 9 POV | 0 High\nView: %s | Participants: %d\nDrive %.0f%% %s | Stamina %.0f / %.0f" % [SHOTS[mode],session.players.size(),fish.motion.swim_drive*100,"DRIVE DISRUPTED" if fish.motion.drive_lockout > 0 else "OVERDRIVE" if fish.motion.overdrive > 0 else "",fish.stamina,fish.endurance]
	debug.text += "\nFish %.1f inches | Fisher score %.1f inches" % [fish.length_inches(),fisher.score_inches]
	if is_instance_valid(fight):
		debug.text += "\nFish: %s | Fisher: %s\n%s | Line %.1f / %.0f m | Tension %.1f | Drag %.0f%%" % [FightDecisions.fish_text(fight.fish_action),FisherControls.plan(fight.perception.observation,fisher.stamina).label,FightSession.Phase.keys()[fight.phase],fight.spool.line_out,fight.spool.maximum_line_out,fight.tension,fisher.drag_setting*100]
		debug.text += "\n"+FightSession.force_readout(fight.spool.fish_load,fight.spool.drag_threshold,fish.force_capacity(),fish.motion.stored_force_multiplier())
		debug.text += "\nREMAINING %.1f m | TAKE-UP %.1f m | REEL RECOVERY %.1f m" % [maxf(0,fight.spool.maximum_line_out-fight.spool.line_out),fight.spool.rod_take_up,fight.recovery_total]
		debug.text += "\nDIVE %.0f%% | ASCENT %.0f%% | SLACK %.2f m\nHOOK LOOSENESS %.2fx | THROW HAZARD %.2f%%/s\nVY %+.1f | %s | %s\nROD %+.2f / %+.2f | REEL %.0f%% | PAYOUT %.1f" % [fish.motion.dive_power*100,fish.motion.ascent_power*100,fight.spool.slack,fight.hook.looseness,(1-exp(-fight.hook.hazard))*100,fish.velocity.y,"FALLING" if fish.motion.falling else "AIRBORNE" if fish.airborne else "SWIMMING",["NEUTRAL","HEAD SHAKE","BODY STROKE"][fish.head.classification],fisher.command.rod_horizontal,fisher.command.rod_vertical,fisher.command.retrieve*100,fight.spool.payout]
		debug.text += "\nRECOVERY %.1f / %.1f m/s | EFF %.0f%% | JUMP LAUNCH %.0f%%\n%s" % [fight.spool.actual_recovery,fight.spool.requested_retrieve,fight.spool.retrieve_efficiency*100,fish.motion.jump_launch_power*100,RodGesture.caption(fight.counter_hint())]
		var age = fight.perception.age()
		var perceived = "CURRENT" if age < 0.18 else "%.2fs OLD" % age
		if fight.power_recovery > 0: debug.text += "\nPOWER INTERRUPTED — ROD RECOVERY"
		debug.text += "\nLINE CONDITION: %.1f%%\nVISION: %s | FOCUS: %.0f%% | AI PERCEPTION: %s\nFish Skill: %.0f%% | Fisher Skill: %.0f%%" % [fight.spool.condition*100,"ON" if fisher.vision_active else "OFF",fisher.focus/fisher.focus_capacity*100,perceived,fight.fish_skill*100,fight.fisher_skill*100]
	else: debug.text += "\n%s | Last result: %s" % [FisherActor.State.keys()[fisher.state],FightSession.Outcome.keys()[fisher.outcome]]

func draw_equipment(fisher: FisherActor, fish: FishPlayer, delta: float) -> void:
	var f = fisher.fight
	if is_instance_valid(f): fish = f.fish
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
	var art_offset = FishingPresentation.visual_rod_offset(Vector3.FORWARD.rotated(Vector3.UP,fisher.boat_yaw))
	if not is_instance_valid(f):
		hand += art_offset
		tip += art_offset
	var control = hand+direction*2
	var rod: Array = []
	for i in range(13):
		var t = i/12.0
		rod.append(hand*(1-t)*(1-t)+control*2*t*(1-t)+tip*t*t)
	draw_ribbon(rod_mesh,rod,0.018)
	equipment.update_view(delta,camera,hand,direction,tip,target,fish if is_instance_valid(f) else null,slack,f.spool.line_rate if is_instance_valid(f) else 0,f.spool.payout if is_instance_valid(f) else 0,f.spool.actual_recovery if is_instance_valid(f) else fisher.command.retrieve*4.5,is_instance_valid(f) or is_instance_valid(fisher.lure),mode == 0,f.spool.requested_retrieve if is_instance_valid(f) else 0,f.spool.retrieve_efficiency if is_instance_valid(f) else 1,f.phase if is_instance_valid(f) else -1)

func draw_ribbon(node: MeshInstance3D, points: Array, thickness: float) -> void:
	var mesh: ImmediateMesh = node.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,art_material)
	var width = camera.global_basis.x*thickness
	for i in range(points.size()-1):
		for point in [points[i]-width,points[i]+width,points[i+1]+width,points[i]-width,points[i+1]+width,points[i+1]-width]: mesh.surface_add_vertex(point)
	mesh.surface_end()
