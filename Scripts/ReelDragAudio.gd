class_name ReelDragAudio
extends Node
## Local presentation only. Input is actual spool payout in metres/second.
const LOOP_START_SECONDS: float = 2.0
const FULL_SPEED: float = 14.0
const MIN_PITCH: float = 0.75
const MAX_PITCH: float = 1.4
const VOLUME: float = 0.4
const CROSSFADE_SECONDS: float = 0.08
var sustain: AudioStreamPlayer
var ending: AudioStreamPlayer
var running: bool = false
var blend: float = 0.0
var level: float = 0.0
var end_level: float = 0
var strain: AudioStreamPlayer
var hook_whiss: AudioStreamPlayer
var hook_remaining: float = 0
var previous_phase: int = -1
var strain_level: float = 0.0

func _ready() -> void:
	sustain = AudioStreamPlayer.new()
	ending = AudioStreamPlayer.new()
	add_child(sustain)
	add_child(ending)
	var stream = load("res://Audio/DragSustain.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = int(LOOP_START_SECONDS*stream.mix_rate)
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	sustain.stream = stream
	ending.stream = load("res://Audio/DragEnd.wav")
	sustain.volume_db = -60
	ending.volume_db = -60
	strain = AudioStreamPlayer.new()
	hook_whiss = AudioStreamPlayer.new()
	add_child(strain)
	add_child(hook_whiss)
	strain.stream = mechanical_loop()
	strain.volume_db = -60
	var hook_stream = load("res://Audio/DragSustain.wav").duplicate() as AudioStreamWAV
	hook_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	hook_whiss.stream = hook_stream
	hook_whiss.pitch_scale = 2.2
	hook_whiss.volume_db = -12

func update_payout(delta: float, payout: float, audible: bool = true) -> void:
	# Changing view/ownership silences both voices; an ordinary stop plays the tail.
	if not audible:
		sustain.stop()
		ending.stop()
		running = false
		blend = 0
		level = 0
		return
	var requested = payout > (0.03 if running else 0.08)
	var effort = clampf(payout/FULL_SPEED,0,1)
	if requested and not running:
		# A quick restart during the crossfade keeps the current mechanical sound.
		if not sustain.playing: sustain.play()
	elif running and not requested:
		end_level = level
		ending.pitch_scale = sustain.pitch_scale
		ending.play()
	running = requested
	if running:
		level = lerpf(level,maxf(0.15,effort),1-exp(-delta*6))
		sustain.pitch_scale = lerpf(sustain.pitch_scale,lerpf(MIN_PITCH,MAX_PITCH,effort),1-exp(-delta*5))
	blend = move_toward(blend,1.0 if running else 0.0,delta/CROSSFADE_SECONDS)
	sustain.volume_db = linear_to_db(maxf(0.001,level*VOLUME*blend))
	ending.volume_db = linear_to_db(maxf(0.001,end_level*VOLUME*(1-blend)))
	if not running and blend <= 0: sustain.stop()
	if running and blend >= 1: ending.stop()

static func mechanical_loop() -> AudioStreamWAV:
	# Four muted ratchet clicks. Deterministic generated PCM, no external asset.
	var rate = 22050
	var frames = 8820
	var data = PackedByteArray()
	data.resize(frames*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 51
	for i in range(frames):
		var t = float(i%2205)/rate
		var click = (sin(TAU*850*t)*0.65+rng.randf_range(-1,1)*0.35)*exp(-t*180)*0.18
		data.encode_s16(i*2,int(click*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream

func update_reel_cues(delta: float, requested: float, efficiency: float, phase: int, audible: bool) -> void:
	var hook_started = phase == FightSession.Phase.IMPACT and previous_phase != phase
	previous_phase = phase
	if not audible:
		strain.stop()
		hook_whiss.stop()
		strain_level = 0
		hook_remaining = 0
		return
	var lost = clampf(1-efficiency,0,1) if requested > 0.05 else 0.0
	strain_level = lerpf(strain_level,lost,1-exp(-delta*10))
	strain.volume_db = linear_to_db(maxf(0.001,strain_level*0.35))
	strain.pitch_scale = lerpf(0.8,1.2,strain_level)
	if lost > 0.02 and not strain.playing: strain.play()
	elif lost <= 0.02 and strain_level < 0.03: strain.stop()
	if hook_started:
		hook_remaining = 0.3
		hook_whiss.play(1.5)
	hook_remaining = maxf(0,hook_remaining-delta)
	hook_whiss.volume_db = linear_to_db(maxf(0.001,0.25*minf(1,hook_remaining/0.06)))
	if hook_remaining <= 0: hook_whiss.stop()
