extends BaseLevel

# Nur für den Regressionstest: gültige Szene mit erkennbarem Aufbaufehler.
func get_default_player_spawn() -> Vector3:
	return Vector3.ZERO

func on_level_enter() -> void:
	GameState.acquire_input_lock()
	queue_free()
