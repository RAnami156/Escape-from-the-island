extends Node2D

var player_in_area: bool = false
var player: Node2D = null
var picked_up: bool = false


func _process(_delta: float) -> void:
	if player_in_area and not picked_up:
		if Input.is_key_pressed(KEY_E):
			pick_up()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		player_in_area = true
		player = body


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "player":
		player_in_area = false
		player = null


func pick_up() -> void:
	if picked_up:
		return

	picked_up = true

	# Добавляем виски в глобальный инвентарь
	Global.whiskey = true

	# Если игрок существует — бутылка подлетает к нему
	if player != null:
		var tween := create_tween()

		tween.set_parallel(true)

		# Подлетаем к игроку
		tween.tween_property(
			self,
			"global_position",
			player.global_position,
			0.35
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

		# Немного увеличиваем предмет
		tween.tween_property(
			self,
			"scale",
			Vector2(1.3, 1.3),
			0.15
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Плавно исчезаем
		tween.tween_property(
			self,
			"modulate:a",
			0.0,
			0.25
		).set_delay(0.1)

		await tween.finished

	# Удаляем предмет со сцены
	queue_free()
	print(Global.whiskey)
