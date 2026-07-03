class_name BattleCharacterFactory

const NORMAL_ATTACK := preload("res://Ressources/Battle/skills/normal_attack.tres")
const RUN_SKILL := preload("res://Ressources/Battle/skills/run.tres")
const HEAL_SKILL := preload("res://Ressources/Battle/skills/heal.tres")


static func from_playable(playable: Playable) -> BattleCharacterResource:
	var res := BattleCharacterResource.new()
	res.name = playable.get_display_name()
	res.maxHealth = playable.get_max_health()
	res.currentHealth = playable.health
	res.maxMana = playable.get_max_mana()
	res.currentMana = playable.mana
	res.speed = 30 + playable.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT) * 3
	res.basicAttack = NORMAL_ATTACK
	res.run = RUN_SKILL
	res.skills = [HEAL_SKILL]
	return res


static func create_enemy(enemy_name: String, health: int, mana: int, enemy_speed: int) -> BattleCharacterResource:
	var res := BattleCharacterResource.new()
	res.name = enemy_name
	res.maxHealth = health
	res.currentHealth = health
	res.maxMana = mana
	res.currentMana = mana
	res.speed = enemy_speed
	res.basicAttack = NORMAL_ATTACK
	res.run = RUN_SKILL
	return res
