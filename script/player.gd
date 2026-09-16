extends CharacterBody2D

@export var speed: float = 100.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "down"

func _physics_process(_delta: float) -> void:
	# Используем твои кастомные действия из Input Map
	var input_vector := Input.get_vector("A", "D", "W", "S")
	
	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * speed
		update_animation(input_vector, true)
	else:
		velocity = Vector2.ZERO
		update_animation(Vector2.ZERO, false)
	
	move_and_slide()

func update_animation(dir: Vector2, is_moving: bool) -> void:
	if is_moving:
		if abs(dir.x) > abs(dir.y):
			if dir.x > 0:
				last_direction = "rigth"
			else:
				last_direction = "left"
		else:
			if dir.y > 0:
				last_direction = "down"
			else:
				last_direction = "top"
		
		animated_sprite.play(last_direction)
	else:
		animated_sprite.play("idle_" + last_direction)
