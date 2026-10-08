extends RefCounted

## Unterstützte Rollen der vorhandenen Szenen, keine frei ladbaren Szenenpfade.
const LEADER := "dannerman"
const MEMBERS := ["dannerman", "shalka"]

static func valid(data: Variant, registry: CharacterRegistry, allow_empty: bool = false) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		return allow_empty
	if data.size() != 2 or not data.get("leader_id") in MEMBERS or not data.get("member_ids") is Array:
		return false
	var members: Array = data.member_ids
	if members.is_empty() or members[0] != data.leader_id:
		return false
	var seen: Dictionary = {}
	for id in members:
		if not id is String or not MEMBERS.has(id) or seen.has(id) or registry.get_character(id) == null:
			return false
		seen[id] = true
	return true


## Alte Spielstände hatten ausschließlich die fest eingebaute Startparty.
static func migrate(active_location: String) -> Dictionary:
	if active_location.is_empty():
		return {}
	return {"leader_id": LEADER, "member_ids": [LEADER, "shalka"]}
