class_name NetworkSession
extends Node
## All RPCs live at one fixed path. Simulation authority is always peer 1.
## Role ownership is separate from Node multiplayer authority; clients own input only.
const FISH_SCENE = preload("res://Scenes/FishPlayer.tscn")
const ROLE_FISH = 0
const ROLE_FISHER = 1
var requested_role: int = ROLE_FISH
var pending_peers: Dictionary = {}
var fisher_view: FisherView
var ai_mode: String = ""
var spectator_mode: bool = false
var spectator_check: bool = false
var spectator_saw_fight: bool = false
var spectator_vision_used: bool = false
var spectator_vision_recovered: bool = false
var spectator_min_focus: float = 100
var spectator_jumped: bool = false
var spectator_jerked: bool = false
var spectator_interrupted: bool = false
var outcome_banner: FightOutcomeBanner
@export var show_test_bait_markers: bool = true
var smoke_fish_driver = FightTestDriver.new()
var fight_smoke: bool = false
var smoke_stage: int = 0
const BAIT_STRIDE = 17
@export var input_hz: float = 30.0
@export var fish_snapshot_hz: float = 20.0
@export var bait_snapshot_hz: float = 10.0
@export var input_timeout: float = 0.35
var players: Dictionary = {}
var baits: Dictionary = {}
var tracks: Dictionary = {}
var last_lifecycle: Dictionary = {}
var last_bait_time: Dictionary = {}
var next_actor_id: int = 1
var world: Node3D
var local_fish: FishPlayer
var school: BaitSchool
var connected: bool = false
var hosting: bool = false
var closed: bool = false
var clock: float = 0.0
var input_clock: float = 0.0
var fish_clock: float = 0.0
var bait_clock: float = 0.0
var input_sequence: int = 0
var status: Label
var smoke: bool = false
var smoke_connected: float = -1.0
var smoke_start: Vector3
var smoke_remote_start: Vector3
var smoke_saw_two: bool = false
var smoke_disconnected: bool = false

static func requested(args: PackedStringArray) -> bool:
	for arg in args:
		if arg in ["--host","--ai-vs-ai"] or arg.begins_with("--join="): return true
	return false

func start(level: Node3D, fish: FishPlayer, args: PackedStringArray) -> void:
	world = level
	local_fish = fish
	local_fish.networked = true
	local_fish.external_input = true
	local_fish.add_to_group("fish_predators")
	smoke = "--network-smoke" in args
	var address = "127.0.0.1"
	var port = 24567
	for arg in args:
		if arg == "--host": hosting = true
		if arg == "--role=fisher": requested_role = ROLE_FISHER
		if arg.begins_with("--ai="): ai_mode = arg.trim_prefix("--ai=")
		if arg == "--fight-smoke": fight_smoke = true
		if arg.begins_with("--join="): address = arg.trim_prefix("--join=")
		if arg.begins_with("--port="): port = arg.trim_prefix("--port=").to_int()
	spectator_mode = "--ai-vs-ai" in args
	spectator_check = "--spectator-check" in args
	if spectator_mode:
		hosting = true
		ai_mode = "both"
		fight_smoke = false
		smoke = false
		local_fish.locally_owned = false
		local_fish.camera.current = false
	outcome_banner = FightOutcomeBanner.new()
	add_child(outcome_banner)
	multiplayer.allow_object_decoding = false
	multiplayer.server_relay = false
	multiplayer.peer_connected.connect(peer_joined)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(func(): connected = true; show_status("Connected; requesting role"); request_role.rpc_id(1,requested_role))
	multiplayer.connection_failed.connect(func(): disconnect_session("Connection failed"))
	multiplayer.server_disconnected.connect(func(): disconnect_session("Host disconnected"))
	var layer = CanvasLayer.new()
	add_child(layer)
	status = Label.new()

	status.add_theme_font_size_override("font_size",16)
	layer.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	status.offset_left = 24
	status.offset_top = 160
	status.offset_right = 600
	status.offset_bottom = 220
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if port < 1024 or port > 65535 or not address.is_valid_ip_address():
		disconnect_session("Invalid IP or port")
		return
	# Only transport construction is ENet-specific. RPC ownership works with MultiplayerPeer.
	var transport = ENetMultiplayerPeer.new()
	var error = transport.create_server(port,7,4) if hosting else transport.create_client(address,port,4)
	if error != OK:
		disconnect_session("Could not open connection: %s" % error_string(error))
		return
	multiplayer.multiplayer_peer = transport
	if hosting:
		connected = true
		if not spectator_mode: add_server_player(1,requested_role)
		school = BaitSchool.new()
		school.arena_half_width = world.arena_width*0.5
		school.water_depth = world.water_depth
		school.actor_spawned.connect(register_bait)
		world.add_child(school)
		if ai_mode in ["fish","both"]: add_server_player(-1,ROLE_FISH,true)
		if ai_mode in ["fisher","both"]: add_server_player(-2,ROLE_FISHER,true)
		show_status("Hosting UDP %d | peer 1" % port)
		if spectator_mode:
			status.hide()
			var observer = FightSpectator.new()
			observer.session = self
			world.add_child(observer)
			print("SPECTATOR participants=",players.keys()," human_actor=false smoke=false")
			if spectator_check and not FightReadabilityChecks.run(): get_tree().quit(1)
	else:
		local_fish.replica = true
		local_fish.visible = false
		show_status("Connecting to %s:%d" % [address,port])

func show_status(message: String) -> void:
	if status != null: status.text = message+"\nF10 disconnect | Fish / Fisher authority session"
	print("NETWORK "+message)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		disconnect_session("Disconnected")

func disconnect_session(message: String) -> void:
	if closed: return
	closed = true
	connected = false
	if multiplayer.multiplayer_peer != null: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	# Freeze this session view; relaunch without network arguments for single player.
	for record in players.values():
		if record.role == ROLE_FISHER and record.entity is FisherActor: record.entity.cleanup()
		record.entity.set_physics_process(false)
	if school != null: school.process_mode = Node.PROCESS_MODE_DISABLED
	local_fish.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_status(message+"; close this window or relaunch to play again")

func peer_joined(peer: int) -> void:
	if hosting and spectator_mode:
		multiplayer.multiplayer_peer.disconnect_peer(peer)
		return
	if hosting and not closed: pending_peers[peer] = clock

@rpc("any_peer","call_remote","reliable",0)
func request_role(role: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if not hosting or closed or sender <= 1 or not pending_peers.has(sender): return
	pending_peers.erase(sender) # Exactly one request per connection, even if malformed.
	if role not in [ROLE_FISH,ROLE_FISHER]:
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	add_server_player(sender,role)
	for id in players:
		player_event.rpc_id(sender,true,id,players[id].role,players[id].entity.position)
	player_event.rpc(true,sender,role,players[sender].entity.position)
	for id in baits: send_bait_event(sender,0,id)
	show_status("Hosting | %d players" % players.size())

func peer_left(peer: int) -> void:
	pending_peers.erase(peer)
	if not hosting or not players.has(peer): return
	var departing = players[peer].entity
	if departing is FisherActor: departing.cleanup()
	elif is_instance_valid(departing.fight): departing.fight.finish(FightSession.Outcome.DISCONNECT)
	departing.queue_free()
	players.erase(peer)
	player_event.rpc(false,peer,ROLE_FISH,Vector3.ZERO)
	smoke_disconnected = true
	show_status("Peer left; host continues | %d players" % players.size())

func add_server_player(peer: int, role: int = ROLE_FISH, ai: bool = false) -> void:
	var actor
	if role == ROLE_FISH:
		actor = local_fish if peer == 1 or (spectator_mode and peer == -1) else make_fish(false,false)
		actor.position = Vector3((players.size()%4)*4,15,12)
		actor.external_input = true
		actor.feeding.ate_bait.connect(func(bait): blood_event.rpc(bait.global_position))
	else:
		actor = FisherActor.new()
		actor.session = self
		actor.peer_id = peer
		world.add_child(actor)
		if ai: actor.position = Vector3(0,world.water_depth,12)
		if peer == 1: setup_fisher_view()
	players[peer] = {"entity":actor,"role":role,"sequence":-1,"received":clock,"tokens":4.0,"token_time":clock,"ai":FightTestDriver.new() if ai else null}

func setup_fisher_view() -> void:
	local_fish.visible = false
	local_fish.locally_owned = false
	local_fish.replica = true
	local_fish.set_physics_process(false)
	local_fish.remove_from_group("fish_predators")
	fisher_view = FisherView.new()
	fisher_view.session = self
	world.add_child(fisher_view)

func make_fish(owned: bool, is_replica: bool) -> FishPlayer:
	var actor: FishPlayer = FISH_SCENE.instantiate()
	actor.networked = true
	actor.locally_owned = owned
	actor.replica = is_replica
	actor.external_input = true
	actor.get_node("CameraPivot/SpringArm3D/Camera3D").current = false
	actor.water_height = world.water_depth
	world.add_child(actor)
	actor.add_to_group("fish_predators")
	return actor

@rpc("authority","call_remote","reliable",0)
func player_event(add: bool, peer: int, role: int, where: Vector3) -> void:
	if hosting or closed: return
	if not add:
		if players.has(peer): players[peer].entity.queue_free(); players.erase(peer)
		tracks.erase("f%d" % peer)
		return
	if players.has(peer) or role not in [ROLE_FISH,ROLE_FISHER]: return
	var owned = peer == multiplayer.get_unique_id()
	var actor
	if role == ROLE_FISH: actor = local_fish if owned else make_fish(false,true)
	else:
		actor = Node3D.new()
		world.add_child(actor)
		if owned: setup_fisher_view()
	actor.position = where
	actor.visible = true
	players[peer] = {"entity":actor,"role":role}
	if owned and role == ROLE_FISH:
		actor.camera.make_current()
		show_status("Connected | owned fish peer %d" % peer)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func fish_intent(sequence: int, axes: PackedFloat32Array, flags: int) -> void:
	# No client entity ID: authenticated transport sender determines the owned channel.
	var sender = multiplayer.get_remote_sender_id()
	if not hosting or closed or sender <= 1 or not players.has(sender): return
	var record: Dictionary = players[sender]
	if record.role != ROLE_FISH: return
	if sequence < 0 or sequence > 2147483647 or sequence <= record.sequence: return
	if axes.size() != 7 or flags < 0 or flags > 7: return
	for number in axes:
		if not is_finite(number): return
	record.tokens = minf(4,record.tokens+(clock-record.token_time)*60)
	record.token_time = clock
	if record.tokens < 1: return
	record.tokens -= 1
	var aim = Vector3(clampf(axes[3],-1,1),clampf(axes[4],-1,1),clampf(axes[5],-1,1))
	if aim.length_squared() < 0.01: return
	record.sequence = sequence
	record.received = clock
	var intent = FishInput.new(axes[0],axes[1],axes[2],aim,flags & 1 != 0,flags & 2 != 0)
	intent.cancel_bite = flags & 4 != 0
	intent.stroke_axis = clampf(axes[6],-1,1)
	record.entity.command = intent

func _physics_process(delta: float) -> void:
	clock += delta
	if spectator_check and spectator_mode:
		if players.has(-2):
			var observer_fisher: FisherActor = players[-2].entity
			spectator_min_focus = minf(spectator_min_focus,observer_fisher.focus)
			if is_instance_valid(observer_fisher.fight):
				if observer_fisher.fight.jerk_notice_time > 0: spectator_jerked = true
				if observer_fisher.fight.interruption > 0: spectator_interrupted = true
			if observer_fisher.vision_active: spectator_vision_used = true
			if spectator_vision_used and not observer_fisher.vision_active and observer_fisher.focus > spectator_min_focus+2: spectator_vision_recovered = true
		if players.has(-1) and players[-1].entity.natural_breach: spectator_jumped = true
		if clock > 39.98: print("OBSERVER Vision used=",spectator_vision_used," recovered=",spectator_vision_recovered," minimum focus=",spectator_min_focus," natural breach=",spectator_jumped)
		if players.has(-2) and is_instance_valid(players[-2].entity.fight):
			if players[-2].entity.fight.phase >= FightSession.Phase.IMPACT and not spectator_saw_fight:
				spectator_saw_fight = true
				print("SPECTATOR PASS natural bait attack and hook-set reached fight")
		if clock >= 40:
			print("GESTURE observed=",spectator_jerked," interruption=",spectator_interrupted)
			var report_ok = false
			for node in world.get_children():
				if node is PerformanceProbe:
					node.save_report()
					report_ok = FileAccess.file_exists(node.last_report_base+".csv") and FileAccess.file_exists(node.last_report_base+".json")
			print("HITCH SAVE ","PASS" if report_ok else "FAIL")
			var valid = players.size() == 2 and players.has(-1) and players.has(-2) and not players.has(1) and spectator_saw_fight and report_ok
			print("SPECTATOR ","PASS" if valid else "FAIL", " natural observer run")
			get_tree().quit(0 if valid else 1)
			return
	if smoke and clock > 12 and not closed:
		push_error("NETWORK SMOKE timeout")
		get_tree().quit(1)
		return
	if closed:
		if fight_smoke: get_tree().quit(0 if smoke_saw_two else 1)
		if smoke: get_tree().quit(0 if smoke_saw_two else 1)
		return
	if not connected: return
	var owned_id = 1 if hosting else multiplayer.get_unique_id()
	if players.has(owned_id):
		input_clock -= delta
		if players[owned_id].role == ROLE_FISHER:
			var input = fisher_view.sample()
			if fight_smoke:
				input.species = BaitMotion.Kind.MINNOW
				input.cast_serial = 1
				if fisher_view.data.size() == 63:
					input.jerk = roundi(fisher_view.data[10]) == FightSession.Phase.CANDIDATE or (roundi(fisher_view.data[10]) == FightSession.Phase.METER and fisher_view.data[11] < 0.72)
			if hosting: players[owned_id].entity.command = input
			elif input_clock <= 0:
				input_sequence += 1
				fisher_intent.rpc_id(1,input_sequence,input.numbers(),input.flags())
		else:
			var intent = local_fish.read_local_input()
			if fight_smoke and hosting: intent = smoke_fish_driver.fish_input(local_fish,self,delta)
			if smoke: intent = FishInput.new(1,0,0,Vector3.FORWARD if hosting else Vector3.RIGHT)
			if hosting: local_fish.command = intent
			elif input_clock <= 0:
				input_sequence += 1
				var aim = intent.aim_direction
				fish_intent.rpc_id(1,input_sequence,PackedFloat32Array([intent.throttle,intent.steering,intent.vertical,aim.x,aim.y,aim.z,intent.stroke_axis]),int(intent.boost)|int(intent.bite_held)<<1|int(intent.cancel_bite)<<2)
		if input_clock <= 0: input_clock = 1.0/input_hz

	if hosting:
		for peer in pending_peers.keys():
			if clock-pending_peers[peer] > 10:
				pending_peers.erase(peer)
				multiplayer.multiplayer_peer.disconnect_peer(peer)
		for id in players:
			var record: Dictionary = players[id]
			if record.ai != null:
				record.entity.command = record.ai.fish_input(record.entity,self,delta) if record.role == ROLE_FISH else record.ai.fisher_input(record.entity,delta)
			elif id != 1 and clock-record.received > (1.25 if record.role == ROLE_FISHER else input_timeout):
				if record.role == ROLE_FISH:
					var neutral = FishInput.new()
					neutral.cancel_bite = true
					record.entity.command = neutral
				else:
					var neutral = FisherIntent.new()
					neutral.cast_serial = record.entity.last_cast
					neutral.species = record.entity.kind
					neutral.tier = record.entity.reel.selected_tier
					neutral.drag = record.entity.drag_setting
					record.entity.command = neutral
					if is_instance_valid(record.entity.fight) and record.entity.fight.phase <= FightSession.Phase.METER: record.entity.fight.finish(FightSession.Outcome.DISCONNECT)

		fish_clock -= delta
		bait_clock -= delta
		if fish_clock <= 0:
			fish_clock = 1.0/fish_snapshot_hz
			for id in players:
				if players[id].role == ROLE_FISH: fish_snapshot.rpc(id,fish_state(players[id].entity))
				else:
					var state = fisher_state(players[id].entity)
					fisher_snapshot.rpc(id,state)
					if id == 1 and fisher_view != null: fisher_view.data = state
		if bait_clock <= 0:
			bait_clock = 1.0/bait_snapshot_hz
			broadcast_baits()
	if smoke: smoke_tick()
	if fight_smoke: fight_smoke_tick()

func fish_state(actor: FishPlayer) -> PackedFloat32Array:
	var p = actor.position
	var h = actor.heading
	var v = actor.velocity
	var f = actor.feeding
	return PackedFloat32Array([p.x,p.y,p.z,h.x,h.y,h.z,v.x,v.y,v.z,f.food,f.bait_eaten,f._charge_time,f._dash_remaining,int(actor.airborne),int(actor.boosting),f.cooldown_remaining,f.bite_flash,f.grace_remaining,actor.stamina,actor.line_force.x,actor.line_force.y,actor.line_force.z,actor.endurance,int(actor.fight_active),actor.fight_pressure,actor.fight_gain,actor.fight_leverage,actor.fight_counter,int(actor.fight_slack),actor.motion.swim_drive,actor.motion.overdrive,actor.motion.run_build,actor.motion.dive_power,int(actor.motion.diving),actor.fight_best_move,actor.fight_anchor.x,actor.fight_anchor.y,actor.fight_anchor.z,actor.fight_roll,actor.motion.cadence_grade,int(actor.damaging_line),actor.directional_pressure,actor.head.offset.x,actor.head.offset.y,actor.head.impact_time,actor.motion.ascent_power,actor.head.shake_pressure])

@rpc("authority","call_remote","unreliable_ordered",2)
func fish_snapshot(peer: int, state: PackedFloat32Array) -> void:
	if hosting or closed or not players.has(peer) or state.size() != 47: return
	var actor: FishPlayer = players[peer].entity
	track("f%d" % peer,actor,Vector3(state[0],state[1],state[2]),FishInput.angles(Vector3(state[3],state[4],state[5])),1.0/fish_snapshot_hz,state[38])
	actor.heading = Vector3(state[3],state[4],state[5])
	actor.velocity = Vector3(state[6],state[7],state[8])
	actor.feeding.food = roundi(state[9])
	actor.feeding.bait_eaten = roundi(state[10])
	actor.feeding._charge_time = state[11]
	actor.feeding.is_charging = state[11] > 0
	actor.feeding._dash_remaining = state[12]
	actor.airborne = state[13] > 0
	actor.boosting = state[14] > 0
	actor.feeding.cooldown_remaining = state[15]
	actor.feeding.bite_flash = state[16]
	actor.feeding.grace_remaining = state[17]
	actor.visual.scale = Vector3.ONE*actor.size_multiplier()
	actor.visual.swim_intensity = actor.velocity.length()/actor.swim_speed
	actor.visual.charge_intensity = actor.feeding.charge_fraction()
	actor.visual.biting = actor.feeding.is_dashing() or state[16] > 0
	actor.stamina = state[18]
	actor.endurance = state[22]
	actor.fight_active = state[23] > 0
	actor.fight_pressure = state[24]
	actor.fight_gain = state[25]
	actor.fight_leverage = state[26]
	actor.fight_counter = state[27]
	actor.fight_slack = state[28] > 0
	actor.motion.swim_drive = state[29]
	actor.motion.overdrive = state[30]
	actor.motion.run_build = state[31]
	actor.motion.dive_power = state[32]
	actor.motion.diving = state[33] > 0
	actor.fight_best_move = roundi(state[34])
	actor.fight_anchor = Vector3(state[35],state[36],state[37])
	actor.fight_roll = state[38]
	actor.directional_pressure = state[41]
	actor.head.offset = Vector2(state[42],state[43])
	actor.head.impact_time = state[44]
	actor.motion.ascent_power = state[45]
	actor.head.shake_pressure = state[46]
	actor.motion.cadence_grade = roundi(state[39])
	actor.damaging_line = state[40] > 0
	actor.line_force = Vector3(state[19],state[20],state[21])
	actor.update_growth_collision()

func register_bait(actor: BaitActor) -> void:
	var id = next_actor_id
	next_actor_id += 1
	baits[id] = actor
	actor.network_id = id
	if is_instance_valid(actor.fisher_owner): add_test_marker(actor)
	last_lifecycle[id] = actor.lifecycle
	send_bait_event(0,0,id)
	actor.bitten.connect(func(_bait,_eater): send_bait_event(0,1,id))
	actor.tree_exiting.connect(func():
		if not closed: bait_event.rpc(2,id,0,0,PackedFloat32Array())
		baits.erase(id)
		last_lifecycle.erase(id))

func bait_state(id: int, actor: BaitActor) -> PackedFloat32Array:
	var p = actor.position
	var r = actor.visual.rotation
	var v = actor.velocity
	if actor.lifecycle == BaitActor.Lifecycle.DEAD_SETTLED: r.z = PI
	return PackedFloat32Array([id,p.x,p.y,p.z,r.x,r.y,r.z,v.x,v.y,v.z,actor.visual.scale.x,actor.visual.speed,actor.visual.twitch,actor.visual.bird_pose,int(actor.visual.bird_powered),actor.visual.action,clock])

func send_bait_event(peer: int, operation: int, id: int) -> void:
	var actor: BaitActor = baits[id]
	var data = bait_state(id,actor)
	data.append(actor.lifecycle)
	data.append(int(is_instance_valid(actor.fisher_owner)))
	if peer == 0: bait_event.rpc(operation,id,actor.kind,actor.body_size,data)
	else: bait_event.rpc_id(peer,operation,id,actor.kind,actor.body_size,data)

@rpc("authority","call_remote","reliable",0)
func bait_event(operation: int, id: int, kind: int, size: float, state: PackedFloat32Array) -> void:
	if hosting or closed: return
	if operation == 2:
		if baits.has(id): baits[id].queue_free(); baits.erase(id)
		tracks.erase("b%d" % id)
		last_bait_time.erase(id)
		return
	if state.size() != BAIT_STRIDE+2: return
	if operation == 0 and not baits.has(id):
		var actor = BaitActor.new() # Fixed local type, no resource names from network.
		actor.kind = kind
		actor.body_size = size
		actor.network_replica = true
		actor.position = Vector3(state[1],state[2],state[3])
		world.add_child(actor)
		baits[id] = actor
	if not baits.has(id): return
	var actor: BaitActor = baits[id]
	if state[18] > 0: add_test_marker(actor)
	actor.lifecycle = roundi(state[17])
	actor.claimed = actor.lifecycle == BaitActor.Lifecycle.CLAIMED
	actor.visual.alive = actor.lifecycle == BaitActor.Lifecycle.ALIVE
	if actor.claimed:
		if actor.has_node("TestBaitMarker"): actor.get_node("TestBaitMarker").hide()
		actor.remove_from_group("bait")
		actor.collision_layer = 0
	apply_bait_state(state)

func broadcast_baits() -> void:
	var batch = PackedFloat32Array()
	for id in baits:
		var actor: BaitActor = baits[id]
		if actor.lifecycle != last_lifecycle[id]:
			last_lifecycle[id] = actor.lifecycle
			send_bait_event(0,1,id)
		# Settled corpses do not need transforms repeated ten times each second.
		if actor.lifecycle == BaitActor.Lifecycle.DEAD_SETTLED: continue
		batch.append_array(bait_state(id,actor))
		if batch.size() >= BAIT_STRIDE*12:
			bait_snapshot.rpc(batch)
			batch = PackedFloat32Array()
	if not batch.is_empty(): bait_snapshot.rpc(batch)

@rpc("authority","call_remote","unreliable",3)
func bait_snapshot(batch: PackedFloat32Array) -> void:
	if hosting or closed or batch.size()%BAIT_STRIDE != 0 or batch.size() > BAIT_STRIDE*12: return
	for offset in range(0,batch.size(),BAIT_STRIDE): apply_bait_state(batch.slice(offset,offset+BAIT_STRIDE))

func apply_bait_state(state: PackedFloat32Array) -> void:
	var id = roundi(state[0])
	if not baits.has(id): return # Reliable creation may arrive after an unreliable snapshot.
	if state[16] < last_bait_time.get(id,-1.0): return
	last_bait_time[id] = state[16]
	var actor: BaitActor = baits[id]
	track("b%d" % id,actor,Vector3(state[1],state[2],state[3]),Vector2(state[4],state[5]),1.0/bait_snapshot_hz,state[6])
	actor.velocity = Vector3(state[7],state[8],state[9])
	actor.visual.scale = Vector3.ONE*state[10]
	actor.visual.speed = state[11]
	actor.visual.twitch = state[12]
	actor.visual.bird_pose = roundi(state[13])
	actor.visual.bird_powered = state[14] > 0
	actor.visual.action = roundi(state[15])

func track(key: String, actor: Node3D, destination: Vector3, angles: Vector2, duration: float, roll: float = 0) -> void:
	tracks[key] = {"actor":actor,"from":actor.position,"to":destination,"rotation":actor.visual.rotation,"target_rotation":Vector3(angles.x,angles.y,roll),"time":0.0,"duration":duration}

func _process(delta: float) -> void:
	if hosting or closed: return
	for record in tracks.values():
		if not is_instance_valid(record.actor): continue
		record.time += delta
		var t = clampf(record.time/record.duration,0,1)
		record.actor.position = record.from.lerp(record.to,t)
		for axis in range(3): record.actor.visual.rotation[axis] = lerp_angle(record.rotation[axis],record.target_rotation[axis],t)

func smoke_tick() -> void:
	# Explicit local development flag only; never callable over the network.
	if players.size() == 2 and smoke_connected < 0:
		smoke_connected = clock
		smoke_start = local_fish.position
		for record in players.values():
			if record.entity != local_fish: smoke_remote_start = record.entity.position
	if smoke_connected >= 0 and clock-smoke_connected > 2 and not smoke_saw_two:
		var other: FishPlayer
		for record in players.values():
			if record.entity != local_fish: other = record.entity
		var moved = is_instance_valid(other) and other.position.distance_to(smoke_remote_start) > 1 and local_fish.position.distance_to(smoke_start) > 1
		if not moved or baits.is_empty() or (not hosting and school != null):
			push_error("NETWORK SMOKE failed ownership/movement/ecosystem")
			get_tree().quit(1)
			return
		smoke_saw_two = true
		print("NETWORK SMOKE PASS two owned fish moved; shared bait count=",baits.size()," server=",hosting)
		if not hosting:
			disconnect_session("Smoke client disconnect")
			get_tree().quit(0)
	if hosting and smoke_saw_two and smoke_disconnected:
		print("NETWORK SMOKE PASS host continues after client disconnect")
		get_tree().quit(0)
	if clock > 12:
		push_error("NETWORK SMOKE connection timeout")
		get_tree().quit(1)

@rpc("any_peer","call_remote","reliable",1)
func fisher_intent(sequence: int, values: PackedFloat32Array, flags: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if not hosting or closed or sender <= 1 or not players.has(sender): return
	var record: Dictionary = players[sender]
	if record.role != ROLE_FISHER or sequence < 0 or sequence > 2147483647 or sequence <= record.sequence: return
	record.tokens = minf(4,record.tokens+(clock-record.token_time)*60)
	record.token_time = clock
	if record.tokens < 1: return
	record.tokens -= 1
	var intent = FisherIntent.decode(values,flags)
	if intent == null:
		if fight_smoke: print("REJECT FISHER ",values," flags=",flags)
		return
	if intent.cast_serial < record.entity.last_cast:
		if fight_smoke: print("REJECT CAST ",intent.cast_serial," last=",record.entity.last_cast)
		return
	record.sequence = sequence
	record.received = clock
	record.entity.command = intent

func fisher_state(actor: FisherActor) -> PackedFloat32Array:
	var f = actor.fight
	var has_fight = is_instance_valid(f)
	var p = f.fish.position if has_fight else actor.position
	var v = f.fish.velocity if has_fight else Vector3.ZERO
	var rod = f.rod_direction if has_fight else actor.command.aim
	var fish_peer: int = 0
	if has_fight:
		for id in players:
			if players[id].entity == f.fish: fish_peer = id
	return PackedFloat32Array([actor.position.x,actor.position.y,actor.position.z,actor.boat_yaw,actor.state,actor.kind,actor.lure.network_id if is_instance_valid(actor.lure) else 0,actor.reel.selected_tier,actor.stamina,actor.focus,f.phase if has_fight else -1,f.meter if has_fight else 0,f.line_length if has_fight else 0,f.tension if has_fight else 0,f.condition if has_fight else 1,int(f.power_active) if has_fight else 0,int(actor.vision_active),rod.x,rod.y,rod.z,fish_peer,p.x,p.y,p.z,v.x,v.y,v.z,actor.outcome,f.quality if has_fight else 0,f.phase_time if has_fight else 0,
		f.spool.distance if has_fight else 0,f.spool.slack if has_fight else 0,actor.drag_setting,f.spool.drag_threshold if has_fight else 0,f.spool.requested_load if has_fight else 0,f.spool.line_rate if has_fight else 0,f.spool.payout if has_fight else 0,1.0 if has_fight and f.power_active else actor.command.retrieve,int(f.spool.slipping) if has_fight else 0,
		f.rod_tip.x if has_fight else 0,f.rod_tip.y if has_fight else 0,f.rod_tip.z if has_fight else 0,f.rod_hand.x if has_fight else 0,f.rod_hand.y if has_fight else 0,f.rod_hand.z if has_fight else 0,f.spool.strength if has_fight else 110,f.rod_horizontal if has_fight else 0,f.rod_vertical if has_fight else 0,
		f.spool.maximum_line_out if has_fight else FightLine.DEFAULT_CAPACITY,
		v.normalized().dot(BaitMotion.horizontal(p-actor.position).cross(Vector3.UP)) if has_fight and actor.vision_active and v.length() > 0.3 else 0,
		f.tension/maxf(1,f.spool.break_threshold()) if has_fight else 0,f.counter_pressure if has_fight else 0,f.fisher_action if has_fight else 4,f.fish.motion.dive_power if has_fight else 0,int(f.fish.motion.diving) if has_fight else 0,f.line_damage_rate if has_fight else 0,f.spool.rod_take_up if has_fight else 0,f.recovery_total if has_fight else 0,f.jerk_direction if has_fight else 0,f.jerk_notice_time if has_fight else 0,f.fish.motion.ascent_power if has_fight else 0,int(f.fish.motion.falling) if has_fight else 0,int(f.fish.airborne) if has_fight else 0])

@rpc("authority","call_remote","unreliable_ordered",2)
func fisher_snapshot(peer: int, state: PackedFloat32Array) -> void:
	if hosting or closed or state.size() != 63 or not players.has(peer) or players[peer].role != ROLE_FISHER: return
	players[peer].entity.position = Vector3(state[0],state[1],state[2])
	if peer == multiplayer.get_unique_id() and fisher_view != null:
		if fight_smoke and (fisher_view.data.is_empty() or fisher_view.data[10] != state[10]): print("CLIENT FIGHT PHASE ",state[10]," fields=",state.size())
		fisher_view.data = state

@rpc("authority","call_remote","reliable",0)
func blood_event(where: Vector3) -> void:
	if hosting or closed: return
	var effect = BloodCloud.new()
	effect.position = where
	world.add_child(effect)

func fight_smoke_tick() -> void:
	# One bounded encounter plus deterministic line contracts; no balance simulation.
	if hosting:
		var fisher: FisherActor
		var fish: FishPlayer
		for record in players.values():
			if record.role == ROLE_FISHER: fisher = record.entity
			else: fish = record.entity
		if fisher != null and fish != null and is_instance_valid(fisher.lure) and fisher.lure.cast_remaining <= 0 and fisher.lure.cast_windup <= 0 and smoke_stage == 0:
			fish.position = fisher.lure.position-Vector3.FORWARD*0.5
			fish.feeding.grace_remaining = 0.2
			fish.feeding.sweep_bite(fish.position,fisher.lure.position)
			smoke_stage = 1
			print("FIGHT SMOKE candidate=",is_instance_valid(fisher.fight))
		if fisher != null and is_instance_valid(fisher.fight) and fisher.fight.phase == FightSession.Phase.FIGHT and smoke_stage == 1:
			if not FightCoreChecks.run(fisher.fight): get_tree().quit(1); return
			print("FIGHT SMOKE PASS authoritative fight and core line contracts")
			smoke_stage = 2
			smoke_connected = clock
		if smoke_stage == 2 and clock-smoke_connected > 4.0:
			if not is_instance_valid(fisher.fight): push_error("Fight ended before bounded movement check"); get_tree().quit(1); return
			print("FIGHT SMOKE AI stamina=",fish.stamina," endurance=",fish.endurance," tension=",fisher.fight.tension," payout=",fisher.fight.spool.payout)
			if fish.endurance >= fish.stamina_capacity: push_error("Fight exertion did not reduce endurance"); get_tree().quit(1); return
			fish.position = fisher.position-Vector3.UP
			fish.velocity = Vector3.ZERO
			fish.stamina = fish.stamina_capacity
			fish.set_physics_process(false)
			fisher.fight.line_length = 3
			smoke_stage = 3
		if smoke_stage == 3 and is_instance_valid(fisher.fight): fisher.fight.after_fish_move(1.0/60.0)
		if smoke_stage == 3 and fisher.state == FisherActor.State.SETUP:
			if fisher.outcome != FightSession.Outcome.LANDED or is_instance_valid(fish.fight):
				push_error("FIGHT SMOKE landing/reset failed"); get_tree().quit(1); return
			print("FIGHT SMOKE PASS full-stamina landing and reset")
			smoke_stage = 4
			smoke_connected = clock
		if smoke_stage == 4 and clock-smoke_connected > 0.4: get_tree().quit(0)
	else:
		if fisher_view != null and fisher_view.data.size() == 63:
			if roundi(fisher_view.data[10]) == FightSession.Phase.FIGHT and not smoke_saw_two:
				smoke_saw_two = true
				print("FIGHT SMOKE PASS replicated fight/HUD state")
			if smoke_saw_two and roundi(fisher_view.data[27]) == FightSession.Outcome.LANDED:
				print("FIGHT SMOKE PASS replicated landing")
				get_tree().quit(0)
	if clock > 14:
		push_error("FIGHT SMOKE timeout")
		get_tree().quit(1)
func add_test_marker(actor: BaitActor) -> void:
	if not show_test_bait_markers or actor.has_node("TestBaitMarker"): return
	var marker = Label3D.new()
	marker.name = "TestBaitMarker"
	marker.text = "◇ TEST BAIT"
	marker.position.y = 1.2
	marker.font_size = 24
	marker.pixel_size = 0.003
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.modulate = Color(0.6,1,1)
	actor.add_child(marker)
	actor.bitten.connect(func(_bait,_eater): marker.hide())

func publish_fight_result(fish: FishPlayer, fisher: FisherActor, result: int) -> void:
	var fish_id = 0
	for id in players:
		if players[id].entity == fish: fish_id = id
	present_fight_result(fish_id,fisher.peer_id,result)
	if connected: fight_result.rpc(fish_id,fisher.peer_id,result)

@rpc("authority","call_remote","reliable",0)
func fight_result(fish_id: int, fisher_id: int, result: int) -> void:
	if hosting or result < 1 or result > FightSession.Outcome.SPOOLED: return
	present_fight_result(fish_id,fisher_id,result)

func present_fight_result(fish_id: int, fisher_id: int, result: int) -> void:
	var owned = 1 if hosting else multiplayer.get_unique_id()
	if spectator_mode or owned == fish_id or owned == fisher_id:
		outcome_banner.show_result(result,owned == fish_id)

func publish_fight_counter(fish: FishPlayer, fisher: FisherActor, kind: int) -> void:
	var fish_id = 0
	for id in players:
		if players[id].entity == fish: fish_id = id
	present_fight_counter(fish_id,fisher.peer_id,kind)
	if connected: fight_counter.rpc(fish_id,fisher.peer_id,kind)

@rpc("authority","call_remote","reliable",0)
func fight_counter(fish_id: int, fisher_id: int, kind: int) -> void:
	if hosting or kind < 1 or kind > 3: return
	present_fight_counter(fish_id,fisher_id,kind)

func present_fight_counter(fish_id: int, fisher_id: int, kind: int) -> void:
	var owned = 1 if hosting else multiplayer.get_unique_id()
	if spectator_mode or owned == fish_id or owned == fisher_id: outcome_banner.show_counter(kind)
