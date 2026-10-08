extends Node

## Persistenter Weltzustand. Bleibt als Autoload, weil Flags und
## Input-Sperren szenenübergreifend gebraucht werden.
## Spielsysteme (Kampf, Shop, Dialog) leben unter MainGame/Systems.

var world_state := WorldState.new()
var _input_lock_count: int = 0
# Besitzergebundene Sperren ergänzen die bestehende Legacy-Zähler-API.
# Legacy release_input_lock kann diese Sperren nicht versehentlich freigeben.
var _input_leases: Dictionary = {}
var _next_input_lease: int = 1
var _loading_game: bool = false
var last_load_error: String = ""

signal game_loaded

## Sitzungsdaten aller vorhandenen Charaktere.
## Beim Levelwechsel erhalten; das Hauptmenü setzt sie beim Spielstart zurück.
var character_registry: CharacterRegistry:
	get:
		return world_state.characters


func get_flag(key: String, default: Variant = false) -> Variant:
	return world_state.flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	world_state.flags[key] = value
	world_state.sync_quest_flags()


func has_flag(key: String) -> bool:
	return world_state.flags.has(key)


func acquire_input_lock() -> void:
	_input_lock_count += 1


func release_input_lock() -> void:
	_input_lock_count = maxi(0, _input_lock_count - 1)


func acquire_input_lease(owner: StringName) -> int:
	var token := _next_input_lease
	_next_input_lease += 1
	_input_leases[token] = owner
	return token


func release_input_lease(token: int) -> bool:
	if not _input_leases.has(token):
		return false
	_input_leases.erase(token)
	return true


func is_player_input_locked() -> bool:
	return _input_lock_count > 0 or not _input_leases.is_empty()


## Erst nach Abbau der Weltfiguren oder vor einem neuen Spiel aufrufen.
## Levelwechsel innerhalb von MainGame dürfen dies nicht auslösen.
func reset_session() -> void:
	world_state.clear()
	_input_lock_count = 0
	_input_leases.clear()


## Niedrige Datenebene für Tests/Bootstrap ohne aktive Welt.
## Für vollständiges Laden inklusive Szenenwechsel load_game verwenden.
func install_world(candidate: WorldState) -> bool:
	if candidate == null or MainGame.instance != null:
		return false
	world_state = candidate
	_input_lock_count = 0
	_input_leases.clear()
	return true


## Stabile Einstiegspunkte für Dialoge und spätere Conditions/Effects.
func knows_fact(character_id: String, fact_id: String) -> bool:
	return world_state.knows_fact(character_id, fact_id)


func learn_fact(character_id: String, fact_id: String) -> bool:
	return world_state.learn_fact(character_id, fact_id)


func forget_fact(character_id: String, fact_id: String) -> bool:
	return world_state.forget_fact(character_id, fact_id)


func meets_condition(condition: Dictionary) -> bool:
	return preload("res://src/core/world/world_rules.gd").meets(world_state, condition)


func apply_effects(effects: Array) -> bool:
	return preload("res://src/core/world/world_rules.gd").apply(world_state, effects)


func apply_effects_if(conditions: Array, effects: Array) -> bool:
	return preload("res://src/core/world/world_rules.gd").apply_if(world_state, conditions, effects)


## Einheitlicher asynchroner Einstieg für spätere Menü-/Ladeoberflächen.
## Aufrufen mit: var error := await GameState.load_game(path)
func load_game(path: String) -> Error:
	if _loading_game:
		return ERR_BUSY
	_loading_game = true
	last_load_error = ""
	var result: Dictionary = await preload("res://src/core/world/world_loader.gd").load_game(self, path)
	last_load_error = result.message
	_loading_game = false
	if result.error == OK:
		game_loaded.emit()
	return result.error
