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

## "Bewegen"-Kampfzug: fester Schritt in eine der vier Richtungen, keine
## Animation/Kollisionsprüfung (Detailmechanik laut Plan noch offen).
const MOVE_STEP_DISTANCE := 2.0
