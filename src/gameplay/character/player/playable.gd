class_name Playable extends CharacterBody3D

const _SheetFactory = preload("res://src/gameplay/character/character_sheet_factory.gd")

static var _basic_item_scene: PackedScene

var inventory_component: InventoryComponent

var inventory: Array[InventorySlot]:
	get:
		_ensure_inventory_component()
		return inventory_component.get_slots()

var equipment: Dictionary:
	get:
		_ensure_inventory_component()
		return inventory_component.equipment


func add_item(item: ItemData, count: int = 1) -> void:
	_ensure_character()
	character.add_item(item, count)


func remove_item(item: ItemData, count: int = 1) -> bool:
	_ensure_character()
	return character.remove_item(item, count)


func equip(slot_key: String, item: ItemData) -> void:
	_ensure_character()
	character.equip(slot_key, item)


func unequip(slot_key: String) -> ItemData:
	_ensure_character()
	return character.unequip(slot_key)


func has_item(item_id: String) -> bool:
	_ensure_character()
	return character.has_item(item_id)


func get_combat_usable_items() -> Array[ItemData]:
	_ensure_character()
	return character.get_combat_usable_items()

# --- Welt-Avatar (Bewegung, Animation, Kollision) ---
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

@export var gravity_enabled: bool = true
@export var gravity: float = -1.0
@export var max_fall_speed: float = 28.0
@export_group("Sprung")
@export var jump_velocity: float = 6.5
## Zusatzrotation für GLTF-Modelle (Blockbench exportiert oft +Z statt Godot -Z).
@export var model_yaw_offset: float = PI

## Charakterdaten. Dieser Node ist nur der Welt-Repräsentant.
@export var character: CharacterResource

var health: int:
	get:
		return character.staerkepunkte if character else 0
	set(value):
		if character:
			character.staerkepunkte = value

var mana: int:
	get:
		return character.konzentrationspunkte if character else 0
	set(value):
		if character:
			character.konzentrationspunkte = value

var gold: int:
	get:
		return character.gold if character else 0
	set(value):
		if character:
			character.gold = maxi(0, value)


func get_display_name() -> String:
	if character and not character.character_name.is_empty():
		return character.character_name
	return name


# --- Kampf-Modus (CombatSession, siehe src/gameplay/combat/engine) ---
# Übersteuert die normale State Machine nur für tatsächliche Teilnehmer;
# alle anderen Playable-Instanzen laufen unverändert weiter (kein globaler
# Input-Lock, siehe CombatManager).
var _combat_session: CombatSession = null


func enter_combat_mode(session: CombatSession) -> void:
	if _combat_session == session:
		return
	_combat_session = session
	stop_horizontal_velocity()
	var machine := get_node_or_null("StateMachine") as PlayerStateMachine
	if machine == null:
		return
	# Follower halten ihre State Machine außerhalb des Kampfes deaktiviert
	# (siehe PartyFollower._ready), sonst würden CombatWait/CombatTurn nie
	# ihre process()/handle_input() bekommen. Für den Leader ist das ein No-Op.
	machine.process_mode = Node.PROCESS_MODE_INHERIT
	var wait_state := machine.get_node_or_null("CombatWait") as State
	if wait_state:
		machine.change_state(wait_state)


func exit_combat_mode() -> void:
	if _combat_session == null:
		return
	_combat_session = null
	var machine := get_node_or_null("StateMachine") as PlayerStateMachine
	if machine == null:
		return
	var idle_state := machine.get_node_or_null("Idle") as State
	if idle_state:
		machine.change_state(idle_state)


func is_in_combat_mode() -> bool:
	return _combat_session != null


func get_combat_session() -> CombatSession:
	return _combat_session


func _ready() -> void:
	if gravity < 0.0:
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	_setup_character()
	_ensure_inventory_component()
	_ensure_model_animator()
	_apply_facing()
	add_to_group(CombatParticipantResolver.COMBAT_REACTIVE_GROUP)


func bind_character(new_character: CharacterResource, duplicate_runtime: bool = true) -> void:
	character = new_character
	_setup_character(duplicate_runtime)
	_ensure_inventory_component()


func _setup_character(duplicate_runtime: bool = true) -> void:
	if character == null:
		character = _SheetFactory.create_default(name)
	if duplicate_runtime:
		character = _SheetFactory.duplicate_for_runtime(character)
	if character:
		character.ensure_initialized()


func _ensure_character() -> void:
	if character == null:
		_setup_character()
	_ensure_inventory_component()


func get_max_health() -> int:
	if character:
		return character.get_staerkepunkte_basis()
	return 0


func get_max_mana() -> int:
	if character:
		return character.get_konzentrationspunkte_basis()
	return 0


func is_character_dead() -> bool:
	return character != null and character.is_dead()


func can_spend_mana(amount: int) -> bool:
	return character != null and character.can_use_konzentration(amount)


func get_effective_attribute(attr: CharacterEnums.Attribute) -> int:
	if character:
		return character.get_effective_attribute(attr)
	return 0


func get_total_weight() -> float:
	return character.get_total_weight() if character else 0.0


func get_max_carry_weight() -> float:
	return character.get_max_carry_weight() if character else 0.0


func can_carry_additional(additional_weight: float) -> bool:
	return character != null and character.can_carry_additional(additional_weight)


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


func try_jump() -> bool:
	if not is_on_floor():
		return false
	velocity.y = jump_velocity
	return true


func is_airborne() -> bool:
	return not is_on_floor()


# --- Bewegungs-Hilfsmethoden ---

func face_world_position(world_pos: Vector3) -> void:
	var to := world_pos - global_position
	to.y = 0.0
	if to.length_squared() < FACING_CHANGE_EPSILON_SQ:
		return
	facing_direction = to.normalized()
	cardinal_direction = _nearest_cardinal(facing_direction)
	_apply_facing()


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
	if character:
		character.apply_staerkeschaden(amount)


func heal(amount: int) -> void:
	if character:
		character.heal_staerke(amount)


func use_mana(amount: int) -> bool:
	if character == null:
		return false
	return character.spend_konzentration(amount)


func restore_mana(amount: int) -> void:
	if character:
		character.restore_konzentration(amount)


func gain_skill_experience(skill_id: String, amount: int) -> void:
	if character:
		character.gain_action_erfahrung(skill_id, amount)





func _ensure_inventory_component() -> void:
	if inventory_component != null and is_instance_valid(inventory_component):
		if character and inventory_component.character != character:
			inventory_component.bind(character)
		return
	inventory_component = get_node_or_null("InventoryComponent") as InventoryComponent
	if inventory_component == null:
		inventory_component = InventoryComponent.new()
		inventory_component.name = "InventoryComponent"
		add_child(inventory_component)
	if not inventory_component.changed.is_connected(_on_inventory_component_changed):
		inventory_component.changed.connect(_on_inventory_component_changed)
	if character:
		inventory_component.bind(character)


func _on_inventory_component_changed() -> void:
	inventar_geaendert.emit()


func consume_item(item: ItemData) -> bool:
	if item == null or not item.consumable:
		return false
	if not remove_item(item, 1):
		return false
	item.apply_effects(self)
	return true


func drop_item_to_world(item: ItemData) -> bool:
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


func _spawn_world_item(item: ItemData) -> void:
	var parent: Node = null
	if MainGame.instance:
		parent = MainGame.instance.get_item_drop_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	if _basic_item_scene == null:
		_basic_item_scene = load("res://src/world/objects/items/basic_item.tscn") as PackedScene
	if _basic_item_scene == null:
		return
	var inst := _basic_item_scene.instantiate() as BasicItem
	inst.item_data = item
	parent.add_child(inst)
	inst.global_position = get_drop_spawn_position()
	var toss := Vector3(facing_direction.x, 1.2, facing_direction.z).normalized() * 1.8
	inst.apply_central_impulse(toss)
