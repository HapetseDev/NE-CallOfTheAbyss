extends SceneTree

const _LookTargets := preload("res://src/gameplay/character/camera/dialogue_look_targets.gd")
const _Marker := preload("res://src/gameplay/character/camera/dialogue_camera_marker.gd")
const _ShotEvent := preload("res://src/core/systems/camera_shot_event.gd")
const _EventHub := preload("res://src/core/systems/camera_event_hub.gd")

## Headless-Checks für Shot-Auflösung und Fallbacks.
## Start: Godot --headless --path <projekt> -s res://src/debug/tools/test_dialogue_camera.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_parse()
	failed += _test_named_markers()
	failed += _test_missing_shot_fallback()
	failed += _test_empty_points()
	failed += _test_hidden_markers_random()
	failed += _test_look_parse()
	failed += _test_look_targets()
	failed += _test_look_fallback()
	failed += _test_look_missing()
	failed += _test_explicit_over_tags()
	failed += _test_random_tags()
	failed += _test_missing_tag_fallback()
	failed += _test_weighted_pick()
	failed += _test_avoid_repeat()
	failed += _test_unavailable_ots()
	failed += _test_tag_helpers()
	failed += _test_fov_helpers()
	failed += _test_shot_fov_transitions()
	failed += _test_shot_without_fov()
	failed += _test_rapid_shot_interrupt()
	failed += _test_restore_during_tween()
	failed += _test_camera_events()
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


func _test_look_parse() -> int:
	if CameraShot.parse_look("eyes") != CameraShot.Look.EYES:
		return _fail("parse look eyes")
	if CameraShot.parse_look("head") != CameraShot.Look.HEAD:
		return _fail("parse look head")
	if CameraShot.parse_look("none") != CameraShot.Look.NONE:
		return _fail("parse look none")
	if CameraShot.default_look(CameraShot.Kind.CLOSE) != CameraShot.Look.EYES:
		return _fail("CLOSE default look")
	if CameraShot.default_look(CameraShot.Kind.MEDIUM) != CameraShot.Look.HEAD:
		return _fail("MEDIUM default look")
	return 0


func _test_look_targets() -> int:
	var looks: Node3D = _make_looks(["Eyes", "Head", "Mouth"]) as Node3D
	var eyes: Marker3D = looks.call("resolve_marker", CameraShot.Look.EYES) as Marker3D
	var head: Marker3D = looks.call("resolve_marker", CameraShot.Look.HEAD) as Marker3D
	if eyes == null or eyes.name != "Eyes":
		looks.free()
		return _fail("resolve Eyes")
	if head == null or head.name != "Head":
		looks.free()
		return _fail("resolve Head")
	looks.free()
	return 0


func _test_look_fallback() -> int:
	var looks: Node3D = _make_looks(["Head"]) as Node3D
	var eyes: Marker3D = looks.call("resolve_marker", CameraShot.Look.EYES) as Marker3D
	if eyes == null or eyes.name != "Head":
		looks.free()
		return _fail("Eyes sollte auf Head fallen")
	var mouth: Marker3D = looks.call("resolve_marker", CameraShot.Look.MOUTH) as Marker3D
	if mouth == null or mouth.name != "Head":
		looks.free()
		return _fail("Mouth sollte auf Head fallen")
	looks.free()
	return 0


func _test_look_missing() -> int:
	var looks: Node3D = _LookTargets.new() as Node3D
	looks.name = "DialogueLookTargets"
	if looks.call("resolve_marker", CameraShot.Look.EYES) != null:
		looks.free()
		return _fail("leere LookTargets müssen null liefern")
	if looks.call("resolve_marker", CameraShot.Look.NONE) != null:
		looks.free()
		return _fail("Look.NONE muss null bleiben")
	looks.free()
	return 0


func _test_explicit_over_tags() -> int:
	var points := _make_points(["Close", "Medium", "Profile"])
	var marker := points.resolve_marker(CameraShot.Kind.PROFILE, PackedStringArray(["emotional"]))
	if marker == null or marker.name != "Profile":
		points.free()
		return _fail("expliziter Shot muss Tags ignorieren")
	points.free()
	return 0


func _test_random_tags() -> int:
	var points := _make_points(["Close", "Medium", "Profile"])
	for _i: int in 16:
		var kind := points.pick_random_kind(PackedStringArray(["emotional"]), false)
		if kind != CameraShot.Kind.CLOSE:
			points.free()
			return _fail("emotional sollte Close wählen")
	points.free()
	return 0


func _test_missing_tag_fallback() -> int:
	var points := _make_points(["Close", "Medium"])
	var kinds: Dictionary = {}
	for _i: int in 24:
		var kind := points.pick_random_kind(PackedStringArray(["unknown_mood"]), false)
		kinds[kind] = true
	if kinds.size() < 2:
		points.free()
		return _fail("unbekannter Tag muss auf alle Shots fallen")
	points.free()
	return 0


func _test_weighted_pick() -> int:
	var points := DialogueCameraPoints.new()
	points.name = "DialogueCameraPoints"
	_add_weighted_marker(points, "Close", 20.0)
	_add_weighted_marker(points, "Profile", 1.0)
	var close_hits := 0
	for _i: int in 80:
		points.reset_last_shot()
		if points.pick_random_kind(PackedStringArray(), false) == CameraShot.Kind.CLOSE:
			close_hits += 1
	points.free()
	if close_hits < 50:
		return _fail("Close mit höherem Gewicht zu selten: %d/80" % close_hits)
	return 0


func _test_avoid_repeat() -> int:
	var points := _make_points(["Close", "Medium"])
	var previous: CameraShot.Kind = points.pick_random_kind()
	for _i: int in 12:
		var kind := points.pick_random_kind()
		if kind == previous:
			points.free()
			return _fail("Random darf denselben Shot nicht direkt wiederholen")
		previous = kind
	points.free()
	return 0


func _test_unavailable_ots() -> int:
	var points := _make_points(["Close", "Medium", "Profile"])
	for _i: int in 24:
		var kind := points.pick_random_kind(PackedStringArray(), false)
		if kind == CameraShot.Kind.OVER_SHOULDER:
			points.free()
			return _fail("RANDOM darf fehlendes OverShoulder nicht wählen")
		if kind == CameraShot.Kind.WIDE:
			points.free()
			return _fail("RANDOM darf fehlendes Wide nicht wählen")
	points.free()
	return 0


func _test_tag_helpers() -> int:
	var tags := CameraShot.split_tags("emotional+intimate, dramatic")
	if tags.size() != 3 or tags[0] != "emotional" or not tags.has("dramatic"):
		return _fail("split_tags")
	var close_tags := CameraShot.default_tags(CameraShot.Kind.CLOSE)
	if not close_tags.has("emotional") or not close_tags.has("intimate"):
		return _fail("default_tags CLOSE")
	if not CameraShot.default_tags(CameraShot.Kind.PROFILE).has("dramatic"):
		return _fail("default_tags PROFILE")
	return 0


func _test_fov_helpers() -> int:
	if not is_equal_approx(CameraShot.resolve_fov(0.0, 50.0), 50.0):
		return _fail("FOV 0 muss aktuellen Wert behalten")
	if not is_equal_approx(CameraShot.resolve_fov(62.0, 50.0), 62.0):
		return _fail("expliziter FOV")
	if not is_equal_approx(CameraShot.resolve_duration(-1.0, 0.35), 0.35):
		return _fail("Duration-Default")
	if not is_equal_approx(CameraShot.resolve_duration(0.5, 0.35), 0.5):
		return _fail("eigene Duration")
	if not is_equal_approx(CameraShot.resolve_duration(0.0, 0.35), 0.0):
		return _fail("Duration 0 ist sofort")
	if CameraShot.tween_ease(CameraShot.TransitionEase.OUT) != Tween.EASE_OUT:
		return _fail("Ease OUT")
	if CameraShot.tween_ease(CameraShot.TransitionEase.DEFAULT) != Tween.EASE_IN_OUT:
		return _fail("Ease DEFAULT")
	if not is_equal_approx(CameraShot.suggested_fov(CameraShot.Kind.CLOSE), 62.0):
		return _fail("suggested FOV CLOSE")
	if not is_equal_approx(CameraShot.suggested_fov(CameraShot.Kind.WIDE), 40.0):
		return _fail("suggested FOV WIDE")
	return 0


func _test_shot_fov_transitions() -> int:
	var rig := _make_tween_rig(50.0)
	var host: Node = rig["host"]
	var cam: Camera3D = rig["cam"]
	var tween: Tween = null
	var medium := _shot_xf(Vector3(0.5, 1.5, 2.4))
	var close := _shot_xf(Vector3(0.3, 1.4, 1.2))
	var profile := _shot_xf(Vector3(1.9, 1.5, 0.3))
	tween = CameraShot.tween_camera(host, cam, medium, 0.0, 50.0, CameraShot.TransitionEase.DEFAULT, tween)
	if not is_equal_approx(cam.fov, 50.0):
		return _fail_tween("Medium FOV", rig)
	var medium_origin := cam.global_position
	tween = CameraShot.tween_camera(host, cam, close, 0.0, 62.0, CameraShot.TransitionEase.OUT, tween)
	if not is_equal_approx(cam.fov, 62.0):
		return _fail_tween("Medium→Close FOV", rig)
	if medium_origin.is_equal_approx(cam.global_position):
		return _fail_tween("Medium→Close Position", rig)
	tween = CameraShot.tween_camera(host, cam, medium, 0.0, 50.0, CameraShot.TransitionEase.DEFAULT, tween)
	if not is_equal_approx(cam.fov, 50.0):
		return _fail_tween("Close→Medium FOV", rig)
	tween = CameraShot.tween_camera(host, cam, profile, 0.0, 48.0, CameraShot.TransitionEase.DEFAULT, tween)
	if not is_equal_approx(cam.fov, 48.0):
		return _fail_tween("Close→Profile FOV", rig)
	_free_tween_rig(rig)
	return 0


func _test_shot_without_fov() -> int:
	var rig := _make_tween_rig(50.0)
	var cam: Camera3D = rig["cam"]
	var inherit := CameraShot.resolve_fov(CameraShot.INHERIT_FOV, cam.fov)
	CameraShot.tween_camera(rig["host"], cam, _shot_xf(Vector3(0.3, 1.4, 1.2)), 0.0, inherit)
	if not is_equal_approx(cam.fov, 50.0):
		return _fail_tween("Shot ohne FOV muss 50 behalten", rig)
	var marker: Marker3D = _Marker.new() as Marker3D
	if not is_equal_approx(float(marker.get("fov")), 0.0):
		marker.free()
		return _fail_tween("Marker-Default FOV ist inherit", rig)
	if not is_equal_approx(float(marker.get("transition_sec")), CameraShot.DEFAULT_TRANSITION_SEC):
		marker.free()
		return _fail_tween("Marker-Default Duration", rig)
	marker.free()
	_free_tween_rig(rig)
	return 0


func _test_rapid_shot_interrupt() -> int:
	var rig := _make_tween_rig(50.0)
	var host: Node = rig["host"]
	var cam: Camera3D = rig["cam"]
	var tween: Tween = CameraShot.tween_camera(host, cam, _shot_xf(Vector3(0.5, 1.5, 2.4)), 8.0, 50.0)
	tween = CameraShot.tween_camera(host, cam, _shot_xf(Vector3(0.3, 1.4, 1.2)), 8.0, 62.0, CameraShot.TransitionEase.OUT, tween)
	tween = CameraShot.tween_camera(host, cam, _shot_xf(Vector3(1.9, 1.5, 0.3)), 0.0, 48.0, CameraShot.TransitionEase.DEFAULT, tween)
	if not is_equal_approx(cam.fov, 48.0):
		return _fail_tween("schnelle Wechsel müssen beim letzten Shot landen", rig)
	if tween != null:
		return _fail_tween("sofortiger letzter Shot darf keinen Tween hinterlassen", rig)
	_free_tween_rig(rig)
	return 0


func _test_restore_during_tween() -> int:
	var rig := _make_tween_rig(50.0)
	var host: Node = rig["host"]
	var cam: Camera3D = rig["cam"]
	var saved_xf := cam.global_transform
	var saved_fov := cam.fov
	var tween: Tween = CameraShot.tween_camera(host, cam, _shot_xf(Vector3(0.3, 1.4, 1.2)), 0.0, 62.0)
	if not is_equal_approx(cam.fov, 62.0):
		return _fail_tween("Close muss FOV ändern", rig)
	if not is_equal_approx(CameraShot.resolve_duration(0.5, 0.35), 0.5):
		return _fail_tween("Wide Duration", rig)
	tween = CameraShot.tween_camera(host, cam, _shot_xf(Vector3(0.8, 2.0, 4.5)), 8.0, 40.0, CameraShot.TransitionEase.IN_OUT, tween)
	tween = CameraShot.tween_camera(host, cam, saved_xf, 0.0, saved_fov, CameraShot.TransitionEase.DEFAULT, tween)
	if not is_equal_approx(cam.fov, 50.0):
		return _fail_tween("Gameplay-FOV nach Dialogende", rig)
	if not saved_xf.origin.is_equal_approx(cam.global_position):
		return _fail_tween("Gameplay-Position nach Dialogende", rig)
	_free_tween_rig(rig)
	return 0


func _make_tween_rig(start_fov: float) -> Dictionary:
	var host := Node.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = start_fov
	host.add_child(cam)
	root.add_child(host)
	return {"host": host, "cam": cam}


func _shot_xf(origin: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, origin).looking_at(origin + Vector3(0.0, 0.0, -1.0), Vector3.UP)


func _free_tween_rig(rig: Dictionary) -> void:
	var host: Node = rig["host"]
	if is_instance_valid(host):
		host.free()


func _fail_tween(message: String, rig: Dictionary) -> int:
	_free_tween_rig(rig)
	return _fail(message)


func _test_camera_events() -> int:
	var hub: Object = _EventHub.new()
	var log: Array[String] = []
	var box: Array = [null]
	var on_shot := func(event: Variant) -> void:
		box[0] = event
		log.append("shot:%s" % CameraShot.tag_name(event.shot))
	var on_done := func(event: Variant) -> void:
		log.append("done:%s" % String(event.source))
	var on_return := func() -> void:
		log.append("returned")

	hub.notify_shot_changed(null)
	if not log.is_empty():
		return _fail("ohne Listener darf emit nichts tun")

	hub.listen_shot_changed(on_shot)
	hub.listen_shot_changed(on_shot)
	hub.listen_transition_finished(on_done)
	hub.listen_control_returned(on_return)

	var npc := Node3D.new()
	npc.name = "EventNPC"
	root.add_child(npc)
	var close: Variant = _ShotEvent.make(npc, CameraShot.Kind.CLOSE, npc, 0.35)
	hub.notify_shot_changed(close)
	hub.notify_transition_finished(close)
	var last_event: Variant = box[0]
	if last_event == null:
		npc.free()
		return _fail("shot_changed ohne Event")
	if last_event.get("character") != npc:
		npc.free()
		return _fail("shot_changed Character")
	if int(last_event.get("shot")) != int(CameraShot.Kind.CLOSE):
		npc.free()
		return _fail("shot_changed Shot: %s" % str(last_event.get("shot")))
	if not is_equal_approx(float(last_event.duration), 0.35):
		npc.free()
		return _fail("shot_changed Duration")

	var medium: Variant = _ShotEvent.make(npc, CameraShot.Kind.MEDIUM, npc, 0.0)
	hub.notify_shot_changed(medium)
	var profile: Variant = _ShotEvent.make(npc, CameraShot.Kind.PROFILE, npc, 0.0)
	hub.notify_shot_changed(profile)
	hub.notify_transition_finished(profile)
	if log.count("shot:close") != 1 or log.count("shot:medium") != 1 or log.count("shot:profile") != 1:
		npc.free()
		return _fail("mehrere Shots hintereinander")

	var restore: Variant = _ShotEvent.make_restore(0.35, 50.0)
	hub.notify_transition_finished(restore)
	hub.notify_control_returned()
	if not log.has("done:restore") or not log.has("returned"):
		npc.free()
		return _fail("Dialogende muss restore + control_returned senden")

	var before_unlisten := log.size()
	hub.unlisten_shot_changed(on_shot)
	hub.unlisten_transition_finished(on_done)
	hub.unlisten_control_returned(on_return)
	hub.notify_shot_changed(close)
	hub.notify_control_returned()
	if log.size() != before_unlisten:
		npc.free()
		return _fail("entfernte Listener dürfen nichts mehr empfangen")

	var abort_log: Array[String] = []
	var on_abort := func() -> void:
		abort_log.append("returned")
	hub.listen_control_returned(on_abort)
	hub.notify_shot_changed(close)
	hub.notify_control_returned()
	if abort_log != ["returned"]:
		npc.free()
		return _fail("Levelwechsel/Deaktivieren bricht ohne transition_finished ab")
	hub.unlisten_control_returned(on_abort)
	npc.free()
	return 0


func _add_weighted_marker(points: DialogueCameraPoints, marker_name: String, weight: float) -> void:
	var marker: Marker3D = _Marker.new() as Marker3D
	marker.name = marker_name
	marker.set("weight", weight)
	marker.set("shot", CameraShot.parse(marker_name))
	points.add_child(marker)


func _make_looks(names: PackedStringArray):
	var looks := _LookTargets.new()
	looks.name = "DialogueLookTargets"
	for marker_name in names:
		var marker := Marker3D.new()
		marker.name = marker_name
		looks.add_child(marker)
	return looks


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
