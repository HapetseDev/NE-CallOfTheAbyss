class_name MainGame
extends Node3D

## Stabiler Spielanker. Level werden in World/LevelRoot geladen;
## Party/Player bleiben unter World/EntityRoot erhalten.

static var instance: MainGame

const PARTY_HUD_SCENE := preload("res://src/ui/hud/party_hud.tscn")
const BATTLE_SCENE := preload("res://src/gameplay/combat/battle_scene.tscn")
const DEFAULT_LEVEL := "res://src/world/levels/regions/Level1Ep1.tscn"

@export var starting_level_path: String = DEFAULT_LEVEL

@onready var world: Node3D = $World
@onready var level_root: Node3D = $World/LevelRoot
@onready var entity_root: Node3D = $World/EntityRoot
@onready var effect_root: Node3D = $World/EffectRoot
@onready var battle_root: Node3D = $BattleRoot
@onready var level_manager: LevelManager = $Systems/LevelManager
@onready var camera_system: CameraSystem = $Systems/CameraSystem
@onready var shop_manager: ShopManager = $Systems/ShopManager
@onready var hud_root: CanvasLayer = $UI/HudRoot
@onready var menu_root: CanvasLayer = $UI/MenuRoot
@onready var dialogue_root: CanvasLayer = $UI/DialogueRoot
@onready var pause_root: CanvasLayer = $UI/PauseRoot
@onready var transition_root: CanvasLayer = $UI/TransitionRoot

var party: Party
var _party_hud: PartyHud
var _battle_instance: Node


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	party = entity_root.get_node_or_null("Party") as Party
	_setup_hud()
	level_manager.setup(level_root, party)
	shop_manager.setup(menu_root)
	if party and party.leader:
		camera_system.set_target(party.leader, true)
	LevelManager.load_level(starting_level_path)


func get_item_drop_parent() -> Node:
	if level_root:
		return level_root
	return self


func start_battle() -> void:
	if camera_system:
		camera_system.set_enabled(false)
	world.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	hud_root.visible = false
	if _battle_instance:
		_battle_instance.queue_free()
	_battle_instance = BATTLE_SCENE.instantiate()
	battle_root.add_child(_battle_instance)


func end_battle() -> void:
	if _battle_instance:
		_battle_instance.queue_free()
		_battle_instance = null
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.visible = true
	hud_root.visible = true
	if camera_system:
		camera_system.set_enabled(true)
	BattleManager.apply_pending_party_state(party)


func _setup_hud() -> void:
	_party_hud = PARTY_HUD_SCENE.instantiate() as PartyHud
	hud_root.add_child(_party_hud)
	if party:
		party.bind_hud(_party_hud, hud_root)
