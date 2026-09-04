class_name StateCombatWait extends State

## Aktiv, solange ein Kampfteilnehmer nicht am Zug ist. Blockiert freie
## Bewegung/E-Menü (ist current_state statt Idle/Walk), ohne den globalen
## GameState-Input-Lock zu nutzen – unbeteiligte Charaktere laufen normal
## weiter. Der Ausstieg passiert entweder über turn_started (-> CombatTurn)
## oder extern über Playable.exit_combat_mode() (-> Idle), wenn der Kampf endet.

@onready var combat_turn: State = $"../CombatTurn"

var _session: CombatSession = null


func enter() -> void:
	player.stop_horizontal_velocity()
	player.update_animation("idle")
	_session = player.get_combat_session()
	if _session and not _session.turn_started.is_connected(_on_turn_started):
		_session.turn_started.connect(_on_turn_started)


func exit() -> void:
	if _session and _session.turn_started.is_connected(_on_turn_started):
		_session.turn_started.disconnect(_on_turn_started)
	_session = null


func _on_turn_started(participant: CombatParticipant) -> void:
	if participant.playable == player:
		get_parent().change_state(combat_turn)
