class_name CombatBalance

## Zentrale Balancing-Konstanten der Kampf-Engine. Startwerte, kein Feintuning –
## brauchen Playtesting (siehe Plan, Abschnitt "Offene Punkte").

## Energiemeter-Schwelle, ab der ein Teilnehmer einen Zug erhält.
const INITIATIVE_THRESHOLD := 100.0
## Multiplikator zwischen Gewandheit-Attribut und Meter-Zuwachs pro Sekunde.
const INITIATIVE_SPEED_FACTOR := 6.0

## Ausweichen (Gewandheit des Ziels vs. Genauigkeit des Angreifers).
const EVADE_FACTOR := 3.0
const EVADE_CAP := 0.6

## Schadensreduktion pro Punkt Robustheit.
const MITIGATION_FACTOR := 1.0

## Radius, in dem Charaktere auf einen Angriff reagieren (CombatParticipantResolver).
const AWARENESS_RADIUS := 8.0

## Fliehen: Grundchance +/- Differenz zur durchschnittlichen Gewandheit der Gegenseite.
const FLEE_BASE_CHANCE := 0.5
const FLEE_SPEED_FACTOR := 0.02
const FLEE_CHANCE_MIN := 0.1
const FLEE_CHANCE_MAX := 0.9
## Strecke, die ein erfolgreich geflohener Charakter vom Schwerpunkt der
## Gegenseite weg zurücklegt (Teleport, keine Kollisionsprüfung) – größer als
## AWARENESS_RADIUS, damit er den Kampfbereich tatsächlich verlässt statt
## nur knapp am Rand stehen zu bleiben.
const FLEE_DISTANCE := AWARENESS_RADIUS + 4.0

## Stehlen: Grundchance +/- Differenz zwischen Gewandheit des Diebs und
## Bewusstsein des Opfers. Fehlschlag löst Kampf aus (siehe StealUI), also
## bewusst etwas riskanter kalibriert als das kostenlose Party-Tauschen.
const STEAL_BASE_CHANCE := 0.5
const STEAL_SKILL_FACTOR := 0.04
const STEAL_CHANCE_MIN := 0.05
const STEAL_CHANCE_MAX := 0.9

## "Bewegen"-Kampfzug: freie Positionierung in einem Kreis um die
## Ausgangsposition. Radius = effektive Gewandheit * STANDARD_LENGTH (später
## ggf. durch Perks modifizierbar). Ein Attributspunkt Gewandheit entspricht
## also genau einer Standardlänge (~1 Meter in der Spielwelt); da Attribute
## nie unter 1 starten, ist das gleichzeitig der praktische Mindestradius.
const STANDARD_LENGTH := 1.0
## Bewegungstempo während der freien Positionierung (kein Sprint), entspricht
## StateWalk.base_speed.
const COMBAT_MOVE_SPEED := 1.0
