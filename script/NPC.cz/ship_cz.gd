extends Node2D


# ============================================================
# VARIABLES
# ============================================================

var helm: bool = false
var sail: bool = false
var planks: bool = false

var helm_repaired: bool = false
var sail_repaired: bool = false
var planks_repaired: bool = false


# ============================================================
# NODES
# ============================================================

@onready var helm_text: Label = $helm/helm_text
@onready var sail_text: Label = $sail/sail_text
@onready var planks_text: Label = $planks/planks_text

@onready var helm_anim: AnimatedSprite2D = $helm_anim
@onready var sail_anim: AnimatedSprite2D = $sail_anim
@onready var planks_anim: AnimatedSprite2D = $planks_anim


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Руль и парус изначально не установлены
	helm_anim.hide()
	sail_anim.hide()

	# Корпус изначально сломан
	planks_anim.play("default")

	update_prompts()


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("E"):
		try_repair()

	update_prompts()


# ============================================================
# REPAIR
# ============================================================

func try_repair() -> void:

	# РУЛЬ
	if helm and not helm_repaired:
		if Global.helm:
			helm_repaired = true
			Global.helm = false

			helm_anim.show()

			print("Kormidelní kolo nainstalováno")

			check_ship()

		return


	# ПАРУС
	if sail and not sail_repaired:
		if Global.parus:
			sail_repaired = true
			Global.parus = false

			sail_anim.show()

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


# ============================================================
# TEXT
# ============================================================

func update_prompts() -> void:

	# РУЛЬ
	if helm and not helm_repaired:
		helm_text.show()

		if Global.helm:
			helm_text.text = "E — nainstalovat kormidelní kolo"
		else:
			helm_text.text = "Je potřeba kormidelní kolo"
	else:
		helm_text.hide()


	# ПАРУС
	if sail and not sail_repaired:
		sail_text.show()

		if Global.parus:
			sail_text.text = "E — nainstalovat plachtu"
		else:
			sail_text.text = "Je potřeba plachta"
	else:
		sail_text.hide()


	# ДОСКИ
	if planks and not planks_repaired:
		planks_text.show()

		if Global.bamboo_boards:
			planks_text.text = "E — opravit trup"
		else:
			planks_text.text = "Jsou potřeba prkna"
	else:
		planks_text.hide()


# ============================================================
# CHECK SHIP
# ============================================================

func check_ship() -> void:
	if helm_repaired and sail_repaired and planks_repaired:
		print("================================")
		print("LOĎ JE KOMPLETNĚ OPRAVENA!")
		print("================================")


# ============================================================
# MAIN AREA
# ============================================================

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		print("----- INVENTORY -----")
		print("kormidelní kolo: " + str(Global.helm))
		print("plachta: " + str(Global.parus))
		print("bambusová prkna: " + str(Global.bamboo_boards))
		print("---------------------")


# ============================================================
# HELM
# ============================================================

func _on_helm_body_entered(body: Node2D) -> void:
	if body.name == "player":
		helm = true
		update_prompts()


func _on_helm_body_exited(body: Node2D) -> void:
	if body.name == "player":
		helm = false
		update_prompts()


# ============================================================
# SAIL
# ============================================================

func _on_sail_body_entered(body: Node2D) -> void:
	if body.name == "player":
		sail = true
		update_prompts()


func _on_sail_body_exited(body: Node2D) -> void:
	if body.name == "player":
		sail = false
		update_prompts()


# ============================================================
# PLANKS
# ============================================================

func _on_planks_body_entered(body: Node2D) -> void:
	if body.name == "player":
		planks = true
		update_prompts()


func _on_planks_body_exited(body: Node2D) -> void:
	if body.name == "player":
		planks = false
		update_prompts()
