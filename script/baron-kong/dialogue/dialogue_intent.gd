class_name DialogueIntent
extends RefCounted


# ============================================================
# PHRASE CHECK
# ============================================================

func contains_phrase(
	text: String,
	phrases: Array
) -> bool:

	var normalized_text: String = text.to_lower().strip_edges()

	for phrase_variant: Variant in phrases:
		var phrase: String = str(phrase_variant).to_lower().strip_edges()

		if phrase.is_empty():
			continue

		if normalized_text.contains(phrase):
			return true

	return false


# ============================================================
# YES / NO
# ============================================================

func is_yes(text: String) -> bool:

	var yes_phrases: Array = [
		"да",
		"конечно",
		"согласен",
		"согласна",
		"хочу",
		"давай",
		"пойдём",
		"пойдем",
		"конечно хочу",
		"я хочу уйти"
	]

	return contains_phrase(text, yes_phrases)


func is_no(text: String) -> bool:

	var no_phrases: Array = [
		"нет",
		"не хочу",
		"не буду",
		"отказываюсь",
		"не согласен",
		"не согласна",
		"не хочу уходить"
	]

	return contains_phrase(text, no_phrases)

# ============================================================
# QUESTION DETECTION
# ============================================================

func is_question(text: String) -> bool:

	var normalized_text: String = text.to_lower().strip_edges()

	if normalized_text.contains("?"):
		return true

	var question_words: Array = [
		"кто",
		"что",
		"где",
		"когда",
		"почему",
		"зачем",
		"как",
		"какой",
		"какая",
		"какие",
		"сколько",
		"можно ли"
	]

	return contains_phrase(normalized_text, question_words)


# ============================================================
# WHISKY
# ============================================================

func mentions_whisky(text: String) -> bool:

	var whisky_phrases: Array = [
		"виски",
		"whisky",
		"whiskey"
	]

	return contains_phrase(text, whisky_phrases)


# ============================================================
# STEERING WHEEL
# ============================================================

func mentions_steering_wheel(text: String) -> bool:

	var steering_phrases: Array = [
		"штурвал",
		"руль",
		"рулём",
		"рулем"
	]

	return contains_phrase(text, steering_phrases)


# ============================================================
# SHIP / BOAT
# ============================================================

func mentions_boat(text: String) -> bool:

	var boat_phrases: Array = [
		"лодка",
		"лодку",
		"корабль",
		"корабля",
		"судно",
		"судна"
	]

	return contains_phrase(text, boat_phrases)


# ============================================================
# BAMBOO
# ============================================================

func mentions_bamboo(text: String) -> bool:

	var bamboo_phrases: Array = [
		"бамбук",
		"бамбуковый",
		"бамбуковая",
		"бамбуковом",
		"бамбуковом лесу",
		"бамбуковый лес"
	]

	return contains_phrase(text, bamboo_phrases)


# ============================================================
# MOVEMENT COMMANDS
# ============================================================

func contains_movement_command(text: String) -> bool:

	var movement_phrases: Array = [
		"иди",
		"идём",
		"идем",
		"пойдём",
		"пойдем",
		"подойди",
		"отойди",
		"следуй",
		"поверни",
		"поворачивай",
		"беги",
		"побежали"
	]

	return contains_phrase(text, movement_phrases)
