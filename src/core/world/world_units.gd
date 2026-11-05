class_name WorldUnits
extends RefCounted

## Verbindlicher Maßstab der 3D-Spielwelt: eine Welteinheit entspricht einem Meter.
## Positionen und Längen werden in Metern, Geschwindigkeiten in Metern/Sekunde
## angegeben. Kamera, Zoom und Sprite-Skalierung verändern diesen Maßstab nicht.
const METER: float = 1.0

## Gemeinsamer Ausgangswert für den Interaktionskreis, in Metern.
const INTERACTION_RADIUS: float = 1.5 * METER
