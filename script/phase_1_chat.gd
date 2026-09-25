class_name Phase1Chat
extends NPCPhaseBase


# ============================================================
# PHASE 1 — NORMAL CHAT
# ============================================================

const NEXT_PHASE := 1

var message_count: int = 0


func get_instruction() -> String:
	return "Just respond naturally to the player's questions. Keep it brief."


func on_message_sent(_controller) -> void:
	message_count += 1

	print(
		"[QUEST] Phase 1 message count: ",
		message_count,
		"/ 2"
	)


func check_transition(_controller) -> bool:
	return message_count >= 2


func get_next_phase_type() -> int:
	return NEXT_PHASE
