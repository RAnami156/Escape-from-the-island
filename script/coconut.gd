extends Node2D

const DURATION := 10.0
const PICKUP_DISTANCE := 30.0
const PIXELS := [
	".....000000.....",
	"...0014442100...",
	"..014444332110..",
	".01444333322110.",
	".01443333322210.",
	"014433533532210",
	"014333533532210",
	"013333333322210",
	"013333353322210",
	"012333353222210",
	".0123333222110.",
	".0122332221110.",
	"..01122221110..",
	"...011111100...",
	".....000000....",
]
const PALETTE := [Color("362317"), Color("654026"), Color("89532e"), Color("ae7541"), Color("d3a468"), Color("281d19")]

var picked_up := false
var elapsed := 0.0
var camera: Camera2D
var original_offset := Vector2.ZERO
var effect: ShaderMaterial
var message: Label
var prompt: Label
var sparkle_time := 0.0


func _ready() -> void:
	z_index = 25
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt = Label.new()
	prompt.text = "E · Кокос" if Global.language == "ru" else "E · Kokos"
	prompt.position = Vector2(-40, -28)
	prompt.size = Vector2(80, 20)
	prompt.scale = Vector2.ONE * 0.4
	prompt.position.x = -16
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.hide()
	add_child(prompt)


func _draw() -> void:
	if picked_up:
		return
	draw_rect(Rect2(-6, 6, 13, 3), Color(0.12, 0.08, 0.03, 0.3))
	for y in PIXELS.size():
		for x in PIXELS[y].length():
			var pixel: String = PIXELS[y][x]
			if pixel != ".":
				draw_rect(Rect2(x - 7, y - 7, 1, 1), PALETTE[int(pixel)])
	# A small pixel glint sweeps between two corners while the coconut is on the sand.
	var phase := fmod(sparkle_time, 2.8)
	var shine := maxf(0.0, sin(phase / 0.85 * PI)) if phase < 0.85 else 0.0
	var corner := Vector2(-4, -5) if int(sparkle_time / 2.8) % 2 == 0 else Vector2(7, -1)
	var glint := Color(1.0, 0.95, 0.7, shine)
	draw_rect(Rect2(corner + Vector2(-2, 0), Vector2(5, 1)), glint)
	draw_rect(Rect2(corner + Vector2(0, -2), Vector2(1, 5)), glint)


func _unhandled_input(event: InputEvent) -> void:
	if not picked_up and event.is_action_pressed("E") and _can_pick_up():
		get_viewport().set_input_as_handled()
		pick_up()


func _can_pick_up() -> bool:
	return Global.player_can_move and is_instance_valid(Global.player) and Global.player.global_position.distance_to(global_position) <= PICKUP_DISTANCE


func pick_up() -> void:
	if picked_up:
		return
	camera = get_viewport().get_camera_2d()
	if camera == null:
		return
	original_offset = camera.offset
	picked_up = true
	prompt.hide()
	queue_redraw()

	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float angle = 0.0;
uniform float strength = 0.0;
void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 axis = vec3(0.57735027);
	vec3 shifted = source.rgb * cos(angle) + cross(axis, source.rgb) * sin(angle)
		+ axis * dot(axis, source.rgb) * (1.0 - cos(angle));
	COLOR = vec4(mix(source.rgb, clamp(shifted * 1.15, 0.0, 1.0), strength), source.a);
}
"""
	effect = ShaderMaterial.new()
	effect.shader = shader
	tint.material = effect
	overlay.add_child(tint)

	message = Label.new()
	_update_message()
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_font_size_override("font_size", 76)
	message.add_theme_color_override("font_outline_color", Color("281735"))
	message.add_theme_constant_override("outline_size", 14)
	overlay.add_child(message)


func _process(delta: float) -> void:
	if not picked_up:
		sparkle_time += delta
		queue_redraw()
		prompt.visible = _can_pick_up()
		return
	elapsed += delta
	if elapsed >= DURATION:
		_restore_camera()
		queue_free()
		return
	var strength := minf(elapsed / 0.8, minf(1.0, (DURATION - elapsed) / 2.0))
	if is_instance_valid(camera):
		camera.offset = original_offset + Vector2(sin(elapsed * 43.0), cos(elapsed * 31.0)) * 2.5 * strength
	effect.set_shader_parameter("angle", elapsed * 1.8)
	effect.set_shader_parameter("strength", strength * 0.85)
	_update_message()
	message.modulate = Color.from_hsv(fmod(elapsed * 0.12, 1.0), 0.4, 1.0, strength)


func _update_message() -> void:
	var seconds := ceili(maxf(0.0, DURATION - elapsed))
	message.text = ("вы занюхали кокос\nОсталось: %d с" if Global.language == "ru" else "Šňupli jste si kokos\nZbývá: %d s") % seconds


func _restore_camera() -> void:
	if is_instance_valid(camera):
		camera.offset = original_offset


func _exit_tree() -> void:
	_restore_camera()
