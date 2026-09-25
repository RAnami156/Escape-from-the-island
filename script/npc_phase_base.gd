class_name NPCPhaseBase
extends RefCounted


# ============================================================
# BASE NPC QUEST PHASE
# ============================================================

## Инструкция, которая добавляется в system prompt Ollama.
func get_instruction() -> String:
	return ""


## Вызывается после успешной отправки/получения реплики NPC.
## Здесь конкретная фаза может обновить свои счетчики.
func on_message_sent(_controller) -> void:
	pass


## Проверяет, нужно ли после текущей реплики
## переключиться на следующую фазу.
func check_transition(_controller) -> bool:
	return false


## Возвращает номер следующей QuestPhase.
## -1 означает "перехода нет".
func get_next_phase_type() -> int:
	return -1
