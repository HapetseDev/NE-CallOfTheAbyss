= Spielabläufe

*Geplantes Zielbild; teilweise umgesetzt.* Die folgenden Beschreibungen sind Designabsicht. Verfügbare Funktionen und Abweichungen sind im aktuellen Umsetzungsstand ausdrücklich getrennt aufgeführt.

== Interaktionen

Beim Druck auf die Interaktionstaste erscheint der Interaktionsradius (Int-R). Dieser bereitet sich innerhalb einer halben Sekunde ausgehen vom Anführer der Gruppe aus. Der Interaktionsradius ist dabei relativ in der Größe zum Wert der Wahrnehmung des Anführers. Intern wird jedoch auch um den Anführer einen Radius gezogen, der den anderen Charakteren entspricht. So wird auch ermittelt, was die anderen Charakteren wahrnehmen und womit sie interagieren können. Kann ein anderer Charakter mit mehr Sachen interagieren als der Anführer, sagt dieser Charakter mit einer Sprechblase über seinen Kopf, dass er was wahrnehmen kann.

#align(center)[#image("../res/aufruf-int-m.png", width: 30%)]

::: info
Während der Aktionsradius aktiv ist, ist die Spielwelt ausgegraut und steht still (alle Animationen werden auch gestoppt).

:::

#align(center)[#image("../res/interaktions-radius.png", width: 30%)]

Innerhalb des Interaktionsradius kann mit “Interagierbaren” (NPCs, Gegnern, Objekte und mehr) interagiert werden.

Bei einer Maussteuerung können diese Objekte mit der Maus ausgewählt werden, bei Tastatur oder Gamepad mit den Bewegungstasten.

#align(center)[#image("../res/objekt-auswahl.png", width: 30%)]

Sobald ein Interagierbares ausgewählt worden ist (mit der Maus mit Linksklick oder mit dem Controller/ Tastatur mit den Bewegungstasten zum “durchklicken”), dann leuchtet die ausgewählte Entität auf und der Name erscheint darüber. Das Leuchten soll in den Optionen später auswählbar sein- so kann es eine Farbe sein oder ein negatives Leuchten sein.

Ist es eine Erst-Interaktion mit dem Objekt oder dem Charakter, ist der Name unbekannt und es erscheinen drei Fragezeichen. Erst-Interaktion bedeutet, wenn der NPC noch nie vorher gesehen worden ist, oder wenn der Typus der Entität nicht bekannt ist (Hat man schon mal einen “Dolch” gesehen, so kann auch jeder andere Dolch erkannt werden, genauso mit bestimmen NPCs wie bestimme Monster oder Tiere).

#align(center)[#image("../res/int-m-objekte.png", width: 30%)]

Direkt nach der Auswahl erscheint das Interaktionsmenü (Int-M). Das Int-M hat eine gewisse Anzahl der Optionen. Die genauen Auswahlmöglichkeiten hängen vom Interagierbaren (der Entität) ab. Ist es ein Gegenstand, so kann es untersucht werden, um den Namen festzustellen oder zu gucken, ob es ein besonderer Vertreter des Typs ist und so den Namen herausfinden. Gegenstände kann man auch ins Inventar packen (“Verstauen” hier aufheben genannt, aber der Begriff aufheben ist nicht eindeutig genug). Manche Gegenstände können auch benutzt werden (Bsp. Heiltrank), wenn es sich um ein Gebrauchsgegenstand handelt.

Falls das Gewicht nicht höher ist als die Körperkraft es zulässt (die dazu notwendige Formel muss noch erstellt werden), kann der Anführer den Gegenstand tragen. So gelangt es nicht ins Inventar, sondern der Charakter trägt es in den Händen. Bis es nicht abgelegt worden ist (Dann über das Int-M und dann die Auswahl des eigenen Charakters), kann der Charakter nichts mit den Händen machen. Beginnt so ein Kampf, muss der Charakter den Gegenstand erst hinlegen, was einen Zug kostet.

Zerschlagen zerstört ein Objekt. Man kann aber auch auf andere Weise einen Gegenstand zerstören - mit einem Messer kann man Objekte, die zerschneidbar sind, auch zerschneiden. 

Wichtig ist, dass Objekte in ihren Attributen ihre Interaktionsmöglichkeiten gespeichert haben. Da kann es auch bedingte Interaktionsmöglichkeiten sein, wie 

```
WENN ein Charakter ein Messer hat DANN kann es zerschnitten werden
```

aber auch

```
WENN ein Charakter Körperkraft über 3 hat DANN kann er das Objekt tragen
```

Es können also auch Objekte mit anderen Objekten interagieren. Aber auch mit der Umwelt. Wird ein brennbares Objekt auf einen heissen oder brennenden Boden gestellt, verbrennt es auch und es entsteht zum Beispiel Asche. Andere Objekte können im Wasser Schwimmen, aufweichen oder zu Boden sinken. 

Diese Informationen werden in den Objekten persistiert.

::: warn
Wichtig ist aber auch, dass die Optionen im Int-M nur angezeigt werden, wenn die Bedingungen erfüllt sind.

:::

#align(center)[#image("../res/interaktion-npc.png", width: 30%)]

Bei NPCs verhält es sich ähnlich - grundsätzlich unterscheidet es sich in der Logik auch nicht von einem Objekt im Sinne eines Interagierbaren- mit wenigen Ausnahmen. 

So kann man Versuchen, mit jedem NPC zu reden. Ansehen erzeugt eine Beschreibung im Log -den Namen erfährt man jedoch nur im Gespräch. Stehlen ist nur bei Partys verfügbar, in der in Mitglied mindestens einen Punkt im Stehlen hat. Dieser wird eine Probe, unabhängig vom Anführer. 

Angreifen greift den NPC an- jedoch erscheint da dann die Frage, ob man dies auch wirklich machen will. Mit Geben kann man den Charakter ein Objekt geben, dass der Anführer in der Hand hält. 

Zudem können manche NPCs getragen werden. 

Wichtig ist, dass sobald eine Handlungsoption ausgewählt worden ist, dass dann das Int-M geschlossen wird, der Int-R zieht sich zusammen, der Freeze und der Grauschleier der Umwelt hört auf und die ausgewählte Aktion wird ausgeführt.