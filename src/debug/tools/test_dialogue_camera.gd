extends SceneTree

## Headless-Checks für Shot-Auflösung und Fallbacks.
## Start: Godot --headless --path <projekt> -s res://src/debug/tools/test_dialogue_camera.gd


func _init() -> void:
	var failed := 0
	failed += _test_parse()
	failed += _test_named_markers()
	failed += _test_missing_shot_fallback()
	failed += _test_empty_points()
	failed += _test_hidden_markers_random()
	if failed == 0:
		print("dialogue_camera: alle Checks ok")
	else:
		printerr("dialogue_camera: %d Checks fehlgeschlagen" % failed)
	quit(failed)


func _test_parse() -> int:
	if CameraShot.parse("close") != CameraShot.Kind.CLOSE:
		return _fail("parse close")
	if CameraShot.parse("ots") != CameraShot.Kind.OVER_SHOULDER:
		return _fail("parse ots")
	if CameraShot.parse("random") != CameraShot.Kind.RANDOM:
		return _fail("parse random")
	if CameraShot.coerce("medium") != CameraShot.Kind.MEDIUM:
		return _fail("coerce medium")
	return 0


func _test_named_markers() -> int:
	var points := _make_points(["Close", "Medium", "Profile"])
	var close := points.resolve_marker(CameraShot.Kind.CLOSE)
	var medium := points.resolve_marker(CameraShot.Kind.MEDIUM)
	var profile := points.resolve_marker(CameraShot.Kind.PROFILE)
	if close == null or close.name != "Close":
		return _fail("resolve CLOSE")
	if medium == null or medium.name != "Medium":
		return _fail("resolve MEDIUM")
	if profile == null or profile.name != "Profile":
		return _fail("resolve PROFILE")
	points.free()
	return 0


func _test_missing_shot_fallback() -> int:
	var points := _make_points(["Close", "Medium", "Profile"])
	var marker := points.resolve_marker(CameraShot.Kind.WIDE)
	if marker == null or points.marker_kind(marker) != CameraShot.Kind.MEDIUM:
		points.free()
		return _fail("WIDE sollte auf MEDIUM fallen")
	var ots := points.resolve_marker(CameraShot.Kind.OVER_SHOULDER)
	if ots == null or points.marker_kind(ots) != CameraShot.Kind.MEDIUM:
		points.free()
		return _fail("OVER_SHOULDER sollte auf MEDIUM fallen")
	points.free()
	return 0


func _test_empty_points() -> int:
	var points := DialogueCameraPoints.new()
	points.name = "DialogueCameraPoints"
	if points.resolve_marker(CameraShot.Kind.CLOSE) != null:
		points.free()
		return _fail("leere Points müssen null liefern")
	if points.has_any_marker():
		points.free()
		return _fail("has_any_marker bei leeren Points")
	points.free()
	return 0


func _test_hidden_markers_random() -> int:
	var points := _make_points(["Close", "Medium", "Wide"])
	var wide := points.get_node("Wide") as Marker3D
	wide.visible = false
	var kinds: Dictionary = {}
	for _i: int in 24:
		var kind := points.pick_random_kind()
		if kind == CameraShot.Kind.WIDE:
			points.free()
			return _fail("RANDOM darf unsichtbares Wide nicht wählen")
		kinds[kind] = true
	if kinds.size() < 2:
		points.free()
		return _fail("RANDOM sollte verschiedene vorhandene Shots wählen")
	var wide_marker := points.resolve_marker(CameraShot.Kind.WIDE)
	if wide_marker == null or wide_marker.name == "Wide":
		points.free()
		return _fail("verstecktes Wide muss fallbacken")
	points.free()
	return 0


func _make_points(names: PackedStringArray) -> DialogueCameraPoints:
	var points := DialogueCameraPoints.new()
	points.name = "DialogueCameraPoints"
	for marker_name in names:
		var marker := Marker3D.new()
		marker.name = marker_name
		points.add_child(marker)
	return points


func _fail(message: String) -> int:
	printerr("FAIL: %s" % message)
	return 1
