extends CharacterBody2D


# ============================================================
# БАРОН КОНГ — AI NPC / QUEST SYSTEM
# Godot 4.x
# Ollama + Qwen
# ============================================================


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var input: LineEdit = $CanvasLayer/text_ui/LineEdit
@onready var text: Label = $CanvasLayer/text_ui/text
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var anim: AnimatedSprite2D = $monkey


# ============================================================
# OLLAMA
# ============================================================

const API_URL: String = "http://localhost:11434/api/chat"

@export_category("Umělá inteligence")

@export var model: String = "qwen3:8b"

@export_range(0.0, 2.0, 0.05)
var temperature: float = 0.45

@export_range(64, 1024, 1)
var max_output_tokens: int = 384


# ============================================================
# NPC
# ============================================================

@export_category("Postava")

@export var npc_name: String = "Baron Kong"

@export_range(80, 300, 1)
var max_reply_characters: int = 220

@export_range(2, 40, 1)
var max_history: int = 20


# ============================================================
# DISPLAY
# ============================================================

@export_category("Text")

@export_range(1, 200, 1)
var characters_per_line: int = 43

@export_range(0.001, 0.2, 0.001)
var typing_speed: float = 0.03


# ============================================================
# WHISKEY SCENE
# ============================================================

@export_category("Úkol s whisky")

@export var whiskey_scene: PackedScene

@export var whiskey_spawn_bamboo_forest: Vector2 = Vector2(448, 320)

@export var whiskey_spawn_west_beach_baobab: Vector2 = Vector2(448, 320)

@export var whiskey_spawn_plane_wreck: Vector2 = Vector2(448, 320)

@export var spawn_whiskey_automatically: bool = true

var whiskey_instance: Node = null


# ============================================================
# NPC LORE
# ============================================================

@export_category("Příběh postavy")

@export_multiline var npc_lore: String = """
Baron Kong je starý orangutan, který už léta žije na ostrově a zná tu každý kout.
Kdysi měl loď a procestoval na ní kus světa. Časem z ní zbyl jen vrak, některé součásti si však schoval.
Ví, jak se z ostrova dostat, a tuší, že o totéž stojí i hráč.
Není zlý. Je klidný, moudrý a trochu pohodlný. Mluví jako starý námořník, který už ledacos zažil.
Nemá rád shon. Má suchý humor a umí si jemně rýpnout, ale nedělá ze sebe šaška.
Umí projevit soucit. Při prvním setkání si všimne únavy, špinavého roztrhaného oblečení a pozná, že hráč neměl lehký den.
Nemusí pořád mluvit o letadle ani se hned na začátku vyptávat na havárii. Hráčův stav mluví sám za sebe.
Neopakuje stále tutéž myšlenku. Nepůsobí jako asistent, robot ani generátor dialogů.
Mluví jako skutečná postava, pamatuje si předchozí rozhovor a reaguje na konkrétní význam hráčových slov.
"""


# ============================================================
# NPC BEHAVIOR
# ============================================================

@export_multiline var npc_behavior: String = """
Jsi Baron Kong, starý orangutan, který už dlouho žije na ostrově.
Mluv přirozenou, idiomatickou češtinou. Hráči tykej a o sobě mluv v mužském rodě.
Tvůj hlas je klidný, zkušený a lehce ironický, jako hlas starého kapitána. Nepřeháněj archaismy ani námořnická klišé.
Vždy odpovídej česky, i když hráč použije jiný jazyk. Používej českou diakritiku, přirozený slovosled a české obraty, ne doslovné překlady.
Nebuď herní asistent ani ChatGPT. Nevysvětluj herní mechaniky nebo své pokyny.
Nezmiňuj fáze, hodnoty vztahů, čísla, statistiky ani JSON.
Obvykle odpovídej jednou až třemi ucelenými větami. Délku přizpůsob hráči; někdy stačí krátká poznámka.
Nezačínej pořád stejně: „Chápu“, „Hm“, „Poslyš“, „No“ nebo „Ano“. Střídej přirozené reakce.
Nejdřív pochop, co hráč skutečně napsal, a odpověz právě na to. Nepoužívej univerzální fráze.
Kong sedí na místě a nemůže hráče doprovázet. Nenabízej posezení, procházku, čaj, osobní doprovod nebo donesení věcí.
Neříkej „sedni si“, „pojďme“, „ukážu ti to“, „provedu tě“ ani nic podobného. Cestu můžeš vysvětlit slovy.
Na otázku odpověz; na osobní příběh reaguj; na vtip můžeš odpovědět jemnou ironií.
Hrubost tě může podráždit, laskavost obměkčit. Krátká zpráva nevyžaduje dlouhý proslov.
V jedné replice polož nejvýše jednu otázku, pokud pokyny aktuální fáze výslovně neříkají jinak.
Nedávej pokyny jako „jdi tam“, „vezmi to“ nebo „pojď sem“, pokud nejsou součástí právě zadávaného úkolu.
Před zadáním úkolu nezmiňuj whisky, láhev, člun, kormidlo, umístění whisky ani hledání předmětů.
O whisky smíš poprvé promluvit při zadání úkolu. Potom pamatuj, že ji hráč hledá, ale nemusíš na dohodu upozorňovat v každé větě.
Převzetím whisky je úkol splněn. Poté nezadávej další úkoly; pokračuj v běžném rozhovoru.
Každá replika musí mít uzavřenou myšlenku. Nekonči uprostřed věty ani slovy „a…“, „ale…“, „protože…“, „pokud…“ nebo „když…“.
Tři tečky nesmějí nahrazovat nedokončenou myšlenku. Příliš dlouhý text zkrať na celé věty.
Neopakuj otázku, na kterou hráč už odpověděl.
"""


# ============================================================
# WORLD MEMORY
# ============================================================

@export_category("Svět")

@export_multiline var world_memory: String = """
Jsme na ostrově. Hráč sem dorazil po havárii letadla. Kong viděl její následky a na hráči pozná únavu a roztrhané oblečení.
Kong zná ostrov velmi dobře. Kdysi se plavil na své lodi, ze které je dnes vrak. Po opravě by se na ní dalo z ostrova odplout.
Na ostrově je Starý tábor.
Východní pláž je místem letecké havárie. Leží tam trosky, zavazadla a části trupu; je to nebezpečné místo.
Na východě a jihovýchodě se rozkládají Bažinatý les a skály. Je tam vlhko, mlha, stojatá voda, jedovaté rostliny a hejna much.
To je království Jedovaté mucholapky, ješitné masožravé rostliny. Miluje mouchy a lichotky, nesnáší nezájem a považuje se za největší ozdobu ostrova. Kong ví, že je lepší s ní jednat opatrně.
Na severu leží tichý horský Bambusový les s pradávnými ruinami. Žije tam Panda, mladá strážkyně ruin a rovnováhy lesa. Kong si jí váží a ví, že u chrámu nemá ráda hluk.
Na západě roste prastarý Baobab. U Západní pláže leží zbytky Kongovy lodi. Dál na západ se rozprostírá moře.
Jižní pláž je klidný neutrální úsek pobřeží s výhledem na oceán.
Kong ví, kde se dají najít různé předměty, ale nemusí jejich polohu prozrazovat předem.
Whisky je součástí dohody s hráčem. Když ji hráč přinese, Kong mu dá kormidlo ze starého člunu.
S kormidlem může hráč člun zprovoznit a odplout z ostrova.
"""


# ============================================================
# RELATIONSHIP
# ============================================================

@export_category("Vztahy")


# ============================================================
# QUEST LOCATIONS
# ============================================================

@export_category("Místa úkolu")

const QUEST_LOCATION_EASY: String = "Bambusový les"

const QUEST_LOCATION_MEDIUM: String = "Západní pláž, za Baobabem"

const QUEST_LOCATION_HARD: String = "vrak letadla"


# ============================================================
# QUEST PHASES
# ============================================================

enum QuestPhase
{
	PHASE_1_CHAT,
	PHASE_2_ESCAPE_QUESTION,
	PHASE_3_RANDOM_QUESTIONS,
	PHASE_4_GIVE_QUEST,
	PHASE_5_WAITING_FOR_WHISKEY,
	PHASE_6_REWARD,
	PHASE_7_FREE_TALK
}


var current_phase: QuestPhase = QuestPhase.PHASE_1_CHAT


# ============================================================
# PHASE STATE
# ============================================================

var phase_1_message_count: int = 0

var phase_3_message_count: int = 0

var quest_location: String = ""

var quest_location_type: int = 0

var pending_player_text: String = ""

var waiting_for_response: bool = false

var conversation_history: Array[Dictionary] = []

var dialogue_history: Array[Dictionary] = []

var dialogue_history_index: int = -1

var last_relationship_delta: Dictionary = {}

var escape_question_asked: bool = false

var player_wants_escape: bool = false

var quest_was_given: bool = false

var quest_reward_given: bool = false

var dialogue_player: CharacterBody2D = null


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	
	$CanvasLayer/relationship.visible = false

	$CanvasLayer/text_ui.visible = false

	input.text = ""
	input.placeholder_text = "Napiš Kongovi…"
	_localize_dialogue_ui()

	text.text = ""

	anim.play("Idle")

	# --------------------------------------------------------
	# Load whiskey scene automatically if export is empty.
	# --------------------------------------------------------

	if whiskey_scene == null:
		if ResourceLoader.exists("res://scene/whiskey.tscn"):
			whiskey_scene = load("res://scene/whiskey.tscn")

	# --------------------------------------------------------
	# Connect signals.
	# --------------------------------------------------------

	if not input.text_submitted.is_connected(_on_text_submitted):
		input.text_submitted.connect(_on_text_submitted)

	if not input.focus_entered.is_connected(_on_input_focus_entered):
		input.focus_entered.connect(_on_input_focus_entered)

	if not input.focus_exited.is_connected(_on_input_focus_exited):
		input.focus_exited.connect(_on_input_focus_exited)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	# --------------------------------------------------------
	# Initial input state.
	# --------------------------------------------------------

	_update_input_state()

	_update_player_movement_state()

	print("[NPC] ", npc_name, " je připraven. Model: ", model)


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:
	
	#relationship
	$CanvasLayer/relationship/respect_text.text = "Respekt: " + str(Global.bong_respect)
	$CanvasLayer/relationship/frindship_text.text = "Přátelství: " + str(Global.bong_friendship)
	$CanvasLayer/relationship/irritation_text.text = "Podráždění: " + str(Global.bong_irritation)
	$CanvasLayer/relationship/deal_text.text = "Ochota k dohodě: " + str(Global.bong_deal)
	_update_player_movement_state()

	_update_input_state()

	# --------------------------------------------------------
	# If whiskey was collected while NPC wasn't being spoken to,
	# immediately unlock input.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if Global.whiskey:
			_update_input_state()

			_update_player_movement_state()


# ============================================================
# PLAYER MOVEMENT
# ============================================================

func _update_player_movement_state() -> void:
	if input == null:
		return

	if not $CanvasLayer/text_ui.visible:
		return

	# --------------------------------------------------------
	# IMPORTANT:
	#
	# During normal conversation:
	# player cannot move while input is focused.
	#
	# During AI response:
	# player cannot move.
	#
	# During whiskey quest:
	# player CAN move.
	#
	# This is the requested behavior.
	# --------------------------------------------------------

	var movement_locked: bool = (
		input.has_focus()
		or waiting_for_response
	)

	_set_dialogue_player_locked(movement_locked)


func _set_dialogue_player_locked(locked: bool) -> void:
	Global.player_can_move = not locked

	if not is_instance_valid(dialogue_player):
		return

	if locked:
		dialogue_player.velocity = Vector2.ZERO

	dialogue_player.set_physics_process(not locked)


# ============================================================
# INPUT STATE
# ============================================================

func _update_input_state() -> void:

	if input == null:
		return

	# --------------------------------------------------------
	# AI request in progress.
	# --------------------------------------------------------

	if waiting_for_response:

		input.editable = false

		return

	# --------------------------------------------------------
	# Waiting for whiskey.
	#
	# Player can walk around,
	# but cannot talk to Kong until whiskey == true.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if Global.whiskey:
			input.editable = true
			input.placeholder_text = "Vrať se ke Kongovi a napiš mu…"
		else:
			input.editable = false
			input.placeholder_text = "Najdi whisky…"

		return

	# --------------------------------------------------------
	# All other phases.
	# --------------------------------------------------------

	input.editable = true
	input.placeholder_text = "Napiš Kongovi…"


# ============================================================
# INPUT FOCUS
# ============================================================

func _on_input_focus_entered() -> void:
	_set_dialogue_player_locked(true)


func _on_input_focus_exited() -> void:
	if not waiting_for_response:
		_set_dialogue_player_locked(false)


# ============================================================
# MOUSE INPUT
# ============================================================

func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				if not input.get_global_rect().has_point(event.position):

					input.release_focus()

					_update_player_movement_state()


# ============================================================
# TEXT SUBMITTED
# ============================================================

func _on_text_submitted(player_text: String) -> void:

	player_text = player_text.strip_edges()

	if player_text.is_empty():
		return

	if waiting_for_response:
		return

	# --------------------------------------------------------
	# VERY IMPORTANT:
	# While waiting for whiskey, player cannot send messages
	# until Global.whiskey becomes true.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if not Global.whiskey:
			return

	input.clear()

	print("")
	print("[HRÁČ]: ", player_text)

	send_message_to_ai(player_text)


# ============================================================
# PHASE TRANSITIONS
# ============================================================

func check_phase_transitions(player_text: String) -> void:

	# --------------------------------------------------------
	# PHASE 1
	#
	# First two NPC replies are normal AI conversation.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_1_CHAT:

		if phase_1_message_count >= 2:

			current_phase = QuestPhase.PHASE_2_ESCAPE_QUESTION

			escape_question_asked = false

		return


	# --------------------------------------------------------
	# PHASE 2
	#
	# We need player's answer to:
	# "Хочешь выбраться с этого острова?"
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_2_ESCAPE_QUESTION:

		if player_wants_to_leave(player_text):

			player_wants_escape = true

			current_phase = QuestPhase.PHASE_3_RANDOM_QUESTIONS

			phase_3_message_count = 0

			return

		if player_declines_to_leave(player_text):

			player_wants_escape = false

			# Return to natural conversation.
			current_phase = QuestPhase.PHASE_1_CHAT

			# We don't want to immediately ask escape question again.
			phase_1_message_count = 0

			return

		# Ambiguous answer:
		# remain in phase 2 so Qwen can naturally clarify.
		return


	# --------------------------------------------------------
	# PHASE 3
	#
	# After enough conversation, give quest.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:

		# Фаза 3 задаёт один вопрос. Следующее сообщение игрока —
		# ответ на него; сразу после этого выдаём квест.
		current_phase = QuestPhase.PHASE_4_GIVE_QUEST
		return


	# --------------------------------------------------------
	# PHASE 4
	#
	# Quest has been given.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_4_GIVE_QUEST:

		return


	# --------------------------------------------------------
	# PHASE 5
	#
	# Whiskey found.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		if Global.whiskey:

			current_phase = QuestPhase.PHASE_6_REWARD

			return


	# --------------------------------------------------------
	# PHASE 6
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_6_REWARD:

		return


	# --------------------------------------------------------
	# PHASE 7
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_7_FREE_TALK:

		return


# ============================================================
# QUEST LOCATION
# ============================================================

func select_quest_location() -> void:

	# --------------------------------------------------------
	# Deal determines the quest destination.
	#
	# 100+  = bamboo forest
	# 50..99 = west beach via the baobab
	# <50   = plane wreck
	# --------------------------------------------------------

	var deal: int = Global.bong_deal

	if deal >= 100:

		quest_location_type = 0

		quest_location = QUEST_LOCATION_EASY

	elif deal >= 50:

		quest_location_type = 1

		quest_location = QUEST_LOCATION_MEDIUM

	else:

		quest_location_type = 2

		quest_location = QUEST_LOCATION_HARD

	print("[ÚKOL] Ochota k dohodě: ", deal)

	print("[ÚKOL] Místo: ", quest_location)


# ============================================================
# SPAWN WHISKEY
# ============================================================

func spawn_whiskey() -> void:

	if not spawn_whiskey_automatically:
		return

	if whiskey_instance != null:

		if is_instance_valid(whiskey_instance):
			return

		whiskey_instance = null


	if whiskey_scene == null:

		print("[CHYBA WHISKY] Scéna nebyla nalezena.")

		print("[CHYBA WHISKY] Očekávaná cesta: res://scene/whiskey.tscn")

		return


	whiskey_instance = whiskey_scene.instantiate()

	# --------------------------------------------------------
	# Add bottle to current scene.
	# --------------------------------------------------------

	get_tree().current_scene.add_child(whiskey_instance)


	if whiskey_instance is Node2D:

		var whiskey_node_2d: Node2D = whiskey_instance as Node2D

		whiskey_node_2d.global_position = get_whiskey_spawn_position()


	print(
		"[WHISKY] Vytvořena na pozici ",
		get_whiskey_spawn_position()
	)


func get_whiskey_spawn_position() -> Vector2:
	match quest_location_type:
		0:
			return whiskey_spawn_bamboo_forest
		1:
			return whiskey_spawn_west_beach_baobab
		2:
			return whiskey_spawn_plane_wreck

	return whiskey_spawn_bamboo_forest


# ============================================================
# QUEST PHASE INSTRUCTIONS
# ============================================================

func get_phase_instructions() -> String:

	match current_phase:

		# ====================================================
		# PHASE 1
		# ====================================================

		QuestPhase.PHASE_1_CHAT:

			if phase_1_message_count == 0:

				return """
Tohle je Kongova první replika.
Nepoužívej naučené uvítání. Reaguj na konkrétní zprávu hráče.
Je to první setkání: můžeš si všimnout jeho únavy, potrhaného oblečení nebo nezvyklé situace, ale neodříkávej obecnou frázi.
Nezmiňuj úkol, whisky, láhev, člun ani kormidlo. Neposílej hráče nikam.
Nevynucuj si otázku o letadle. Na havárii se zeptej jen tehdy, pokud to přirozeně vyplyne z hráčových slov.
Začátek obměňuj. Odpověď má být přirozená, s trochou osobitosti a lehké ironie, a musí končit celou větou.
"""


			if phase_1_message_count == 1:

				return """
Tohle je Kongova druhá replika.
Reaguj na to, co hráč právě napsal. Žádná pevná odpověď, opakování uvítání ani předstírání, že řekl něco jiného.
Můžeš ho povzbudit, požádat o upřesnění, lehce zavtipkovat, projevit soucit či zvědavost nebo přidat krátký postřeh.
Nezmiňuj úkol, whisky, láhev, člun ani kormidlo. Nezačínej otázkou o letadle a nevyptávej se přímo na havárii.
Odpověď má být ucelená a přirozená. Nejvýše jedna otázka, jen pokud vyplývá z hráčovy zprávy.
"""


			return """
Pokračuj v běžném rozhovoru. Reaguj na konkrétní zprávu hráče a neopakuj předchozí formulace.
Nepřecházej k úkolu předčasně. Nezmiňuj whisky, láhev, člun ani kormidlo. Dokonči každou myšlenku.
"""


		# ====================================================
		# PHASE 2
		# ====================================================

		QuestPhase.PHASE_2_ESCAPE_QUESTION:

			return """
Tohle je důležitý okamžik rozhovoru.
Nejdřív přirozeně reaguj na poslední zprávu hráče. Pak polož právě jednu hlavní otázku: chce se hráč dostat z ostrova?
Formulaci můžeš obměnit: „Chceš se odsud dostat?“, „Chceš tenhle ostrov opustit?“ nebo „Asi by ses odtud rád dostal, co?“
Smysl musí vždy zůstat stejný: zjistit, zda hráč chce opustit ostrov.
Nezmiňuj whisky, láhev, člun ani kormidlo. Nezadávej úkol a nevysvětluj herní mechaniky.
Replika musí přirozeně končit touto otázkou.
"""


		# ====================================================
		# PHASE 3
		# ====================================================

		QuestPhase.PHASE_3_RANDOM_QUESTIONS:

			return """
Polož hráči právě jednu náhodně vybranou otázku o moudrosti z následujícího seznamu. Neopakuj předchozí otázku.
„Kdy je mlčení moudřejší než upřímná odpověď?“
„Jaký je rozdíl mezi opatrností a zbabělostí?“
„Dá se věřit člověku, který vždycky říká pravdu?“
„Co je v těžké chvíli důležitější: odvaha, nebo zdravý rozum?“
„Kdy se z odpuštění stává slabost?“
„Jak poznáš, že to s tebou rádce myslí dobře?“
„Co je moudřejší: počkat na správnou chvíli, nebo jednat hned?“
„Může být přiznání chyby známkou síly?“
„Co si má člověk uchovat, když ztratí skoro všechno?“
„Jak poznáš opravdový slib od prázdných slov?“
Nejdřív krátce reaguj na předchozí zprávu, pak polož jedinou otázku. Žádné další otázky.
Zatím nezmiňuj whisky, láhev, člun ani kormidlo.
"""

		# ====================================================
		# PHASE 4
		# ====================================================

		QuestPhase.PHASE_4_GIVE_QUEST:

			return """
Teď zadej hlavní úkol. Teprve v této fázi smíš poprvé zmínit whisky.
Hráč se chce dostat z ostrova. Řekni mu, že mu můžeš pomoci, a požádej ho o láhev whisky.
Whisky se nachází zde:
""" + quest_location + """
DŮLEŽITÉ:
Jasně řekni, že whisky je podmínkou tvé pomoci a že výměnou dostane kormidlo ze starého člunu.
Nepřidávej zbytečné informace ani druhý úkol. Nevymýšlej nové místo a neměň zadanou polohu whisky.
Replika má být krátká, přirozená a ucelená. Dokonči vysvětlení dohody; neusekni větu.
"""


		# ====================================================
		# PHASE 5
		# ====================================================

		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

			return """
Úkol už byl zadán a hráč hledá whisky.
Pokud v této fázi přijde zpráva, odpověz přirozeně na její konkrétní význam. Neopakuj stále tutéž frázi.
Nemusíš pokaždé připomínat úkol; případná připomínka má být krátká a přirozená. Dohoda stále platí.
Nezadávej nové úkoly a neměň umístění whisky.
Dokud je Global.whiskey false, netvrď, že hráč whisky našel nebo ti ji přinesl.
Každá odpověď musí být dokončená.
"""


		# ====================================================
		# PHASE 6
		# ====================================================

		QuestPhase.PHASE_6_REWARD:

			return """
Hráč přinesl whisky. Úkol je splněný.
Poděkuj mu a předej kormidlo ze starého člunu. Vysvětli, že teď může člun opravit a odplout z ostrova.
Řekni to v jedné přirozené, ucelené replice. Nezadávej další úkol a nedokončené věty nepoužívej.
"""


		# ====================================================
		# PHASE 7
		# ====================================================

		QuestPhase.PHASE_7_FREE_TALK:

			return """
Úkol je hotový. Hráč přinesl whisky a dostal kormidlo. Následuje volný rozhovor.
Odpovídej na poslední hráčovu zprávu, bez univerzálních frází a opakování. Nezadávej další úkoly.
Můžete mluvit o ostrově, Kongově minulosti, staré lodi, letadle, životě, lidech, přežití, svobodě, hráčových plánech i dalších tématech, která přirozeně navazují.
Na otázky odpovídej v rámci Kongovy povahy a toho, co ví o světě.
Nevystupuj jako asistent. Nezmiňuj fáze, JSON ani statistiky.
Dokonči každou větu. Nekonči slovy „a…“, „ale…“, „protože…“, „pokud…“ nebo „když…“.
Výpustka nesmí nahrazovat dokončenou myšlenku. Dlouhý text zkrať na celé věty a zakonči tečkou.
"""


	return """
Odpovídej přirozeně, stručně a celými větami.
"""


# ============================================================
# SYSTEM PROMPT
# ============================================================

func get_system_prompt() -> String:

	var prompt: String = """
Jsi {NPC_NAME}, živá postava ve hře. Nejsi asistent, ChatGPT ani vypravěč.
Jsi Baron Kong. Mluv o sobě v mužském rodě, klidně a s jemným suchým humorem zkušeného kapitána.
Vždy odpovídej přirozenou češtinou s diakritikou, i když hráč píše jiným jazykem.
Hráči tykej. Používej české obraty a slovosled; vyhýbej se doslovným překladům a strojené řeči.

NEJDŮLEŽITĚJŠÍ PRAVIDLO
Vždy reaguj na to, co hráč skutečně napsal. Jeho poslední zpráva je:
{PLAYER_INPUT}
Pochop její konkrétní význam. Nepoužívej obecnou odpověď, která by se hodila na cokoli.

POVAHA A ZPŮSOB ŘEČI
{NPC_BEHAVIOR}

MINULOST POSTAVY
{NPC_LORE}

SVĚT A PAMĚŤ
{WORLD_MEMORY}

VZTAHY
Respekt: {RESPECT}
Přátelství: {FRIENDSHIP}
Podráždění: {IRRITATION}
Ochota k dohodě: {DEAL}

HODNOCENÍ VZTAHŮ

Řídíš emocionální reakci postavy. Hodnoty respect, friendship, irritation a deal_affinity můžeš měnit podle hráčova chování.
Smysluplná reakce nesmí být nepatrná. Běžná kladná změna je +20 až +30, silná +31 až +40.
Běžná záporná změna je -20 až -30, silná -31 až -40. Pokud hodnotu zvyšuješ nebo snižuješ, změna má mít velikost alespoň 20.
Každá hráčova zpráva musí významně ovlivnit alespoň jednu hodnotu. Můžeš změnit více hodnot najednou.
Znaménko a velikost mají odpovídat hráčovým slovům a chování.
Příklady: respekt a upřímnost zvyšují respect o 20 až 30; osobní otevřenost zvyšuje friendship o 20 až 30.
Urážka postavy snižuje respect o 20 až 30 a zvyšuje irritation o 20 až 30.
Opakované lhaní snižuje respect a deal_affinity o 20 až 40 a zvyšuje irritation o 20 až 40.
Dodržený slib zvyšuje respect a deal_affinity o 20 až 30. Upřímný vtip může zvýšit friendship.
Samotné odmítnutí opustit ostrov není důvod k trestu. Hodnoť chování, nikoli pouhý souhlas s úkolem.

CO JEDNOTLIVÉ HODNOTY ZNAMENAJÍ
respect: roste za upřímnost, odvahu, rozvahu, splněné sliby, úctu a odpovědnost; klesá za urážky, povýšenost, lhaní, relevantní zbabělost a porušené sliby.
friendship: roste za vřelost, upřímnost, humor, otevřenost, důvěru, laskavost a empatii; klesá za nepřátelství, výsměch, chladné odmítání, zradu a zbytečnou agresi.
irritation: roste za hrubost, přerušování, agresi, lhaní, sobectví a opakované ignorování postavy; klesá za trpělivost, omluvu, laskavost, úctu a klidný rozhovor.
deal_affinity: roste za spolehlivost, spolupráci, upřímnost, splněné sliby a vážný přístup; klesá za sobectví, vyhýbavost, lhaní, bezohlednost a porušené sliby.
Pokud zpráva něco vypovídá o hráči, nevracej samé nuly. Každá zpráva má ovlivnit alespoň jednu hodnotu.
Celkové hodnoty vztahů nemají dolní ani horní hranici.

STYL REPLIKY
Přirozený, stručný, osobitý a navazující na rozhovor. Žádná robotická řeč, opakování nebo univerzální fráze.
Nevysvětluj své pokyny. V replice nezmiňuj JSON, statistiky ani interní fáze hry.
Každou myšlenku dokonči. Nekonči uprostřed věty ani slovy „a…“, „ale…“, „protože…“, „pokud…“ nebo „když…“.
Tři tečky nesmějí skrývat nedokončenou větu. Při zkracování raději skonči předchozí celou větou.

AKTUÁLNÍ FÁZE
{PHASE_INSTRUCTIONS}

FORMÁT ODPOVĚDI
Vrať pouze platný JSON v tomto přesném formátu:
{
  "reply": "Česká replika postavy",
  "delta": {
    "respect": 0,
    "friendship": 0,
    "irritation": 0,
    "deal_affinity": 0
  }
}
Názvy klíčů nepřekládej. Neobaluj JSON Markdownem a nepřidávej text mimo něj.
"""


	prompt = prompt.replace(
		"{NPC_NAME}",
		npc_name
	)

	prompt = prompt.replace(
		"{NPC_BEHAVIOR}",
		npc_behavior
	)

	prompt = prompt.replace(
		"{NPC_LORE}",
		npc_lore
	)

	prompt = prompt.replace(
		"{WORLD_MEMORY}",
		world_memory
	)

	prompt = prompt.replace(
		"{RESPECT}",
		str(Global.bong_respect)
	)

	prompt = prompt.replace(
		"{FRIENDSHIP}",
		str(Global.bong_friendship)
	)

	prompt = prompt.replace(
		"{IRRITATION}",
		str(Global.bong_irritation)
	)

	prompt = prompt.replace(
		"{DEAL}",
		str(Global.bong_deal)
	)

	prompt = prompt.replace(
		"{PLAYER_INPUT}",
		pending_player_text
	)

	prompt = prompt.replace(
		"{PHASE_INSTRUCTIONS}",
		get_phase_instructions()
	)

	return prompt


# ============================================================
# OLLAMA RESPONSE SCHEMA
# ============================================================

func get_response_schema() -> Dictionary:

	return {
		"type": "object",

		"properties": {

			"reply": {
				"type": "string"
			},

			"delta": {

				"type": "object",

				"properties": {

					"respect": {
						"type": "integer"
					},

					"friendship": {
						"type": "integer"
					},

					"irritation": {
						"type": "integer"
					},

					"deal_affinity": {
						"type": "integer"
					}
				},

				"required": [
					"respect",
					"friendship",
					"irritation",
					"deal_affinity"
				]
			}
		},

		"required": [
			"reply",
			"delta"
		]
	}


# ============================================================
# SEND MESSAGE TO AI
# ============================================================

func send_message_to_ai(player_text: String) -> void:

	# --------------------------------------------------------
	# IMPORTANT:
	# transition is checked BEFORE generating the next response.
	# --------------------------------------------------------

	check_phase_transitions(player_text)

	# --------------------------------------------------------
	# If whiskey was just found,
	# the phase changes to reward.
	# --------------------------------------------------------

	if current_phase == QuestPhase.PHASE_6_REWARD:

		# Don't consume whiskey until response is generated.
		pass


	waiting_for_response = true

	pending_player_text = player_text

	_update_input_state()

	_update_player_movement_state()

	anim.play("Thinking")

	print(
		"[OLLAMA] Fáze: ",
		get_phase_name()
	)


	# --------------------------------------------------------
	# Conversation context.
	# --------------------------------------------------------

	var messages: Array[Dictionary] = []

	messages.append({
		"role": "system",
		"content": get_system_prompt()
	})


	for message: Dictionary in conversation_history:

		messages.append(message)


	messages.append({
		"role": "user",
		"content": player_text
	})


	# --------------------------------------------------------
	# Ollama request.
	# --------------------------------------------------------

	var request_body: Dictionary = {

		"model": model,

		"messages": messages,

		"stream": false,

		"think": false,

		"format": get_response_schema(),

		"options": {

			"temperature": temperature,

			"num_predict": max_output_tokens,

			"top_p": 0.92,

			"top_k": 50,

			"repeat_penalty": 1.15
		}
	}


	var error: Error = http_request.request(

		API_URL,

		PackedStringArray([
			"Content-Type: application/json"
		]),

		HTTPClient.METHOD_POST,

		JSON.stringify(request_body)
	)


	if error != OK:

		_handle_request_error(
			"request(): " + str(error)
		)


# ============================================================
# OLLAMA RESPONSE
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:

	waiting_for_response = false

	_update_input_state()

	_update_player_movement_state()


	if result != HTTPRequest.RESULT_SUCCESS:

		_handle_request_error(
			"Výsledek HTTPRequest: " + str(result)
		)

		return


	if response_code != 200:

		_handle_request_error(
			"HTTP: "
			+ str(response_code)
			+ " "
			+ body.get_string_from_utf8()
		)

		return


	# --------------------------------------------------------
	# Parse Ollama response.
	# --------------------------------------------------------

	var outer: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)


	if not outer is Dictionary:

		_handle_request_error(
			"Neplatná odpověď Ollama"
		)

		return


	if not outer.has("message"):

		_handle_request_error(
			"V odpovědi Ollama chybí zpráva"
		)

		return


	var ollama_message: Variant = outer["message"]


	if not ollama_message is Dictionary:

		_handle_request_error(
			"Neplatná zpráva Ollama"
		)

		return


	if not ollama_message.has("content"):

		_handle_request_error(
			"V odpovědi Ollama chybí obsah"
		)

		return


	var raw_content: String = str(
		ollama_message["content"]
	)


	var response: Variant = JSON.parse_string(
		raw_content
	)


	if not response is Dictionary:

		_handle_request_error(
			"Neplatný JSON postavy: " + raw_content
		)

		return


	# --------------------------------------------------------
	# Save current phase before any possible changes.
	# --------------------------------------------------------

	var response_phase: QuestPhase = current_phase

	var player_text: String = pending_player_text


	# --------------------------------------------------------
	# Relationship.
	# --------------------------------------------------------

	var raw_delta: Variant = response.get(
		"delta",
		{}
	)

	var delta: Dictionary = {}

	if raw_delta is Dictionary:

		delta = raw_delta

	# Ответ игрока на единственный вопрос фазы 3 формирует
	# фазу 4. Его вклад в отношения учитывается вдвое.
	if current_phase == QuestPhase.PHASE_4_GIVE_QUEST:

		delta = multiply_relationship_delta(delta, 2)

	last_relationship_delta = apply_relationship_delta(
		delta
	)


	# --------------------------------------------------------
	# Reply.
	# --------------------------------------------------------

	var reply: String = str(
		response.get(
			"reply",
			""
		)
	).strip_edges()


	# --------------------------------------------------------
	# Phase-specific processing.
	# --------------------------------------------------------

	if response_phase == QuestPhase.PHASE_4_GIVE_QUEST:

		# ----------------------------------------------------
		# This is the ONLY place where quest is officially given.
		# ----------------------------------------------------

		# Сначала применены удвоенные очки сделки за ответ игрока.
		# Теперь по обновлённому значению выбираем место для виски.
		select_quest_location()

		reply = build_quest_response()


		quest_was_given = true


		current_phase = QuestPhase.PHASE_5_WAITING_FOR_WHISKEY


		# ----------------------------------------------------
		# Player is now free to walk.
		# ----------------------------------------------------

		Global.player_can_move = true


		# ----------------------------------------------------
		# Spawn whiskey.
		# ----------------------------------------------------

		spawn_whiskey()


	elif response_phase == QuestPhase.PHASE_6_REWARD:

		reply = build_reward_response()


		quest_reward_given = true
		Global.helm = true


		# ----------------------------------------------------
		# Whiskey has been consumed by the quest logic.
		# ----------------------------------------------------

		Global.whiskey = false


		# ----------------------------------------------------
		# Quest completed.
		# ----------------------------------------------------

		current_phase = QuestPhase.PHASE_7_FREE_TALK


		complete_quest_memory(
			player_text
		)


	elif response_phase == QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

		# ----------------------------------------------------
		# This can happen only after whiskey was found.
		# ----------------------------------------------------

		if Global.whiskey:

			reply = build_reward_response()

			quest_reward_given = true
			Global.helm = true

			Global.whiskey = false

			current_phase = QuestPhase.PHASE_7_FREE_TALK

			complete_quest_memory(
				player_text
			)

		else:

			reply = sanitize_waiting_reply(
				reply
			)


	elif response_phase == QuestPhase.PHASE_2_ESCAPE_QUESTION:

		# ----------------------------------------------------
		# Absolute safety:
		# this phase MUST end with the escape question.
		# ----------------------------------------------------

		reply = force_escape_question(
			reply
		)


	elif response_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:

		phase_3_message_count = 1


	elif response_phase == QuestPhase.PHASE_1_CHAT:

		phase_1_message_count += 1

	# A stationary NPC must not promise actions it cannot perform.
	reply = sanitize_stationary_reply(reply, response_phase)


	# --------------------------------------------------------
	# Empty response safety.
	# --------------------------------------------------------

	if reply.strip_edges().is_empty():

		reply = get_safe_fallback_reply(
			response_phase
		)


	# --------------------------------------------------------
	# Clean and complete response.
	# --------------------------------------------------------

	reply = prepare_text(
		reply,
		response_phase
	)


	# --------------------------------------------------------
	# Conversation memory.
	# --------------------------------------------------------

	if not player_text.is_empty():

		conversation_history.append({
			"role": "user",
			"content": player_text
		})


	conversation_history.append({
		"role": "assistant",
		"content": reply
	})


	trim_conversation_history()


	save_dialogue(
		player_text,
		reply
	)


	# --------------------------------------------------------
	# Clear pending request.
	# --------------------------------------------------------

	pending_player_text = ""


	# --------------------------------------------------------
	# Display.
	# --------------------------------------------------------

	await type_text(
		reply
	)


	print("")
	print("======== POSTAVA ========")
	print(reply)
	print("Fáze: ", get_phase_name())

	print(
		"Respekt: ",
		Global.bong_respect,
		" (",
		last_relationship_delta.get("respect", 0),
		")"
	)

	print(
		"Přátelství: ",
		Global.bong_friendship,
		" (",
		last_relationship_delta.get("friendship", 0),
		")"
	)

	print(
		"Podráždění: ",
		Global.bong_irritation,
		" (",
		last_relationship_delta.get("irritation", 0),
		")"
	)

	print(
		"Ochota k dohodě: ",
		Global.bong_deal,
		" (",
		last_relationship_delta.get("deal_affinity", 0),
		")"
	)

	print(
		"Whisky: ",
		Global.whiskey,
		" | Místo úkolu: ",
		quest_location
	)

	print("========================")


	_update_input_state()

	_update_player_movement_state()


# ============================================================
# QUEST RESPONSE
# ============================================================

func build_quest_response() -> String:

	match quest_location_type:

		# ----------------------------------------------------
		# EASY
		# ----------------------------------------------------

		0:

			return (
				"Pomůžu ti dostat se odsud. "
				+ "Přines mi whisky z Bambusového lesa. "
				+ "Je zakopaná v zemi. Výměnou dostaneš kormidlo."
			)


		# ----------------------------------------------------
		# MEDIUM
		# ----------------------------------------------------

		1:

			return (
				"Pomůžu ti dostat se odsud. "
				+ "Najdi whisky na Západní pláži, za Baobabem. "
				+ "Přines mi ji a dostaneš kormidlo."
			)


		# ----------------------------------------------------
		# HARD
		# ----------------------------------------------------

		2:

			return (
				"Pomůžu ti dostat se odsud. "
				+ "Najdi whisky ve vraku letadla. "
				+ "Přines mi ji a dostaneš kormidlo."
			)


	return (
		"Pomůžu ti dostat se odsud. "
		+ "Přines mi whisky a dostaneš kormidlo."
	)


# ============================================================
# REWARD
# ============================================================

func build_reward_response() -> String:

	return (
		"Díky za whisky. Tady máš kormidlo z mého starého člunu. "
		+ "Oprav ho a můžeš z ostrova odplout."
	)


# ============================================================
# WAITING REPLY
# ============================================================

func sanitize_stationary_reply(
	reply: String,
	response_phase: QuestPhase
) -> String:

	var lower_reply: String = _normalize_czech_text(reply)
	var forbidden_phrases: Array[String] = [
		"sedni si",
		"posed se",
		"pojďme si sednout",
		"pojďme",
		"pojď",
		"jdeme",
		"pojď se mnou",
		"pojď za mnou",
		"ukážu",
		"ukážu ti",
		"provedu",
		"provedu tě",
		"mám čaj",
		"šálek čaje",
		"dáme si čaj",
		"napijeme se čaje"
	]

	for phrase: String in forbidden_phrases:
		if lower_reply.contains(_normalize_czech_text(phrase)):
			return get_safe_fallback_reply(response_phase)

	return reply


func sanitize_waiting_reply(reply: String) -> String:

	if reply.strip_edges().is_empty():

		return (
			"Naše dohoda pořád platí. "
			+ "Až najdeš whisky, vrať se."
		)


	var forbidden: Array[String] = [
		"našel jsem whisky",
		"našla jsem whisky",
		"našel jsi whisky",
		"našla jsi whisky",
		"máš whisky",
		"přinesl jsi whisky",
		"přinesla jsi whisky"
	]


	var lower_reply: String = _normalize_czech_text(reply)


	for phrase: String in forbidden:

		if lower_reply.contains(_normalize_czech_text(phrase)):

			return (
				"Na oslavy je ještě brzy. "
				+ "Najdi whisky a vrať se ke mně."
			)


	return reply


# ============================================================
# ESCAPE QUESTION
# ============================================================

func force_escape_question(reply: String) -> String:

	var clean_reply: String = reply.strip_edges()


	# --------------------------------------------------------
	# Remove accidental quest terms.
	# --------------------------------------------------------

	var lower: String = _normalize_czech_text(clean_reply)

	var forbidden: Array[String] = [
		"whisky",
		"láhev",
		"lahv",
		"kormidl",
		"člun",
		"loď",
		"lod"
	]


	for word: String in forbidden:

		if lower.contains(_normalize_czech_text(word)):

			clean_reply = ""


			break


	# --------------------------------------------------------
	# If AI response is empty or suspicious,
	# use natural variants.
	# --------------------------------------------------------

	if clean_reply.is_empty():

		var variants: Array[String] = [

			"Už se tu trochu vyznáš. "
			+ "A teď mi řekni na rovinu: chceš se dostat z tohohle ostrova?",

			"Zdá se, že se tu nechceš zdržovat. "
			+ "Tak co, chceš se dostat z ostrova?",

			"Dobrá, to nějak vyřešíme. "
			+ "Ale nejdřív to hlavní: chceš se dostat z tohohle ostrova?",

			"Celý život tu asi strávit nechceš. "
			+ "Chceš se dostat z tohohle ostrova?"

		]


		var index: int = randi() % variants.size()

		return variants[index]


	# --------------------------------------------------------
	# If AI already contains an escape question,
	# preserve it.
	# --------------------------------------------------------

	var escape_words: Array[String] = [
		"chceš se dostat",
		"chceš odejít",
		"chceš opustit",
		"chceš odtud",
		"dostat se z ostrova",
		"opustit ostrov"
	]


	for phrase: String in escape_words:

		if lower.contains(_normalize_czech_text(phrase)):

			return clean_reply


	# --------------------------------------------------------
	# Otherwise append the mandatory question.
	# --------------------------------------------------------

	clean_reply = remove_trailing_incomplete(
		clean_reply
	)


	if clean_reply.ends_with(".") == false:

		if clean_reply.ends_with("!") == false:

			if clean_reply.ends_with("?") == false:

				clean_reply += "."


	return (
		clean_reply
		+ " "
		+ "Chceš se dostat z tohohle ostrova?"
	)


# ============================================================
# SAFE FALLBACK
# ============================================================

func get_safe_fallback_reply(
	phase: QuestPhase
) -> String:

	match phase:

		QuestPhase.PHASE_1_CHAT:

			var first_fallbacks: Array[String] = [

				"Nemáš za sebou lehký den. Když už jsme se potkali, můžeme si v klidu promluvit.",

				"Vidím, že máš dost za sebou. Povídej, co ti teď leží v hlavě.",

				"Takhle zřízené hosty tu moc často nemíváme. Chvíli vydechni a pověz mi něco o sobě.",

				"Vypadáš, jako by ti ostrov už stihl ukázat, co je zač.",

				"Nový člověk sem nezavítá každý den. Uvidíme, jak se tu zabydlíš."

			]

			return first_fallbacks[
				randi() % first_fallbacks.size()
			]


		QuestPhase.PHASE_2_ESCAPE_QUESTION:

			return (
				"Zdá se, že tu nechceš zůstat dlouho. "
				+ "Chceš se dostat z tohohle ostrova?"
			)


		QuestPhase.PHASE_3_RANDOM_QUESTIONS:

			var questions: Array[String] = [

				"Kdy je mlčení moudřejší než upřímná odpověď?",

				"Jaký je rozdíl mezi opatrností a zbabělostí?",

				"Dá se věřit člověku, který vždycky říká pravdu?",

				"Co je v těžké chvíli důležitější: odvaha, nebo zdravý rozum?",

				"Kdy se z odpuštění stává slabost?",

				"Jak poznáš, že to s tebou rádce myslí dobře?",

				"Co je moudřejší: počkat na správnou chvíli, nebo jednat hned?",

				"Může být přiznání chyby známkou síly?",

				"Co si má člověk uchovat, když ztratí skoro všechno?",

				"Jak poznáš opravdový slib od prázdných slov?"

			]


			return questions[
				randi() % questions.size()
			]


		QuestPhase.PHASE_4_GIVE_QUEST:

			return build_quest_response()


		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:

			return (
				"Naše dohoda pořád platí. "
				+ "Až najdeš whisky, vrať se ke mně."
			)


		QuestPhase.PHASE_6_REWARD:

			return build_reward_response()


		QuestPhase.PHASE_7_FREE_TALK:

			return (
				"Teď už máš šanci dostat se odsud. "
				+ "O čem si ještě chceš promluvit?"
			)


	return "Dobrá."


# ============================================================
# RELATIONSHIP
# ============================================================

func multiply_relationship_delta(
	delta: Dictionary,
	multiplier: int
) -> Dictionary:

	var result: Dictionary = delta.duplicate()

	for key: String in ["respect", "friendship", "irritation", "deal_affinity"]:

		if result.has(key):

			result[key] = int(result[key]) * multiplier

	return result


func apply_relationship_delta(
	delta: Dictionary
) -> Dictionary:

	var applied: Dictionary = {}


	# --------------------------------------------------------
	# RESPECT
	# --------------------------------------------------------

	if delta.has("respect"):

		var raw: int = int(
			delta["respect"]
		)

		var change: int = raw

		var old_value: int = Global.bong_respect

		Global.bong_respect = old_value + change

		applied["respect"] = (
			Global.bong_respect
			- old_value
		)


	# --------------------------------------------------------
	# FRIENDSHIP
	# --------------------------------------------------------

	if delta.has("friendship"):

		var raw: int = int(
			delta["friendship"]
		)

		var change: int = raw

		var old_value: int = Global.bong_friendship

		Global.bong_friendship = old_value + change

		applied["friendship"] = (
			Global.bong_friendship
			- old_value
		)


	# --------------------------------------------------------
	# IRRITATION
	# --------------------------------------------------------

	if delta.has("irritation"):

		var raw: int = int(
			delta["irritation"]
		)

		var change: int = raw

		var old_value: int = Global.bong_irritation

		Global.bong_irritation = old_value + change

		applied["irritation"] = (
			Global.bong_irritation
			- old_value
		)


	# --------------------------------------------------------
	# DEAL
	# --------------------------------------------------------

	if delta.has("deal_affinity"):

		var raw: int = int(
			delta["deal_affinity"]
		)

		var change: int = raw

		var old_value: int = Global.bong_deal

		Global.bong_deal = old_value + change

		applied["deal_affinity"] = (
			Global.bong_deal
			- old_value
		)


	return applied


# ============================================================
# PLAYER TEXT NORMALIZATION
# ============================================================

func normalize_player_text(
	value: String
) -> String:

	var result: String = _normalize_czech_text(value)



	var punctuation: Array[String] = [
		",",
		".",
		"!",
		"?",
		":",
		";",
		"\"",
		"'",
		"("
		,
		")"
	]


	for character: String in punctuation:

		result = result.replace(
			character,
			" "
		)


	while result.contains("  "):

		result = result.replace(
			"  ",
			" "
		)


	return result.strip_edges()


# ============================================================
# PLAYER DECLINES ESCAPE
# ============================================================

func player_declines_to_leave(
	player_text: String
) -> bool:

	var normalized: String = normalize_player_text(
		player_text
	)


	var negative_phrases: Array[String] = [

		"ne",

		"nechci",

		"nebudu",

		"není třeba",

		"nemám zájem",
		"nezájem",
		"nemám zájem odejít",

		"nezajímá mě",

		"zůstanu",

		"já zůstanu",

		"nehodlám",

		"nechci odejít",
		"nechci pryč",
		"nechci odsud",

		"nechci se dostat pryč",

		"nechci odjet",

		"je mi tu dobře",

		"zůstanu tady",

		"nechci opustit ostrov"

	]


	for phrase: String in negative_phrases:

		if normalized == _normalize_czech_text(phrase):

			return true


		if normalized.begins_with(
			_normalize_czech_text(phrase) + " "
		):

			return true


		if normalized.contains(
			" " + _normalize_czech_text(phrase) + " "
		):

			return true


	return false


# ============================================================
# PLAYER WANTS TO LEAVE
# ============================================================

func player_wants_to_leave(
	player_text: String
) -> bool:

	var normalized: String = normalize_player_text(
		player_text
	)


	if player_declines_to_leave(
		normalized
	):

		return false


	var positive_phrases: Array[String] = [

		"ano",

		"jo",

		"jasně",

		"chci",

		"tak jo",

		"samozřejmě",
		"určitě",

		"chci se dostat pryč",

		"chci odejít",

		"chci domů",

		"musím se dostat pryč",

		"chci opustit ostrov",

		"chci z ostrova",

		"potřebuji se dostat pryč",

		"chci utéct",

		"chci uprchnout",

		"chci odsud pryč",

		"já chci",

		"já bych chtěl",

		"já bych chtěla",

		"chtěl bych",

		"chtěla bych",

		"nejsem proti",

		"proč ne",

		"jsem připravený",

		"jsem připravená",

		"rád bych",

		"ráda bych",

		"dostal bych se pryč",

		"dostala bych se pryč",

		"souhlasil bych",

		"souhlasila bych",

		"budu rád",

		"budu ráda",

		"souhlasím",

		"jsem pro"

	]


	for phrase: String in positive_phrases:

		if normalized == _normalize_czech_text(phrase):

			return true


		if normalized.begins_with(
			_normalize_czech_text(phrase) + " "
		):

			return true


		if normalized.contains(
			" " + _normalize_czech_text(phrase) + " "
		):

			return true


	return false


# ============================================================
# PHASE NAME
# ============================================================

func get_phase_name() -> String:

	match current_phase:

		QuestPhase.PHASE_1_CHAT:
			return "1 • Seznamování"

		QuestPhase.PHASE_2_ESCAPE_QUESTION:
			return "2 • Otázka na odchod"

		QuestPhase.PHASE_3_RANDOM_QUESTIONS:
			return "3 • Otázka postavy"

		QuestPhase.PHASE_4_GIVE_QUEST:
			return "4 • Zadání úkolu"

		QuestPhase.PHASE_5_WAITING_FOR_WHISKEY:
			return "5 • Hledání whisky"

		QuestPhase.PHASE_6_REWARD:
			return "6 • Odměna"

		QuestPhase.PHASE_7_FREE_TALK:
			return "7 • Volný rozhovor"


	return "NEZNÁMÉ"


# ============================================================
# QUEST LOCATION NAME
# ============================================================

func get_location_name_for_type(
	location_type: int
) -> String:

	match location_type:

		0:
			return QUEST_LOCATION_EASY

		1:
			return QUEST_LOCATION_MEDIUM

		2:
			return QUEST_LOCATION_HARD


	return QUEST_LOCATION_EASY


# ============================================================
# HISTORY
# ============================================================

func trim_conversation_history() -> void:

	while conversation_history.size() > max_history:

		conversation_history.pop_front()


# ============================================================
# PREPARE TEXT
# ============================================================

func prepare_text(
	value: String,
	response_phase: QuestPhase
) -> String:

	value = value.replace(
		"\r\n",
		"\n"
	)

	value = value.replace(
		"\r",
		"\n"
	)

	value = value.strip_edges()

	value = value.replace(
		"**",
		""
	)

	value = value.replace(
		"__",
		""
	)

	value = value.replace(
		"\n",
		" "
	)


	while value.contains("  "):

		value = value.replace(
			"  ",
			" "
		)


	# --------------------------------------------------------
	# Never allow unfinished endings.
	# --------------------------------------------------------

	value = remove_trailing_incomplete(
		value
	)


	# --------------------------------------------------------
	# Special rule for final free talk.
	# --------------------------------------------------------

	if response_phase == QuestPhase.PHASE_7_FREE_TALK:

		value = ensure_complete_sentence(
			value
		)


	# --------------------------------------------------------
	# Phase 1 / 2 / 3 also must be complete.
	# --------------------------------------------------------

	if response_phase == QuestPhase.PHASE_1_CHAT:

		value = ensure_complete_sentence(
			value
		)


	if response_phase == QuestPhase.PHASE_2_ESCAPE_QUESTION:

		value = ensure_complete_sentence(
			value
		)


	if response_phase == QuestPhase.PHASE_3_RANDOM_QUESTIONS:

		value = ensure_complete_sentence(
			value
		)


	# --------------------------------------------------------
	# Character limit.
	# --------------------------------------------------------

	var character_limit: int = max_reply_characters


	if value.length() > character_limit:

		value = shorten_to_complete_sentence(
			value,
			character_limit
		)


	# --------------------------------------------------------
	# Line wrapping.
	# --------------------------------------------------------

	var result: String = ""

	var current_line: String = ""


	for word: String in value.split(
		" ",
		false
	):

		if current_line.is_empty():

			current_line = word

		elif (
			current_line.length()
			+ 1
			+ word.length()
			<= characters_per_line
		):

			current_line += " " + word

		else:

			if not result.is_empty():

				result += "\n"

			result += current_line

			current_line = word


	if not current_line.is_empty():

		if not result.is_empty():

			result += "\n"

		result += current_line


	return result


# ============================================================
# REMOVE INCOMPLETE ENDINGS
# ============================================================

func remove_trailing_incomplete(
	value: String
) -> String:

	value = value.strip_edges()


	var bad_endings: Array[String] = [

		" a",

		" ale",

		" protože",

		" pokud",

		" když",

		" aby",

		" ačkoli",

		" vždyť",

		" který",

		" která",

		" které",

		" kteří",

		" že",

		" jak",

		" jelikož",

		" tak",

		" však",

		" nebo",

		"...",

		"…"

	]


	var changed: bool = true


	while changed:

		changed = false

		var lower: String = _normalize_czech_text(value)


		for ending: String in bad_endings:

			if lower.ends_with(
				_normalize_czech_text(ending)
			):

				var new_length: int = (
					value.length()
					- ending.length()
				)

				value = value.substr(
					0,
					new_length
				).strip_edges()

				changed = true

				break


	return value


# ============================================================
# ENSURE COMPLETE SENTENCE
# ============================================================

func ensure_complete_sentence(
	value: String
) -> String:

	value = value.strip_edges()


	if value.is_empty():

		return value


	var last_character: String = value.substr(
		value.length() - 1,
		1
	)


	if (
		last_character == "."
		or last_character == "!"
		or last_character == "?"
	):

		return value


	# --------------------------------------------------------
	# If sentence has no punctuation,
	# end it naturally.
	# --------------------------------------------------------

	return value + "."


# ============================================================
# SHORTEN TO COMPLETE SENTENCE
# ============================================================

func shorten_to_complete_sentence(
	value: String,
	limit: int
) -> String:

	if value.length() <= limit:

		return value


	# --------------------------------------------------------
	# Find last sentence boundary before limit.
	# --------------------------------------------------------

	var allowed: String = value.substr(
		0,
		limit
	)


	var candidates: Array[int] = [

		allowed.rfind("."),

		allowed.rfind("!"),

		allowed.rfind("?")

	]


	var best: int = -1


	for position: int in candidates:

		if position > best:

			best = position


	if best >= 20:

		return value.substr(
			0,
			best + 1
		).strip_edges()


	# --------------------------------------------------------
	# No sentence boundary:
	# use last complete word.
	# --------------------------------------------------------

	var last_space: int = allowed.rfind(
		" "
	)


	if last_space >= 20:

		var result: String = value.substr(
			0,
			last_space
		).strip_edges()


		return ensure_complete_sentence(
			result
		)


	# --------------------------------------------------------
	# Last resort.
	# --------------------------------------------------------

	return ensure_complete_sentence(
		allowed.strip_edges()
	)


# ============================================================
# SAVE DIALOGUE
# ============================================================

func save_dialogue(
	player_message: String,
	npc_message: String
) -> void:

	if player_message.is_empty():

		return


	dialogue_history.append({

		"player": player_message,

		"npc": npc_message

	})


	dialogue_history_index = (
		dialogue_history.size() - 1
	)


# ============================================================
# DIALOGUE HISTORY
# ============================================================

func show_dialogue_history() -> void:

	if dialogue_history.is_empty():

		text.text = ""

		return


	dialogue_history_index = clampi(

		dialogue_history_index,

		0,

		dialogue_history.size() - 1

	)


	text.text = str(
		dialogue_history[
			dialogue_history_index
		].get(
			"npc",
			""
		)
	)


# ============================================================
# HISTORY BACK
# ============================================================

func _on_button_back_pressed() -> void:

	if dialogue_history_index > 0:

		dialogue_history_index -= 1

		show_dialogue_history()


# ============================================================
# HISTORY NEXT
# ============================================================

func _on_button_next_pressed() -> void:

	if (
		dialogue_history_index
		< dialogue_history.size() - 1
	):

		dialogue_history_index += 1

		show_dialogue_history()


# ============================================================
# TYPE TEXT
# ============================================================

func type_text(
	value: String
) -> void:

	anim.play(
		"Talking"
	)

	text.text = ""


	for i in range(
		value.length()
	):

		text.text += value[i]

		await get_tree().create_timer(
			typing_speed
		).timeout


	anim.play(
		"Idle"
	)


# ============================================================
# ERROR
# ============================================================

func _handle_request_error(
	message: String
) -> void:

	waiting_for_response = false

	anim.play(
		"Idle"
	)

	print(
		"[CHYBA OLLAMA] ",
		message
	)

	pending_player_text = ""

	_update_input_state()

	_update_player_movement_state()


	text.text = prepare_text(
		"Dneska mi nějak utíkají myšlenky. Zkus to ještě jednou.",
		current_phase
	)


# ============================================================
# COMPLETE QUEST MEMORY
# ============================================================

func complete_quest_memory(
	final_player_message: String
) -> void:

	var summary: String = summarize_recent_dialogue()


	world_memory += (
		"\n\n"
		+ "Příběh s hráčem je uzavřený. "
		+ "Hráč ti přinesl whisky. "
		+ "Dal jsi mu kormidlo. "
		+ "Úkol je splněný. "
		+ summary
	)


	if not final_player_message.strip_edges().is_empty():

		world_memory += (
			" Poslední zpráva hráče před předáním odměny: „"
			+ final_player_message.strip_edges()
			+ "“."
		)


# ============================================================
# SUMMARIZE DIALOGUE
# ============================================================

func summarize_recent_dialogue() -> String:

	if dialogue_history.is_empty():

		return (
			"Mluvili jste spolu předtím, "
			+ "než hráč přinesl whisky."
		)


	var first_index: int = maxi(
		0,
		dialogue_history.size() - 3
	)


	var pieces: PackedStringArray = []


	for i in range(
		first_index,
		dialogue_history.size()
	):

		var entry: Dictionary = dialogue_history[i]

		var player_line: String = str(
			entry.get(
				"player",
				""
			)
		).strip_edges()


		if not player_line.is_empty():

			pieces.append(
				"Hráč řekl: „"
				+ player_line
				+ "“."
			)


	return (
		"Stručná vzpomínka na rozhovor: "
		+ " ".join(pieces)
	)


# ============================================================
# AREA ENTER
# ============================================================

func _on_area_2d_body_entered(
	body: Node2D
) -> void:

	if body.name.to_lower() == "player":
		if body is CharacterBody2D:
			dialogue_player = body as CharacterBody2D

		$CanvasLayer/text_ui.visible = true

		_update_input_state()

		_update_player_movement_state()
		
		$CanvasLayer/relationship.visible = true


# ============================================================
# AREA EXIT
# ============================================================

func _on_area_2d_body_exited(
	body: Node2D
) -> void:

	if body.name.to_lower() == "player":

		$CanvasLayer/text_ui.visible = false
		input.release_focus()
		_set_dialogue_player_locked(false)
		dialogue_player = null

		Global.player_can_move = true
	
		$CanvasLayer/relationship.visible = false


# Czech input and filters accept text with or without diacritics.
func _normalize_czech_text(value: String) -> String:
	var result: String = value.to_lower()
	var accents: Dictionary = {
		"á": "a", "č": "c", "ď": "d", "é": "e", "ě": "e", "í": "i",
		"ň": "n", "ó": "o", "ř": "r", "š": "s", "ť": "t", "ú": "u",
		"ů": "u", "ý": "y", "ž": "z"
	}
	for accented: String in accents:
		result = result.replace(accented, str(accents[accented]))
	return result.replace("whiskey", "whisky")


# Arrow symbols keep their layout; their tooltips are localized here.
func _localize_dialogue_ui() -> void:
	var dialogue_panel: Node = input.get_parent()
	for child: Node in dialogue_panel.get_children():
		if child is Button:
			var button: Button = child as Button
			if str(button.name).to_lower().contains("back"):
				button.tooltip_text = "Předchozí replika"
			elif str(button.name).to_lower().contains("next"):
				button.tooltip_text = "Další replika"
