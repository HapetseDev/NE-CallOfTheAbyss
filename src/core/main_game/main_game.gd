class_name MainGame
extends Node3D

## Stabiler Spielanker. Level werden in World/LevelRoot geladen;
## Party/Player bleiben unter World/EntityRoot erhalten.

static var instance: MainGame

const PARTY_HUD_SCENE := preload("res://src/ui/hud/party_hud.tscn")
const COMBAT_ORDER_HUD_SCENE := preload("res://src/ui/hud/combat_order_hud.tscn")
const EVENT_LOG_HUD_SCENE := preload("res://src/ui/hud/event_log_hud.tscn")
const TOP_BAR_HUD_SCENE := preload("res://src/ui/hud/top_bar_hud.tscn")
const DEFAULT_LEVEL := "res://src/world/levels/regions/Level1Ep1.tscn"

## Höhe der unteren Spiel-Leiste; TopBarHud behält seinen bisherigen Typnamen.
const TOP_BAR_HEIGHT := 60.0

@export var starting_level_path: String = DEFAULT_LEVEL

@onready var world: Node3D = $World
@onready var level_root: Node3D = $World/LevelRoot
@onready var entity_root: Node3D = $World/EntityRoot
@onready var effect_root: Node3D = $World/EffectRoot
@onready var level_manager: LevelManager = $Systems/LevelManager
@onready var sequence_manager: SequenceManager = $Systems/SequenceManager
@onready var camera_system: CameraSystem = $Systems/CameraSystem
@onready var shop_manager: ShopManager = $Systems/ShopManager
@onready var party_trade_manager: PartyTradeManager = $Systems/PartyTradeManager
@onready var steal_manager: StealManager = $Systems/StealManager
@onready var hud_root: CanvasLayer = $UI/HudRoot
@onready var menu_root: CanvasLayer = $UI/MenuRoot
@onready var dialogue_root: CanvasLayer = $UI/DialogueRoot
@onready var pause_root: CanvasLayer = $UI/PauseRoot
@onready var transition_root: CanvasLayer = $UI/TransitionRoot

## Nur der Ladekoordinator hält beim vorübergehenden Aushängen die Sitzung fest.
var preserve_state_on_exit: bool = false

var party: Party
var game_windows: GameWindows
var _party_hud: PartyHud
var _combat_order_hud: CombatOrderHud
var _event_log_hud: EventLogHud
var _top_bar_hud: TopBarHud


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
		# Kinder (Systeme, UI und Weltfiguren) sind bereits aus dem Baum entfernt.
		if not preserve_state_on_exit:
			GameState.reset_session()


func _ready() -> void:
	party = entity_root.get_node_or_null("Party") as Party
	_setup_hud()
	_setup_menus()
	level_manager.setup(level_root, party)
	shop_manager.setup(menu_root)
	party_trade_manager.setup(menu_root)
	steal_manager.setup(menu_root)
	if party and party.leader:
		camera_system.set_target(party.leader, true)
	LevelManager.load_level(GameState.world_state.active_location if not GameState.world_state.active_location.is_empty() else starting_level_path)


func get_item_drop_parent() -> Node:
	if level_root:
		return level_root
	return self


func _setup_hud() -> void:
	_top_bar_hud = TOP_BAR_HUD_SCENE.instantiate() as TopBarHud
	hud_root.add_child(_top_bar_hud)
	_top_bar_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_top_bar_hud.offset_top = -TOP_BAR_HEIGHT
	_top_bar_hud.offset_bottom = 0
	_top_bar_hud.inventory_pressed.connect(_on_top_bar_inventory_pressed)
	_top_bar_hud.character_pressed.connect(_on_top_bar_character_pressed)
	_top_bar_hud.party_pressed.connect(_on_top_bar_party_pressed)
	_top_bar_hud.map_pressed.connect(_on_top_bar_map_pressed)
	_top_bar_hud.log_pressed.connect(_on_top_bar_log_pressed)
	_top_bar_hud.menu_pressed.connect(_on_top_bar_menu_pressed)
	_top_bar_hud.debug_pressed.connect(_on_top_bar_debug_pressed)

	var below_bar := float(NEDimensions.SPACING_M)
	_party_hud = PARTY_HUD_SCENE.instantiate() as PartyHud
	_party_hud.world_tracking = true
	hud_root.add_child(_party_hud)
	if party:
		party.bind_hud(_party_hud, hud_root, below_bar)
	_combat_order_hud = COMBAT_ORDER_HUD_SCENE.instantiate() as CombatOrderHud
	hud_root.add_child(_combat_order_hud)
	_combat_order_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combat_order_hud.offset_left = -236.0
	_combat_order_hud.offset_right = -16.0
	_combat_order_hud.offset_top = below_bar
	_event_log_hud = EVENT_LOG_HUD_SCENE.instantiate() as EventLogHud
	hud_root.add_child(_event_log_hud)
	_event_log_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_event_log_hud.offset_left = 16.0
	_event_log_hud.offset_right = 436.0
	_event_log_hud.offset_top = -240.0
	_event_log_hud.offset_bottom = -TOP_BAR_HEIGHT - NEDimensions.SPACING_S
	if CombatManager.instance:
		_combat_order_hud.bind(CombatManager.instance)



func _setup_menus() -> void:
	game_windows = preload("res://src/ui/menus/game_windows.gd").new()
	menu_root.add_child(game_windows)
	game_windows.setup(party)


func _on_top_bar_inventory_pressed() -> void:
	game_windows.open_page(2)

func _on_top_bar_character_pressed() -> void:
	game_windows.open_page(1)

func _on_top_bar_party_pressed() -> void:
	game_windows.open_page(0)

func _on_top_bar_map_pressed() -> void:
	game_windows.open_page(3)

func _on_top_bar_log_pressed() -> void:
	game_windows.open_page(4)

func _on_top_bar_menu_pressed() -> void:
	game_windows.open_page(5)

func _on_top_bar_debug_pressed() -> void:
	game_windows.open_page(6)
