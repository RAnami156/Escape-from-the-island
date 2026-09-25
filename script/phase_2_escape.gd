class_name Phase2Escape
extends NPCPhaseBase


# ============================================================
# PHASE 2 — ESCAPE QUESTION
# ============================================================

const NEXT_PHASE := 2

var message_count: int = 0


func get_instruction() -> String:
	return "CRITICAL INSTRUCTION: In this reply, you MUST ask the player if they want to escape this island."


func on_message_sent(_controller) -> void:
	message_count += 1

	print(
		"[QUEST] Phase 2 message count: ",
		message_count,
		"/ 1"
	)


func check_transition(_controller) -> bool:
	return message_count >= 1


func get_next_phase_type() -> int:
	return NEXT_PHASE
