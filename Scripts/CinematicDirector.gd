class_name CinematicDirector
extends RefCounted
## Local presentation only. Never consumes gameplay RNG or submits actor inputs.
var view: FightSpectator
var rng = RandomNumberGenerator.new()
var shot_age: float = 0
var hold_time: float = 0
var priority: int = 0
var pending: Dictionary = {}
var watches: Dictionary = {}
var preferred_subject: String = "fish"
var event_name: String = "swim"
var previous_event: String = ""
var previous_fight: int = 0
var previous_counter: float = -1
var previous_eaten: int = 0
var previous_outcome: int = 0
var bite_hold: float = 0
var last_heading: Vector3 = Vector3.FORWARD
var prey: BaitActor
var distance_scale: float = 1
var height_offset: float = 0
var side: float = 1
var fov_offset: float = 0
var safety_cooldown: float = 0
var clearance = SphereShape3D.new()
var terrain_wait: float = 0
var near_terrain: bool = false
var recent_families: Array[String] = []
var shot_event: String = "swim"
var rear_offset: float = 0
var jump_hold: bool = false
var was_airborne: bool = false
var reaction_hold: float = 0

static func family(shot: String) -> String:
	if shot in ["fish","fish-rear"]: return "rear"
	return {"fish-side":"side","fish-front":"front","wide":"wide","fisher":"boat"}.get(shot,shot)

func _init(observer: FightSpectator, seed_value: int) -> void:
	view = observer
	if seed_value >= 0: rng.seed = seed_value+9001
	else: rng.randomize()
	clearance.radius = 0.4

## Small future-control seam: subjects are fish, prey, or boat. Requests expire.
func request_shot(shot: String, duration: float = 5, interest: int = 4, subject: String = "fish", event: String = "external") -> void:
	if not shot in FightSpectator.SHOTS or shot == "free": return
	if not pending.is_empty() and interest < int(pending.priority): return
	pending = {"shot":shot,"duration":clampf(duration,5,10),"priority":interest,"subject":subject,"ttl":3.0,"event":event}

func watch_event(event: String, shot: String, duration: float = 5) -> void:
	watches[event] = {"shot":shot,"duration":duration}

func cue(event: String, shots: Array, interest: int, subject: String = "fish", refresh: bool = false) -> void:
	event_name = event
	var current: String = view.SHOTS[view.mode]
	# Compatible action transitions do not change distance/side or restart a cut.
	if not refresh and current in shots and shot_age < hold_time and not watches.has(event):
		preferred_subject = subject
		priority = maxi(priority,interest)
		if event == "counter": reaction_hold = 2.5
		if event in ["ascent","breach"]: jump_hold = true
		if event in ["side-dash","ascent","breach","counter"]: shot_event = event
		return
	var options = shots.duplicate()
	var different = options.filter(func(shot): return family(shot) != family(current) and not family(shot) in recent_families)
	if different.is_empty(): different = options.filter(func(shot): return family(shot) != family(current))
	if not different.is_empty(): options = different
	var selected = options[rng.randi_range(0,options.size()-1)]
	var duration = rng.randf_range(5,10)
	if watches.has(event):
		selected = watches[event].shot
		duration = watches[event].duration
	request_shot(selected,duration,interest,subject,event)

func update(delta: float, fish: FishPlayer, fisher: FisherActor) -> void:
	shot_age += delta
	bite_hold = maxf(0,bite_hold-delta)
	reaction_hold = maxf(0,reaction_hold-delta)
	if was_airborne and not fish.airborne:
		jump_hold = false
		reaction_hold = maxf(reaction_hold,1.5) # Let the splash settle.
	if jump_hold and not fish.airborne and fish.motion.ascent_power <= 0.1 and not was_airborne:
		jump_hold = false
	was_airborne = fish.airborne
	safety_cooldown = maxf(0,safety_cooldown-delta)
	if not pending.is_empty():
		pending.ttl -= delta
		if pending.ttl <= 0: pending.clear()
	var fight = fisher.fight
	var fight_id = fight.get_instance_id() if is_instance_valid(fight) else 0
	if fight_id != previous_fight:
		previous_fight = fight_id
		previous_event = ""
		previous_counter = -1
	prey = view.session.players[-1].ai.food.target
	terrain_wait -= delta
	if terrain_wait <= 0:
		terrain_wait = 0.75
		var ahead = fish.position+fish.heading*10+Vector3.DOWN*3
		var terrain_ray = PhysicsRayQueryParameters3D.create(fish.position,ahead,1,[fish.get_rid()])
		near_terrain = not fish.get_world_3d().direct_space_state.intersect_ray(terrain_ray).is_empty()
	var event = "swim"
	var shots: Array = ["fish-rear","fish-side","fish","wide","fish-front"]
	var interest = 0
	var subject = "fish"
	if is_instance_valid(fight):
		if fight.phase == FightSession.Phase.IMPACT:
			event = "hookset"; shots = ["fisher"]; interest = 3; subject = "boat"
		elif fish.airborne:
			event = "breach"; shots = ["fish-side","fish-front","wide"]; interest = 3
		elif fish.motion.ascent_power > 0.1:
			event = "ascent"; shots = ["fish-side","fish-rear"]; interest = 2
		elif fish.motion.diving:
			event = "dive"; shots = ["fish-side","fish-rear"]; interest = 2
		elif fish.motion.side_time > 0:
			event = "side-dash"; shots = ["fish-side"]; interest = 2
		elif fish.motion.overdrive > 0 or fish.motion.powered_active:
			event = "powered-run"; shots = ["fish-rear","fish-front"]; interest = 2
		elif fight.phase == FightSession.Phase.OPENING:
			event = "opening"; shots = ["fish-rear","fish"]; interest = 2
		else:
			event = "fight"; shots = ["fish-rear","fish-side","fisher"]
		var counter = float(fight.last_counter.get("counter_input_time",-1))
		if counter != previous_counter and counter >= 0:
			previous_counter = counter
			# Keep an already useful fish shot rather than cutting off the recoil.
			cue("counter",[view.SHOTS[view.mode] if view.mode in [1,4,5,6] else "fish-side"],3)
	elif fish.feeding.is_dashing():
		event = "feeding-dash"; shots = ["fish-side","fish-front"]; interest = 2; subject = "prey"
	elif fish.feeding.is_charging:
		event = "feeding-charge"; shots = ["fish-side","fish-front"]; interest = 2; subject = "prey"
	elif is_instance_valid(prey):
		event = "approach"; shots = ["fish-side","fish-front"]; interest = 1; subject = "prey"
	if event == "swim" and near_terrain:
		event = "terrain"; shots = ["fish-side","fish-front","wide"]; interest = 1
	elif event == "swim" and shot_age >= 3 and fish.heading.dot(last_heading) < 0.25:
		event = "course-change"; shots = ["fish-side","fish-rear"]; interest = 1
	if event != previous_event:
		previous_event = event
		cue(event,shots,interest,subject)
	if fisher.outcome != previous_outcome:
		previous_outcome = fisher.outcome
		if fisher.outcome == FightSession.Outcome.LANDED: cue("landing",["wide","fisher"],3,"boat")
	if fish.feeding.bait_eaten != previous_eaten:
		previous_eaten = fish.feeding.bait_eaten
		bite_hold = 2.0
		pending.clear()
	# Ordinary cuts wait for the full hold. Higher interest can interrupt after
	# 2.5 s for major events; dash, jump, bite and counter motion are protected.
	var locked = ((fish.feeding.is_dashing() and event != "hookset") or bite_hold > 0 or (fish.motion.side_time > 0 and shot_event == "side-dash") or jump_hold or reaction_hold > 0) and event != "hookset"
	if not locked and not pending.is_empty() and (shot_age >= hold_time or (int(pending.priority) >= 3 and int(pending.priority) > priority and shot_age >= 2.5)):
		select_pending(fish)
	elif not locked and shot_age >= hold_time and pending.is_empty():
		if fish.heading.dot(last_heading) < 0.25: event_name = "course-change"
		else: event_name = event
		cue(event_name,shots,interest,subject,true)
		if not pending.is_empty(): select_pending(fish)

func select_pending(fish: FishPlayer) -> void:
	shot_event = pending.get("event","external")
	var changed = pending.shot != view.SHOTS[view.mode]
	if changed:
		recent_families.append(family(view.SHOTS[view.mode]))
		if recent_families.size() > 2: recent_families.pop_front()
		view.set_shot(pending.shot,shot_event in ["hookset","breach","counter","landing"])
	if shot_event in ["ascent","breach"]: jump_hold = true
	if shot_event == "counter": reaction_hold = 2.5
	hold_time = pending.duration
	priority = pending.priority
	preferred_subject = pending.subject
	pending.clear()
	shot_age = 0
	last_heading = fish.heading
	if not changed: return
	distance_scale = rng.randf_range(0.85,1.2)
	height_offset = rng.randf_range(-1.3,2.0)
	side = -1 if rng.randf() < 0.5 else 1
	fov_offset = rng.randf_range(-3,3)
	rear_offset = rng.randf_range(-3,3)

func compose(fish: FishPlayer, fisher: FisherActor, target: Vector3, desired: Vector3) -> Dictionary:
	var shot = view.SHOTS[view.mode]
	var fighting = is_instance_valid(fisher.fight)
	var jumping = jump_hold or fish.airborne or fish.motion.ascent_power > 0.1
	if shot == "wide" and jumping:
		# A jump wide frames the Fish/waterline, never the full boat separation.
		target = fish.position
		desired = fish.position+Vector3(16*side,7,15)*distance_scale
	elif shot == "wide" and preferred_subject == "boat":
		target = fisher.position+Vector3.UP
		desired = fisher.position+Vector3(12*side,9,16)*distance_scale
	elif shot == "wide" and not fighting and preferred_subject != "boat":
		target = fish.position+fish.heading*3
		desired = fish.position+Vector3(16*side,9+height_offset,19)*distance_scale
	elif shot != "fisher" and shot != "wide":
		target = fish.position+fish.heading*2
		if preferred_subject == "prey" and is_instance_valid(prey) and fish.position.distance_to(prey.position) < 24:
			target = fish.position.lerp(prey.position,0.35)
			desired += (desired-fish.position).normalized()*minf(5,fish.position.distance_to(prey.position)*0.2)
		desired = fish.position+(desired-fish.position)*distance_scale+Vector3.UP*height_offset
		if shot == "fish-side" or shot == "fish-front":
			var right = BaitMotion.horizontal(fish.heading).cross(Vector3.UP)
			desired -= right*(desired-fish.position).dot(right)*(1-side)
	if family(shot) == "rear":
		desired += BaitMotion.horizontal(fish.heading).cross(Vector3.UP)*rear_offset
	if jumping and shot in ["fish-side","fish-front","fish-rear","fish"]:
		target = fish.position+Vector3.UP*0.7
		desired.y = fish.position.y+0.5 # Stay close/low during ascent and fall.
	var surface_shot = shot == "fisher" or (shot == "wide" and (fighting or preferred_subject == "boat"))
	if surface_shot: desired.y = maxf(desired.y,fisher.position.y+2)
	return {"target":target,"position":desired,"fov":(60 if shot == "fisher" else 75 if shot == "wide" else 68)+fov_offset,"surface":surface_shot}

func protect_camera(fish: FishPlayer, fisher: FisherActor, target: Vector3, surface_shot: bool) -> Vector3:
	var camera = view.camera
	var anchor = (fish.position+Vector3.UP*2 if jump_hold or fish.airborne else fisher.position+Vector3.UP*3) if surface_shot else fish.position
	var space = fish.get_world_3d().direct_space_state
	# Sphere sweep catches terrain/rocks along the full camera path (mask 1),
	# independent of flat-floor assumptions. Gameplay actors are excluded.
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = clearance
	query.collision_mask = 1
	query.exclude = [fish.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY,anchor)
	query.motion = camera.position-anchor
	var safe = space.cast_motion(query)
	if safe[0] < 1: camera.position = anchor+query.motion*maxf(0,safe[0]-0.03)
	# Boat is visual geometry, so give its hull a conservative clearance volume.
	var boat_offset = camera.position-fisher.position
	if absf(boat_offset.y) < 1.5 and Vector2(boat_offset.x,boat_offset.z).length() < 4:
		camera.position.y = fisher.position.y+2
	if surface_shot: camera.position.y = maxf(camera.position.y,fisher.position.y+1.5)
	var ray = PhysicsRayQueryParameters3D.create(fish.position,camera.position,1,[fish.get_rid()])
	var obstruction = space.intersect_ray(ray)
	if not obstruction.is_empty() and not surface_shot:
		camera.position = obstruction.position+obstruction.normal*0.5
	var bad = camera.position.distance_to(fish.position) < 1.2 or not obstruction.is_empty()
	if bad and safety_cooldown <= 0:
		view.set_shot("fish-rear")
		preferred_subject = "fish"
		hold_time = 3
		shot_age = 0
		safety_cooldown = 3
		pending.clear()
		query.transform.origin = fish.position
		query.motion = -BaitMotion.horizontal(fish.heading)*8+Vector3.UP*3
		var fallback_safe = space.cast_motion(query)
		camera.position = fish.position+query.motion*maxf(0,fallback_safe[0]-0.03)
		target = fish.position
	# Keep framing on the fish when a lagging/prey-centered view loses it.
	var frame = Rect2(Vector2.ZERO,camera.get_viewport().get_visible_rect().size).grow(-60)
	if camera.is_position_behind(fish.position) or not frame.has_point(camera.unproject_position(fish.position)):
		target = fish.position
	return target
