= RPG-Mechaniken

*Geplantes Zielbild; teilweise umgesetzt.* Die folgenden Beschreibungen sind Designabsicht. Verfügbare Funktionen und Abweichungen sind im aktuellen Umsetzungsstand ausdrücklich getrennt aufgeführt.

== Elemente des Charakterbogen

=== Charakterwerte

==== Grundlegende Eigenschaften

Ein Charakter hat sechs verschiedene grundlegende Eigenschaften. Das sind

- *Name (String)*: Der Name des Charakters
- *Ausbildung (Enum):* Je nachdem, welche Ausbildung gemacht wird, kann der Charakter mit unterschiedlichen Fähigkeiten und Modifikatoren der Attribute ausgestattet sein, können aber auch Caps und Mali bedeuten.
- *Spezies (Enum):* Es gibt eine Reihe von Spezies, die gespielt werden können. Jede Spezies hat unterschiedliche Fähigkeiten und Modifikatoren der Attribute, können aber auch Caps und Mali bedeuten.
- *Herkunft (Enum):* Es gibt eine Reihe von Möglichkeiten der Herkunft, wie Waise, Adelig etc. Jede Herkunft hat unterschiedliche Fähigkeiten und Modifikatoren der Attribute, können aber auch Caps und Mali bedeuten.
- *Ziel (String):* Ein Ziel, dass ein Charakter verfolgt. Kann frei gewählt werden und hat keine unmittelbaren Auswirkungen auf das Gameplay. Storytechnisch hingegen definiert das Ziel die Handlungsmaxime eines Charakters.
- *Besonderheiten (Enum):* Es gibt noch weitere Besonderheiten, wo man sich zwei aussuchen kann. Modifizieren Attribute und geben Fähigkeiten, können aber auch Caps und Mali bedeuten.

=== Charakterpunkte

Ein Charakter hat zwei grundlegende Punkte: Stärkepunkte (Vergleichbar mit HP bei klassischen Rollenspielen) und Konzentrationspunkte (Vergleichbar mit MP).  
Stärkepunkte ermitteln sich aus der Attributen eines Charakters: Die Anzahl der Punkte des Attributs Körperkraft plus die Anzahl der Punkte des Attributs Gewandtheit plus die Anzahl der Punkte des Attributs Robustheit mal zwei.
Konzentrationspunkte ermitteln sich wie folgt: Die Anzahl der Punkte des Attributs Verstand plus Die Anzahl der Punkte des Attributs Willenskraft plus Die Anzahl der Punkte des Attributs Bewusstsein mal zwei.

Die Anzahl an Stärkepunkte und Konzentrationspunkte erscheint zunächst niedrig. Der Hintergrund ist, dass man eigentlich mit den doppelten Wert rechnen muss, nämlich die Zahl positiv und die Zahl negativ.

So ist es nicht schlimm, Stärkepunkte und Konzentrationspunkte bis null zu verbrauchen. Sie regenerieren sich sehr schnell im Kampf zum Beispiel und auch beim gehen. Auch essen kann hier schnell Wunde bewirken. Essen kleine Kratzer, Stöße, leichte Kopfschmerzen, also nichts wildes.

Schäden im Minusbereich der Charakterpunkte bedarfen einer fachgerechten Heilung oder einer tiefen Regeneration. Sollten die aktuellen Stärkepunkte dem negativen Basiswert entsprechen, dann ist der Charakter tot. Sollten die Konzentrationspunkte dem negativen Basiswert entsprechen, dann kann keine Fähigkeit mehr angewendet werden, die Konzentrationspunkte erfordert.

=== Attribute

Es gibt sieben Attribute:

- *Körperkraft* *(körperlich)*
- *Gewandtheit* *(körperlich)*
- *Robustheit* *(körperlich)*
- *Willenskraft* *(geistig)*
- *Verstand* *(geistig)*
- *Bewusstsein* *(geistig)*
- *Präsenz* *(beides)*

Grundsätzlich sind die Attribute vergleich mit klassischen Attributen aus RPGs wie Stärke, Intelligenz, Agilität usw., jedoch mit dem Unterschied, dass diese Werte veränderlich sind. Körperkraft kann runter gehen, wenn man krank ist, Verstand kann sinken, wenn man betrunken ist, Willenskraft kann steigen.

Bei der Charaktererstellung werden keine Punkte auf die Attribute verteilt, noch gibt es irgendwelche Grundpunkte bei den Attributen.

Attribute steigen, wenn man entsprechende Fähigkeiten lernt, wie bei Körperkraft "Nahkampfwaffen benutzen", bei Bewusstsein "Meditieren" und bei Präsenz "flirten". Fähigkeiten kann man lernen durch Lehrer, durch die Spezies, Herkunft usw. bei der Charaktererstellung und bei gegebenen Umständen: wenn man eine Waffe in die Hand nimmt, kann man Nahkampfwaffen führen steigern.  
Es gibt 5 Fähigkeiten, die man aktiv steigen kann. Jedes Level der Fähigkeit steigert das übergeordnete Attribut. Jede Aktion erzeugt Erfahrungspunkte: Diese Punkte können verteilt werden auf die Fähigkeiten: 100 Punkte sind ein Level der Fähigkeit. 20 Level ist ein Cap, was je nach Spezies, Herkunft, erlernter Beruf etc. gecappt oder erhöht werden kann.

== Ansicht der Attribute mit Platzhalter der Fähigkeiten

=== Körperkraft

Körperkraft ist das Attribut, dass am ehesten mit dem klassischen Attribute “Stärke” zu vergleichen ist. Zur Körperkraft gehören Fähigkeiten, die primär Stärke benötigen. Andere Besonderheiten sind die Tragkraft, die mit erhöhter Körperkraft ein hergeht. Eine einfache Probe ist das Gewicht: Gewicht ist ein Float-datentyp, der diskrete Werte einnehmen kann zwischen null und zehn. Ist ein Gegenstand schwerer als der Körperkraft-Level des Charakters, kann dieser den Gegenstand nicht aufheben.

*Beinflusst:*

- Stärkepunkte (Erhöht die Stärkepunkte um Eins je Level)
- Tragekraft
- Schaden von Gegenständen, die mit Stärke geführt werden. 


=== Robustheit

Robustheit kann auch Konstitution genannt werden, die Fähigkeit, körperliche Widerstandskraft aufzubauen. Charaktere mit einer hohen Robustheit haben mehr stärke Punkte, sind widerstandsfähiger gegen Schmerz und Gift (dazu zehn auch Nervengifte wie Alkohol oder Drogen), und können, wie bei Körperkraft, mehr tragen.

*Beeinflusst:*

- Stärkepunkte (Erhöht die Stärkepunkte um Zwei je Level)
- Tragkraft
- Widerstandskraft gegenüber Schaden und Giften.


=== Gewandtheit

Flinke Menschen besitzen eine hohe Gewandtheit. Es ist aber auch ein Zeichen von Geschick, wenn Menschen sehr gewandt sind. 

*Beinflusst:*

- Stärkepunkte 
- Erhöht den Bewegungsradius um ein Feld pro Level
- Erhöht den Schaden mit Waffen, die Geschicklichkeit benötigen.
- Je höher der Level, desto höher ist die Möglichkeit, zu parieren.


=== Verstand

Beeinflusst Konzentrationspunkte


=== Willenskraft

Beeinflusst Konzentrationspunkte


=== Bewusstsein

Beeinflusst Konzentrationspunkte mal Zwei


=== Präsenz

In anderen Spielen oft Charisma genannt, steht Präsenz für die Fähigkeit, gut auszusehen und andere Menschen in seinen Bann zu ziehen. Präsenz jedoch hat keinen Einfluss auf Stärkepunkte oder Konzentrationspunkte und stellt somit eine Besonderheit da. 

*Beeinflusst:* 

- soziale Interaktionen (Erhöht Beziehungen um einen halben Punkt pro Level)
- Begleiter bleiben bei präsenten Menschen entweder länger (bei Level 5) oder nur für die Hälfte des Geldes (Stufe 10).


​           

=== Besitz und Beziehungen

==== Inventar


==== Begleiter


==== Beziehungen


Im Buch der Charaktere findet man Informationen zu allen einzelnen Punkten.

#figure(
  table(
    columns: 2,
    table.header([Wert], [Bedeutung]),
    [\+10], [liebt dich / absolute Loyalität],
    [\+5], [wohlgesonnen],
    [0], [neutral],
    [\-5], [misstrauisch],
    [\-10], [feindselig / tötet dich bei Gelegenheit],
  ), caption: [Übersicht der Beziehungen],
) <texpile-table-474deabb0bed>