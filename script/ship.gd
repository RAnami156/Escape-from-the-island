extends Node2D

var helm: bool = false
var sail: bool = false
var planks: bool = false

var helm_repaired: bool = false
var sail_repaired: bool = false
var planks_repaired: bool = false

@onready var helm_text: Label = $helm_text
@onready var sail_text: Label = $sail_text
@onready var planks_text: Label = $planks_text


func _ready() -> void:
	update_prompts()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("E"):
		if helm and not helm_repaired and Global.helm:
			helm_repaired = true
			Global.helm = false
			print("Штурвал установлен")
			check_ship()

		elif sail and not sail_repaired and Global.parus:
			sail_repaired = true
			Global.parus = false
			print("Парус установлен")
			check_ship()

		elif planks and not planks_repaired and Global.bamboo_boards:
			planks_repaired = true
			Global.bamboo_boards = false
			print("Корпус починен")
			check_ship()

	update_prompts()


func update_prompts() -> void:
	helm_text.visible = helm and not helm_repaired
	sail_text.visible = sail and not sail_repaired
	planks_text.visible = planks and not planks_repaired

	helm_text.text = "E — установить штурвал" if Global.helm else "Нужен штурвал"
	sail_text.text = "E — установить парус" if Global.parus else "Нужен парус"
	planks_text.text = "E — починить корпус" if Global.bamboo_boards else "Нужны доски"


func check_ship() -> void:
	if helm_repaired and sail_repaired and planks_repaired:
		print("Корабль полностью починен!")
		# Здесь можно разрешить отплытие.


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		print("helm " + str(Global.helm))
		print("parus " + str(Global.parus))
		print("bamboo_boards " + str(Global.bamboo_boards))


func _on_helm_body_entered(body: Node2D) -> void:
	if body.name == "player":
		helm = true


func _on_helm_body_exited(body: Node2D) -> void:
	if body.name == "player":
		helm = false


func _on_sail_body_entered(body: Node2D) -> void:
	if body.name == "player":
		sail = true


func _on_sail_body_exited(body: Node2D) -> void:
	if body.name == "player":
		sail = false


func _on_planks_body_entered(body: Node2D) -> void:
	if body.name == "player":
		planks = true


func _on_planks_body_exited(body: Node2D) -> void:
	if body.name == "player":
		planks = false
