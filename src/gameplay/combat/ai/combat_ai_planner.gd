extends RefCounted

const GRID := preload("res://src/world/combat/combat_grid.gd")

static func _clear_to_position(body: Playable, from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * CombatLineOfSight.EYE_HEIGHT, to + Vector3.UP * CombatLineOfSight.EYE_HEIGHT, CombatLineOfSight.LAYER_WALLS)
	return body.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Nur am tatsächlichen eigenen Zug mutieren, niemals durch Vorschau/choose().
static func update_observations(session: CombatSession, actor: CombatParticipant, profile: Resource) -> void:
	var retained: Dictionary = {}
	if profile.target_memory_turns > 0:
		for target in session.participants:
			if target.side == actor.side or target.side == CombatParticipantResolver.SIDE_NEUTRAL or target.is_out_of_combat() or not is_instance_valid(target.playable):
				continue
			var id := target.playable.get_instance_id()
			if not actor.ai_last_seen.has(id):
				continue
			var record: Dictionary = actor.ai_last_seen[id].duplicate()
			record.age = int(record.age) + 1
			var reached := actor.playable.global_position.distance_to(record.position) <= GRID.CELL_SIZE + GRID.EPSILON and _clear_to_position(actor.playable, actor.playable.global_position, record.position)
			if record.age <= profile.target_memory_turns and not reached:
				retained[id] = record
		for target in perceived_enemies(session, actor, profile):
			retained[target.playable.get_instance_id()] = {"position": target.playable.global_position, "age": 0}
	actor.ai_last_seen = retained

static func _prefix(path: PackedVector3Array, maximum: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var cost := 0.0
	for index in path.size():
		if index > 0:
			cost += path[index - 1].distance_to(path[index])
		if cost > maximum + GRID.EPSILON:
			break
		result.append(path[index])
	return result

static func _approach_move(actor: CombatParticipant, profile: Resource, field: Dictionary, target: CombatParticipant, reason: String) -> Dictionary:
	var radius := GRID.budget(actor.playable)
	var path := _prefix(field.path, minf(radius, profile.movement_search_radius))
	if path.size() < 2:
		return {}
	return {"kind": "move", "path": path, "target": target, "origin": actor.playable.global_position, "radius": radius, "tactical": false, "reason": reason}

## Zu einer tatsächlichen Angriffsmöglichkeit planen, auch wenn der erste
## Bewegungszug den Luftlinienabstand nicht verkleinert.
static func _approach_visible(session: CombatSession, actor: CombatParticipant, enemies: Array[CombatParticipant], options: Array[CombatAction], profile: Resource) -> Dictionary:
	var fields := GRID.planning_routes(actor.playable, session, profile.approach_planning_distance, profile.movement_search_radius).values()
	fields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cost < b.cost)
	var goal: Dictionary = {}
	var goal_attack: Dictionary = {}
	for field in fields:
		if not goal.is_empty() and float(field.cost) > float(goal.cost) + GRID.EPSILON:
			break
		if field.cost < profile.minimum_progress:
			continue
		var future := best_attack(actor, enemies, options, profile, field.position - Vector3.UP * GRID.FLOOR_CLEARANCE)
		if not future.is_empty() and (goal_attack.is_empty() or float(future.score) > float(goal_attack.score)):
			goal = field
			goal_attack = future
	if goal.is_empty():
		return {}
	return _approach_move(actor, profile, goal, goal_attack.target, "approach_attack")

## Verdeckte Ziele nur an ihrer zuletzt gesehenen Position suchen, nicht an
## ihrer aktuellen (unbekannten) Weltposition. Keine Angriffsplanung auf sie.
static func _pursue_memory(session: CombatSession, actor: CombatParticipant, profile: Resource) -> Dictionary:
	if profile.target_memory_turns <= 0 or actor.ai_last_seen.is_empty():
		return {}
	var fields := GRID.planning_routes(actor.playable, session, profile.approach_planning_distance, profile.movement_search_radius).values()
	fields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cost < b.cost)
	for field in fields:
		if field.cost < profile.minimum_progress:
			continue
		for target in session.participants:
			if not is_instance_valid(target.playable) or target.is_out_of_combat() or target.side == actor.side or target.side == CombatParticipantResolver.SIDE_NEUTRAL:
				continue
			var record: Dictionary = actor.ai_last_seen.get(target.playable.get_instance_id(), {})
			if record.is_empty() or int(record.age) > profile.target_memory_turns:
				continue
			var standpoint: Vector3 = field.position - Vector3.UP * GRID.FLOOR_CLEARANCE
			if standpoint.distance_to(record.position) > GRID.CELL_SIZE + GRID.EPSILON:
				continue
			if not _clear_to_position(actor.playable, standpoint, record.position):
				continue
			return _approach_move(actor, profile, field, target, "last_seen")
	return {}

static func perceived_enemies(session: CombatSession, actor: CombatParticipant, profile: Resource) -> Array[CombatParticipant]:
	var enemies: Array[CombatParticipant] = []
	var side := CombatParticipantResolver.SIDE_VICTIM if actor.side == CombatParticipantResolver.SIDE_ATTACKER else CombatParticipantResolver.SIDE_ATTACKER
	for target in session.participants:
		if target.side != side or target.is_out_of_combat() or not is_instance_valid(target.playable):
			continue
		if actor.playable.global_position.distance_to(target.playable.global_position) > profile.perception_radius:
			continue
		if CombatLineOfSight.has_clear_line(actor.playable, target.playable, CombatLineOfSight.LAYER_WALLS):
			enemies.append(target)
	enemies.sort_custom(func(a: CombatParticipant, b: CombatParticipant) -> bool:
		return actor.playable.global_position.distance_squared_to(a.playable.global_position) < actor.playable.global_position.distance_squared_to(b.playable.global_position))
	if enemies.size() > profile.max_targets:
		enemies.resize(profile.max_targets)
	return enemies

static func attack_options(actor: CombatParticipant) -> Array[CombatAction]:
	var actions: Array[CombatAction] = []
	for item in actor.playable.get_combat_usable_items():
		if item.consumable:
			continue
		for mode in item.get_combat_usage_modes():
			if not mode.ammunition_item_id.is_empty() and not actor.playable.character.inventory.has_item(mode.ammunition_item_id):
				continue
			var action := CombatAction.new()
			action.actor = actor
			action.type = CombatAction.ActionType.ITEM
			action.item = item
			action.item_usage_mode = mode
			actions.append(action)
	var equipment := actor.playable.character.inventory.equipment
	if equipment.get("primaer_hand") == null or equipment.get("nebenhand") == null:
		var punch := CombatAction.new()
		punch.actor = actor
		punch.type = CombatAction.ActionType.ABILITY
		punch.ability = AbilityCatalog.get_definition("fausthieb")
		actions.append(punch)
	return actions

static func reach(action: CombatAction) -> float:
	return action.item_usage_mode.range_meters if action.item else action.ability.melee_range_meters

static func best_attack(actor: CombatParticipant, enemies: Array[CombatParticipant], options: Array[CombatAction], profile: Resource, at: Vector3) -> Dictionary:
	var best: Dictionary = {}
	for target in enemies:
		for option in options:
			if not WorldUnits.is_within_range(at, target.playable.global_position, reach(option)):
				continue
			for zone in CombatAnatomy.profile(target.playable.character).zones:
				var check_walls: bool = option.item_usage_mode.requires_line_of_sight if option.item else true
				var hit := CombatAnatomy.trace(actor, target, check_walls, zone.zone_id, at)
				var recipient := hit.get("target") as CombatParticipant
				# Keine freundlichen oder neutralen Abfänger. Fäuste behalten ihre
				# bestehende Fähigkeitsauflösung und müssen genau dieses Ziel treffen.
				if recipient == null or recipient.side == actor.side or recipient.side == CombatParticipantResolver.SIDE_NEUTRAL:
					continue
				if not WorldUnits.is_within_range(at, recipient.playable.global_position, reach(option)):
					continue
				if option.item == null and (recipient != target or hit.zone_id != zone.zone_id):
					continue
				var score := _attack_score(option, recipient, hit.zone_id, profile, at)
				if score > float(best.get("score", 0.0)):
					var action := CombatAction.new()
					action.actor = actor
					action.type = option.type
					action.item = option.item
					action.item_usage_mode = option.item_usage_mode
					action.ability = option.ability
					action.targets = [target]
					action.target_zone_id = zone.zone_id
					best = {"kind": "attack", "action": action, "target": target, "recipient": recipient, "score": score, "damage": _attack_damage(action, recipient, hit.zone_id, at)}
	return best

static func _attack_damage(action: CombatAction, target: CombatParticipant, zone_id: String, at: Vector3) -> int:
	var sheet := action.actor.playable.character
	var power := sheet.get_effective_attribute(CharacterEnums.Attribute.KOERPERKRAFT)
	var damage_type := "blunt"
	if action.item:
		power += action.item.get_combat_value(action.item_usage_mode) + CombatResolver.get_damage_skill_bonus(sheet, action.item.get_combat_skill_id(action.item_usage_mode))
		damage_type = action.item_usage_mode.damage_type
	else:
		power += CombatResolver.get_damage_skill_bonus(sheet, "waffenloser_kampf")
	var zone := CombatAnatomy.profile(target.playable.character).get_zone(zone_id)
	var protection := CombatAnatomy.protection(target.playable.character, zone, damage_type, CombatAnatomy.direction_from_position(at, target.playable))
	var minimum := 1 if power > 0 and not protection.armored else 0
	var mitigation := target.playable.get_effective_attribute(CharacterEnums.Attribute.ROBUSTHEIT) * CombatBalance.MITIGATION_FACTOR + float(protection.amount)
	var damage := maxi(minimum, roundi(power * zone.damage_multiplier) - int(mitigation))
	return damage

static func _attack_score(action: CombatAction, target: CombatParticipant, zone_id: String, profile: Resource, at: Vector3) -> float:
	var damage := _attack_damage(action, target, zone_id, at)
	if damage <= 0:
		return 0.0
	var sheet := action.actor.playable.character
	var hostility := -RelationshipService.get_disposition(sheet, target.playable.character)
	var wounded := 1.0 - clampf(float(target.playable.health) / maxf(1.0, target.playable.get_max_health()), 0.0, 1.0)
	return maxf(0.01, damage * profile.damage_weight + hostility * profile.hostility_weight + wounded * profile.wounded_target_weight)

static func choose(session: CombatSession, actor: CombatParticipant, profile: Resource) -> Dictionary:
	var enemies := perceived_enemies(session, actor, profile)
	var options := attack_options(actor)
	if options.is_empty():
		return {}
	if enemies.is_empty():
		return _pursue_memory(session, actor, profile)
	var origin := actor.playable.global_position
	var attack := best_attack(actor, enemies, options, profile, origin)
	var tactical := not attack.is_empty()
	if tactical and (not profile.tactical_reposition_enabled or actor.ai_reposition_cooldown > 0 or int(attack.damage) >= attack.recipient.playable.health + attack.recipient.playable.get_max_health()):
		return attack
	var threshold: float = float(attack.get("score", 0.0)) * profile.reposition_attack_multiplier + profile.reposition_min_gain
	var radius := maxf(1.0, actor.playable.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)) * WorldUnits.METER
	var search := minf(radius, profile.movement_search_radius)
	var max_reach := 0.0
	for option in options:
		max_reach = maxf(max_reach, reach(option))
	var desired := maxf(0.85, minf(max_reach * profile.preferred_reach_ratio, search))
	var fields := GRID.reachable(actor.playable, session, search)
	var best_move: Dictionary = {}
	var best_score := -INF
	for field in fields.values():
		if field.cost < profile.minimum_progress:
			continue
		var point: Vector3 = field.position
		# Wegpunkte liegen zur Körperprüfung 5 cm über dem Boden; Angriff vom Standpunkt aus bewerten.
		var future := best_attack(actor, enemies, options, profile, point - Vector3.UP * GRID.FLOOR_CLEARANCE)
		var target: CombatParticipant = enemies[0]
		var progress := -INF
		for enemy in enemies:
			var before := absf(origin.distance_to(enemy.playable.global_position) - desired)
			var gain := before - absf(point.distance_to(enemy.playable.global_position) - desired)
			if gain > progress:
				progress = gain
				target = enemy
		if not future.is_empty():
			target = future.target
		var score: float
		if tactical:
			if future.is_empty():
				continue
			score = float(future.score) - float(field.cost) * profile.reposition_path_cost
			if score <= threshold:
				continue
		else:
			if progress < profile.minimum_progress and future.is_empty():
				continue
			score = progress + (100.0 + float(future.score) if not future.is_empty() else 0.0) - float(field.cost) * 0.01
		if score > best_score:
			best_score = score
			best_move = {"kind": "move", "path": field.path, "target": target, "origin": origin, "radius": radius, "tactical": tactical, "prepares_attack": not future.is_empty()}
	if not tactical and (best_move.is_empty() or not best_move.prepares_attack):
		var approach := _approach_visible(session, actor, enemies, options, profile)
		if not approach.is_empty():
			return approach
	return best_move if not best_move.is_empty() else attack
