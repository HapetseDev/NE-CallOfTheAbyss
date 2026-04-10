class_name Playable extends CharacterBody3D

# --- Bewegung ---
var cardinal_direction: Vector3 = Vector3(0, 0, 1)  # DOWN
var direction: Vector3 = Vector3.ZERO
const DIR_4 = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]

# --- Nodes (optional – werden nur genutzt wenn vorhanden) ---
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var sprite_3d: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D

# Optionales Schrittsound-System (wird von abgeleiteten Klassen gesetzt)
var footstep_player: FootstepPlayer

signal direction_changed(new_direction: Vector3)

# --- Stats ---
@export var max_health: int = 100
var _health: int = 0
var health: int:
	get: return _health
	set(value): _health = clampi(value, 0, max_health)

@export var max_mana: int = 50
var _mana: int = 0
var mana: int:
	get: return _mana
	set(value): _mana = clampi(value, 0, max_mana)

var experience: int = 0
var level: int = 1
@export var experience_per_level: int = 100

# --- Skills ---
var skills: Array[String] = []

# --- Talente (Name -> Stufe) ---
var talente: Dictionary[String, int] = {}

# --- Inventar ---
var inventory: Array = []

# --- Ausrüstung ---
var equipment: Dictionary = {
	"kopf":    null,
	"rumpf":   null,
	"waffe":   null,
	"nebenhand": null,
	"beine":   null,
	"füße":    null,
}


func _ready() -> void:
	health = max_health
	mana = max_mana


func _process(_delta: float) -> void:
	direction = get_move_direction()


func _physics_process(_delta: float) -> void:
	move_and_slide()


# Wird von Player (Input) und NPC (KI) überschrieben
func get_move_direction() -> Vector3:
	return Vector3.ZERO


# --- Bewegungs-Hilfsmethoden ---

func set_direction() -> bool:
	if direction == Vector3.ZERO:
		return false
	var dir_2d := Vector2(direction.x, direction.z)
	var cardinal_2d := Vector2(cardinal_direction.x, cardinal_direction.z)
	var direction_id := int(round((dir_2d + cardinal_2d * 0.1).angle() / TAU * DIR_4.size()))
	var new_dir: Vector3 = DIR_4[direction_id]
	if new_dir == cardinal_direction:
		return false
	cardinal_direction = new_dir
	direction_changed.emit(new_dir)
	if sprite_3d:
		sprite_3d.flip_h = true if cardinal_direction == Vector3(-1, 0, 0) else false
	return true


func update_animation(state: String) -> void:
	if animation_player:
		animation_player.play(state + "_" + anim_direction())


func anim_direction() -> String:
	if cardinal_direction == Vector3(0, 0, 1):
		return "down"
	elif cardinal_direction == Vector3(0, 0, -1):
		return "up"
	else:
		return "side"


# --- Kampf ---

func take_damage(amount: int) -> void:
	health -= amount


func heal(amount: int) -> void:
	health += amount


func use_mana(amount: int) -> bool:
	if _mana < amount:
		return false
	mana -= amount
	return true


func restore_mana(amount: int) -> void:
	mana += amount


# --- Erfahrung & Level ---

func gain_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_per_level * level:
		_level_up()


func _level_up() -> void:
	experience -= experience_per_level * level
	level += 1


# --- Inventar ---

func add_item(item: Variant) -> void:
	inventory.append(item)


func remove_item(item: Variant) -> bool:
	var idx := inventory.find(item)
	if idx >= 0:
		inventory.remove_at(idx)
		return true
	return false


func has_item(item: Variant) -> bool:
	return inventory.has(item)


# --- Ausrüstung ---

func equip(slot: String, item: Variant) -> void:
	if not equipment.has(slot):
		push_warning("Playable: Unbekannter Ausrüstungsslot '%s'" % slot)
		return
	equipment[slot] = item


func unequip(slot: String) -> Variant:
	if not equipment.has(slot):
		push_warning("Playable: Unbekannter Ausrüstungsslot '%s'" % slot)
		return null
	var item: Variant = equipment[slot]
	equipment[slot] = null
	return item


# --- Skills ---

func learn_skill(skill: String) -> void:
	if not skills.has(skill):
		skills.append(skill)


func has_skill(skill: String) -> bool:
	return skills.has(skill)


# --- Talente ---

func learn_talent(talent: String, stufe: int = 1) -> void:
	talente[talent] = stufe


func has_talent(talent: String) -> bool:
	return talente.has(talent)


func get_talent_stufe(talent: String) -> int:
	if talente.has(talent):
		return talente[talent]
	return 0


func steigere_talent(talent: String) -> void:
	talente[talent] = get_talent_stufe(talent) + 1
