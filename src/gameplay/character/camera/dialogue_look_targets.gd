class_name DialogueLookTargets
extends Node3D

## Blickziele für die Dialogkamera (Eyes / Head / Mouth). Keine eigene Kamera.


static func find_in(host: Node) -> DialogueLookTargets:
	if host == null or not is_instance_valid(host):
		return null
	if host is DialogueLookTargets:
		return host
	var direct: Node = host.get_node_or_null("DialogueLookTargets")
	if direct is DialogueLookTargets:
		return direct
	for child in host.get_children():
		if child is DialogueLookTargets:
			return child
	return null


func resolve_marker(look: CameraShot.Look) -> Marker3D:
	_align_to_host()
	if look == CameraShot.Look.NONE:
		return null
	var requested := look
	if requested == CameraShot.Look.AUTO:
		requested = CameraShot.Look.EYES
	var marker := _find_by_look(requested)
	if marker:
		return marker
	for fallback in CameraShot.look_fallback_order(requested):
		if fallback == requested:
			continue
		marker = _find_by_look(fallback)
		if marker:
			return marker
	return _first_marker()


func _find_by_look(look: CameraShot.Look) -> Marker3D:
	for child in get_children():
		if not _is_usable_marker(child):
			continue
		if _look_of(child as Marker3D) == look:
			return child as Marker3D
	return null


func _first_marker() -> Marker3D:
	for child in get_children():
		if _is_usable_marker(child):
			return child as Marker3D
	return null


func _look_of(marker: Marker3D) -> CameraShot.Look:
	var looks: Array[CameraShot.Look] = [CameraShot.Look.EYES, CameraShot.Look.HEAD, CameraShot.Look.MOUTH]
	for look: CameraShot.Look in looks:
		for marker_name in CameraShot.look_marker_names(look):
			if marker.name.nocasecmp_to(marker_name) == 0:
				return look
	return CameraShot.Look.NONE


func _is_usable_marker(child: Node) -> bool:
	return child is Marker3D and is_instance_valid(child) and (child as Node3D).visible


func _align_to_host() -> void:
	var host: Node = get_parent()
	if host == null or not ("facing_direction" in host):
		return
	var facing_value: Variant = host.get("facing_direction")
	if not (facing_value is Vector3):
		return
	var facing: Vector3 = facing_value
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		return
	look_at(global_position + facing.normalized(), Vector3.UP, true)
