# Charakterregeln in JSON: Anleitung zu den Beispielen

Stand: 12. Oktober 2026. Die Beispiele liegen unter
[`src/data/character_rules/`](../src/data/character_rules/README.md).

## Was diese Dateien bewirken

Die Dateien sind ein **Vorschlag für einen zukünftigen Datenvertrag**, kein
bereits unterstütztes Importformat. Der aktuelle Godot-Code lädt weiterhin seine
vorhandenen Charakter-, Talent- und Aktionsressourcen. Die Beispiele verändern
kein Spielverhalten und keine Spielstände. Es wurde kein zweites Regelsystem
implementiert. Ein späterer Import muss die vorhandenen Kataloge und
Conditions-/WorldRules-Verträge erweitern.

Alle Definitionen enthalten `format_version: 1`, eine stabile `id`, `name`,
`description` und `status: "example_draft"`. Die Formatversion bezeichnet diesen
Entwurf, nicht die Spielstandversion. Namen und Beschreibungen sind frei editierbar.
IDs sind technische Verweise: Kleinbuchstaben, Ziffern und Unterstriche verwenden,
mit einem Buchstaben beginnen. Pro Kategorie müssen IDs eindeutig sein.

Alle folgenden Bedeutungen sind **vorgeschlagene Auswertungsregeln**, damit die
Beispiele zusammenpassen. Sie müssen vor dem Import verbindlich entschieden und
implementiert werden. Neue Operationen lassen sich nicht allein durch das
Erfinden eines neuen `type` ausführbar machen.

## Schnell anfangen

1. Öffne [`charmante_ueberzeugung.json`](../src/data/character_rules/conditions/charmante_ueberzeugung.json).
   Ändere die Talentgrenzen oder ersetze `all` testweise durch `any`.
2. Öffne [`schwert_doppelhieb_bereit.json`](../src/data/character_rules/conditions/schwert_doppelhieb_bereit.json).
   Hier treffen Talentstufe, Attribut und passende Ausrüstung zusammen.
3. Öffne [`schwert_doppelhieb.json`](../src/data/character_rules/actions/schwert_doppelhieb.json).
   Verändere Trefferstärken, Kosten oder die Anzahl der Einträge unter `steps`.
4. Öffne [`schwert_doppelhieb_freischaltung.json`](../src/data/character_rules/rules/schwert_doppelhieb_freischaltung.json).
   Diese Regel verbindet Voraussetzung und Ersetzung des normalen Angriffs.

Kopiere für neue Varianten eine ähnliche Datei und ändere Dateiname sowie ID.
Die Vorlage-Dateien bleiben dadurch als Vergleich erhalten. Nach Änderungen
müssen JSON-Syntax, Verweise und später die Spielwirkung geprüft werden.

## Attribute und Talente

`attributes/` enthält Körperkraft, Gewandheit, Robustheit, Willenskraft, Verstand,
Bewusstsein und Präsenz. `base_value` ist ein vorgeschlagener Standard für neu
erzeugte Figuren, keine nachträgliche Änderung vorhandener Basiswerte.
`minimum` begrenzt den berechneten Wert nach unten. `base_plus_skill_levels`
beschreibt Basiswert plus die Beiträge der zugeordneten Talente.

`skills/` enthält Flirten, Überzeugen, Schwertkampf, Beidhändigkeit, Magiekunde,
Meditieren und Einschüchtern. `attribute_id` verweist auf ein Attribut.
`attribute_bonus_per_level: 1` bedeutet einen Attributspunkt pro Talentstufe.
`xp_per_level: 100` und `max_level: 20` zeigen eine lineare Entwicklung.
Die Höchststufe 20 ist absichtlich höher als der aktuelle Standardwert 10.

**Wichtige Wechselwirkung:** Flirten 11 plus Überzeugen 11 ergeben bei
Präsenz-Basis 1 bereits Präsenz 23. Die zusätzliche Voraussetzung Präsenz > 5
ist dann automatisch erfüllt. Das Beispiel bildet deinen Wunsch ab, macht aber
auch diese Konsequenz des bisherigen additiven Attributmodells sichtbar.

`schwertkampf` und `ueberzeugen` sind neue Beispiel-IDs. Vorhandene Talente heißen
unter anderem `schwertkampf_klassisch` und `rhetorik_ueberzeugen`. Ein späterer
Import darf sie nicht unbemerkt parallel verdoppeln oder alten Fortschritt verlieren;
es braucht eine ausdrückliche Zuordnung/Migration oder die Wiederverwendung der
vorhandenen IDs. Individuelle Stufen und Erfahrung bleiben im Charakterspielstand,
nicht in diesen Definitionsdateien.

## Bedingungen lesen und kombinieren

Eine Datei in `conditions/` enthält ihren Ausdruck im Feld `condition`.
Ein Ausdruck ist entweder eine Gruppe oder eine einzelne Prüfung:

- `all: [...]`: Alle Unterbedingungen müssen zutreffen.
- `any: [...]`: Mindestens eine Unterbedingung muss zutreffen.
- `not: {...}`: Genau eine Unterbedingung wird verneint.
- `type: "condition_ref"`: Verwendet eine andere Bedingung über `condition_id`.

Gruppen lassen sich beliebig sinnvoll verschachteln. Leere Gruppen und zyklische
Verweise sollen beim Import abgelehnt werden. Ein Knoten enthält entweder genau
einen Gruppenoperator oder eine typisierte Prüfung, keine Mischung.

Numerische Prüfungen verwenden `operator` mit `>`, `>=`, `==`, `!=`, `<=` oder `<`.
„Über Stufe 10“ ist `> 10`; „ab Stufe 10“ ist `>= 10`. JSON-Zahlen sind Zahlen,
keine Texte. Wahrheitswerte schreibt man `true` und `false`.

### Wer wird geprüft?

`subject: "actor"` bezeichnet die handelnde oder sprechende Figur,
`subject: "target"` ihr konkretes Gegenüber. `toward: "actor"` bei einer
Beziehungsprüfung beschreibt die Richtung: Im Verhandlungsbeispiel muss das
Gegenüber die sprechende Figur mindestens neutral bewerten, nicht umgekehrt.
Fehlt eine benötigte Figur, soll die Prüfung fehlschlagen.

### Prüfarten in den Beispielen

- `skill_level`: prüft `skill_id` und Stufe einer Figur.
- `attribute_value`: prüft `attribute_id`; `value_source: "effective"` verlangt
  den berechneten Wert einschließlich Talentboni und künftig wirksamer Modifikatoren.
- `equipped_item_tag`: verlangt eine Eigenschaft `tag` an einem Gegenstand im
  konkreten Ausrüstungsplatz. Die Beispiele verwenden `schwert`.
- `knows_fact`: prüft figurenbezogenes Wissen über `fact_id`.
- `flag_equals`: vergleicht einen weltweiten booleschen Zustand.
- `relationship_value`: prüft die gerichtete Beziehung zwischen zwei Figuren.
- `resource_value`: prüft aktuelle Stärke- oder Konzentrationspunkte.
- `resource_ratio`: prüft aktuelle Punkte geteilt durch ihren Basiswert. Bei
  Stärke 3 und Basis 12 ergibt sich 0,25. Überheilung kann Werte über 1 und
  Verletzung Werte unter 0 ergeben; es wird nicht auf 0–1 begrenzt. Bei Basis 0
  oder kleiner soll diese Prüfung fehlschlagen, statt durch 0 zu teilen.
- `has_status`: prüft eine aktive zeitweilige Wirkung über `status_id`.

Wissen, Flags und Beziehungen haben bereits verwandte Verträge in
[`WorldRules`](../src/core/world/world_rules.gd). Die hier gezeigte Kontextsyntax
mit `actor`/`target` ist jedoch neu und **nicht direkt an WorldRules übergebbar**.
Auch Gruppenoperatoren, Talent-/Attributprüfungen, Gegenstandstags und Statusprüfungen
sind dort noch nicht so implementiert. Unbekannte Prüfarten oder fehlende Werte
sollen geschlossen fehlschlagen und eine hilfreiche Diagnose liefern. Das gilt
auch unter `not`: ein ungültiger Ausdruck darf durch Verneinung nicht wahr werden.

## Die sechs Bedingungsbeispiele

- **Charmante Überzeugung:** Flirten > 10, Überzeugen > 10 und Präsenz > 5.
- **Doppelhieb bereit:** Schwertkampf ≥ 10, Gewandheit > 5 und mindestens ein
  Schwert in rechter oder linker Hand.
- **Friedliche Verhandlung:** entweder die soziale Kombination oder Überzeugen
  ≥ 8 mit bekanntem Passwort; zusätzlich kein Alarm und eine mindestens neutrale
  Beziehung des Gegenübers zur sprechenden Figur.
- **Zwei Schwerter bereit:** Doppelhieb-Voraussetzung, Beidhändigkeit ≥ 6 und
  ein Schwert in jeder Hand.
- **Notfall-Schutz:** höchstens 25 Prozent der Stärke-Basis, mindestens 4
  Konzentrationspunkte und noch kein aktiver Eiserner Wille.
- **Arkaner Fokus:** Magiekunde ≥ 8 und entweder Meditieren ≥ 6 mit Bewusstsein
  ≥ 8 oder Wissen über einen arkanen Lehrsatz; zusätzlich nicht verwirrt.

Die Wissens-, Flag-, Dialogoptions- und Status-IDs mit Präfix `beispiel_` sind
bewusste Platzhalter für Inhalte. Sie erzeugen keine Fakten, Dialogzeilen oder
Zustände. Die Gegenstandseigenschaft `schwert` benötigt später ein Tagfeld und
entsprechend markierte Gegenstandsdaten; das vorhandene Messer zählt nicht
automatisch als Schwert.

## Aktionen: Ziel, Kosten und mehrere Schritte

Eine Aktion in `actions/` definiert:

- `requires_condition_id`: optionale Voraussetzung; erneut bei Ausführung prüfen.
- `target_type`: `self`, `single_enemy` oder `single_ally` in diesen Beispielen.
- `requires_line_of_sight`: ob freie Sicht nötig ist.
- `range`: `distance` mit maximalem Abstand in Welteinheiten oder `self`.
- `cost`: Zugkosten und Konzentrationskosten für die **gesamte** Aktion.
- `steps`: geordnete Effektschritte, nicht zusätzliche eigene Züge.

Die Distanzgrenzen sind Beispiele für eine zukünftige Reichweitenprüfung. Der
aktuelle Kampf wertet solche numerischen Angriffsreichweiten noch nicht aus.

Beim Doppelhieb werden zwei Schadensschritte gegen dasselbe gewählte Ziel
aufgelöst. Jeder hat eine eigene Ausweichprüfung und eigene Robustheitsminderung.
Zweimal Stärke 4 gegen Robustheit 3 ergibt ohne Ausweichen insgesamt 2 Schaden,
während einmal Stärke 8 insgesamt 5 Schaden ergeben würde. Zwei Treffer sind
also nicht automatisch stärker als ein einzelner mit gleicher Gesamtstärke.
`stop_when_target_out_of_combat: true` verhindert den zweiten Treffer gegen ein
bereits ausgeschiedenes Ziel. Die Kosten werden einmal bezahlt.

Der Kreuzhieb verwendet für den ersten Treffer Körperkraft, für den zweiten
Gewandheit als Genauigkeitsattribut. Der fokussierte Feuerstoß zeigt eine
zusätzliche, kostenpflichtige Fernaktion. `defense: "current_evade_and_robustness"`
verweist konzeptionell auf die vorhandene Verteidigungsformel; es ist keine
bereits vom Resolver unterstützte JSON-Option.

Eiserner Wille und Ermutigen zeigen `apply_status` mit einem Attributbonus.
`owner_turns` meint hier beendete eigene Züge des **Empfängers**, wobei der beim
Auftragen gegebenenfalls laufende Zug nicht mitzählt. `count: 2` endet also nach
zwei späteren eigenen Zügen. `refresh_duration` erneuert bei erneuter Anwendung
desselben Status nur die Dauer, stapelt aber keinen weiteren Bonus. Die
Definition gilt nur für diese Beispiele. Ein Laufzeit-Statussystem samt
Speicherregeln ist noch nicht implementiert.

**Vor Implementierung entscheiden:** Ändert Robustheit +2 auch sofort die
Stärke-Basis? Bleiben aktuelle Punkte gleich? Was passiert bei Ablauf und
negativen Punkten mit der Todesgrenze? Dieses Beispiel legt nur den Attributbonus
fest; eine solche Folgeentscheidung ist daraus nicht automatisch beschlossen.

Ein späterer Resolver sollte Voraussetzungen, Ziele, Reichweite und unterstützte
Effekte vor Kostenabzug validieren. Ungültige Aktionen dürfen nicht teilweise
bezahlt oder ausgeführt werden. Zufälliges Ausweichen ist dagegen ein reguläres
Ergebnis eines bezahlten Angriffs.

## Regeln: zusätzliche Angebote und Ersetzungen

`rules/` verbindet eine `condition_id` mit einem `effect` und einer `priority`.
`scope` legt fest, wann die Regel berücksichtigt wird:

- `dialog_options`: beim Zusammenstellen der Gesprächsoptionen.
- `combat_action_selection`: beim Zusammenstellen verfügbarer Kampfaktionen.

`offer_dialog_option` bietet eine separat definierte Dialogoption an.
`offer_action` ergänzt eine Aktion. `replace_action` ersetzt eine vorhandene
Aktion durch die genannte Alternative. Bedingungen sind dynamische Prüfungen:
Fällt eine Voraussetzung weg, entfällt auch das Angebot. Sie lernen nichts
permanent und führen beim Prüfen keine Effekte aus.

**Vorgeschlagene Konfliktregel:** Mehrere Ersetzungen derselben Ausgangsaktion
werden gegen dieselbe ursprüngliche Aktionsliste geprüft. Die höchste Priorität
gewinnt. Gleich hohe zutreffende Prioritäten für dieselbe Aktion sind ein
Konfigurationsfehler. Ersetzungen werden nicht rekursiv verkettet. Eine nicht
vorhandene Ausgangsaktion wird durch Ersetzung nicht neu angeboten.

Doppelhieb ersetzt den normalen Schwertangriff mit Priorität 10. Kreuzhieb ersetzt
denselben normalen Angriff mit Priorität 20. Sind beide Voraussetzungen erfüllt,
gewinnt Kreuzhieb. Einträge für dieselbe zusätzliche Aktion oder Dialogoption
sollen nicht doppelt erscheinen.

Die Notfall-Regel bietet Eiserner Wille lediglich zur Auswahl an. Sie wirkt nicht
automatisch bei Verletzung. Ermutigen ist bewusst eine isolierte Aktionsvorlage;
es gibt noch keine Freischaltungsregel dafür. So lässt sich eine eigene erstellen.

## Kleine Prüffälle zum Experimentieren

- Flirten 10, Überzeugen 11, Präsenz 23: charmante Option fehlt wegen `> 10`.
- Beide Talente 11, Präsenz 23: charmante Option erlaubt.
- Schwertkampf 10, Gewandheit 5, Schwert vorhanden: Doppelhieb fehlt wegen `> 5`.
- Schwertkampf 10, Gewandheit 6, ein Schwert: Doppelhieb verfügbar.
- Zusätzlich Beidhändigkeit 6 und zweites Schwert: Kreuzhieb gewinnt Priorität.
- Passende Sozialwerte, aber Alarm aktiv: charmante Grundbedingung stimmt,
  friedliche Verhandlung bleibt gesperrt.
- Stärke 3 von 12, Konzentration 4, kein Schutzstatus: Notfall-Schutz verfügbar.
- Dieselbe Figur mit Schutzstatus: nicht erneut über diese Regel verfügbar.

Diese Fälle beschreiben die beabsichtigte Semantik der Beispieldaten, keine schon
bestandenen Laufzeittests. Beim Erstellen wurden JSON-Syntax, ID-Konsistenz,
interne Verweise und Zyklenfreiheit der Bedingungsverweise geprüft. Die Wirkung
im Spiel kann erst mit einem Importer und passenden Integrationstests geprüft werden.
