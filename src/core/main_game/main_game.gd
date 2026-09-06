class_name MainGame
extends Node3D

## Stabiler Spielanker. Level werden in World/LevelRoot geladen;
## Party/Player bleiben unter World/EntityRoot erhalten.

static var instance: MainGame

const PARTY_HUD_SCENE := preload("res://src/ui/hud/party_hud.tscn")
const COMBAT_ORDER_HUD_SCENE := preload("res://src/ui/hud/combat_order_hud.tscn")
const EVENT_LOG_HUD_SCENE := preload("res://src/ui/hud/event_log_hud.tscn")
const DEFAULT_LEVEL := "res://src/world/levels/regions/Level1Ep1.tscn"

@export var starting_level_path: String = DEFAULT_LEVEL

@onready var world: Node3D = $World
@onready var level_root: Node3D = $World/LevelRoot
@onready var entity_root: Node3D = $World/EntityRoot
@onready var effect_root: Node3D = $World/EffectRoot
@onready var level_manager: LevelManager = $Systems/LevelManager
@onready var camera_system: CameraSystem = $Systems/CameraSystem
@onready var shop_manager: ShopManager = $Systems/ShopManager
@onready var party_trade_manager: PartyTradeManager = $Systems/PartyTradeManager
@onready var steal_manager: StealManager = $Systems/StealManager
@onready var hud_root: CanvasLayer = $UI/HudRoot
@onready var menu_root: CanvasLayer = $UI/MenuRoot
@onready var dialogue_root: CanvasLayer = $UI/DialogueRoot
@onready var pause_root: CanvasLayer = $UI/PauseRoot
@onready var transition_root: CanvasLayer = $UI/TransitionRoot

var party: Party
var _party_hud: PartyHud
var _combat_order_hud: CombatOrderHud
var _event_log_hud: EventLogHud


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
	party_trade_manager.setup(menu_root)
	steal_manager.setup(menu_root)
	if party and party.leader:
		camera_system.set_target(party.leader, true)
	LevelManager.load_level(starting_level_path)


func get_item_drop_parent() -> Node:
	if level_root:
		return level_root
	return self


func _setup_hud() -> void:
	_party_hud = PARTY_HUD_SCENE.instantiate() as PartyHud
	hud_root.add_child(_party_hud)
	if party:
		party.bind_hud(_party_hud, hud_root)
	_combat_order_hud = COMBAT_ORDER_HUD_SCENE.instantiate() as CombatOrderHud
	hud_root.add_child(_combat_order_hud)
	_combat_order_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combat_order_hud.offset_left = -236.0
	_combat_order_hud.offset_right = -16.0
	_combat_order_hud.offset_top = 16.0
	_event_log_hud = EVENT_LOG_HUD_SCENE.instantiate() as EventLogHud
	hud_root.add_child(_event_log_hud)
	_event_log_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_event_log_hud.offset_left = 16.0
	_event_log_hud.offset_right = 436.0
	_event_log_hud.offset_top = -320.0
	_event_log_hud.offset_bottom = -16.0
	if CombatManager.instance:
		_combat_order_hud.bind(CombatManager.instance)
