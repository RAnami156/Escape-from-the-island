extends Node2D

const RUSSIAN_NPC_SCRIPTS: Dictionary = {
	^"bong": preload("res://script/NPC.ru/bong.gd"),
	^"flycather": preload("res://script/NPC.ru/npc_flycatcher_ollama_ru.gd"),
	^"panda": preload("res://script/NPC.ru/npc_panda_ollama_ru.gd"),
}


func _enter_tree() -> void:
	# Select scripts before the NPCs initialize their dialogue and signals.
	if Global.language != "ru":
		return
	for npc_path: NodePath in RUSSIAN_NPC_SCRIPTS:
		_set_npc_script(get_node(npc_path), RUSSIAN_NPC_SCRIPTS[npc_path])
	$panda.sprite_path = ^"AnimatedSprite2D"


func _set_npc_script(npc: Node, localized_script: Script) -> void:
	var original_script: Script = npc.get_script()
	var scene_overrides: Dictionary = {}
	# Preserve scene-specific quest resources and coordinates, while allowing
	# the translated script to supply its own default names and dialogue.
	for property: Dictionary in original_script.get_script_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_EDITOR):
			continue
		var property_name: StringName = property.name
		var value: Variant = npc.get(property_name)
		if value != original_script.get_property_default_value(property_name):
			scene_overrides[property_name] = value

	npc.set_script(localized_script)
	for property: Dictionary in localized_script.get_script_property_list():
		if scene_overrides.has(property.name):
			npc.set(property.name, scene_overrides[property.name])
