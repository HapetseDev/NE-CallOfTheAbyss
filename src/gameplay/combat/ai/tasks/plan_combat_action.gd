@tool
extends BTAction

func _tick(_delta: float) -> Status:
	return SUCCESS if agent.plan_turn() else FAILURE
