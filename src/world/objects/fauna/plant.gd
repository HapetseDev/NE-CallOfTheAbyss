class_name Plant extends Interactable

@export var is_schneidbar: bool = true

@onready var h_itbox: Hitbox = $HItbox


func _ready() -> void:
	super._ready()  # add_to_group("interactable")
	h_itbox.damaged.connect(take_damage)


func take_damage(_damage: int) -> void:
	queue_free()


# Prüft, ob der Spieler das Werkzeug zum Schneiden besitzt (ausgerüstet oder im Inventar)
func can_schneiden(player: Playable) -> bool:
	if not is_schneidbar:
		return false
	var w = player.equipment.get("waffe")
	if w == "Messer":
		return true
	if w is ItemData and (w as ItemData).item_id == "Messer":
		return true
	return player.has_item("Messer")


func get_actions(player: Playable) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if can_schneiden(player):
		actions.append({"label": "Schneiden", "action_id": "schneiden"})
	return actions


func perform_action(action_id: String, _player: Playable) -> void:
	if action_id == "schneiden":
		queue_free()
