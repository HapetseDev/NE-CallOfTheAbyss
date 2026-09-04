class_name CombatLineOfSight

## Prüft, ob zwischen zwei Charakteren eine freie Sichtlinie besteht (kein
## anderer Körper – Wand oder Charakter – steht dazwischen). Nahkampf,
## Fernkampf und die meiste Magie sind ohne freie Sicht nicht anwendbar.
##
## Adaptiert das Raycast-Muster aus occlusion_visual.gd (PhysicsRayQueryParameters3D,
## RID-Exclude der eigenen Collider, Boden-Normalen-Filter). Anders als dort zählen
## hier andere Charakterkörper selbst als Blocker, nicht nur Wände.

const EYE_HEIGHT := 1.5
const FLOOR_NORMAL_Y := 0.65

## Layer-Werte aus project.godot: Player=1, Walls=16(Bit 5), NPC=256(Bit 9).
const LAYER_PLAYER := 1
const LAYER_WALLS := 16
const LAYER_NPC := 256
const DEFAULT_LOS_MASK := LAYER_PLAYER | LAYER_WALLS | LAYER_NPC


static func has_clear_line(from: Node3D, to: Node3D, mask: int = DEFAULT_LOS_MASK) -> bool:
	return get_blocking_body(from, to, mask) == null


## Gibt den blockierenden Node zurück, oder null wenn die Sicht frei ist.
static func get_blocking_body(from: Node3D, to: Node3D, mask: int = DEFAULT_LOS_MASK) -> Node:
	if from == null or to == null or not is_instance_valid(from) or not is_instance_valid(to):
		return null
	var world := from.get_world_3d()
	if world == null:
		return null
	var space := world.direct_space_state
	if space == null:
		return null

	var from_pos := from.global_position + Vector3.UP * EYE_HEIGHT
	var to_pos := to.global_position + Vector3.UP * EYE_HEIGHT

	var exclude: Array[RID] = []
	_collect_collision_rids(from, exclude)
	_collect_collision_rids(to, exclude)

	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = mask
	query.exclude = exclude

	var result := space.intersect_ray(query)
	if result.is_empty():
		return null

	var normal: Vector3 = result.get("normal", Vector3.UP)
	if normal.y > FLOOR_NORMAL_Y:
		return null

	return result.get("collider") as Node


static func _collect_collision_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_collision_rids(child, out)
