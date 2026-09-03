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


static func _normalize(text: String) -> String:
	return text.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
