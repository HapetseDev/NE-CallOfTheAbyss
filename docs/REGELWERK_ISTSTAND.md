# Nascent Eternity: Call of the Abyss – aktuelles Regelwerk

Historischer Stand: 9. Oktober 2026.

**Nachtrag vom 13. Oktober:** Die Schadensregeln K-06 bis K-09 wurden inzwischen erweitert: Schlag verwendet effektive Körperkraft plus den zusätzlichen Waffenlos-Bonus; Gegenstände addieren Körperkraft, Kampfwert und einen passenden Talentbonus. Dieser Zusatzbonus zählt nach der Folgeentscheidung nur mit abgerundeter halber Stufe. Erfolgreiche Treffer mit positiver Rohstärke auf ungerüstete Ziele verursachen mindestens 1 Schaden; Rüstungs-/Trefferzonenregeln befinden sich im Übergang. Gegenstandsbruch und Level-/Kampfmusik sind hinzugekommen. Die aktuellen Details stehen im Abschnitt [Angriffe und Musik](DOKUMENTATION.md#angriffe-und-musik-13-oktober-2026). Die folgenden ursprünglichen Zahlen beschreiben den Stand vor dieser Änderung.

Stand der ursprünglichen Auswertung: 9. Oktober 2026. Aus dem Quellcode des aktuellen Arbeitsverzeichnisses abgeleitet, einschließlich der noch nicht eingecheckten Inventaränderungen. Ausgangscommit: `4b501da`.

Dieses Dokument beschreibt das gegenwärtige Verhalten. Es ist kein Vorschlag für das endgültige Spielsystem. **Wirksam** bezeichnet ausgeführte Regeln; **vorbereitet** bezeichnet vorhandene Daten oder Funktionen ohne vollständige Einbindung; **offen** bezeichnet fehlendes Verhalten oder auffällige Grenzen. Die Regelnummern ermöglichen konkrete Rückmeldungen, beispielsweise: „K-04: Nahkampf soll höchstens zwei Meter Reichweite haben.“

## 1. Aufbau eines Charakters

### C-01 – Ein gemeinsamer Charakterbogen

**Wirksam.** Spielerfiguren, Begleiter und NPCs verwenden denselben Typ Charakterbogen. Eine stabile Charakter-ID verbindet die Figur mit ihren gespeicherten Daten. Die sichtbare Figur in der Welt repräsentiert diesen Bogen; ihre Lebens- und Konzentrationswerte bilden keinen getrennten zweiten Vorrat.

Ein Charakter enthält:

- Identität: ID, Name, Ausbildung, Spezies, Herkunft, persönliches Ziel und Besonderheiten.
- Sieben Basisattribute, gelernte Talente mit Stufe und Talent-Erfahrung, aktive Trainingsauswahl, freie Erfahrungspunkte und einen Bonus auf die Talent-Höchststufe.
- Aktuelle Stärke- und Konzentrationspunkte sowie eine gesonderte Kennzeichnung für dauerhafte Niederlage.
- Fraktionszugehörigkeiten, gerichtete Beziehungen und Begleiterdaten.
- Gold, Rucksack und Ausrüstung.

Portrait und Paperdoll werden über den kleingeschriebenen Charakternamen im jeweiligen Assetordner gefunden. Sie ändern keine Werte.

### C-02 – Herkunft, Spezies und Ausbildung

**Vorbereitet.** Verfügbare Auswahlwerte sind:

- Ausbildung: keine, Krieger, Gelehrter, Handwerker.
- Spezies: keine, Mensch, Elf, Zwerg.
- Herkunft: keine, Waise, adelig, bürgerlich.
- Besonderheiten: keine, mutig, feinfühlig, geduldig.

Diese Angaben erzeugen derzeit **keine automatischen Attributboni, Mali, Talentpakete oder Höchststufen**. Die Startwerte stehen direkt in den Charaktervorlagen. Die Konstante „höchstens zwei Besonderheiten“ existiert, wird am Charakterbogen aber nicht als allgemeine Aufnahmegrenze durchgesetzt. Ein persönliches Ziel ist zunächst Text.

### C-03 – Sieben Attribute und ihre tatsächlich wirksamen Aufgaben

**Wirksam.** Ein effektives Attribut ergibt sich aus:

> Effektiver Wert = höchstens nach unten auf 0 begrenzt: Basiswert + Summe aller Stufen gelernter Talente dieses Attributs.

Ein Talent mit Stufe 3 gibt seinem zugeordneten Attribut also +3. Dieser Bonus gilt auch für andere Handlungen, die dasselbe Attribut verwenden. Ein Schwertkampftalent kann dadurch beispielsweise die Genauigkeit des Fausthiebs erhöhen.

- **Körperkraft:** Stärkepunkte, Tragkraft und Genauigkeit entsprechender Angriffe; Standardattribut des Fausthiebs und improvisierter Schläge.
- **Gewandheit:** Stärkepunkte, Initiative, passive Ausweichchance, Bewegungsradius, Fluchtchance sowie Genauigkeit von Messerstichen und Würfen.
- **Robustheit:** zählt doppelt zu den Stärkepunkten und reduziert eingehenden Schaden.
- **Willenskraft:** Konzentrationspunkte.
- **Verstand:** Konzentrationspunkte und Genauigkeit von Angriffsfähigkeiten aus Verstand-Talenten, etwa Feuerstoß.
- **Bewusstsein:** zählt doppelt zu den Konzentrationspunkten. Außerhalb des eigentlichen Kampfes unter anderem Gegenwert für Diebstahl.
- **Präsenz:** trägt soziale Talente. Es gibt derzeit keine allgemeine Überreden- oder Einschüchterungsprobe im Kampf.

Ein frisch erzeugter Resource-Bogen startet mit Basiswert 1 pro Attribut. Die Standardfiguren-Fabrik verwendet ohne Vorgaben 2. Benannte Figuren haben individuell eingetragene Werte. Ein allgemeines Punktverteilungssystem zur Charaktererschaffung ist daraus nicht abzuleiten.

### C-04 – Stärke- und Konzentrationspunkte

**Wirksam.** Alle folgenden Formeln verwenden effektive Attribute:

> Stärke-Basis = Körperkraft + Gewandheit + 2 × Robustheit.
>
> Konzentrations-Basis = Verstand + Willenskraft + 2 × Bewusstsein.

Aktuelle Punkte und Basiswerte sind getrennte Zahlen. Beim erstmaligen Initialisieren werden beide Vorräte auf ihre Basis gesetzt, wenn beide aktuellen Werte 0 sind. Das Wiederherstellen gespeicherter Charaktere schützt den gespeicherten Zustand vor diesem anfänglichen Auffüllen.

Schaden wird von den aktuellen Stärkepunkten abgezogen. **0 Stärkepunkte bedeutet derzeit weder Tod noch automatische Kampfunfähigkeit.** Auch negative Punkte oberhalb der Todesgrenze erlauben weiterhin Aktionen.

> Tod liegt vor, wenn aktuelle Stärkepunkte ≤ minus Stärke-Basis.

Bei Stärke-Basis 12 liegt die Todesgrenze somit bei −12. Von +12 bis −12 sind 24 Schadenspunkte nötig.

Für eine Fähigkeit mit positiven Konzentrationskosten müssen mindestens so viele aktuelle Konzentrationspunkte vorhanden sein. Die Kosten können den Vorrat auf 0, regulär aber nicht unter 0 senken. Eine zusätzliche Erschöpfungsprüfung bei minus Konzentrations-Basis existiert; der gewöhnliche Kostencheck greift schon früher. Kostenlose Fähigkeiten bleiben verfügbar.

**Offen:** Heilung und Konzentrationswiederherstellung addieren ihren Betrag ohne obere Begrenzung. Ein Trank kann über den Basiswert hinaus heilen. Es gibt keine allgemeine laufende Regeneration beim Gehen oder pro Kampfrunde, keine getrennte Heilregel für negative Punkte und keine allgemeine Wiederbelebungsregel.

### C-05 – Talente, Training und Erfahrung

**Teilweise wirksam.** Jedes Talent besitzt einen Namen, eine ID, Beschreibung und genau ein zugeordnetes Attribut. Gelernte Talente speichern Stufe und Fortschritt zur nächsten Stufe.

- Pro Stufenanstieg werden 100 Talent-Erfahrung benötigt, unabhängig von der bisherigen Stufe.
- Die übliche Höchststufe ist 10 plus der figurenspezifische Höchststufenbonus.
- Höchstens fünf Talente können gleichzeitig für aktives Training markiert sein.
- Aktions-Erfahrung wird nur für ein aktiv markiertes Talent angenommen. Erfahrung über dessen Höchststufe hinaus wandert in den freien Erfahrungsvorrat.
- Ein Stufenanstieg erhöht den effektiven Wert des zugehörigen Attributs um 1. Zusätzlich werden aktuelle Stärke und Konzentration jeweils um 1 angehoben, sofern sie positiv sind, dabei höchstens bis zur jeweiligen neuen Basis. Bei 0 oder negativen Werten erfolgt diese Auffüllung nicht.

**Vorbereitet/offen:** Die Anzeige und der Debug-Editor sehen fünf Talentplätze je Attribut vor. Die allgemeinen Lern- und Erfahrungsmethoden setzen diese Grenze nicht durchgehend durch. Eine vollständige Lernregel über Lehrer, Herkunft oder Waffenbenutzung fehlt. Im untersuchten Spielcode rufen Kampfaktionen die vorhandene Methode für Aktions-Erfahrung nicht auf; Angreifen trainiert daher nicht automatisch.

**Auffälliger Fehler im Erfahrungspfad:** Die Methode zum Verteilen freier Erfahrung behandelt den Rückgabewert der Talentberechnung als Wahrheitswert. Dieser Rückgabewert ist tatsächlich die übrig gebliebene Erfahrung. Bei vollständiger Verwendung wird deshalb 0 zurückgegeben und der freie Vorrat nicht abgezogen, obwohl das Talent bereits verändert wurde. Bei Rest-Erfahrung kann dagegen der gesamte angebotene Betrag abgezogen werden. Dieser Pfad ist außerdem nicht als regulärer Bedienablauf eingebunden. Er ist keine verlässliche fertige Spielerregel.

### C-06 – Konkrete Startbeispiele

**Wirksam in den Vorlagen; Spielstände können abweichen.**

**Dannerman:** Basisattribute Körperkraft 3, Gewandheit 2, Robustheit 2, Willenskraft 2, Verstand 2, Bewusstsein 2, Präsenz 3. Nahkampfwaffen Stufe 2 und klassischer Schwertkampf Stufe 1 erhöhen Körperkraft auf 6. Meditieren Stufe 1 erhöht Bewusstsein auf 3. Daraus folgen Stärke-Basis 12, Konzentrations-Basis 10 und Tragkraft 40. Die Vorlage enthält 50 freie Erfahrung, 50 Gold und ein Messer im Rucksack. Das Messer ist dadurch zunächst noch kein im Kampf bereitgelegter Gegenstand.

**Shalka:** Basisattribute 2, 3, 2, 2, 2, 3, 2 in derselben Reihenfolge. Ausweichen Stufe 2 erhöht Gewandheit auf 5; Meditieren Stufe 1 erhöht Bewusstsein auf 4. Daraus folgen Stärke-Basis 11, Konzentrations-Basis 12 und Tragkraft 20. Startgold: 20.

## 2. Besitz und kampfbereite Ausrüstung

### I-01 – Ausrüstungsplätze

**Wirksam.** Es gibt Kopf, Rumpf, rechte Hand, linke Hand, Beine, Füße, Schmuck und neun Plätze Schnellausrüstung. Einen zusätzlichen Waffenplatz gibt es nicht mehr.

Beide Hände und sämtliche Schnellplätze nehmen beliebige Gegenstände auf, auch Tränke. Körperplätze verlangen einen passenden Ausrüstungsplatz am Gegenstand und akzeptieren keine Verbrauchsgegenstände. Je Ausrüstungsplatz liegt ein einzelner Gegenstand, kein ganzer Rucksackstapel.

Der Rucksack enthält Gegenstände in Stapeln nach ihrer jeweiligen Stapelgrenze. Die Inventare werden in der Partyreihenfolge angezeigt: Anführer zuerst, danach Begleiter. Ausrüstung gehört weiterhin der jeweiligen Figur.

### I-02 – Zugriff im Kampf

**Wirksam.** Das Gegenstandsmenü berücksichtigt rechte Hand, linke Hand und die neun Schnellplätze. Gegenstände im Rucksack sowie Kopf-, Rumpf-, Bein-, Fuß- oder Schmuckplatz erscheinen dort nicht als verwendbare Kampfgegenstände.

Zwei belegte Hände geben keinen automatischen Doppelangriff. Für einen Gegenstandsangriff wird ein Gegenstand mit einer Verwendungsart ausgewählt. Es gibt keine allgemeine Zweihandpflicht, Nebenhandstrafe oder besondere Beidhändigkeitsberechnung.

### I-03 – Gewicht und Gegenstandseigenschaften

**Wirksam.**

> Tragkraft = 10 + 5 × effektive Körperkraft.
>
> Getragenes Gewicht = Rucksackgewicht einschließlich Stapelanzahl + Gewicht sämtlicher ausgerüsteter Gegenstände.

Ausrüsten und Zurücklegen ändern das Gesamtgewicht nicht. Die Aufnahmeprüfung vergleicht zusätzliches Gewicht mit der verbleibenden Tragkraft. Das reine Hinzufügen auf Datenebene führt diese Prüfung nicht selbst aus; die jeweiligen Aufnahmeabläufe müssen sie verwenden. Eine allgemeine Bewegungs- oder Kampfstrafe durch Überlast ist nicht eingebaut.

Gegenstände haben bereits mehr als Gewicht: unter anderem Stapelgröße, Ausrüstungszuordnung, Verbrauchskennzeichnung, Heil- und Konzentrationswirkung sowie eigene Kampf-Verwendungsarten. Eine allgemeine Gegenstandsrüstung oder ein Schadensbonus durch angelegte Kleidung wird in der Schadensformel nicht ausgewertet.

## 3. Beginn, Beteiligung und Zugfolge

### K-01 – Wo und wie ein Kampf beginnt

**Wirksam.** Ein Angriff eröffnet oder erweitert einen Kampf in der normalen Spielwelt. Angreifer und Opfer erhalten die beiden Kampfseiten. Derzeit gibt es eine zentrale laufende Kampfsitzung; neue Angriffe werden dieser zugeordnet. Bereits tote oder dauerhaft als besiegt markierte Figuren dürfen nicht teilnehmen.

Nahe reaktionsfähige Figuren werden in einem Radius von 8 Welteinheiten **um den Angreifer** geprüft. Die Beteiligung wird anlässlich des Angriffs ermittelt; es gibt hier keine laufende automatische Rekrutierung allein durch späteres Heranlaufen.

### K-02 – Beziehungen bestimmen die Seite

**Wirksam.** Beziehungen sind gerichtet und auf −10 bis +10 begrenzt. A kann B mögen, ohne dass B A mag. Ein persönlicher Eintrag hat Vorrang vor Fraktionsbeziehungen. Unter passenden Fraktionswerten gewinnt der mit dem größten absoluten Betrag; bei Gleichstand der zuerst gefundene.

Ein hinzukommender Kandidat unterstützt:

1. Das Opfer, wenn seine Beziehung zum Opfer positiv und mindestens so hoch wie zum Angreifer ist.
2. Sonst den Angreifer, wenn dessen Wert positiv und höher als der zum Opfer ist.
3. Sonst zunächst niemanden. Bei dieser neutralen Einordnung hilft eine gemeinsame Party als Auffangregel: zuerst gemeinsame Party mit dem Angreifer, sonst mit dem Opfer.

Negative Beziehungen allein lassen einen Zuschauer also nicht automatisch gegen die gehasste Figur kämpfen. Bei gleich hoher positiver Sympathie für beide erhält das Opfer Vorrang. Partymitglieder können aufgrund positiver Beziehungen auf unterschiedlichen Seiten landen.

### K-03 – Initiative statt fester Runden

**Wirksam.** Jeder Teilnehmer beginnt mit Initiative 0.

> Initiativezuwachs pro Sekunde = effektive Gewandheit × 6.
>
> Bei 100 Initiative wird ein Zug in die Warteschlange gestellt; 100 werden abgezogen, ein Rest bleibt erhalten.

Eine Figur mit Gewandheit 5 benötigt aus leerem Meter etwa 3,33 Sekunden, eine mit Gewandheit 2 etwa 8,33 Sekunden. Diese Zeiten gelten nur, während die Figur tatsächlich Initiative sammelt.

**Wichtig:** Der aktive Teilnehmer und bereits in der Zugwarteschlange stehende Figuren sammeln nicht weiter. Die übrigen sammeln auch während der Menüwahl oder Positionierung des aktiven Teilnehmers weiter, höchstens bis sie selbst einen wartenden Zug erhalten. Es gibt immer nur einen aktiven Zug. Langes Überlegen kann somit die Warteschlange füllen, löst aber keine parallelen Angriffe aus.

Schnelle Figuren kommen häufiger zum Zug; eine exakt doppelte Anzahl Züge bei doppelter Gewandheit ist wegen dieser Wartelogik keine allgemeine Garantie. Bei gleichzeitigem Erreichen der Schwelle entscheidet die Durchlaufreihenfolge der Teilnehmer. Gewandheit 0 erzeugt keinen Initiativezuwachs.

Ein Rundensignal existiert, hat aber keine angeschlossene allgemeine Regeneration oder Statusdauerregel. Alle Partymitglieder werden in ihren jeweiligen Zügen manuell bedient; echte NPCs handeln automatisch.

## 4. Aktionen und Trefferberechnung

### K-04 – Eine ausgeführte Aktion pro Zug

**Wirksam.** Das Menü bietet Gegenstand, Fähigkeit, Bewegen, Reden und Fliehen. Ein Angriff und eine Bewegung sind getrennte Zugentscheidungen. Zurücknavigation in Auswahlmenüs verbraucht keinen Zug. Eine ausgelöste Gegenstands- oder Fähigkeitsaktion beendet den Zug auch dann, wenn ihre Auflösung fehlschlägt.

### K-05 – Reichweite und Sichtlinie

**Wirksam mit offener Grenze.** Für viele Angriffe muss eine freie Sichtlinie bestehen. Wände und andere Charakterkörper können diese auf Augenhöhe blockieren. Das Menü sperrt entsprechende Einzelziele; die Schadensauflösung prüft nochmals.

**Es gibt im laufenden Kampf derzeit keine numerische Nahkampf- oder Wurfentfernungsgrenze.** Die Kennzeichnungen Nahkampf, Fernkampf und Wurf sind vorhanden, werden in der Zielauswahl und Schadensauflösung aber nicht als Distanzregel ausgewertet. Ein Messerstich kann dadurch ein entferntes Kampfziel bei freier Sicht erreichen. Die Bewegungskreisgröße ist keine Angriffsreichweite.

### K-06 – Automatische Verteidigung

**Wirksam.** Jeder einzelne Schadensangriff verwendet folgende Schritte:

1. Genauigkeit = effektives Angriffsattribut der gewählten Verwendungsart bzw. des Quelltalents der Fähigkeit. Ohne Quelltalent wird Körperkraft verwendet.
2. Ausweichchance = 3 Prozentpunkte × (Gewandheit des Ziels − Genauigkeit), begrenzt auf 0 bis 60 Prozent.
3. Bei erfolgreichem Ausweichen: 0 Schaden.
4. Andernfalls Schaden = Angriffsstärke − Robustheit des Ziels, mindestens 0.

Es gibt keinen Mindestschaden von 1. Das Angriffsattribut erhöht **nicht** den Rohschaden. Es beeinflusst das Ausweichen des Ziels. Bei gleich hoher Genauigkeit und Ziel-Gewandheit beträgt die Ausweichchance 0 Prozent. Kritische Treffer, Schadensstreuung, Trefferzonen, Schadenstypen, Resistenzen und aktive Parade sind nicht Teil dieser Berechnung. Verteidigung kostet keinen eigenen Zug.

**Beispiel:** Messerstich mit Stärke 6 und Genauigkeit 5 gegen Gewandheit 7 und Robustheit 3: 6 Prozent Ausweichchance; bei einem Treffer 3 Schaden.

### K-07 – Gegenstandsangriffe

**Wirksam; Zahlen sind vorläufige Balancingwerte.**

- Messer, Stechen: Stärke 6, Genauigkeit über Gewandheit, kein Verbrauch.
- Messer, Werfen: Stärke 8, Genauigkeit über Gewandheit, verbraucht das ausgewählte ausgerüstete Messer.
- Stein, Schlagen: Stärke 4, Genauigkeit über Körperkraft, kein Verbrauch.
- Stein, Werfen: Stärke 5, Genauigkeit über Gewandheit, verbraucht den ausgewählten ausgerüsteten Stein.
- Jeder Gegenstand ohne eigene Verwendungsarten: improvisiertes Schlagen, Stärke 1, Genauigkeit über Körperkraft, kein Verbrauch.

Ein Heiltrank kann damit auch zum improvisierten Schlagen verwendet werden; dabei heilt er nicht und wird nicht verbraucht. Bei Robustheit des Ziels von mindestens 1 macht ein improvisierter Treffer mit dem derzeitigen Startwert keinen Schaden.

Das Datenfeld „zugehöriges Talent“, etwa Messerwerfen, wird nicht als zusätzlicher gezielter Bonus ausgewertet. Ein solches Talent kann über seinen allgemeinen Attributbonus wirken. Geworfene Gegenstände verschwinden aus dem Ausrüstungsplatz; ein Projektil mit anschließender Bergung wird hier nicht erzeugt.

### K-08 – Tränke und andere Verbrauchsgegenstände

**Wirksam.** Ein Verbrauchsgegenstand aus Hand oder Schnellausrüstung kann auf genau einen noch aktiven Teilnehmer derselben Kampfseite angewendet werden, einschließlich der eigenen Figur. Dabei wird genau der ausgewählte ausgerüstete Gegenstand entfernt. Gleichartige Rucksackvorräte werden nicht stattdessen verbraucht.

Der vorhandene Heiltrank gibt 25 Stärkepunkte zurück. Allgemein können Gegenstände außerdem Konzentration wiederherstellen, wenn ihr entsprechender Wert positiv ist. Für diesen Verbrauchspfad gibt es keine eigene Distanz- oder Sichtlinienprüfung. Ausgeschiedene Teilnehmer sind keine wählbaren Heilziele.

### K-09 – Aktive Fähigkeiten

**Wirksam/vorbereitet.** Aktive Fähigkeiten werden nach dem erforderlichen Quelltalent und dessen Mindeststufe freigeschaltet. Talent und aktive Aktion sind damit zwei verschiedene Dinge.

Der aktuelle Katalog enthält:

- **Fausthieb:** für jeden verfügbar, 0 Konzentrationskosten, ein Gegner, Stärke 5, Genauigkeit über Körperkraft, Sichtlinie erforderlich.
- **Feuerstoß:** Magiekunde ab Stufe 1, 8 Konzentrationskosten, ein Gegner, Stärke 14, Genauigkeit über Verstand, Sichtlinie erforderlich.
- **Schlachtruf:** Bardenkunst ab Stufe 1, 6 Konzentrationskosten, alle Verbündeten, vorgesehene Verstärkung 3, keine Sichtlinie verlangt. **Die Verstärkung ist noch nicht implementiert.**

Schaden und Heilung sind als Fähigkeitseffekte implementiert. Im vorhandenen Katalog steht derzeit keine aktive Heilfähigkeit. Verstärkung, Schwächung und sonstige Spezialwirkungen schlagen als nicht implementiert fehl. Dabei werden positive Konzentrationskosten bereits **vor** der Effektprüfung abgezogen: Ein Schlachtruf kann aktuell 6 Punkte und den Zug kosten, ohne jemanden zu stärken.

Außerhalb des Kampfes gibt es ein Party-Fähigkeitenmenü. Unterstützende Effekte verwenden dort bislang nur die Heilauflösung; offensive Fähigkeiten gegen Fremde können den Kampf eröffnen und sofort als Erstschlag wirken, bevor ein regulärer Initiativezug anfällt.

### K-10 – Bewegen

**Wirksam.** Die Figur darf sich mit WASD innerhalb eines Kreises um ihre Ausgangsposition positionieren.

> Radius = größerer Wert aus 1 und effektiver Gewandheit × 1 Welteinheit.

Das Bewegungstempo beträgt 1 Welteinheit pro Sekunde. Begrenzend ist die Entfernung zur Ausgangsposition, keine aufsummierte Wegstrecke. Innerhalb des Kreises kann man daher während der Positionierung mehrfach hin und her gehen. Die normale Körperbewegung verwendet die Weltphysik; die zusätzliche Kreisbegrenzung korrigiert die Position am Rand.

„Bewegung ausführen“ übernimmt die Position und beendet den Zug. „Abbrechen“ setzt auf die Ausgangsposition zurück und öffnet das Kampfmenü ohne Zugverbrauch.

### K-11 – Reden

**Wirksam mit offener Spielregel.** Figuren mit passender NPC-Interaktion können als Gesprächspartner gewählt werden, auch auf der eigenen Seite. Die vorhandene Gesprächsaktion wird aufgerufen und der Zug beendet. Es gibt keine allgemeine Berechnung für Überzeugen, Kapitulation, Einschüchtern oder einen automatischen Friedensschluss. Konkrete Dialoginhalte können eigene Wirkungen besitzen.

### K-12 – Fliehen

**Wirksam.**

> Fluchtchance = 50 Prozent + 2 Prozentpunkte × (eigene Gewandheit − durchschnittliche Gewandheit der noch aktiven Gegenseite), begrenzt auf 10 bis 90 Prozent.

Gewandheit 7 gegen durchschnittlich 4 ergibt beispielsweise 56 Prozent. Auch ein gescheiterter Versuch beendet den Zug.

Ein erfolgreicher Wurf allein genügt nicht: Der Level muss einen geeigneten Fluchtbereich für Party bzw. Gegner bieten, dort muss ein freier Zielplatz existieren und ein begehbarer Weg dorthin gefunden werden. Die Figur läuft den Weg tatsächlich ab. Ohne freien Weg scheitert das Entkommen trotz positivem Wurf. Wird die Figur unterwegs aufgehalten, wird ihre Fluchtkennzeichnung wieder aufgehoben.

Während der Flucht erhält sie keine Züge und ist kein reguläres Kampfziel mehr. Das Seitenende wartet auf laufende Fluchten. Ein einzeln entkommener Charakter erhält seine freie Steuerung erst nach Ende der gesamten Sitzung zurück. Erneutes Angreifen kann einen bereits geflohenen Teilnehmer wieder aufnehmen.

## 5. Gegnerverhalten, Niederlage und Konsequenzen

### K-13 – Gegenwärtige Gegner-KI

**Wirksam und einfach gehalten.** Der NPC sucht auf der Gegenseite ein Ziel mit freier Sichtlinie. Er bevorzugt die Figur mit der negativsten eigenen Beziehung; Gleichstände bleiben bei der zuerst gefundenen Figur.

Er nimmt den ersten verfügbaren Kampfgegenstand und dessen erste Verwendungsart. Wenn keiner vorhanden ist, verwendet er Fausthieb. Er plant keine Bewegung, Flucht, Heilung oder ausgefeilte Fähigkeitskombination. Ein Trank im ersten nutzbaren Platz kann deshalb als improvisierte Schlagwaffe behandelt werden. Findet er kein sichtbares Ziel, beendet er seinen Zug ohne Aktion.

### K-14 – Niederlage ist nicht 0 Stärkepunkte

**Wirksam.** Die normale Schadensauflösung meldet einen Teilnehmer erst dann als besiegt, wenn positiver Schaden ihn an oder unter seine Todesgrenze gebracht hat. Eine separate automatische Bewusstlosigkeit bei 0 oder im negativen Bereich existiert nicht.

Für NPCs mit Interaktionskomponente wird diese Niederlage zusätzlich dauerhaft am Charakterbogen und gegebenenfalls mit den konfigurierten Weltflags/Ereignissen vermerkt. Diese Kennzeichnung ist unabhängig von Heilung und verhindert weitere Kampfteilnahme. Für Partyfiguren ist derselbe persistente NPC-Niederlagepfad nicht automatisch angeschlossen; ihr Todeswert verhindert jedoch die erneute Teilnahme.

### K-15 – Ende des Kampfes und Belohnungen

**Wirksam/offen.** Die Sitzung endet, wenn eine Seite keinen aktiven Teilnehmer mehr hat und die andere noch mindestens einen. Besiegte und Geflohene zählen als ausgeschieden. Sind beide Seiten gleichzeitig ohne aktive Teilnehmer, enthält diese Endprüfung keinen eigenen Abschlusszweig.

Zum Ende verlassen sämtliche Teilnehmer den Kampfmodus. Eine allgemeine Game-over-Regel bei Party-Niederlage, automatische Beuteverteilung oder allgemeine Sieg-Erfahrung ist nicht angeschlossen. Einzelne NPC-Niederlagen können Weltzustand und Quests fortschreiben; konkrete Questbelohnungen sind separate Regeln und kein allgemeiner Kampfertrag. Flucht löst nicht das NPC-Niederlageereignis aus.

## 6. Punkte für den Vergleich mit deinen Vorstellungen

Diese Fragen beschließen noch keine Änderung. Sie markieren besonders folgenreiche Unterschiede bzw. offene Entscheidungen:

1. **C-02/C-03:** Sollen Spezies, Herkunft, Ausbildung und Besonderheiten Werte automatisch erzeugen? Soll es überhaupt Basisattribute geben oder ausschließlich Talentstufen?
2. **C-04:** Sollen negative Stärkepunkte weiter volle Handlungsfähigkeit erlauben? Wie sollen oberes Heilungslimit, Regeneration, negative Verletzungen und Wiederbelebung funktionieren?
3. **C-04:** Dürfen Fähigkeiten Konzentration unter 0 verbrauchen, solange die negative Basis noch nicht erreicht ist?
4. **C-05:** Welche Handlungen trainieren welche Talente, wie werden freie Erfahrung und Lehrer benutzt und wo gelten feste Platzgrenzen?
5. **K-03:** Soll die Initiative während der Zugwahl weiterlaufen oder für alle pausieren?
6. **K-05/K-06:** Welche Entfernungen gelten für Nahkampf, Wurf und Magie? Sollen Attribute auch Schaden erhöhen? Soll Robustheit schwache Angriffe vollständig aufheben können?
7. **I-02/K-07:** Welche Regeln gelten für zwei Waffen, Zweihandgegenstände, Rüstung und geborgene Wurfgegenstände?
8. **K-08:** Sollen Tränke auf entfernte Verbündete ohne Sichtlinie wirken? Wie werden im Kampf weitere Rucksackgegenstände nachgerüstet?
9. **K-09/K-11:** Was genau bewirken Verstärkungen, Schwächungen und Gespräche, und welche Kosten fallen bei Fehlschlägen an?
10. **K-14/K-15:** Was unterscheidet besiegt, bewusstlos und tot? Welche Konsequenzen und Belohnungen folgen nach Kampfende?

Für Änderungswünsche genügt dieses Muster:

> Regelnummer: …  
> Gewünschte Regel: …  
> Konkretes Beispiel: …  
> Geltung: Party / NPCs / alle Figuren.  
> Umgang mit bereits gespeicherten Figuren: …

## 7. Quellen und Prüfgrundlage

Die Aussagen wurden durch Lesen der tatsächlich aufgerufenen Implementierung und Abgleich mit den Ressourcen gewonnen. Für dieses Dokument wurde kein Spielverhalten verändert. Es handelt sich um eine statische Codeauswertung, nicht um eine neue vollständige Laufzeitprüfung sämtlicher Regeln.

Zentrale Quellen, relativ zu diesem Dokument verlinkt:

- [Charakterbogen und Punkte](../src/resources/characters/character_sheet.gd), [Auswahlwerte und Grenzen](../src/resources/characters/character_enums.gd), [Erfahrungsberechnung](../src/gameplay/character/character_sheet_calculator.gd).
- [Charaktervorlagen](../src/resources/characters/sheets/), [Talentzuordnungen](../src/resources/characters/attribute_talent_catalog.gd), [Talentkatalog](../src/core/managers/skill_catalog.gd).
- [Inventar](../src/gameplay/inventory/inventory.gd), [Gegenstandsdaten](../src/resources/items/item_data.gd), [Messer](../src/resources/items/messer.tres), [Stein](../src/resources/items/stein.tres), [Heiltrank](../src/resources/items/heiltrank.tres).
- [Punkteanbindung und Kampffähigkeit](../src/gameplay/character/player/playable.gd), [Partyreihenfolge](../src/gameplay/character/party/party.gd).
- [Kampfbeginn und Ende](../src/core/managers/combat_manager.gd), [Beteiligung](../src/gameplay/combat/engine/combat_participant_resolver.gd), [Beziehungen](../src/gameplay/combat/relationships/relationship_service.gd).
- [Initiative und Sitzung](../src/gameplay/combat/engine/combat_session.gd), [Schadens- und Effektauflösung](../src/gameplay/combat/engine/combat_resolver.gd), [Balancingwerte](../src/resources/combat/combat_balance.gd), [Sichtlinie](../src/gameplay/combat/engine/combat_line_of_sight.gd).
- [Spieleraktionen](../src/gameplay/character/state_machine/state_combat_turn.gd), [Bewegung](../src/gameplay/character/state_machine/state_combat_move.gd), [Gegner-KI](../src/gameplay/combat/engine/npc_combat_brain.gd), [Fluchtbereiche](../src/world/combat/flee_area.gd), [Fluchtwege](../src/world/combat/flee_route.gd).
- [Aktive Fähigkeitsdefinition](../src/resources/abilities/ability_definition.gd), [vorhandene Fähigkeiten](../src/resources/abilities/definitions/), [Freischaltung](../src/core/managers/ability_catalog.gd), [Party-Fähigkeiten](../src/gameplay/character/state_machine/state_party_skills.gd), [Unterstützung außerhalb des Kampfes](../src/gameplay/combat/engine/party_ability_resolver.gd).

Zum Kontext wurden [technische Dokumentation](DOKUMENTATION.md), [offene Architekturpunkte](ARCHITEKTUR_OFFENE_PUNKTE.md) und die Charakterabschnitte des [Design-Dokuments](NascentEternity-Design-Document.md) herangezogen. Diese Texte enthalten teilweise ältere Beschreibungen: insbesondere Fluchtteleport, vollständig pausierte Initiative und ältere Party-/Speicherannahmen. Für die obigen Regeln war die aktuelle Implementierung ausschlaggebend. Die im Design beschriebene Regeneration und Herkunftsmodifikatoren sind damit nicht als bereits implementiert übernommen worden.
