extends Node

## Gemeinsame Ansichten für Handausrüstung und vorhandene Kopfmodelle.

const VISUAL := preload("res://src/resources/items/item_visual.gd")
const SOCKET_BONES := {"primaer_hand": "RightHand", "nebenhand": "LeftHand", "kopf": "Head"}
var _head_rotation := Basis.IDENTITY
var _head_offset := Vector3.ZERO
var actor: Playable
var _sheet: CharacterResource
var _sockets: Dictionary = {}
var _items: Dictionary = {}
var _visuals: Dictionary = {}

func setup(owner_actor: Playable) -> void:
	actor = owner_actor
	process_priority = 100
	var model := actor.get_node_or_null("Model") as Node3D
	var skeleton := _find_skeleton(model)
	for slot in SOCKET_BONES:
		var socket: Node3D
		var bone := skeleton.find_bone(SOCKET_BONES[slot]) if skeleton else -1
		if bone >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.bone_name = SOCKET_BONES[slot]
			skeleton.add_child(attachment)
			socket = attachment
			if slot == "kopf":
				var pose := skeleton.global_basis * skeleton.get_bone_global_pose(bone).basis
				_head_rotation = pose.orthonormalized().inverse() * CombatAnatomy.frame(actor).basis
				var front := skeleton.find_bone("headfront")
				var rear := skeleton.find_bone("head_end")
				if front >= 0 and rear >= 0:
					var center := (skeleton.get_bone_global_pose(front).origin + skeleton.get_bone_global_pose(rear).origin) * 0.5
					_head_offset = skeleton.get_bone_global_pose(bone).affine_inverse() * center
		else:
			socket = Node3D.new()
			actor.add_child(socket)
		socket.name = "Held_" + slot
		_sockets[slot] = socket
	_bind_sheet()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _bind_sheet() -> void:
	if is_instance_valid(_sheet) and _sheet.inventory_changed.is_connected(_sync):
		_sheet.inventory_changed.disconnect(_sync)
	_sheet = actor.character
	if _sheet:
		_sheet.ensure_equipment_slots()
		_sheet.inventory_changed.connect(_sync)
	_sync()

func _sync() -> void:
	for slot in SOCKET_BONES:
		var item: ItemData = _sheet.inventory.equipment.get(slot) if _sheet and _sheet.inventory else null
		if slot == "kopf" and item and not VISUAL.ARMOR_MODELS.has(item.item_id):
			item = null
		if _items.get(slot) == item:
			continue
		var previous := _visuals.get(slot) as Node3D
		if is_instance_valid(previous):
			previous.hide()
			previous.queue_free()
		_visuals.erase(slot)
		_items[slot] = item
		if item:
			var visual := VISUAL.create(item)
			_sockets[slot].add_child(visual)
			if slot == "kopf":
				visual.basis = _head_rotation
				visual.position = _head_offset
			else:
				visual.rotation.x = -PI * 0.5
			_visuals[slot] = visual
	_update_scale()

func _process(_delta: float) -> void:
	if actor.character != _sheet:
		_bind_sheet()
	else:
		_sync() # berücksichtigt auch direkte Änderungen am bestehenden Equipment-Dictionary

func _update_scale() -> void:
	for slot in _visuals:
		var socket := _sockets[slot] as Node3D
		if not socket is BoneAttachment3D:
			var forward := Vector3(actor.facing_direction.x, 0, actor.facing_direction.z).normalized()
			if forward.is_zero_approx():
				forward = Vector3.BACK
			socket.global_transform = Transform3D(Basis(Vector3.UP.cross(forward), Vector3.UP, forward), actor.global_position)
			var offset := (CombatAnatomy.profile(actor.character).get_zone("head").center - VISUAL.bounds(_visuals[slot]).get_center()) if slot == "kopf" else Vector3(0.3 if slot == "primaer_hand" else -0.3, 0.6, 0.05)
			socket.global_position += socket.global_basis * offset
		# GLB-Armatures sind teils auf 0,01 skaliert. Gegenstände bleiben in Weltmetern.
		var inherited := socket.global_transform.basis.get_scale().abs()
		_visuals[slot].scale = Vector3(1.0 / maxf(inherited.x, 0.0001), 1.0 / maxf(inherited.y, 0.0001), 1.0 / maxf(inherited.z, 0.0001))

func _exit_tree() -> void:
	if is_instance_valid(_sheet) and _sheet.inventory_changed.is_connected(_sync):
		_sheet.inventory_changed.disconnect(_sync)
	for socket in _sockets.values():
		if is_instance_valid(socket):
			socket.queue_free()
	_sockets.clear()
	_visuals.clear()
	_items.clear()
	_sheet = null
