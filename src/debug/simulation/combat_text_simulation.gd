class_name CombatTextSimulation
extends RefCounted

## Isolierte Charakterkopien; dieselbe Initiative und Aktionsauflösung wie im Spiel.
## Keine Welt, Sichtlinien, Laufwege, Dialoge, Party-KI oder menschlichen Denkpausen.
var actors: Array[Playable] = []
var session: CombatSession
var rng := RandomNumberGenerator.new()
var configs: Array[Dictionary] = []
var lines: PackedStringArray = []
var elapsed := 0.0
var turns := 0
var damage := [0, 0]
var dodges := [0, 0]
var winner := -1
var done := false
var limit_reason := ""
const MAX_TURNS := 300
const MAX_SECONDS := 600.0

func setup(sheets: Array[CharacterResource], options: Array[Dictionary], random_seed: int) -> void:
	cleanup()
	rng.seed = random_seed
	configs = options.duplicate(true)
	lines.clear()
	elapsed = 0.0
	turns = 0
	damage = [0, 0]
	dodges = [0, 0]
	winner = -1
	done = false
	limit_reason = ""
	session = CombatSession.new()
	for i in 2:
		var actor := Playable.new()
		actor.character = sheets[i].duplicate(true) as CharacterResource
		actor.character.is_defeated = false
		actor.character.inventory = Inventory.new()
		actor.character.ensure_equipment_slots()
		actor.character.staerkepunkte = actor.character.get_staerkepunkte_basis()
		actor.character.konzentrationspunkte = actor.character.get_konzentrationspunkte_basis()
		actors.append(actor)
		if configs[i].get("armored", false):
			var armor := ItemData.new()
			armor.item_id = "simulation_armor"
			armor.is_armor = true
			actor.character.inventory.equip("rumpf", armor)
		var item_path: String = configs[i].get("item_path", "")
		var item: ItemData = null
		if item_path == "custom":
			item = ItemData.new()
			item.item_name = "Testgegenstand"
			item.item_id = "simulation_item"
			item.combat_value = maxi(1, int(configs[i].get("combat_value", 1)))
			item.combat_skill_id = configs[i].get("skill_id", "")
		elif not item_path.is_empty():
			item = load(item_path).duplicate(true) as ItemData
		if item:
			item.break_chance = clampf(float(configs[i].get("break_chance", item.break_chance)), 0.0, 1.0)
			actor.character.inventory.equip("primaer_hand", item)
		session.participants.append(CombatParticipant.new(actor, CombatParticipantResolver.SIDE_ATTACKER if i == 0 else CombatParticipantResolver.SIDE_VICTIM))
		lines.append("%s: Stärke %d bis Todesgrenze %d; Konzentration %d; effektive KK %d, GW %d, RB %d." % [actor.get_display_name(), actor.health, -actor.get_max_health(), actor.mana, actor.get_effective_attribute(CharacterEnums.Attribute.KOERPERKRAFT), actor.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT), actor.get_effective_attribute(CharacterEnums.Attribute.ROBUSTHEIT)])
	lines.append("Zufallsstart: %d. Freie Sicht, sofortige Zugentscheidungen, keine Bewegung oder Flucht." % random_seed)
	for i in 2:
		if actors[i].is_character_dead():
			done = true
			limit_reason = "Keine gültige Startstärke (Basis 0)."
			lines.append(limit_reason)

func step() -> void:
	if done:
		return
	while session.get_active_participant() == null and elapsed < MAX_SECONDS:
		session._tick_initiative(0.05)
		elapsed += 0.05
		session._advance_turn_queue()
	if elapsed >= MAX_SECONDS or turns >= MAX_TURNS:
		done = true
		limit_reason = "Abbruchgrenze: %d Aktionen oder %.0f simulierte Sekunden; kein Sieger." % [MAX_TURNS, MAX_SECONDS]
		lines.append(limit_reason)
		return
	var participant := session.get_active_participant()
	var index := session.participants.find(participant)
	var target := session.participants[1 - index]
	var action := _action(index, participant, target)
	var held: ItemData = actors[index].equipment.get("primaer_hand")
	var result := CombatResolver.resolve_action(action, rng, false)
	turns += 1
	for outcome in result.outcomes:
		damage[index] += outcome.damage
		if outcome.evaded:
			dodges[1 - index] += 1
		var text := "%s weicht aus" % target.playable.get_display_name() if outcome.evaded else ("%d Schaden" % outcome.damage if outcome.damage > 0 else "0 Schaden – durch Robustheit abgefangen")
		var attack_name := action.item.item_name + " / " + action.item_usage_mode.label if action.item else action.ability.ability_name
		lines.append("[%6.2f s] #%d %s → %s mit %s: %s. Stärke %d / %d; Konzentration des Angreifers %d." % [elapsed, turns, participant.playable.get_display_name(), target.playable.get_display_name(), attack_name, text, target.playable.health, target.playable.get_max_health(), participant.playable.mana])
	if held and actors[index].equipment.get("primaer_hand") == null:
		lines.append("%s: %s %s; danach Schlag." % [participant.playable.get_display_name(), held.item_name, "verbraucht/geworfen" if action.item_usage_mode and action.item_usage_mode.consumes_item else "zerbrochen"])
	for defeated in result.defeated_targets:
		session.mark_defeated(defeated)
		winner = index
		done = true
		lines.append("%s gewinnt nach %d Aktionen und %.2f simulierten Sekunden." % [participant.playable.get_display_name(), turns, elapsed])
	session.end_turn(participant)

func _action(index: int, actor: CombatParticipant, target: CombatParticipant) -> CombatAction:
	var action := CombatAction.new()
	action.actor = actor
	action.targets = [target]
	var item: ItemData = actor.playable.equipment.get("primaer_hand")
	if item:
		action.type = CombatAction.ActionType.ITEM
		var modes := item.get_combat_usage_modes()
		action.item = item
		action.item_usage_mode = modes[clampi(int(configs[index].get("mode_index", 0)), 0, modes.size() - 1)].duplicate(true)
		action.item_usage_mode.requires_line_of_sight = false
	else:
		action.type = CombatAction.ActionType.ABILITY
		var id: String = configs[index].get("ability_id", "fausthieb")
		var ability := AbilityCatalog.get_definition(id)
		if ability == null or not AbilityCatalog.get_available_for(actor.playable.character).has(ability) or (ability.mana_cost > 0 and not actor.playable.can_spend_mana(ability.mana_cost)):
			if id != "fausthieb":
				lines.append("%s: Fähigkeit nicht verfügbar oder Konzentration zu niedrig – stattdessen Schlag." % actor.playable.get_display_name())
			ability = AbilityCatalog.get_definition("fausthieb")
		action.ability = ability.duplicate(true)
		action.ability.requires_line_of_sight = false
	return action

func run() -> Dictionary:
	while not done:
		step()
	return {"winner": winner, "turns": turns, "seconds": elapsed, "damage": damage.duplicate(), "dodges": dodges.duplicate(), "log": "\n".join(lines), "limit_reason": limit_reason}

func cleanup() -> void:
	if is_instance_valid(session):
		session.free()
	session = null
	for actor in actors:
		actor.free()
	actors.clear()
