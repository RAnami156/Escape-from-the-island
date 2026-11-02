extends Node2D
## A self-contained discovery at the crash site. Reads Kong's position only.

const INTERACTION_DISTANCE := 62.0
const TARGET_WIDTH := 0.19
const REQUIRED_HITS := 2
const OPEN_DURATION := 0.85

var active := false
var hits := 0
var cursor := 0.0
var target_center := 0.64
var direction := 1.0
var feedback_good := false
var feedback_left := 0.0
var cooldown := 0.0
var reveal_left := 0.0
var toast_left := 0.0
var compass_angle := -PI / 2.0
var _was_open := false
var _sounds: Dictionary = {}
var _locked_player: CharacterBody2D
var _previous_physics := true

@onready var display: Control = $UI/Display
@onready var sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	light_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_priority = 10
	_was_open = Global.compass_chest_opened
	for frequency: int in [180, 640, 980]:
		_sounds[frequency] = _tone(frequency)


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	feedback_left = maxf(0.0, feedback_left - delta)
	reveal_left = maxf(0.0, reveal_left - delta)
	toast_left = maxf(0.0, toast_left - delta)
	if active:
		if not near_chest():
			close_lock()
		else:
			# Existing dialogue scripts can update the shared movement flag.
			# Own a separate physics lock without changing any NPC's behavior.
			Global.player_can_move = false
			_locked_player.set_physics_process(false)
			if cooldown <= 0.0:
				advance_cursor(delta)
	if Global.compass_chest_opened != _was_open:
		_was_open = Global.compass_chest_opened
		reveal_left = OPEN_DURATION if _was_open and not Global.compass_found else 0.0
	if Global.compass_found and is_instance_valid(Global.player):
		var offset := target_offset()
		if offset.length() > 1.0:
			compass_angle = compass_bearing()
	queue_redraw()
	display.queue_redraw()


func advance_cursor(delta: float) -> void:
	# Reflect overshoot too, so a slow frame cannot leave the cursor off the bar.
	cursor += direction * delta * (0.70 + hits * 0.12)
	while cursor < 0.0 or cursor > 1.0:
		if cursor > 1.0:
			cursor = 2.0 - cursor
			direction = -1.0
		elif cursor < 0.0:
			cursor = -cursor
			direction = 1.0


func near_chest() -> bool:
	return is_instance_valid(Global.player) and Global.player.global_position.distance_to(global_position) <= INTERACTION_DISTANCE


func can_interact() -> bool:
	if not near_chest() or not Global.player_can_move or get_tree().paused:
		return false
	var focused := get_viewport().gui_get_focus_owner()
	return not (focused is LineEdit or focused is TextEdit)


func target_offset() -> Vector2:
	var target := get_parent().get_node_or_null("bong") as Node2D
	if target == null or not is_instance_valid(Global.player):
		return Vector2.ZERO
	return target.global_position - Global.player.global_position


func compass_bearing() -> float:
	if not is_instance_valid(Global.player) or target_offset().is_zero_approx():
		return compass_angle
	# Match the direction on screen; turning the character does not rotate the dial.
	return get_viewport().get_canvas_transform().basis_xform(target_offset()).angle()


func moving_toward_kong() -> bool:
	if not is_instance_valid(Global.player) or not Global.player_can_move or get_tree().paused:
		return false
	if not Global.player.is_physics_processing() or target_offset().is_zero_approx():
		return false
	# Actual movement after collisions: pushing against a wall must not turn green.
	return Global.player.get_real_velocity().dot(target_offset().normalized()) > 1.0


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("esc"):
		close_lock()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab"):
		# Hand Tab back to the existing settings menu after releasing our lock.
		close_lock()
		return
	if event is InputEventKey and event.physical_keycode in [KEY_F5, KEY_F9]:
		return
	if event.is_action_pressed("E") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE):
		attempt_hit()
	# Keep chat shortcuts and clicks from stealing focus/movement during the puzzle.
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if active or not event.is_action_pressed("E") or not can_interact() or Global.compass_found:
		return
	get_viewport().set_input_as_handled()
	if Global.compass_chest_opened:
		if reveal_left <= 0.0:
			collect_compass()
	else:
		open_lock()


func open_lock() -> void:
	if active or Global.compass_chest_opened or not can_interact():
		return
	active = true
	hits = 0
	cursor = 0.05
	direction = 1.0
	target_center = 0.64
	cooldown = 0.18
	feedback_left = 0.0
	Global.player_can_move = false
	Global.player.velocity = Vector2.ZERO
	_locked_player = Global.player
	_previous_physics = _locked_player.is_physics_processing()
	_locked_player.update_animation(Vector2.ZERO, false)
	_locked_player.set_physics_process(false)
	display.mouse_filter = Control.MOUSE_FILTER_STOP
	display.queue_redraw()


func close_lock() -> void:
	if not active:
		return
	active = false
	Global.player_can_move = true
	if is_instance_valid(_locked_player):
		_locked_player.set_physics_process(_previous_physics)
	_locked_player = null
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.queue_redraw()


func attempt_hit() -> void:
	if not active or cooldown > 0.0:
		return
	feedback_good = absf(cursor - target_center) <= TARGET_WIDTH / 2.0
	feedback_left = 0.85
	cooldown = 0.3
	if not feedback_good:
		_play(180)
		return
	hits += 1
	_play(640)
	if hits >= REQUIRED_HITS:
		Global.compass_chest_opened = true
		reveal_left = OPEN_DURATION
		close_lock()
		SaveGame.save_game(false)
	else:
		target_center = 0.34
		cursor = 0.95
		direction = -1.0


func collect_compass() -> void:
	if Global.compass_found or not Global.compass_chest_opened or reveal_left > 0.0 or not can_interact():
		return
	Global.compass_found = true
	compass_angle = compass_bearing()
	toast_left = 5.5
	_play(980)
	SaveGame.save_game(false)


func _exit_tree() -> void:
	if active:
		Global.player_can_move = true
		if is_instance_valid(_locked_player):
			_locked_player.set_physics_process(_previous_physics)


func _play(frequency: int) -> void:
	sound.stream = _sounds[frequency]
	sound.play()


func _tone(frequency: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := 2646
	var data := PackedByteArray()
	data.resize(samples * 2)
	for index in samples:
		var envelope := sin(PI * float(index) / samples)
		data.encode_s16(index * 2, int(sin(TAU * frequency * index / 22050.0) * envelope * 14000.0))
	stream.data = data
	return stream


func _draw() -> void:
	var opened := Global.compass_chest_opened
	var progress := 1.0 - clampf(reveal_left / OPEN_DURATION, 0.0, 1.0) if opened else 0.0
	var lift := 1.0 - pow(1.0 - progress, 3.0)
	var edge := Color("392a24")
	var wood := Color("a97044")
	var light := Color("d2a06a")
	var shade := Color("795034")
	var gold := Color("e4c278")
	draw_rect(Rect2(-15, 9, 32, 4), Color(0, 0, 0, 0.16))
	# Plain wood, one latch and small corner caps.
	draw_rect(Rect2(-17, -1, 34, 11), edge)
	draw_rect(Rect2(-15, 10, 30, 2), edge)
	draw_rect(Rect2(-15, 1, 30, 7), wood)
	draw_rect(Rect2(-15, 7, 30, 3), shade)
	for x: int in [-15, 12]:
		draw_rect(Rect2(x, 6, 3, 4), gold)
	# The lid pivots around the back edge, exposing the dark interior.
	draw_rect(Rect2(-17, -12, 34, 13), edge)
	draw_rect(Rect2(-15, -10, 30, 9), Color("50382c"))
	var pulse := sin(progress * PI)
	if opened and not Global.compass_found:
		draw_rect(Rect2(-12, -9, 24, 8), Color(1.0, 0.8, 0.4, pulse * 0.3))
	var tilt := cos(lift * 2.45)
	# Avoid a singular transform as the lid passes through its edge-on position.
	if absf(tilt) > 0.02:
		draw_set_transform(Vector2(0, -12), 0.0, Vector2(1.0, tilt))
		draw_rect(Rect2(-15, 0, 30, 13), edge)
		draw_rect(Rect2(-17, 2, 34, 9), edge)
		draw_rect(Rect2(-15, 2, 30, 9), wood if tilt > 0.0 else shade)
		draw_rect(Rect2(-13, 2, 26, 2), light)
		draw_rect(Rect2(-15, 9, 30, 2), shade)
		draw_rect(Rect2(-3, 8, 6, 7), edge)
		draw_rect(Rect2(-2, 9, 4, 5), gold)
		draw_rect(Rect2(-1, 10, 2, 2), edge)
		draw_set_transform(Vector2.ZERO)
	if opened and not Global.compass_found:
		var reveal := smoothstep(0.25, 1.0, progress)
		draw_set_transform(Vector2(0, lerpf(1.0, -7.0, reveal)))
		draw_rect(Rect2(-3, -5, 6, 10), Color(edge, reveal))
		draw_rect(Rect2(-5, -3, 10, 6), Color(edge, reveal))
		draw_rect(Rect2(-3, -3, 6, 6), Color(gold, reveal))
		draw_rect(Rect2(-1, -3, 2, 3), Color(Color("b94b40"), reveal))
		draw_rect(Rect2(-1, 0, 2, 3), Color(Color("637c91"), reveal))
		draw_set_transform(Vector2.ZERO)
		# Three brief pixel glints follow the compass as it rises.
		for point: Vector2 in [Vector2(-9, -6), Vector2(9, -10), Vector2(0, -18)]:
			var glint := point + Vector2(0, -4.0 * lift)
			var color := Color(gold, pulse * 0.8)
			draw_rect(Rect2(glint - Vector2(2, 0), Vector2(5, 1)), color)
			draw_rect(Rect2(glint - Vector2(0, 2), Vector2(1, 5)), color)
