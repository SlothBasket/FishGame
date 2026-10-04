class_name CaptureEventLog
extends RefCounted
## Transition-only CSV. Timestamps use the authoritative session simulation clock.
var file: FileAccess
var path: String = ""
var previous: Dictionary = {}
var fight_id: int = 0
var eaten: int = 0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("user://capture-events")
	path = "user://capture-events/capture_%s_%d.csv" % [Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_usec()]
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
	if not session.players.has(-1) or not session.players.has(-2): return
	var fish: FishPlayer = session.players[-1].entity
	var fisher: FisherActor = session.players[-2].entity
	var fight = fisher.fight
	var id = fight.get_instance_id() if is_instance_valid(fight) else 0
	if id != fight_id:
		fight_id = id
		previous.clear()
		if id != 0: record(session,"fight-start")
	edge(session,"feeding-charge",fish.feeding.is_charging)
	edge(session,"feeding-dash",fish.feeding.is_dashing())
	if fish.feeding.bait_eaten > eaten: record(session,"bite-success",{"total_eaten":fish.feeding.bait_eaten})
	eaten = fish.feeding.bait_eaten
	edge(session,"ascent",fish.motion.ascent_power > 0.1)
	edge(session,"breach",fish.airborne)
	if id == 0: return
	edge(session,"hookset",fight.phase == FightSession.Phase.IMPACT,{"quality":fight.quality})
	edge(session,"opening",fight.phase == FightSession.Phase.OPENING)
	edge(session,"drive",fish.motion.powered_active and fish.motion.overdrive <= 0)
	edge(session,"overdrive",fish.motion.overdrive > 0)
	edge(session,"left-dash",fish.motion.side_time > 0 and fish.motion.side_sign < 0)
	edge(session,"right-dash",fish.motion.side_time > 0 and fish.motion.side_sign > 0)
	edge(session,"dive",fish.motion.diving)
	edge(session,"power-reel",fight.power_active)
