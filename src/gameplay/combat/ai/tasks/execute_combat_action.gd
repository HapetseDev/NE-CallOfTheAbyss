@tool
extends BTAction

func _tick(delta: float) -> Status:
	return agent.execute_plan(delta)
