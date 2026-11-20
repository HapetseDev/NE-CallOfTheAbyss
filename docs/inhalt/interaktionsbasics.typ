= Interaktionsbasics

*Geplantes Zielbild; teilweise umgesetzt.* Die folgenden Beschreibungen sind Designabsicht. Verfügbare Funktionen und Abweichungen sind im aktuellen Umsetzungsstand ausdrücklich getrennt aufgeführt.

== Kontrolle des Spielers

Der Spieler hat grundsätzlich folgende Möglichkeiten, mit dem Spiel zu interagieren:

#figure(
  table(
    columns: 3,
    table.header([Nummer], [Bezeichnung], [Weitere Details]),
    [1], [*Maus*], [Links-Klick und Rechtsklick sowie Mausbewegungen.],
    [2], [*Maus und Tastatur*], [Kombination aus Maus und Tastatur.],
    [3], [*Tastatur alleine*], [Bewegung mit Pfeiltasten oder WSAD, Bestätigungstaste und Abbrechentaste],
    [4], [*Controller*], [Bewegung mit Steuerkreuz oder linken Stick und zwei Tasten des Controllers, Bestätigung und Abbrechen.],
  ),
  caption: [Überblick über die Eingabequellen],
) <texpile-table-4f433c2cf831>



Ziel ist es, das möglichst wenige Tasten benötigt werden. Wichtig ist es hierbei, dass das UI dennoch intuitiv zu nutzen ist. Ziel ist es ebenfalls, dass grundsätzlich jede Steuerung gleichzeitig verwendet werden kann. Da es keine Mehrspieler-Option gibt, kann bei vorhandener Hardware alle Eingabemöglichkeiten zeitgleich aktiv sein.

=== Feedback für den Spieler

Geht der Spieler mit der Maus oder sonstigen Eingabemethoden über eine Spielobjekt (d.h. kein Objekt im Spiel wie ein Heiltrank etc. sondern programmatische Objekte wie ein Button etc. und alle Entitäten, mit dem der Nutzer interagieren kann), erscheint ein dezentes Geräusch, damit der Spieler es besser wahrnimmt, dass er was ausgewählt hat. Buttons verändern zusätzlich die Farbe, in dem sie 20% heller werden, als die übrigen Buttons. 

Wenn ein Spielobjekt ausgewählt wird, wird dies ebenfalls audiovisuell untermalt. Es erscheint ein anderer, dezenter und “freundlicher”, d.h. heller Signalton und der Button wird 20% dunkler, als es im Normalzustand ist, d.h. es soll ein Drücken des Knopfes simuliert werden. Sollte der Spieler bei einem Fenster die Abbrechen oder Zurück-Taste drücken, erscheint auch ein anderer, dezenter, diesmal dunkler Signalton.

Wird nichts durchiteriert, keine Spielobjekte also ausgewählt, kein Menüabgebrochen oder keine Option ausgewählt werden, dann erscheint kein Ton. Töne und Feedback gibt es nur bei Interaktionen.