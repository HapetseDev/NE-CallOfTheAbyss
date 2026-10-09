*Autor: Peter Sebastian Hansel*

![](/Users/hapetse/Dev/NECOTA2D/docs/res/NE-Cota-Logo.png)

## Design Dokument

Version: 1

(Wird bei jeder Bearbeitung inkrementiert)

# Inhalt

1. [Basic Pitch](#basic-pitch)
2. [Technische Grundlagen](#technische-grundlagen)
3. Interaktionsbasics
4. RPG-Mechaniken
5. Titelmenü
6. Spielabläufe

# Basic Pitch

## Elevator Pitch

Singleplayer-Dungeon-Crawler-Puzzel-RPG mit Fokus auf Interaktion, Rätsel, Gespräche und Erforschung. Entschleunigtes Gameplay, mit Fokus auf Einbindung vieler Altergruppen und integrativer Steuerung, d.h. wenige Buttons.

## Synopsis der Geschichte

Gruppe geht in eine Dungeon.

# Technische Grundlagen

## Frameworks

Bisher wird nur Godot in der Version 4.7 verwendet. Entwicklungssprache ist GDScript, offen ist der Umstieg auf CSharp, Version 10.

Möglicherweise wird für den Audiobereich ein weiteres Framework eingebunden.

Ziel ist es, nur OSS-Software zu verwenden.

## Builds

Zielplattformen sind wie folgt:

- **Windows** (über Steam und GOG)
- **Mac** (Über Steam und GOG, nur M-Prozessoren)
- **Linux**
  - Linux nativ als Appimage
  - Linux über Steam (für Steamdeck)
  - Ein Linuxbuild, damit es für Batocera zur Verfügung steht

Nicht relevant aber schön wenn es irgendwie gehen würde:

- **FreeBSD** (Paketformat nicht bestimmt)
- **Haiku** (Paketformat nicht bestimmt)

Ein Release auf Konsolen ist nicht geplant ebenso wie ein Release auf mobile Plattformen)

# Interaktionsbasics

## Kontrolle des Spielers

Der Spieler hat grundsätzlich folgende Möglichkeiten, mit dem Spiel zu interagieren:

| Nr | Bezeichnung           | Weitere Details                                                                                        |
|----|-----------------------|--------------------------------------------------------------------------------------------------------|
| 1  | **Maus**              | Links-Klick und Rechtsklick sowie Mausbewegungen.                                                      |
| 2  | **Maus und Tastatur** | Kombination aus Maus und Tastatur.                                                                     |
| 3  | **Tastatur alleine**  | Bewegung mit Pfeiltasten oder WSAD, Bestätigungstaste und Abbrechentaste                               |
| 4  | **Controller**        | Bewegung mit Steuerkreuz oder linken Stick und zwei Tasten des Controllers, Bestätigung und Abbrechen. |

Ziel ist es, das möglichst wenige Tasten benötigt werden. Wichtig ist es hierbei, dass das UI dennoch intuitiv zu nutzen ist. Ziel ist es ebenfalls, dass grundsätzlich jede Steuerung gleichzeitig verwendet werden kann. Da es keine Mehrspieler-Option gibt, kann bei vorhandener Hardware alle Eingabemöglichkeiten zeitgleich aktiv sein.

### Feedback für den Spieler

Geht der Spieler mit der Maus oder sonstigen Eingabemethoden über eine Spielobjekt (d.h. kein Objekt im Spiel wie ein Heiltrank etc. sondern programmatische Objekte wie ein Button etc. und alle Entitäten, mit dem der Nutzer interagieren kann), erscheint ein dezentes Geräusch, damit der Spieler es besser wahrnimmt, dass er was ausgewählt hat. Buttons verändern zusätzlich die Farbe, in dem sie 20% heller werden, als die übrigen Buttons. 

Wenn ein Spielobjekt ausgewählt wird, wird dies ebenfalls audiovisuell untermalt. Es erscheint ein anderer, dezenter und “freundlicher”, d.h. heller Signalton und der Button wird 20% dunkler, als es im Normalzustand ist, d.h. es soll ein Drücken des Knopfes simuliert werden. Sollte der Spieler bei einem Fenster die Abbrechen oder Zurück-Taste drücken, erscheint auch ein anderer, dezenter, diesmal dunkler Signalton.

Wird nichts durchiteriert, keine Spielobjekte also ausgewählt, kein Menüabgebrochen oder keine Option ausgewählt werden, dann erscheint kein Ton. Töne und Feedback gibt es nur bei Interaktionen.

# RPG-Mechaniken

## Elemente des Charakterbogen

### Charakterwerte

#### Grundlegende Eigenschaften

Ein Charakter hat sechs verschiedene grundlegende Eigenschaften. Das sind

- **Name (String)**: Der Name des Charakters
- **Ausbildung (Enum):** Je nachdem, welche Ausbildung gemacht wird, kann der Charakter mit unterschiedlichen Fähigkeiten und Modifikatoren der Attribute ausgestattet sein, können aber auch Caps und Mali bedeuten.
- **Spezies (Enum):** Es gibt eine Reihe von Spezies, die gespielt werden können. Jede Spezies hat unterschiedliche Fähigkeiten und Modifikatoren der Attribute, können aber auch Caps und Mali bedeuten.
- **Herkunft (Enum):** Es gibt eine Reihe von Möglichkeiten der Herkunft, wie Waise, Adelig etc. Jede Herkunft hat unterschiedliche Fähigkeiten und Modifikatoren der Attribute, können aber auch Caps und Mali bedeuten.
- **Ziel (String):** Ein Ziel, dass ein Charakter verfolgt. Kann frei gewählt werden und hat keine unmittelbaren Auswirkungen auf das Gameplay. Storytechnisch hingegen definiert das Ziel die Handlungsmaxime eines Charakters.
- **Besonderheiten (Enum):** Es gibt noch weitere Besonderheiten, wo man sich zwei aussuchen kann. Modifizieren Attribute und geben Fähigkeiten, können aber auch Caps und Mali bedeuten.

### Charakterpunkte

Ein Charakter hat zwei grundlegende Punkte: Stärkepunkte (Vergleichbar mit HP bei klassischen Rollenspielen) und Konzentrationspunkte (Vergleichbar mit MP).  
Stärkepunkte ermitteln sich aus der Attributen eines Charakters: Die Anzahl der Punkte des Attributs Körperkraft plus die Anzahl der Punkte des Attributs Gewandtheit plus die Anzahl der Punkte des Attributs Gewandtheit mal zwei.  
Konzentrationspunkte ermitteln sich wie folgt: Die Anzahl der Punkte des Attributs Verstand plus Die Anzahl der Punkte des Attributs Willenskraft plus Die Anzahl der Punkte des Attributs Bewusstsein mal zwei.

Die Anzahl an Stärkepunkte und Konzentrationspunkte erscheint zunächst niedrig. Der Hintergrund ist, dass man eigentlich mit den doppelten Wert rechnen muss, nämlich die Zahl positiv und die Zahl negativ.

So ist es nicht schlimm, Stärkepunkte und Konzentrationspunkte bis null zu verbrauchen. Sie regenerieren sich sehr schnell im Kampf zum Beispiel und auch beim gehen. Auch essen kann hier schnell Wunde bewirken. Essen kleine Kratzer, Stöße, leichte Kopfschmerzen, also nichts wildes.

Schäden im Minusbereich der Charakterpunkte bedarfen einer fachgerechten Heilung oder einer tiefen Regeneration. Sollten die aktuellen Stärkepunkte dem negativen Basiswert entsprechen, dann ist der Charakter tot. Sollten die Konzentrationspunkte dem negativen Basiswert entsprechen, dann kann keine Fähigkeit mehr angewendet werden, die Konzentrationspunkte erfordert.

### Attribute

Es gibt sieben Attribute:

- ***Körperkraft*** *(körperlich)*
- ***Gewandtheit*** *(körperlich)*
- ***Robustheit*** *(körperlich)*
- ***Willenskraft*** *(geistig)*
- ***Verstand*** *(geistig)*
- ***Bewusstsein*** *(geistig)*
- ***Präsenz*** *(beides)*

Grundsätzlich sind die Attribute vergleich mit klassischen Attributen aus RPGs wie Stärke, Intelligenz, Agilität usw., jedoch mit dem Unterschied, dass diese Werte veränderlich sind. Körperkraft kann runter gehen, wenn man krank ist, Verstand kann sinken, wenn man betrunken ist, Willenskraft kann steigen.

Bei der Charaktererstellung werden keine Punkte auf die Attribute verteilt, noch gibt es irgendwelche Grundpunkte bei den Attributen.

Attribute steigen, wenn man entsprechende Fähigkeiten lernt, wie bei Körperkraft "Nahkampfwaffen benutzen", bei Bewusstsein "Meditieren" und bei Präsenz "flirten". Fähigkeiten kann man lernen durch Lehrer, durch die Spezies, Herkunft usw. bei der Charaktererstellung und bei gegebenen Umständen: wenn man eine Waffe in die Hand nimmt, kann man Nahkampfwaffen führen steigern.  
Es gibt 5 Fähigkeiten, die man aktiv steigen kann. Jedes Level der Fähigkeit steigert das übergeordnete Attribut. Jede Aktion erzeugt Erfahrungspunkte: Diese Punkte können verteilt werden auf die Fähigkeiten: 100 Punkte sind ein Level der Fähigkeit. 20 Level ist ein Cap, was je nach Spezies, Herkunft, erlernter Beruf etc. gecappt oder erhöht werden kann.

## Ansicht der Attribute mit Platzhalter der Fähigkeiten

### Körperkraft

Körperkraft ist das Attribut, dass am ehesten mit dem klassischen Attribute “Stärke” zu vergleichen ist. Zur Körperkraft gehören Fähigkeiten, die primär Stärke benötigen. Andere Besonderheiten sind die Tragkraft, die mit erhöhter Körperkraft ein hergeht. Eine einfache Probe ist das Gewicht: Gewicht ist ein Float-datentyp, der diskrete Werte einnehmen kann zwischen null und zehn. Ist ein Gegenstand schwerer als der Körperkraft-Level des Charakters, kann dieser den Gegenstand nicht aufheben.

**Beinflusst:**

- Stärkepunkte (Erhöht die Stärkepunkte um Eins je Level)
- Tragekraft
- Schaden von Gegenständen, die mit Stärke geführt werden. 

| Name der Fähigkeit | Level  |
|--------------------|--------|
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |

### Robustheit

Robustheit kann auch Konstitution genannt werden, die Fähigkeit, körperliche Widerstandskraft aufzubauen. Charaktere mit einer hohen Robustheit haben mehr stärke Punkte, sind widerstandsfähiger gegen Schmerz und Gift (dazu zehn auch Nervengifte wie Alkohol oder Drogen), und können, wie bei Körperkraft, mehr tragen.

**Beeinflusst:**

-  Stärkepunkte (Erhöht die Stärkepunkte um Zwei je Level)
- Tragkraft
- Widerstandskraft gegenüber Schaden und Giften.

| Name der Fähigkeit | Level  |
|--------------------|--------|
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |

### Gewandtheit

Flinke Menschen besitzen eine hohe Gewandtheit. Es ist aber auch ein Zeichen von Geschick, wenn Menschen sehr gewandt sind. 

**Beinflusst:**

- Stärkepunkte 
- Erhöht den Bewegungsradius um ein Feld pro Level
- Erhöht den Schaden mit Waffen, die Geschicklichkeit benötigen.
- Je höher der Level, desto höher ist die Möglichkeit, zu parieren.

| Name der Fähigkeit | Level  |
|--------------------|--------|
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |

### Verstand

Beeinflusst Konzentrationspunkte

| Name der Fähigkeit | Level  |
|--------------------|--------|
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |

### Willenskraft

Beeinflusst Konzentrationspunkte

| Name der Fähigkeit | Level  |
|--------------------|--------|
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |

### Bewusstsein

Beeinflusst Konzentrationspunkte mal Zwei

| Name der Fähigkeit | Level  |
|--------------------|--------|
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |

### Präsenz

In anderen Spielen oft Charisma genannt, steht Präsenz für die Fähigkeit, gut auszusehen und andere Menschen in seinen Bann zu ziehen. Präsenz jedoch hat keinen Einfluss auf Stärkepunkte oder Konzentrationspunkte und stellt somit eine Besonderheit da. 

**Beeinflusst:** 

- soziale Interaktionen (Erhöht Beziehungen um einen halben Punkt pro Level)
- Begleiter bleiben bei präsenten Menschen entweder länger (bei Level 5) oder nur für die Hälfte des Geldes (Stufe 10).

| Name der Fähigkeit | Level  |
|--------------------|--------|
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |
|                    | \___\_ |

​           

### Besitz und Beziehungen

#### Inventar

| Bezeichnung | Details | Menge  |
|-------------|---------|--------|
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |
|             |         | \___\_ |

#### Begleiter

| Name | Details | Befristung |
|------|---------|------------|
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |
|      |         | \___\_     |

#### Beziehungen

| Name der Person oder Fraktion | Details | Wertung (+10 bis -10) |
|-------------------------------|---------|-----------------------|
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |
|                               |         | \___\_                |

Im Buch der Charaktere findet man Informationen zu allen einzelnen Punkten.

| Wert | Bedeutung                               |
|------|-----------------------------------------|
| +10  | liebt dich / absolute Loyalität         |
| +5   | wohlgesonnen                            |
| 0    | neutral                                 |
| \-5  | misstrauisch                            |
| \-10 | feindselig / tötet dich bei Gelegenheit |

# Titelmenü

## Aufbau

Das Titelmenü besteht neben der Hintergrundmusik aus drei Elementen:

![](/Users/hapetse/Dev/NECOTA2D/docs/res/darstellung-titelmennu.png)

### Element 1 Logo und Titel

Element 1 ist eine einfache Einblendung einer Bilddatei - es ist noch zu klären, ob es sich um eine skalierbare Datei handeln wird oder um eine Binärdatei. Es besteht aus dem Logo des Franchise und dem Titel des Spiels.

### Element 2 Hintergrund

Das Hintergrund besteht aus eingeblendeten Szenen. Die Szenen sind angelehnt an Level aus dem Spiel. Dabei wird in einer gemächlichen Geschwindigkeit die Kamera von oben nach unten durch die Szene bewegt. Jede einzelne Szene wird durch ein ebenfalls gemächliches Fade-to-Black und Fade-in gewechselt.

Es wird noch überlegt, ob ein Filter hinterlegt wird, damit die Objekte des Hintergrunds nicht zu sehr ablenkend ist (Sowas wie ein Grauschleier oder ähnliches).

#### Szenenreihenfolge

| Nr. | Szene                | Ab welchen Zeitpunkt |
|-----|----------------------|----------------------|
| 1   | Wald                 | Immer                |
| 2   | Thronraum            | Immer                |
| 3   | Erstes Dungeon Level | Immer                |

Die Reihenfolge der Szenen ist noch nicht final abgeschossen.

### Element 3 Optionen

Es ist geplant, dass es drei Optionen gibt: 

| Nr. | Option        | Wozu dient die Option   |
|-----|---------------|-------------------------|
| 1   | “Neues Spiel” | Startet ein neues Spiel |
| 2   | “Spiel laden” | Lädt ein neues Spiel    |
| 3   | “Beenden”     | Beendet das Programm    |

::: error
Es ist noch offen, ob es die Option “Option” gibt, wo Optionen wie Sprachauswahl möglich sein können.

:::

# Spielabläufe

## Interaktionen

Beim Druck auf die Interaktionstaste erscheint der Interaktionsradius (Int-R). Dieser bereitet sich innerhalb einer halben Sekunde ausgehen vom Anführer der Gruppe aus. Der Interaktionsradius ist dabei relativ in der Größe zum Wert der Wahrnehmung des Anführers. Intern wird jedoch auch um den Anführer einen Radius gezogen, der den anderen Charakteren entspricht. So wird auch ermittelt, was die anderen Charakteren wahrnehmen und womit sie interagieren können. Kann ein anderer Charakter mit mehr Sachen interagieren als der Anführer, sagt dieser Charakter mit einer Sprechblase über seinen Kopf, dass er was wahrnehmen kann.

![](/Users/hapetse/Dev/NECOTA2D/docs/res/aufruf-int-m.png)

::: info
Während der Aktionsradius aktiv ist, ist die Spielwelt ausgegraut und steht still (alle Animationen werden auch gestoppt).

:::

![](/Users/hapetse/Dev/NECOTA2D/docs/res/interaktions-radius.png)

Innerhalb des Interaktionsradius kann mit “Interagierbaren” (NPCs, Gegnern, Objekte und mehr) interagiert werden.

Bei einer Maussteuerung können diese Objekte mit der Maus ausgewählt werden, bei Tastatur oder Gamepad mit den Bewegungstasten.

![](/Users/hapetse/Dev/NECOTA2D/docs/res/objekt-auswahl.png)

Sobald ein Interagierbares ausgewählt worden ist (mit der Maus mit Linksklick oder mit dem Controller/ Tastatur mit den Bewegungstasten zum “durchklicken”), dann leuchtet die ausgewählte Entität auf und der Name erscheint darüber. Das Leuchten soll in den Optionen später auswählbar sein- so kann es eine Farbe sein oder ein negatives Leuchten sein.

Ist es eine Erst-Interaktion mit dem Objekt oder dem Charakter, ist der Name unbekannt und es erscheinen drei Fragezeichen. Erst-Interaktion bedeutet, wenn der NPC noch nie vorher gesehen worden ist, oder wenn der Typus der Entität nicht bekannt ist (Hat man schon mal einen “Dolch” gesehen, so kann auch jeder andere Dolch erkannt werden, genauso mit bestimmen NPCs wie bestimme Monster oder Tiere).

![](/Users/hapetse/Dev/NECOTA2D/docs/res/int-m-objekte.png)

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

![](/Users/hapetse/Dev/NECOTA2D/docs/res/interaktion-npc.png)

Bei NPCs verhält es sich ähnlich - grundsätzlich unterscheidet es sich in der Logik auch nicht von einem Objekt im Sinne eines Interagierbaren- mit wenigen Ausnahmen. 

So kann man Versuchen, mit jedem NPC zu reden. Ansehen erzeugt eine Beschreibung im Log -den Namen erfährt man jedoch nur im Gespräch. Stehlen ist nur bei Partys verfügbar, in der in Mitglied mindestens einen Punkt im Stehlen hat. Dieser wird eine Probe, unabhängig vom Anführer. 

Angreifen greift den NPC an- jedoch erscheint da dann die Frage, ob man dies auch wirklich machen will. Mit Geben kann man den Charakter ein Objekt geben, dass der Anführer in der Hand hält. 

Zudem können manche NPCs getragen werden. 

Wichtig ist, dass sobald eine Handlungsoption ausgewählt worden ist, dass dann das Int-M geschlossen wird, der Int-R zieht sich zusammen, der Freeze und der Grauschleier der Umwelt hört auf und die ausgewählte Aktion wird ausgeführt.

# Darstellung von Spielefenster

Ein Spielefenster ist eine Ansicht für den Spieler, um den verschiedenen Erfordernissen des Spiels Herr zu werden.

## Normaler Spielüberblick

Für meiste Zeit des Spiels sieht der Spieler eine Übersichts des Spielfelds. Hier dargestellt mit Kuben, Zylinder und Strichfiguren. Über jeden Charakter, der der Party angehört ist ein kleines, halb-transparentes Fenster, mit einem Bild und der Anzahl der SP und KP. 

![](/Users/hapetse/Dev/NECOTA2D/docs/res/-Übersicht.png)

Unten ist das halb-transparente Log-Feld, wo die Nachrichten an den Spieler angezeigt werden. Darunter ist die Spiel-Leiste. Bisher sind die folgende Punkte für die Leiste vorgesehen: 

- Party, zum Sortieren der Party-Reihenfolge (und später zum Einstellen einer Formation)
- Charakter, zum Aufrufen der Charakterblätter
- Inventar, zum Aufrufen des Paperdolls und des Gepäcks
- Karte
- Log
- Menü zum Speichern, laden, Beenden des Spiels und zum Aufruf der Optionen
- und für die Entwicklung ein Debug Menü.

## Grundsätzlicher Aufbau der Fenster

Die Fenster, welche Aufgerufen werden, sind angeordnet als "Cover Flow", was einer derartigen Sicht entspricht:

![](/Users/hapetse/Dev/NECOTA2D/docs/res/Cover-Flow.png)

Das jeweilige Fenster, das aufgerufen wurde, wird in der Mitte angezeigt. Links und Rechts davon sind die jeweiligen Fenster der Leiste, wie sie in der Spiel-Leiste aufgelistet werden. 

Die Reihenfolge im Moment ist wie folgt: 

1. Party
2. Charakter
3. Inventar
4. Karte
5. Log
6. Menü
7. Debug 

Ist also das Fenster "Karte" aufgerufen, wird links angeschrägt von Rechts nach links "Inventar", "Charakter" und "Party" angezeigt, und rechts wird von links nach rechts "Log", "Menü" und "Debug" angezeigt. Es wiederholt sich dabei immer wieder, so dass links von "Party" "Debug" oder "Menü" angezeigt. Um die Fenster zu wechseln muss mit der Maus oder oder mit der Tastatur/Controller-Steuerung der Pfeil nach Links oder Rechts ausgewählt werden.

Beim Fensterwechsel gleitet die gewählte Karte in 0,28 Sekunden aus der
entsprechenden Richtung in die Mitte. Die seitlichen Karten bewegen sich mit;
Skalierung und leichte Drehung unterstreichen den Cover-Flow-Eindruck.
Schnelle Richtungswechsel, Schließen und Größenänderungen beenden den bisherigen
Übergang sauber. Dies gilt für Maus, Tastatur und Controller gleichermaßen.

## Party Fenster

Das Partyfenster ist dazu gedacht, den Anführer zu bestimmen und auch die Reihenfolge der Party. 

![](/Users/hapetse/Dev/NECOTA2D/docs/res/-Party-Übersicht.png)

Das Fenster kann bis nach unten gescrollt werden, da die Anzahl an Partymitgliedern nicht beschränkt ist.

## Charakter Fenster

Das Charakterfenster zeigt die Charakterblätter aller Charakter in Reihenfolge, wie sie im Party Fenster festgelegt wurde.

![](/Users/hapetse/Dev/NECOTA2D/docs/res/-Charakter.png)

Die Charakterblätter können durchgescrollt werden. Sobald ein Charakterblatt eines Charakters zuende ist, wird das nächste direkt darunter angezeigt.

Umgesetzt: Kopfbereich mit Porträt, Stammdaten und SP-/KP-Balken; darunter
Körperkraft/Gewandheit, Robustheit/Willenskraft und Verstand/Bewusstsein als
Attributpaare, anschließend zentrierte Präsenz, Begleiter und Beziehungen.
Die helle Referenzgestaltung ist auf das Charakterblatt begrenzt; Navigation
und die gemeinsame vertikale Scrollfläche verwenden die bestehende Architektur.


## Inventar Fenster

Von der Bedienung ist das Inventar-Fenster genauso zu behandeln wie das Charakterfenster. Hier wird jedoch das Inventar angezeigt. Mit Drag und Drop über Maus oder mit einem Aktionsmenü ausgerüstet werden. 

![](/Users/hapetse/Dev/NECOTA2D/docs/res/-Inventar.png)

Gegenstände können über Kontextmenü oder über Drag and Drop an andere Charakter weitergegeben werden, da ein Inventar eines Charakters überhalb des Inventars eines anderes Charakters durchgescrollt werden kann.

# Weiterführende Dokumentation

## Architekturarbeit

- [Offene Entscheidungen und nächste Schritte](ARCHITEKTUR_OFFENE_PUNKTE.md)
- [WorldState und aktueller Speichervertrag](src/core/world/README.md)