class_name Playable extends CharacterBody3D

# --- Bewegung ---
var cardinal_direction: Vector3 = Vector3(0, 0, 1)  # Nächste Kardinalrichtung (Legacy / Sprites)
var facing_direction: Vector3 = Vector3(0, 0, 1)  # Normalisierte Blickrichtung (XZ)
var direction: Vector3 = Vector3.ZERO
const DIR_4 = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
const FACING_CHANGE_EPSILON_SQ := 0.0001

# --- Nodes (optional – werden nur genutzt wenn vorhanden) ---
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var sprite_3d: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
@onready var model_root: Node3D = get_node_or_null("Model") as Node3D

var model_animator: CharacterModelAnimator

# Optionales Schrittsound-System (wird von abgeleiteten Klassen gesetzt)
var footstep_player: FootstepPlayer

signal direction_changed(new_direction: Vector3)
signal inventar_geaendert

# --- Stats ---
@export var character_name: String = ""
## Zusatzrotation für GLTF-Modelle (Blockbench exportiert oft +Z statt Godot -Z).
@export var model_yaw_offset: float = PI
@export var gravity_enabled: bool = true
@export var gravity: float = -1.0
@export var max_fall_speed: float = 28.0
@export var max_health: int = 100
var _health: int = 0
var health: int:
	get: return _health
	set(value): _health = clampi(value, 0, max_health)

@export var gold: int = 50
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


func get_display_name() -> String:
	if not character_name.is_empty():
		return character_name
	return name


func _ready() -> void:
	if gravity < 0.0:
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	health = max_health
	mana = max_mana
	_ensure_model_animator()
	_apply_facing()


func _process(_delta: float) -> void:
	direction = get_move_direction()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not gravity_enabled:
		return
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


# Wird von Player (Input) und NPC (KI) überschrieben
func get_move_direction() -> Vector3:
	return Vector3.ZERO


func set_horizontal_velocity(horizontal: Vector3) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func stop_horizontal_velocity() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


# --- Bewegungs-Hilfsmethoden ---

func set_direction() -> bool:
	if direction == Vector3.ZERO:
		return false
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < FACING_CHANGE_EPSILON_SQ:
		return false
	flat = flat.normalized()

	var facing_changed := facing_direction.distance_squared_to(flat) > FACING_CHANGE_EPSILON_SQ
	facing_direction = flat
	_apply_facing()

	var new_cardinal := _nearest_cardinal(flat)
	var cardinal_changed := new_cardinal != cardinal_direction
	if cardinal_changed:
		cardinal_direction = new_cardinal

	if facing_changed or cardinal_changed:
		direction_changed.emit(facing_direction)
		return true
	return false


func get_facing_yaw() -> float:
	return atan2(-facing_direction.x, -facing_direction.z) + model_yaw_offset


func _apply_facing() -> void:
	if model_root:
		model_root.rotation.y = get_facing_yaw()
	elif sprite_3d:
		sprite_3d.flip_h = facing_direction.x < 0.0


func _nearest_cardinal(dir: Vector3) -> Vector3:
	var dir_2d := Vector2(dir.x, dir.z)
	var direction_id := int(round(dir_2d.angle() / TAU * DIR_4.size())) % DIR_4.size()
	return DIR_4[direction_id]


func _ensure_model_animator() -> void:
	if model_root == null:
		return
	model_animator = model_root.get_node_or_null("ModelAnimator") as CharacterModelAnimator
	if model_animator:
		return
	model_animator = CharacterModelAnimator.new()
	model_animator.name = "ModelAnimator"
	model_root.add_child(model_animator)


func _uses_model_visual() -> bool:
	return model_root != null and (sprite_3d == null or not sprite_3d.visible)


func update_animation(state: String) -> void:
	if _uses_model_visual():
		if model_animator:
			model_animator.play_state(state)
		return
	if animation_player:
		animation_player.play(state + "_" + anim_direction())


func anim_direction() -> String:
	var dir := facing_direction
	if dir.length_squared() < FACING_CHANGE_EPSILON_SQ:
		dir = cardinal_direction
	if absf(dir.z) >= absf(dir.x):
		return "down" if dir.z > 0.0 else "up"
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

func add_item(item: Variant, anzahl: int = 1) -> void:
	if item is Item:
		for slot in inventory:
			if slot is Dictionary and slot.get("item") is Item \
					and (slot["item"] as Item).item_id == (item as Item).item_id:
				slot["count"] = mini(slot["count"] + anzahl, (item as Item).max_stapel)
				inventar_geaendert.emit()
				return
		inventory.append({"item": item, "count": anzahl})
	else:
		inventory.append(item)
	inventar_geaendert.emit()


func remove_item(item: Variant, anzahl: int = 1) -> bool:
	if item is Item:
		for i in inventory.size():
			var slot = inventory[i]
			if slot is Dictionary and slot.get("item") is Item \
					and (slot["item"] as Item).item_id == (item as Item).item_id:
				slot["count"] -= anzahl
				if slot["count"] <= 0:
					inventory.remove_at(i)
				inventar_geaendert.emit()
				return true
		return false
	var idx := inventory.find(item)
	if idx >= 0:
		inventory.remove_at(idx)
		inventar_geaendert.emit()
		return true
	return false


func has_item(item: Variant) -> bool:
	if item is String:
		for slot in inventory:
			if slot is String and slot == item:
				return true
			if slot is Dictionary and slot.get("item") is Item \
					and (slot["item"] as Item).item_id == item:
				return true
		return false
	if item is Item:
		for slot in inventory:
			if slot is Dictionary and slot.get("item") is Item \
					and (slot["item"] as Item).item_id == (item as Item).item_id:
				return true
		return false
	return inventory.has(item)


func consume_item(item: Item) -> bool:
	if item == null or not item.verbrauchbar:
		return false
	if not remove_item(item, 1):
		return false
	item.apply_effects(self)
	return true


const _BASIC_ITEM_SCENE: PackedScene = preload("res://Charaktere/Props/Items/basic_item.tscn")


func drop_item_to_world(item: Item) -> bool:
	if item == null or not remove_item(item, 1):
		return false
	_spawn_world_item(item.duplicate_item())
	return true


func get_drop_spawn_position() -> Vector3:
	var forward := Vector3(facing_direction.x, 0.0, facing_direction.z)
	if forward.length_squared() < FACING_CHANGE_EPSILON_SQ:
		forward = Vector3(0, 0, 1)
	forward = forward.normalized()
	return global_position + forward * 1.1 + Vector3(0, 0.45, 0)


func _spawn_world_item(item: Item) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var inst := _BASIC_ITEM_SCENE.instantiate() as BasicItem
	inst.item_data = item
	world.add_child(inst)
	inst.global_position = get_drop_spawn_position()
	var toss := Vector3(facing_direction.x, 1.2, facing_direction.z).normalized() * 1.8
	inst.apply_central_impulse(toss)


# --- Ausrüstung ---

func equip(slot: String, item: Variant) -> void:
	if not equipment.has(slot):
		push_warning("Playable: Unbekannter Ausrüstungsslot '%s'" % slot)
		return
	equipment[slot] = item
	inventar_geaendert.emit()


func unequip(slot: String) -> Variant:
	if not equipment.has(slot):
		push_warning("Playable: Unbekannter Ausrüstungsslot '%s'" % slot)
		return null
	var item: Variant = equipment[slot]
	equipment[slot] = null
	inventar_geaendert.emit()
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
