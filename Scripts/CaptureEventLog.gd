class_name CaptureEventLog
extends RefCounted
## Transition-only CSV. Timestamps use the authoritative session simulation clock.
var file: FileAccess
var path: String = ""
var previous: Dictionary = {}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("user://capture-events")
	path = "user://capture-events/capture_%s_%d.csv" % [Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_usec()+OS.get_process_id()*1000000]
	file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_warning("Cannot open capture event log: "+path)
		return
	file.store_csv_line(PackedStringArray(["timestamp","event","encounter_seed","metadata_json"]))
	file.flush()
	print("CAPTURE EVENTS: ",ProjectSettings.globalize_path(path))

func record(session: NetworkSession, event: String, metadata: Dictionary = {}) -> void:
	if file == null: return
	file.store_csv_line(PackedStringArray(["%.4f" % session.clock,event,str(session.encounter_seed),JSON.stringify(metadata)]))
	file.flush() # Events are sparse; preserve timestamps even if filming is stopped.

func edge(session: NetworkSession, event: String, active: bool, metadata: Dictionary = {}) -> void:
	if active and not previous.get(event,false): record(session,event,metadata)
	previous[event] = active

func sample(session: NetworkSession) -> void:
	for peer in session.players:
		var actor = session.players[peer].entity
		if not actor is FishPlayer: continue
		sample_fish(session,peer,actor)

func sample_fish(session: NetworkSession, peer: int, fish: FishPlayer) -> void:
	var fight = fish.fight
	var id = fight.get_instance_id() if is_instance_valid(fight) else 0
	var key = str(peer)
	var history: Dictionary = previous.get(key,{})
	var metadata = {"fish_peer":peer}
	if is_instance_valid(fight): metadata["fisher_peer"] = fight.fisher.peer_id
	if id != int(history.get("fight",0)):
		if id != 0: record(session,"fight-start",metadata)
		history.clear()
		history["fight"] = id
	var states = {"feeding-charge":fish.feeding.is_charging,"feeding-dash":fish.feeding.is_dashing(),"ascent":fish.motion.ascent_power > 0.1,"breach":fish.airborne}
	if is_instance_valid(fight):
		states.merge({"hookset":fight.phase == FightSession.Phase.IMPACT,"opening":fight.phase == FightSession.Phase.OPENING,"drive":fish.motion.powered_active and fish.motion.overdrive <= 0,"overdrive":fish.motion.overdrive > 0,"left-dash":fish.motion.side_time > 0 and fish.motion.side_sign < 0,"right-dash":fish.motion.side_time > 0 and fish.motion.side_sign > 0,"dive":fish.motion.diving,"power-reel":fight.power_active})
	for event in states:
		if states[event] and not history.get(event,false): record(session,event,metadata)
		history[event] = states[event]
	if fish.feeding.bait_eaten > int(history.get("eaten",fish.feeding.bait_eaten)):
		var meal = metadata.duplicate()
		meal["total_eaten"] = fish.feeding.bait_eaten
		record(session,"bite-success",meal)
	history["eaten"] = fish.feeding.bait_eaten
	previous[key] = history
