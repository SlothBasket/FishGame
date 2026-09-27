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
var end_level: float = 0.0

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
