class_name BattleCharacterResource extends Resource

@export var name: String = "Kämpfer"
@export var maxHealth: int = 100
@export var currentHealth: int = 100
@export var maxMana: int = 50
@export var currentMana: int = 50
@export var speed: int = 50
@export var overDriveValue: int = 0
@export var basicAttack: Resource
@export var skills: Array[Resource] = []
@export var items: Array[Resource] = []
@export var run: Resource


func take_damage(amount: int) -> void:
	currentHealth = maxi(currentHealth - amount, 0)


func is_alive() -> bool:
	return currentHealth > 0
