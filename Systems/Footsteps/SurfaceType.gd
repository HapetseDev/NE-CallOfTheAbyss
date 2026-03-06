class_name SurfaceType extends RefCounted

# Oberflächentypen für Schrittgeräusche
enum Type {
	GRASS,
	STONE,
	WOOD,
	SAND,
	WATER,
	METAL,
	DIRT,
	SNOW,
	DEFAULT
}

# Konvertiert String zu Type (für Metadaten)
static func from_string(surface_name: String) -> Type:
	match surface_name.to_lower():
		"grass": return Type.GRASS
		"stone", "rock": return Type.STONE
		"wood", "wooden": return Type.WOOD
		"sand": return Type.SAND
		"water", "puddle": return Type.WATER
		"metal": return Type.METAL
		"dirt", "earth": return Type.DIRT
		"snow", "ice": return Type.SNOW
		_: return Type.DEFAULT

# Konvertiert Type zu String (für Debug)
static func to_string_name(type: Type) -> String:
	match type:
		Type.GRASS: return "grass"
		Type.STONE: return "stone"
		Type.WOOD: return "wood"
		Type.SAND: return "sand"
		Type.WATER: return "water"
		Type.METAL: return "metal"
		Type.DIRT: return "dirt"
		Type.SNOW: return "snow"
		_: return "default"
