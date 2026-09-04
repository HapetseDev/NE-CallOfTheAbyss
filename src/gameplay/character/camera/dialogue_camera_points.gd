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


func resolve_marker(kind: CameraShot.Kind, shot_tags: PackedStringArray = PackedStringArray()) -> Marker3D:
	_align_to_host()
	var requested := kind
	if requested == CameraShot.Kind.RANDOM:
		requested = pick_random_kind(shot_tags)
	var marker := _find_by_kind(requested)
	if marker:
		_remember_kind(requested)
		return marker
	for fallback in CameraShot.FALLBACK_ORDER:
		if fallback == requested:
			continue
		marker = _find_by_kind(fallback)
		if marker:
			_remember_kind(fallback)
			return marker
	var first := _first_marker()
	if first:
		_remember_kind(_kind_of(first))
	return first


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


func pick_random_kind(
	shot_tags: PackedStringArray = PackedStringArray(),
	avoid_repeat: bool = true
) -> CameraShot.Kind:
	var entries := _weighted_entries(shot_tags)
	if entries.is_empty() and not shot_tags.is_empty():
		entries = _weighted_entries(PackedStringArray())
	if entries.is_empty():
		return CameraShot.Kind.MEDIUM
	if avoid_repeat and entries.size() > 1 and _last_random_kind != CameraShot.Kind.RANDOM:
		var filtered: Array[Dictionary] = []
		for entry in entries:
			if entry["kind"] != _last_random_kind:
				filtered.append(entry)
		if not filtered.is_empty():
			entries = filtered
	var chosen := _pick_weighted(entries)
	_remember_kind(chosen)
	return chosen


func reset_last_shot() -> void:
	_last_random_kind = CameraShot.Kind.RANDOM


func _remember_kind(kind: CameraShot.Kind) -> void:
	if CameraShot.is_concrete(kind):
		_last_random_kind = kind


func _pick_weighted(entries: Array[Dictionary]) -> CameraShot.Kind:
	var total := 0.0
	for entry in entries:
		total += float(entry["weight"])
	if total <= 0.0:
		return CameraShot.coerce(entries[0]["kind"])
	var pick := randf() * total
	var acc := 0.0
	for entry in entries:
		acc += float(entry["weight"])
		if pick <= acc:
			return CameraShot.coerce(entry["kind"])
	return CameraShot.coerce(entries[entries.size() - 1]["kind"])


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


func _marker_tags(marker: Marker3D) -> PackedStringArray:
	if marker is DialogueCameraMarker:
		var custom: PackedStringArray = (marker as DialogueCameraMarker).tags
		if not custom.is_empty():
			var normalized: PackedStringArray = []
			for raw in custom:
				var tag := CameraShot.normalize_tag(raw)
				if not tag.is_empty() and not normalized.has(tag):
					normalized.append(tag)
			if not normalized.is_empty():
				return normalized
	return CameraShot.default_tags(_kind_of(marker))


func _marker_matches_tags(marker: Marker3D, shot_tags: PackedStringArray) -> bool:
	if shot_tags.is_empty():
		return true
	var owned := _marker_tags(marker)
	for requested in shot_tags:
		var tag := CameraShot.normalize_tag(requested)
		if not tag.is_empty() and owned.has(tag):
			return true
	return false


func _is_usable_marker(child: Node) -> bool:
	return child is Marker3D and is_instance_valid(child) and (child as Node3D).visible


func _weighted_entries(shot_tags: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for child in get_children():
		if not _is_usable_marker(child):
			continue
		var marker := child as Marker3D
		var kind := _kind_of(marker)
		if not CameraShot.is_concrete(kind):
			continue
		if not _marker_matches_tags(marker, shot_tags):
			continue
		entries.append({
			"kind": kind,
			"weight": _marker_weight(marker),
		})
	return entries
