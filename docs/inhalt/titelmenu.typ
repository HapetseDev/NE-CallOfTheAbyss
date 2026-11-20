= Titelmenü

*Geplantes Zielbild; teilweise umgesetzt.* Die Skizze beschreibt das Ziel. Aktuell gibt es drei Platzhalterräume und zusätzlich zu Neues Spiel/Laden/Beenden eine Kampfsimulation. Die Musikdatei ist vorhanden; ein Hauptmenü-Optionsknopf ist weiterhin offen.

== Aufbau

Das Titelmenü besteht neben der Hintergrundmusik aus drei Elementen:

#align(center)[#image("res/darstellung-titelmennu.png", width: 30%)]

=== Element 1 Logo und Titel

Element 1 ist eine einfache Einblendung einer Bilddatei - es ist noch zu klären, ob es sich um eine skalierbare Datei handeln wird oder um eine Binärdatei. Es besteht aus dem Logo des Franchise und dem Titel des Spiels.

=== Element 2 Hintergrund

Das Hintergrund besteht aus eingeblendeten Szenen. Die Szenen sind angelehnt an Level aus dem Spiel. Dabei wird in einer gemächlichen Geschwindigkeit die Kamera von oben nach unten durch die Szene bewegt. Jede einzelne Szene wird durch ein ebenfalls gemächliches Fade-to-Black und Fade-in gewechselt.

Es wird noch überlegt, ob ein Filter hinterlegt wird, damit die Objekte des Hintergrunds nicht zu sehr ablenkend ist (Sowas wie ein Grauschleier oder ähnliches).

==== Szenenreihenfolge

#figure(
  table(
    columns: 3,
    table.header([Nr.], [Szene], [Ab welchen Zeitpunkt]),
    [1], [Wald], [Immer],
    [2], [Thronraum], [Immer],
    [3], [Erstes Dungeon Level], [Immer],
  ), caption: [Szenenreihenfolge],
) <texpile-table-8b21e465546c>



Die Reihenfolge der Szenen ist noch nicht final abgeschossen.

=== Element 3 Optionen

Es ist geplant, dass es drei Optionen gibt:

#figure(
  table(
    columns: 3,
    table.header([Nr.], [Option], [Wozu dient die Option]),
    [1], [“Neues Spiel”], [Startet ein neues Spiel],
    [2], [“Spiel laden”], [Lädt ein neues Spiel],
    [3], [“Beenden”], [Beendet das Programm],
  ),
  caption: [Übersicht der Optionen],
) <texpile-table-cc29715c7a23>




::: error
Es ist noch offen, ob es die Option “Option” gibt, wo Optionen wie Sprachauswahl möglich sein können.

:::