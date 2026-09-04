class_name CombatParticipantResolver
extends Object

## Entscheidet, wer sich an einem Kampf beteiligt und auf welcher Seite –
## rein über Beziehungen (RelationshipService), nicht über feste
## "Spieler vs. Gegner"-Zuordnung. Auch eigene Party-Mitglieder können so
## gegen die eigene Seite antreten, wenn ihre Beziehung es nahelegt.

const SIDE_ATTACKER := &"attacker_side"
const SIDE_VICTIM := &"victim_side"
const SIDE_NEUTRAL := &"neutral"

const COMBAT_REACTIVE_GROUP := "combat_reactive"


## Ordnet candidate anhand seiner Beziehung zu attacker und victim einer
## Kampfseite zu. Verbündete des Opfers greifen zu dessen Gunsten ein,
## Verbündete des Angreifers unterstützen ihn, alle anderen bleiben neutral
## und schauen zu.
static func classify(candidate: Playable, attacker: Playable, victim: Playable) -> StringName:
	if candidate == null or candidate.character == null:
		return SIDE_NEUTRAL
	if candidate == attacker:
		return SIDE_ATTACKER
	if candidate == victim:
		return SIDE_VICTIM

	var disp_to_victim := 0
	if victim and victim.character:
		disp_to_victim = RelationshipService.get_disposition(candidate.character, victim.character)
	var disp_to_attacker := 0
	if attacker and attacker.character:
		disp_to_attacker = RelationshipService.get_disposition(candidate.character, attacker.character)

	if disp_to_victim > 0 and disp_to_victim >= disp_to_attacker:
		return SIDE_VICTIM
	if disp_to_attacker > 0 and disp_to_attacker > disp_to_victim:
		return SIDE_ATTACKER
	return SIDE_NEUTRAL


## Sammelt kampffähige Kandidaten (Gruppe "combat_reactive") im Radius um origin,
## origin selbst ausgenommen.
static func scan_candidates(origin: Node3D, radius: float = CombatBalance.AWARENESS_RADIUS) -> Array[Playable]:
	var result: Array[Playable] = []
	if origin == null or not is_instance_valid(origin):
		return result
	var tree := origin.get_tree()
	if tree == null:
		return result
	var radius_sq := radius * radius
	for node in tree.get_nodes_in_group(COMBAT_REACTIVE_GROUP):
		if node == origin or not (node is Playable):
			continue
		var playable := node as Playable
		if playable.global_position.distance_squared_to(origin.global_position) <= radius_sq:
			result.append(playable)
	return result
