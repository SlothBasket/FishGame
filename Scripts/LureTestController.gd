class_name LureTestController
extends Node
## Development-only bridge from keyboard to FishingBaitDriver intent.

var fish
var lure: BaitActor
var driver: BaitMotion.FishingBaitDriver
var active: bool = false
var anchor_position: Vector3
var spawn_position: Vector3
var mode_label: Label
var bait_parent: Node3D

func setup(owner_fish, parent: Node3D, anchor: Vector3) -> void:
	fish = owner_fish
	bait_parent = parent
	anchor_position = anchor
	spawn_position = fish.global_position + Vector3(0, 2, -8)
	driver = BaitMotion.FishingBaitDriver.new(anchor_position)
	driver.pause_vertical_rate = -0.42
	driver.retrieve_vertical_influence = 0.12
	_spawn_lure(BaitMotion.Kind.JERKBAIT)
	_make_label(parent)

func _make_label(parent: Node) -> void:
	var layer = CanvasLayer.new()
	parent.add_child(layer)
	mode_label = Label.new()
	mode_label.position = Vector2(40, 140)
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_label.add_theme_color_override("font_color", Color("efc581"))
	layer.add_child(mode_label)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB: set_active(not active)
			KEY_Q:
				if active: driver.jerk_pressed = true
			KEY_E:
				if active: driver.jig_pressed = true
			KEY_F:
				if active: reset_lure()
			KEY_X:
				if active: switch_lure()
			KEY_1:
				if active: driver.idle_action = BaitMotion.IdleAction.LOOK
			KEY_2:
				if active: driver.idle_action = BaitMotion.IdleAction.QUIVER
			KEY_3:
				if active: driver.idle_action = BaitMotion.IdleAction.FAN
			KEY_4:
				if active: driver.idle_action = BaitMotion.IdleAction.REST
			KEY_0:
				if active: driver.idle_action = BaitMotion.IdleAction.NONE

func set_active(value: bool) -> void:
	active = value
	# Freeze player intent while testing the lure; camera remains available for viewing.
	fish.external_input = active
	if active: fish.command = FishInput.new()
	else:
		fish.external_input = false
		driver.retrieve_input = 0.0
	_update_label()

func reset_lure() -> void:
	lure.global_position = spawn_position
	lure.velocity = Vector3.ZERO
	lure.heading = Vector3.FORWARD
	driver._impulse_time = 0.0

func switch_lure() -> void:
	var next_kind = BaitMotion.Kind.JIG if lure.kind == BaitMotion.Kind.JERKBAIT else BaitMotion.Kind.JERKBAIT
	lure.queue_free()
	_spawn_lure(next_kind)

func _spawn_lure(kind: BaitMotion.Kind) -> void:
	lure = BaitActor.new()
	lure.name = "FishermanTestLure"
	lure.kind = kind
	lure.source = BaitMotion.Source.FISHERMAN
	lure.position = spawn_position
	lure.driver = driver
	lure.bitten.connect(_on_lure_bitten)
	bait_parent.add_child(lure)
	driver.pause_vertical_rate = -0.7 if kind == BaitMotion.Kind.JIG else -0.42
	_update_label()

func _on_lure_bitten(_bait, _eater) -> void:
	var kind = lure.kind
	await get_tree().create_timer(1.0).timeout
	_spawn_lure(kind)

func _physics_process(_delta: float) -> void:
	if not active:
		return
	driver.retrieve_input = Input.get_action_strength("forward")
	driver.steer_input = Input.get_axis("left", "right")

func _update_label() -> void:
	if mode_label == null:
		return
	var kind_name = "JIG" if lure != null and lure.kind == BaitMotion.Kind.JIG else "JERKBAIT"
	mode_label.text = ("LURE TEST: %s  |  W retrieve  A/D bias  Q jerk  E jig  X switch  F reset\n" % kind_name
		+ "1 look  2 quiver  3 fan  4 rest  0 clear  |  TAB return to fish") if active else "TAB  toggle fisherman-bait test"
