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
			print("Kormidelní kolo nainstalováno")
			check_ship()

		elif sail and not sail_repaired and Global.parus:
			sail_repaired = true
			Global.parus = false
			print("Plachta nainstalována")
			check_ship()

		elif planks and not planks_repaired and Global.bamboo_boards:
			planks_repaired = true
			Global.bamboo_boards = false
			print("Trup opraven")
			check_ship()

	update_prompts()


func update_prompts() -> void:
	helm_text.visible = helm and not helm_repaired
	sail_text.visible = sail and not sail_repaired
	planks_text.visible = planks and not planks_repaired

	helm_text.text = "E — nainstalovat kormidelní kolo" if Global.helm else "Je potřeba kormidelní kolo"
	sail_text.text = "E — nainstalovat plachtu" if Global.parus else "Je potřeba plachta"
	planks_text.text = "E — opravit trup" if Global.bamboo_boards else "Jsou potřeba prkna"


func check_ship() -> void:
	if helm_repaired and sail_repaired and planks_repaired:
		print("Loď je kompletně opravena!")
		# Zde lze povolit vyplutí.


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		print("kormidelní kolo " + str(Global.helm))
		print("plachta " + str(Global.parus))
		print("bambusová prkna " + str(Global.bamboo_boards))


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
