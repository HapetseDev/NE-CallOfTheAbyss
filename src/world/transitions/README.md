# Wiederverwendbarer Levelausgang

`level_exit.tscn` als Instanz in ein Level ziehen und an die gewünschte Stelle
setzen. Beide bestehenden Level verwenden diese Szene bereits.

1. Am Root `target_level` auf die Zielszene setzen (diese muss BaseLevel verwenden).
2. `target_arrival` auf einen Node3D im Ziellevel setzen, relativ zu dessen Root.
   Ein Marker3D eignet sich ebenso wie die vorhandene Eingangsshape.
3. Die Box unter `Ausgangshape` im Inspector passend vergrößern/verkleinern.
   Die Standardform ist pro Instanz unabhängig. Nicht benötigte Visuals gibt es nicht.
4. Den Ankunftspunkt auf begehbaren Boden außerhalb des Zielausgangs legen.

Nur der Party-Leader aktiviert einen Ausgang. Die bestehende Sperre gegen
Anfangsüberlappungen verhindert sofortiges Zurückwechseln nach Ankunft oder Laden.
Kampf und Interaktionen verhindern den Wechsel.

Die Darstellung übernimmt zentral der LevelManager mit dem bestehenden
`MainGame/UI/TransitionRoot/FadeRect`. So wird die Abdeckung beim Levelabbau nicht
mitgelöscht. Im Inspector des LevelManagers sind `fade_out_seconds` (0,2),
`settle_seconds` (0,45) und `fade_in_seconds` (0,25) einstellbar. Währenddessen
bleiben Eingaben gesperrt, die Physik läuft weiter. Bei ungültigem Ziel wird die
bisherige Welt wieder eingeblendet. Direkter Spielstand-Ladevorgang und initialer
Spielstart verwenden weiterhin ihren eigenen Aufbau ohne diesen Ausgangs-Fade.

Der kurze Schwarzabschnitt verdeckt gewöhnliches Absinken; er korrigiert keine
falsch platzierten Figuren, fehlende Böden oder beliebig große Fallhöhen.
`zugang.gd` am bisherigen Levelpfad bleibt als kompatibler Verweis erhalten.

## Höhe der Ausgangszone

Die Ausgangsbox muss die Kollisionskapsel einer auf dem Boden stehenden Figur
schneiden. In beiden vorhandenen Leveln liegt der Boden am Ausgang bei ungefähr
Y = -0,95; die Figur reicht bis etwa Y = 0,05. Die Ausgänge waren dagegen so hoch
platziert, dass ihre Unterkanten bei Y = 0,86 bzw. Y = 1,16 lagen. Dadurch blieb
`overlaps_body(leader)` beim normalen Gehen immer falsch.

Die Ausgangsmittelpunkte liegen jetzt bei Y = -0,45. Ihre horizontalen Positionen,
Größen, Ziellevel und Ankunftspunkte bleiben erhalten.

`res://src/debug/tools/test_transition_ground.tscn` lässt Dannerman und Shalka
jeweils mit normaler Bewegung von begehbarem Boden in beide Ausgänge laufen und
prüft Ziellevel, Freigabe der Sperre sowie Schutz vor sofortigem Rückwechsel.
Der Test teleportiert die Figur ausdrücklich nicht in die Höhe der Ausgangsbox,
weil dies eine falsch platzierte Zone im bisherigen Übergangstest verdeckte.
