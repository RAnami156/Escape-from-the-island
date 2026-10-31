extends Node2D

const GOOD_FRIENDSHIP: int = 30

const FINAL_GOOD: String = "res://scene/final_leave.tscn"
const FINAL_BAD: String = "res://scene/final2_leave.tscn"

var helm: bool = false
var sail: bool = false
var planks: bool = false

var helm_repaired: bool = false
var sail_repaired: bool = false
var planks_repaired: bool = false

var ship_ready: bool = false
var leaving: bool = false

@onready var helm_text: Label = $helm/helm_text
@onready var sail_text: Label = $sail/sail_text
@onready var planks_text: Label = $planks/planks_text
@onready var final_text: Label = $final_text

@onready var helm_anim: AnimatedSprite2D = $helm_anim
@onready var sail_anim: AnimatedSprite2D = $sail_anim
@onready var planks_anim: AnimatedSprite2D = $planks_anim

@onready var ship_area: Area2D = $Area2D


func _ready() -> void:
	helm_anim.hide()
	sail_anim.hide()
	planks_anim.play("default")

	final_text.text = "Отплыть?\nE — Да" if Global.language == "ru" else "Chcete odplout?\nE — Ano"
	final_text.hide()

	update_prompts()


func _process(_delta: float) -> void:
	if leaving:
		return

	if Global.player_can_move and Input.is_action_just_pressed("E"):
		if ship_ready:
			if is_player_near_ship():
				leave_island()
		else:
			try_repair()

	update_prompts()


func is_player_near_ship() -> bool:
	if helm or sail or planks:
		return true

	for body in ship_area.get_overlapping_bodies():
		if body.name == "player":
			return true

	return false


func try_repair() -> void:
	# РУЛЬ
	if helm and not helm_repaired:
		if Global.helm:
			helm_repaired = true
			Global.helm = false

			helm_anim.show()
			helm_anim.play("default")

			print("Kormidelní kolo nainstalováno")
			check_ship()

		return

	# ПАРУС
	if sail and not sail_repaired:
		if Global.parus:
			sail_repaired = true
			Global.parus = false

			sail_anim.show()
			sail_anim.play("default")

			print("Plachta nainstalována")
			check_ship()

		return

	# ДОСКИ
	if planks and not planks_repaired:
		if Global.bamboo_boards:
			planks_repaired = true
			Global.bamboo_boards = false

			planks_anim.play("fixed")

			print("Trup opraven")
			check_ship()

		return


func update_prompts() -> void:
	helm_text.visible = helm and not helm_repaired
	sail_text.visible = sail and not sail_repaired
	planks_text.visible = planks and not planks_repaired

	if Global.helm:
		helm_text.text = "E — установить штурвал" if Global.language == "ru" else "E — nainstalovat kormidelní kolo"
	else:
		helm_text.text = "Нужен штурвал" if Global.language == "ru" else "Je potřeba kormidelní kolo"

	if Global.parus:
		sail_text.text = "E — установить парус" if Global.language == "ru" else "E — nainstalovat plachtu"
	else:
		sail_text.text = "Нужен парус" if Global.language == "ru" else "Je potřeba plachta"

	if Global.bamboo_boards:
		planks_text.text = "E — починить корпус" if Global.language == "ru" else "E — opravit trup"
	else:
		planks_text.text = "Нужны доски" if Global.language == "ru" else "Jsou potřeba prkna"

	final_text.visible = (
		ship_ready
		and is_player_near_ship()
		and not leaving
	)


func repair_all() -> void:
	# The quick-action panel repairs the same state and visuals as normal play.
	helm_repaired = true
	sail_repaired = true
	planks_repaired = true
	helm_anim.show()
	helm_anim.play("default")
	sail_anim.show()
	sail_anim.play("default")
	planks_anim.play("fixed")
	check_ship()


func check_ship() -> void:
	if helm_repaired and sail_repaired and planks_repaired:
		ship_ready = true
		print("LOĎ JE KOMPLETNĚ OPRAVENA!")

	update_prompts()


func has_good_relationships() -> bool:
	return (
		Global.bong_friendship >= GOOD_FRIENDSHIP
		and Global.panda_friendship >= GOOD_FRIENDSHIP
	)


func leave_island() -> void:
	if leaving or not ship_ready:
		return

	SaveGame.save_game(false)
	leaving = true
	final_text.hide()

	var final_scene: String = FINAL_BAD

	if has_good_relationships():
		final_scene = FINAL_GOOD

	var error: Error = get_tree().change_scene_to_file(final_scene)

	if error != OK:
		leaving = false
		push_error("Nepodařilo se otevřít scénu: " + final_scene)
		update_prompts()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		update_prompts()


func _on_helm_body_entered(body: Node2D) -> void:
	if body.name == "player":
		helm = true
		update_prompts()


func _on_helm_body_exited(body: Node2D) -> void:
	if body.name == "player":
		helm = false
		update_prompts()


func _on_sail_body_entered(body: Node2D) -> void:
	if body.name == "player":
		sail = true
		update_prompts()


func _on_sail_body_exited(body: Node2D) -> void:
	if body.name == "player":
		sail = false
		update_prompts()


func _on_planks_body_entered(body: Node2D) -> void:
	if body.name == "player":
		planks = true
		update_prompts()


func _on_planks_body_exited(body: Node2D) -> void:
	if body.name == "player":
		planks = false
		update_prompts()
