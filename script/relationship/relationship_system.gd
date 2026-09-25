class_name RelationshipSystem
extends RefCounted


const MIN_VALUE := 20
const MAX_VALUE := 60


var values := {
	"respect": 30,
	"friendship": 35,
	"irritation": 25,
	"deal_affinity": 30
}


var change_limits := {
	"respect": 5,
	"friendship": 5,
	"irritation": 5,
	"deal_affinity": 5
}


func setup() -> void:

	values = {
		"respect": 30,
		"friendship": 35,
		"irritation": 25,
		"deal_affinity": 30
	}


func apply_delta(delta: Dictionary) -> Dictionary:

	var applied := {}

	for key in values.keys():

		if not delta.has(key):
			continue

		var requested := int(delta[key])

		var limit := int(
			change_limits[key]
		)

		requested = clampi(
			requested,
			-limit,
			limit
		)

		var old_value := int(values[key])

		values[key] = clampi(
			old_value + requested,
			MIN_VALUE,
			MAX_VALUE
		)

		var actual := int(values[key]) - old_value

		if actual != 0:
			applied[key] = actual

	return applied


func get_value(key: String) -> int:
	return int(values.get(key, 0))


func get_score() -> int:

	return (
		get_value("respect")
		+ get_value("friendship")
		+ get_value("deal_affinity")
		- get_value("irritation")
	)


func get_impression() -> String:

	var score := get_score()

	if score >= 115:
		return "Ну что ж... похоже, человек ты толковый. С тобой можно иметь дело."

	if score >= 90:
		return "Пожалуй, я тебя понял. Не идеальный человек, конечно, но доверять тебе можно."

	if score >= 70:
		return "Есть в тебе свои странности, но совсем безнадёжным тебя не назовёшь."

	return "Характер у тебя непростой. Но, думаю, шанс тебе дать можно."
