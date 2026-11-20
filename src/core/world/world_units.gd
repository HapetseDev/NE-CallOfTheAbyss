class_name WorldUnits
extends RefCounted

## Verbindlicher Maßstab der 3D-Spielwelt: eine Welteinheit entspricht einem Meter.
## Positionen und Längen werden in Metern, Geschwindigkeiten in Metern/Sekunde
## angegeben. Kamera, Zoom und Sprite-Skalierung verändern diesen Maßstab nicht.
const METER: float = 1.0

## Gemeinsamer Ausgangswert für den Interaktionskreis, in Metern.
const INTERACTION_RADIUS: float = 1.5 * METER

## Ein Millimeter Toleranz für physische Ankunft an einer Reichweitengrenze.
static func is_within_range(from: Vector3, to: Vector3, reach: float) -> bool:
	return from.distance_squared_to(to) <= pow(reach + 0.001 * METER, 2)
