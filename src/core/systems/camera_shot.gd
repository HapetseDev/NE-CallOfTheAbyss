class_name CameraShot

## Gemeinsame Shot-Typen für DialogueSystem und CameraSystem.
## Neue Einstellungen hier ergänzen und optional einen Marker-Namen mappen.

enum Kind {
	CLOSE,
	MEDIUM,
	WIDE,
	PROFILE,
	OVER_SHOULDER,
	RANDOM,
}

enum Look {
	AUTO,
	NONE,
	EYES,
	HEAD,
	MOUTH,
}

enum TransitionEase {
	DEFAULT,
	IN,
	OUT,
	IN_OUT,
}

## fov <= 0: aktuellen Kamera-FOV behalten. transition_sec < 0: System-Default.
const INHERIT_FOV: float = 0.0
const DEFAULT_TRANSITION_SEC: float = -1.0

const CONCRETE: Array[Kind] = [
	Kind.CLOSE,
	Kind.MEDIUM,
	Kind.WIDE,
	Kind.PROFILE,
	Kind.OVER_SHOULDER,
]

## CLOSE fehlt → MEDIUM, danach weitere vorhandene Shots, zuletzt eine berechnete Position.
const FALLBACK_ORDER: Array[Kind] = [
	Kind.MEDIUM,
	Kind.CLOSE,
	Kind.WIDE,
	Kind.PROFILE,
	Kind.OVER_SHOULDER,
]


static func parse(text: String, default_kind: Kind = Kind.MEDIUM) -> Kind:
	var key := _normalize(text)
	if key.is_empty():
		return default_kind
	match key:
		"close", "closeup", "close_up", "cu":
			return Kind.CLOSE
		"medium", "medium_shot", "mid", "ms":
			return Kind.MEDIUM
		"wide", "wide_shot", "ws", "long":
			return Kind.WIDE
		"profile", "side", "profil":
			return Kind.PROFILE
		"over_shoulder", "overshoulder", "over-the-shoulder", "ots":
			return Kind.OVER_SHOULDER
		"random":
			return Kind.RANDOM
		_:
			return default_kind


static func coerce(value: Variant, default_kind: Kind = Kind.MEDIUM) -> Kind:
	match typeof(value):
		TYPE_INT:
			var as_int := int(value)
			if as_int >= int(Kind.CLOSE) and as_int <= int(Kind.RANDOM):
				return as_int as Kind
		TYPE_STRING:
			return parse(String(value), default_kind)
	return default_kind


static func tag_name(kind: Kind) -> String:
	match kind:
		Kind.CLOSE:
			return "close"
		Kind.MEDIUM:
			return "medium"
		Kind.WIDE:
			return "wide"
		Kind.PROFILE:
			return "profile"
		Kind.OVER_SHOULDER:
			return "over_shoulder"
		Kind.RANDOM:
			return "random"
		_:
			return "medium"


static func marker_names(kind: Kind) -> PackedStringArray:
	match kind:
		Kind.CLOSE:
			return PackedStringArray(["Close", "close", "CloseUp", "CU"])
		Kind.MEDIUM:
			return PackedStringArray(["Medium", "medium", "MediumShot", "MS"])
		Kind.WIDE:
			return PackedStringArray(["Wide", "wide", "WideShot", "WS"])
		Kind.PROFILE:
			return PackedStringArray(["Profile", "profile", "Profil"])
		Kind.OVER_SHOULDER:
			return PackedStringArray(["OverShoulder", "over_shoulder", "OTS", "OverTheShoulder"])
		_:
			return PackedStringArray()


static func is_concrete(kind: Kind) -> bool:
	return kind != Kind.RANDOM


static func normalize_tag(text: String) -> String:
	return _normalize(text)


static func default_tags(kind: Kind) -> PackedStringArray:
	match kind:
		Kind.CLOSE:
			return PackedStringArray(["emotional", "intimate"])
		Kind.MEDIUM:
			return PackedStringArray(["neutral", "conversation"])
		Kind.WIDE:
			return PackedStringArray(["neutral", "conversation"])
		Kind.PROFILE:
			return PackedStringArray(["dramatic"])
		Kind.OVER_SHOULDER:
			return PackedStringArray(["conversation"])
		_:
			return PackedStringArray()


static func split_tags(text: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var normalized := text.strip_edges().replace(",", "+").replace(";", "+").replace(" ", "+")
	for part in normalized.split("+", false):
		var tag := normalize_tag(part)
		if not tag.is_empty() and not result.has(tag):
			result.append(tag)
	return result


static func parse_look(text: String, default_look: Look = Look.AUTO) -> Look:
	var key := _normalize(text)
	if key.is_empty():
		return default_look
	match key:
		"eyes", "eye", "augen":
			return Look.EYES
		"head", "face", "kopf":
			return Look.HEAD
		"mouth", "lips", "mund":
			return Look.MOUTH
		"none", "default", "height", "chest":
			return Look.NONE
		"auto":
			return Look.AUTO
		_:
			return default_look


static func coerce_look(value: Variant, default_look: Look = Look.AUTO) -> Look:
	match typeof(value):
		TYPE_INT:
			var as_int := int(value)
			if as_int >= int(Look.AUTO) and as_int <= int(Look.MOUTH):
				return as_int as Look
		TYPE_STRING:
			return parse_look(String(value), default_look)
	return default_look


static func default_look(kind: Kind) -> Look:
	match kind:
		Kind.MEDIUM, Kind.WIDE:
			return Look.HEAD
		_:
			return Look.EYES


static func look_tag_name(look: Look) -> String:
	match look:
		Look.EYES:
			return "eyes"
		Look.HEAD:
			return "head"
		Look.MOUTH:
			return "mouth"
		Look.NONE:
			return "none"
		_:
			return "auto"


static func look_marker_names(look: Look) -> PackedStringArray:
	match look:
		Look.EYES:
			return PackedStringArray(["Eyes", "eyes", "Eye", "Augen"])
		Look.HEAD:
			return PackedStringArray(["Head", "head", "Face", "Kopf"])
		Look.MOUTH:
			return PackedStringArray(["Mouth", "mouth", "Lips", "Mund"])
		_:
			return PackedStringArray()


static func suggested_fov(kind: Kind) -> float:
	match kind:
		Kind.CLOSE:
			return 62.0
		Kind.WIDE:
			return 40.0
		Kind.PROFILE:
			return 48.0
		Kind.OVER_SHOULDER:
			return 52.0
		_:
			return 50.0


static func resolve_fov(requested: float, current_fov: float) -> float:
	if requested <= INHERIT_FOV:
		return current_fov
	return clampf(requested, 1.0, 179.0)


static func resolve_duration(requested: float, default_sec: float) -> float:
	if requested < 0.0:
		return maxf(0.0, default_sec)
	return maxf(0.0, requested)


static func tween_ease(ease: TransitionEase) -> Tween.EaseType:
	match ease:
		TransitionEase.IN:
			return Tween.EASE_IN
		TransitionEase.OUT:
			return Tween.EASE_OUT
		_:
			return Tween.EASE_IN_OUT


static func kill_tween(tween: Tween) -> void:
	if tween != null and is_instance_valid(tween):
		tween.kill()


static func tween_camera(
	host: Node,
	camera: Camera3D,
	xf: Transform3D,
	duration: float,
	target_fov: float = INHERIT_FOV,
	ease: TransitionEase = TransitionEase.DEFAULT,
	existing: Tween = null,
	on_finished: Callable = Callable()
) -> Tween:
	kill_tween(existing)
	if host == null or camera == null or not is_instance_valid(camera):
		return null
	var next_fov := resolve_fov(target_fov, camera.fov)
	if duration <= 0.0:
		camera.global_transform = xf
		camera.fov = next_fov
		if on_finished.is_valid():
			on_finished.call()
		return null
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(tween_ease(ease))
	tween.tween_property(camera, "global_transform", xf, duration)
	if not is_equal_approx(camera.fov, next_fov):
		tween.tween_property(camera, "fov", next_fov, duration)
	if on_finished.is_valid():
		tween.finished.connect(on_finished, CONNECT_ONE_SHOT)
	return tween


static func look_fallback_order(look: Look) -> Array[Look]:
	match look:
		Look.HEAD:
			return [Look.HEAD, Look.EYES, Look.MOUTH]
		Look.MOUTH:
			return [Look.MOUTH, Look.HEAD, Look.EYES]
		_:
			return [Look.EYES, Look.HEAD, Look.MOUTH]


static func _normalize(text: String) -> String:
	return text.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
