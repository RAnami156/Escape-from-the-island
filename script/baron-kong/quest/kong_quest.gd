class_name KongQuest
extends RefCounted


enum WhiskyLocation {
	WEST_BEACH,
	BAMBOO_FOREST,
	EAST_BEACH
}


var quest_given := false
var whisky_location: WhiskyLocation = WhiskyLocation.BAMBOO_FOREST


func choose_location(
	relationship: RelationshipSystem
) -> void:

	var deal_affinity := relationship.get_value(
		"deal_affinity"
	)

	# Локация определяется один раз.
	# После этого она больше никогда не меняется.

	if deal_affinity >= 46:

		whisky_location = WhiskyLocation.WEST_BEACH

	elif deal_affinity >= 31:

		whisky_location = WhiskyLocation.BAMBOO_FOREST

	else:

		whisky_location = WhiskyLocation.EAST_BEACH


func build_final_response(
	relationship: RelationshipSystem,
	_world_memory: String
) -> String:

	choose_location(relationship)

	var impression := relationship.get_impression()

	var location_text := get_location_text()

	return impression + " " + """
Я помогу тебе выбраться, но сначала мне нужен виски.

Найдёшь и принесёшь его мне — я отдам тебе штурвал от моей старой лодки. С ним можно будет восстановить лодку и покинуть остров.

""" + location_text


func get_location_text() -> String:

	match whisky_location:

		WhiskyLocation.WEST_BEACH:

			return """
Виски ищи у Западного пляжа. Бутылка плавает в воде недалеко от берега.
"""


		WhiskyLocation.BAMBOO_FOREST:

			return """
Виски спрятан в Бамбуковом лесу.

А вот где именно находится лес — этого я тебе пока не скажу.
"""


		WhiskyLocation.EAST_BEACH:

			return """
Виски должен быть возле места крушения у Восточного пляжа. Есть у меня подозрение, что в самолётах иногда бывает кое-что интересное.
"""


	return ""
