class_name CombatAnatomy extends RefCounted

const PROFILE_PATHS := {
	"human": "res://src/resources/combat/bodies/human.tres",
	"beetle": "res://src/resources/combat/bodies/beetle.tres",
	"animal": "res://src/resources/combat/bodies/animal.tres",
}
const DAMAGE_TYPES: Array[String] = ["blunt", "slash", "pierce", "magic"]
const DAMAGE_LABELS := {"blunt": "Wucht", "slash": "Schnitt", "pierce": "Stich", "magic": "Magie"}
static var _profiles: Dictionary = {}

static func profile_for_id(id: String) -> CombatBodyProfile:
	var key := id if PROFILE_PATHS.has(id) else "human"
	if not _profiles.has(key):
		_profiles[key] = load(PROFILE_PATHS[key]) as CombatBodyProfile
	return _profiles[key] as CombatBodyProfile

static func zone_label(id: String) -> String:
	for key in PROFILE_PATHS:
		var zone := profile_for_id(key).get_zone(id)
		if zone:
			return zone.label
	return id

static func profile(sheet: CharacterResource) -> CombatBodyProfile:
	return profile_for_id(sheet.body_profile_id if sheet else "human")

static func position(actor: Node3D) -> Vector3:
	return actor.global_position if actor.is_inside_tree() else actor.position

static func frame(actor: Playable) -> Transform3D:
	var forward := Vector3(actor.facing_direction.x, 0, actor.facing_direction.z).normalized()
	if forward.is_zero_approx():
		forward = Vector3.BACK
	return Transform3D(Basis(Vector3.UP.cross(forward), Vector3.UP, forward), position(actor))

static func aim_point(actor: Playable, zone_id: String = "") -> Vector3:
	var body := profile(actor.character)
	var zone := body.get_zone(zone_id if not zone_id.is_empty() else body.default_zone_id)
	return frame(actor) * (zone.center if zone else body.get_zone(body.default_zone_id).center)

static func direction(actor: Playable, target: Playable) -> String:
	if actor == null or target == null:
		return "front"
	var incoming := position(actor) - position(target)
	incoming.y = 0
	if incoming.is_zero_approx():
		return "front"
	var facing := frame(target).basis.z
	var dot := facing.dot(incoming.normalized())
	return "front" if dot >= 0.5 else ("rear" if dot <= -0.5 else "side")

static func evasion_factor(actor: Playable, target: Playable) -> float:
	var body := profile(target.character)
	match direction(actor, target):
		"rear": return body.rear_evasion
		"side": return body.side_evasion
	return body.front_evasion

static func _protection(values: Dictionary, damage_type: String) -> float:
	return maxf(0.0, float(values.get(damage_type, 0.0)))

static func protection(sheet: CharacterResource, zone: CombatBodyZone, damage_type: String) -> Dictionary:
	var amount := _protection(zone.natural_protection, damage_type)
	var armored := amount > 0.0
	if sheet and sheet.inventory:
		# Nur angelegte Körperplätze, nie Hände, Schmuck oder Schnellausrüstung.
		for slot in ["kopf", "rumpf", "beine", "fuesse"]:
			var item: Variant = sheet.inventory.equipment.get(slot)
			if not item is ItemData or not item.is_armor:
				continue
			var covers: bool = zone.zone_id in item.armor_zones if not item.armor_zones.is_empty() else slot in zone.equipment_slots
			if covers:
				armored = true
				amount += _protection(item.armor_protection, damage_type)
	return {"amount": amount, "armored": armored}

## Profil-Trefferboxen ersetzen für Angriffe die Bewegungskapseln. Keine
## Treffer-Nodes oder Laufzeitkopien von Charakterdaten erforderlich.
static func trace(actor: CombatParticipant, aimed: CombatParticipant, check_walls: bool, zone_id: String = "") -> Dictionary:
	if actor == null or aimed == null or not is_instance_valid(actor.playable) or not is_instance_valid(aimed.playable) or aimed.is_out_of_combat():
		return {}
	var requested := profile(aimed.playable.character)
	if not zone_id.is_empty() and requested.get_zone(zone_id) == null:
		return {}
	var start := aim_point(actor.playable)
	var end := aim_point(aimed.playable, zone_id)
	var candidates: Array[CombatParticipant] = [aimed]
	var session := actor.playable.get_combat_session()
	if is_instance_valid(session):
		candidates = session.participants
	var exclude: Array[RID] = []
	CombatLineOfSight._collect_collision_rids(actor.playable, exclude)
	var nearest := INF
	var found: Dictionary = {}
	for candidate in candidates:
		if not is_instance_valid(candidate.playable) or candidate.playable == actor.playable:
			continue
		CombatLineOfSight._collect_collision_rids(candidate.playable, exclude)
		var transform := frame(candidate.playable)
		var inverse := transform.affine_inverse()
		for zone in profile(candidate.playable.character).zones:
			var box := AABB(zone.center - zone.size * 0.5, zone.size)
			var local_hit: Variant = box.intersects_segment(inverse * start, inverse * end)
			if local_hit == null:
				continue
			var hit: Vector3 = transform * local_hit
			var distance := start.distance_squared_to(hit)
			if distance < nearest:
				nearest = distance
				found = {"target": candidate, "zone_id": zone.zone_id, "position": hit}
	# Wände und nicht registrierte Körper bleiben echte Physik-Hindernisse.
	if actor.playable.is_inside_tree() and aimed.playable.is_inside_tree():
		var mask := CombatLineOfSight.DEFAULT_LOS_MASK if check_walls else CombatLineOfSight.LAYER_PLAYER | CombatLineOfSight.LAYER_NPC
		var query := PhysicsRayQueryParameters3D.create(start, end, mask, exclude)
		query.collide_with_areas = false
		query.hit_from_inside = true
		var obstacle := actor.playable.get_world_3d().direct_space_state.intersect_ray(query)
		if not obstacle.is_empty() and start.distance_squared_to(obstacle.position) <= nearest:
			return {}
	if found.is_empty() or (found.target as CombatParticipant).is_out_of_combat():
		return {}
	return found
