class_name DialogueCameraPoints
extends Node3D

## Referenzpunkte für die Dialogkamera. Keine eigene Camera3D.
## +Z der Marker zeigt nach vorne (Blickrichtung des Charakters).

@export var look_height: float = 1.4

var _last_random_kind: CameraShot.Kind = CameraShot.Kind.RANDOM


static func find_in(host: Node) -> DialogueCameraPoints:
	if host == null or not is_instance_valid(host):
		return null
	if host is DialogueCameraPoints:
		return host
	var direct: Node = host.get_node_or_null("DialogueCameraPoints")
	if direct is DialogueCameraPoints:
		return direct
	for child in host.get_children():
		if child is DialogueCameraPoints:
			return child
	return null


func get_look_position(subject: Node3D) -> Vector3:
	if subject == null or not is_instance_valid(subject):
		return global_position + Vector3.UP * look_height
	return subject.global_position + Vector3.UP * look_height


func resolve_marker(kind: CameraShot.Kind) -> Marker3D:
	_align_to_host()
	var requested := kind
	if requested == CameraShot.Kind.RANDOM:
		requested = pick_random_kind()
	var marker := _find_by_kind(requested)
	if marker:
		return marker
	for fallback in CameraShot.FALLBACK_ORDER:
		if fallback == requested:
			continue
		marker = _find_by_kind(fallback)
		if marker:
			return marker
	return _first_marker()


func resolve_kind(kind: CameraShot.Kind) -> CameraShot.Kind:
	var marker := resolve_marker(kind)
	if marker == null:
		if kind == CameraShot.Kind.RANDOM:
			return CameraShot.Kind.MEDIUM
		return kind if CameraShot.is_concrete(kind) else CameraShot.Kind.MEDIUM
	return marker_kind(marker)


func marker_kind(marker: Marker3D) -> CameraShot.Kind:
	if marker == null or not is_instance_valid(marker):
		return CameraShot.Kind.MEDIUM
	return _kind_of(marker)


func pick_random_kind() -> CameraShot.Kind:
	var entries := _weighted_entries()
	if entries.is_empty():
		return CameraShot.Kind.MEDIUM
	if entries.size() > 1 and _last_random_kind != CameraShot.Kind.RANDOM:
		var filtered: Array[Dictionary] = []
		for entry in entries:
			if entry["kind"] != _last_random_kind:
				filtered.append(entry)
		if not filtered.is_empty():
			entries = filtered
	var total := 0.0
	for entry in entries:
		total += float(entry["weight"])
	if total <= 0.0:
		var fallback_kind: CameraShot.Kind = CameraShot.coerce(entries[0]["kind"])
		_last_random_kind = fallback_kind
		return fallback_kind
	var pick := randf() * total
	var acc := 0.0
	for entry in entries:
		acc += float(entry["weight"])
		if pick <= acc:
			var chosen: CameraShot.Kind = CameraShot.coerce(entry["kind"])
			_last_random_kind = chosen
			return chosen
	var last_kind: CameraShot.Kind = CameraShot.coerce(entries[entries.size() - 1]["kind"])
	_last_random_kind = last_kind
	return last_kind


func has_any_marker() -> bool:
	return _first_marker() != null


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


func _find_by_kind(kind: CameraShot.Kind) -> Marker3D:
	if not CameraShot.is_concrete(kind):
		return null
	for child in get_children():
		if not _is_usable_marker(child):
			continue
		if _kind_of(child as Marker3D) == kind:
			return child as Marker3D
	return null


func _first_marker() -> Marker3D:
	for child in get_children():
		if _is_usable_marker(child):
			return child as Marker3D
	return null


func _kind_of(marker: Marker3D) -> CameraShot.Kind:
	if marker is DialogueCameraMarker:
		var tagged: CameraShot.Kind = (marker as DialogueCameraMarker).shot
		if CameraShot.is_concrete(tagged):
			return tagged
	for kind: CameraShot.Kind in CameraShot.CONCRETE:
		for marker_name in CameraShot.marker_names(kind):
			if marker.name.nocasecmp_to(marker_name) == 0:
				return kind
	return CameraShot.Kind.MEDIUM


func _marker_weight(marker: Marker3D) -> float:
	if marker is DialogueCameraMarker:
		return maxf(0.0, (marker as DialogueCameraMarker).weight)
	return 1.0


func _is_usable_marker(child: Node) -> bool:
	return child is Marker3D and is_instance_valid(child) and (child as Node3D).visible


func _weighted_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for child in get_children():
		if not _is_usable_marker(child):
			continue
		var marker := child as Marker3D
		var kind := _kind_of(marker)
		if not CameraShot.is_concrete(kind):
			continue
		entries.append({
			"kind": kind,
			"weight": _marker_weight(marker),
		})
	return entries
