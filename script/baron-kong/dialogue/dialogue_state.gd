class_name DialogueState
extends RefCounted


enum Stage {
	FIRST_TWO_MESSAGES,
	INTRODUCTION,
	ASKING_EXIT,
	QUESTION_1,
	QUESTION_2,
	QUESTION_3,
	FINAL_DEAL,
	DECLINED,
	FINISHED
}


var stage: Stage = Stage.FIRST_TWO_MESSAGES

var player_message_count := 0
var question_number := 0

var wants_to_leave := false


func is_finished() -> bool:
	return (
		stage == Stage.FINISHED
		or stage == Stage.DECLINED
	)


func get_stage_name() -> String:

	match stage:

		Stage.FIRST_TWO_MESSAGES:
			return "FIRST_TWO_MESSAGES"

		Stage.INTRODUCTION:
			return "INTRODUCTION"

		Stage.ASKING_EXIT:
			return "ASKING_EXIT"

		Stage.QUESTION_1:
			return "QUESTION_1"

		Stage.QUESTION_2:
			return "QUESTION_2"

		Stage.QUESTION_3:
			return "QUESTION_3"

		Stage.FINAL_DEAL:
			return "FINAL_DEAL"

		Stage.DECLINED:
			return "DECLINED"

		Stage.FINISHED:
			return "FINISHED"

	return "UNKNOWN"
