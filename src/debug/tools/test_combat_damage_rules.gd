extends Node
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func _ready() -> void:
	var actor := Playable.new()
	var target := Playable.new()
	actor.character = CharacterResource.new()
	target.character = CharacterResource.new()
	actor.character.ensure_initialized()
	target.character.ensure_initialized()
	target.character.robustheit = 100
	target.character.gewandheit = 0
	var attacker := CombatParticipant.new(actor)
	var victim := CombatParticipant.new(target)
	for level in [0, 1, 2, 3, 10]:
		actor.character.debug_set_skill_level("waffenloser_kampf", level)
		check(CombatResolver.get_damage_skill_bonus(actor.character, "waffenloser_kampf") == floori(level / 2.0), "Halber Bonus, Stufe %d" % level)
	check(CombatResolver.resolve_damage(attacker, victim, 2, CharacterEnums.Attribute.KOERPERKRAFT) == 1, "Robustheit allein hebt Mindestschaden nicht auf")
	check(CombatResolver.resolve_damage(attacker, victim, 0, CharacterEnums.Attribute.KOERPERKRAFT) == 0, "Null Angriffsstärke erzeugt keinen Schaden")
	var armor := ItemData.new()
	armor.is_armor = true
	target.character.inventory.add_item(armor)
	check(not CombatResolver.has_worn_armor(target.character), "Rucksackrüstung schützt nicht")
	target.character.inventory.equip("guertel_1", armor)
	check(not CombatResolver.has_worn_armor(target.character), "Schnellausrüstung gilt nicht als angelegte Rüstung")
	target.character.inventory.equip("rumpf", armor)
	check(CombatResolver.resolve_damage(attacker, victim, 2, CharacterEnums.Attribute.KOERPERKRAFT) == 0, "Gerüsteter Treffer darf Nullschaden verursachen")
	check(CombatResolver.resolve_damage(attacker, victim, 2, CharacterEnums.Attribute.KOERPERKRAFT, null, false) == 1, "Explizit ungerüstete Trefferstelle hat Mindestschaden")
	check(CombatResolver.resolve_damage(attacker, victim, 2, CharacterEnums.Attribute.KOERPERKRAFT, null, true) == 0, "Explizit gerüstete Trefferstelle kann Schaden vollständig mindern")
	target.character.inventory.unequip("rumpf")
	var clothing := ItemData.new()
	target.character.inventory.equip("rumpf", clothing)
	check(not CombatResolver.has_worn_armor(target.character), "Normale Kleidung gilt nicht automatisch als Rüstung")
	target.character.gewandheit = 100
	var rng := RandomNumberGenerator.new()
	for random_seed in range(1, 100):
		rng.seed = random_seed
		var saved_state := rng.state
		if rng.randf() < CombatBalance.EVADE_CAP:
			rng.state = saved_state
			break
	check(CombatResolver.resolve_damage(attacker, victim, 2, CharacterEnums.Attribute.KOERPERKRAFT, rng) == 0, "Ausweichen bleibt bei Nullschaden")
	var codec := WorldValueCodec.new()
	var encoded: Dictionary = codec.encode(armor)
	check((codec.decode(encoded) as ItemData).is_armor, "Rüstungskennzeichnung wird gespeichert")
	encoded.value.erase("is_armor")
	var old := WorldValueCodec.new()
	old.migrate_legacy_armor_items = true
	check((old.decode(encoded) as ItemData).is_armor == false, "Alte Gegenstände werden nicht unbemerkt zu Rüstung")
	encoded.value.is_armor = "true"
	check(codec.decode(encoded) == null and codec.failed, "Ungültige Rüstungskennzeichnung abgelehnt")
	actor.free()
	target.free()
	print("combat_damage_rules: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
