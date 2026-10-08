# WorldState – erster Architekturbaustein

Offene Questregeln und die geplante Fortsetzung stehen in
[Architektur: offene Entscheidungen und nächste Schritte](../../../ARCHITEKTUR_OFFENE_PUNKTE.md).

`GameState.world_state` besitzt die Charakterregistrierung, Flags, besuchte Orte,
Charakterpositionen und persistente Weltobjekte. Er enthält keine Welt-Nodes.
Die bisherige API `GameState.character_registry` verweist auf dieselbe Registry.
Beziehungen und Skills bleiben in den vorhandenen CharacterResources.

## Bereits angebunden

- Alle registrierten Charakterdaten einschließlich Inventar und Ausrüstung.
- Aktueller Ort und zuletzt erfasste Positionen der registrierten Figuren.
- Die drei Pflanzen und der Heiltrank in Level1Ep1 mit festen Objekt-IDs.
- Abgelegte Gegenstände mit fortlaufend vergebenen IDs.
- Sitzungsneustart leert auch Orte, Objektzustände und Positionsdaten.

Inventar und Ausrüstung sind die einzige Quelle für Gegenstandsbesitz.
`get_object_owner(id)` ermittelt den Besitzer daraus. `ItemData.world_object_id`
kennzeichnet eine einzelne Weltinstanz; solche Gegenstände werden nicht gestapelt.
Ein aufgenommener oder verbrauchter Gegenstand behält einen entfernten Eintrag in
`objects`, damit die Ursprungsszene ihn nicht erneut erzeugt. Beim Ablegen wird
derselbe Eintrag wieder aktiv. Normale Inventargegenstände ohne Welt-ID bleiben
stapelbar; Überläufe und Entnahmen werden über mehrere Stapel verteilt.

Vor einem Levelwechsel erfasst `WorldSceneState` Positionen, nach dem Laden
stellt es sie und aktive abgelegte Gegenstände wieder her. Ein ungültiges Ziel
wird vor dem Abbau des bisherigen Levels abgelehnt. Während Kampf oder
Eingabesperre findet kein Levelwechsel statt.

## Speichervertrag Version 8

`LevelManager.instance.save_world(path)` erfasst den Zustand im freien Gameplay
und schreibt JSON. Während Kampf/Dialog/anderer Eingabesperre liefert es
`ERR_BUSY`. Erst eine vollständig geschriebene und wieder eingelesene temporäre
Datei ersetzt den bisherigen Stand. Dies ist kein Garantieversprechen gegen
Stromausfall des Dateisystems.

`WorldSaveStore.new().read(path)` liefert einen unabhängigen, geprüften
WorldState oder `null`; `last_error` erläutert den Fehler. Unbekannte Versionen,
Resourceklassen, falsche Datentypen, ungültige Stapel und widersprüchlicher Besitz
werden abgelehnt. Resourceklassen sind ausdrücklich freigegeben; es werden keine
frei benannten Scripts aus dem Spielstand ausgeführt. Vorlagenpfade müssen auf
die Charaktervorlagen des Projekts verweisen. 0/0-Punkte werden nicht neu befüllt.

Der gemeinsame Einstieg für das Hauptmenü und freies Gameplay ist
`await GameState.load_game(path)`. Er liefert `OK` oder einen Fehlercode;
`GameState.last_load_error` enthält die Erklärung. Nur nach Erfolg wird
`GameState.game_loaded` gesendet. Ein parallel laufender Aufruf liefert `ERR_BUSY`
und verändert den Fehlerstatus des ersten Aufrufs nicht.

Der Koordinator prüft Datei, aktive Welt, Party und Leveltyp vor dem Austausch.
Am nächsten Frame-Rand prüft er erneut die aktuelle Szene und die Sperren.
Die alte Szene bleibt während des synchronen Neuaufbaus außerhalb des Baums
erhalten. Erst nach Prüfung von Level, Party, Charakterbindungen und Kamera wird
sie freigegeben. Bei einem erkennbaren Aufbaufehler werden dieselben alten Nodes,
der bisherige WorldState und die aktuelle Kamera wieder eingesetzt. Das schützt
vor den geprüften Fehlerfällen, nicht vor beliebigen Script-Nebeneffekten oder
einem Engine-Absturz. Level-Einstiege dürfen keine externen Aktionen auslösen.

Kampf, pausierter Szenenbaum und Eingabesperren verhindern das Laden. Eine spätere
Ladeoberfläche muss ihre eigene Sperre vor dem Aufruf freigeben; fremde Sperren
werden nicht aufgehoben. Da bei Erfolg die aufrufende Szene freigegeben wird,
sollte sie keinen notwendigen Code nach dem `await` besitzen. Der Autoload führt
den Ablauf unabhängig von diesem Aufrufer zu Ende. Isolierte Daten-Snapshots ohne
aktive Welt bleiben mit `WorldSaveStore.read` lesbar, sind aber keine ladbaren
Spielsitzungen. `install_world` bleibt eine niedrige Daten-API für Tests/Bootstrap.
Das aktuelle Speicherformat ist Version 8; siehe Kartenabschnitt.

`test_world_loader.tscn` prüft Datei-/Versionsfehler, Sperren, parallele Aufrufe,
Änderungen während der Vorbereitung, Rückkehr nach Aufbaufehler, Werte/Positionen,
Ereignishistorie, Systembindungen sowie Laden aus Spiel und Hauptmenü.

Der Hauptmenüknopf für ein neues Spiel setzt weiterhin alles zurück.

### Manuelle Speicherplätze und Oberfläche

Im Spielmenü öffnet **Speichern / Laden** die gemeinsame Oberfläche; im Hauptmenü
steht **Spiel laden** bereit. **Neu speichern** erzeugt immer eine neue Datei
unter `user://saves/`. Eine feste Slot-Anzahl gibt es nicht; die praktische Grenze
setzen verfügbarer Speicherplatz und Dateisystem. Gleiche Namen überschreiben
keinen früheren Spielstand. Leere Namen werden zu „Spielstand“, Pfadzeichen werden
ersetzt und Dateititel auf 80 UTF-8-Bytes begrenzt.

`save_catalog.gd` vergibt zufällige Datei-IDs und liest für die Übersicht nur
Dateinamen und Änderungszeiten, nicht sämtliche Weltdaten. Die Liste ist nach
Änderungszeit absteigend sortiert (bei Gleichstand nach Dateipfad), zeigt Zeiten
in UTC und unterstützt Suche über alle Einträge sowie Seiten zu je 50 Einträgen.
Unfertige `.tmp`-Dateien erscheinen nicht. Die vollständige Validierung findet
erst beim Laden des gewählten Spielstands statt; auch ein beschädigter Eintrag
lässt sich dadurch mit einer verständlichen Fehlermeldung behandeln.

Die Oberfläche gibt vor Speichern/Laden nur ihre eigene Eingabesperre frei und
stellt diese bei Fehlern wieder her. Laden im Spiel erfordert einen zweiten
Bestätigungsklick wegen ungespeicherten Fortschritts. Die Menüinstanz darf beim
erfolgreichen Laden verschwinden; der Autoload führt den Austausch zu Ende.
`test_save_menu.tscn` prüft diese Abläufe einschließlich beider Menüeinstiege,
getrennter gleichnamiger Slots, großer Listen, Suche und Schreibfehlern.

Automatisches Speichern sowie Überschreiben, Umbenennen und Löschen über die
Oberfläche sind nicht Bestandteil dieses Schritts. Bestehende Speicherdateien
bleiben erhalten. Das aktuelle Speicherformat ist Version 8; siehe Kartenabschnitt.

## Bewusste Grenzen

Dies ist ein erster Speichervertrag, kein vollständiger Spielstand für das gesamte
Spiel. UI, laufende Dialoge, Kampfzustand,
Physikgeschwindigkeiten und Simulationszeit sind nicht enthalten. Händlerangebote
und Bestände werden ab Version 4 gespeichert. Figuren werden weiterhin von den
vorhandenen Szenen erzeugt; ortsübergreifendes NPC-Spawning und persistente
Entfernung getöteter Figuren sind noch offen. Positionen gelten für die vorhandenen
Figuren am jeweiligen Ort. Weitere fest platzierte Weltobjekte brauchen explizite,
projektweit eindeutige IDs; automatisch vergebene IDs sind nur für dynamische Drops.

Ein erstes persistentes Ereignisprotokoll ist angebunden; automatische Queststeuerung ist noch offen. Conditions/Effects sind
für Faktenwissen, boolesche Flags und Gold als erster Teilumfang angebunden. Phase 02 ist daher noch nicht vollständig abgeschlossen.
Die Resourcefelder gehören zu Version 7; Schemaänderungen erfordern eine explizite
Versionsmigration. Version 1 wird ausdrücklich mit leeren Fakten- und Wissensbereichen migriert;
vorhandene Charakter- und Weltdaten bleiben erhalten. Fehlende Wissensbereiche in
Version 2 bis 7 werden als beschädigte Daten abgelehnt. Version 1/2 ergänzen das
neue Charakterfeld `is_defeated` zunächst mit false; vorhandene NPC-Sieg-Flags
werden beim Szenenaufbau übernommen. Version 3 bis 7 verlangen das Feld ausdrücklich.
Version 1 bis 3 beginnen ohne gespeicherte Händlerdaten; ShopManager ergänzt
diese beim Szenenaufbau aus den Vorlagen. Ab Version 4 ist der Bereich `shops` verpflichtend. Version 1 bis 4 erhalten
ein leeres Ereignisprotokoll; Ab Version 5 ist `events` verpflichtend. Ab Version 6 ist `quest_states` verpflichtend;
Versionen 1–5 leiten den Banditenquestzustand aus ihren bisherigen Flags ab.
Andere Versionen werden abgelehnt.

## Verifikation

Mit Godot 4.7 im Projektverzeichnis:

```sh
Godot --headless --path . res://src/debug/tools/test_world_state.tscn
Godot --headless --path . res://src/debug/tools/test_character_registry.tscn
Godot --headless --path . -s res://src/debug/tools/test_dialogue_camera.gd
```

Die WorldState-Tests durchlaufen echte Levelwechsel, Übergabe, Ablegen, JSON-Rundlauf,
Neuaufbau einer Welt, 0/0-Werte, Neustartbereinigung und beschädigte Dateien.
Die Testdateien liegen unter `/tmp/necota-world-test.json` und Nebenpfaden.

## Strukturierte Fakten und individuelles Wissen

`define_fact(id, subject, predicate, object)` definiert eine unveränderliche Aussage
unter einer stabilen ID. Identische Definitionen sind idempotent, widersprüchliche
Definitionen werden abgelehnt. Die drei Bestandteile sind nicht leere semantische
IDs; sie können auch noch nicht instanziierte Figuren oder Gegenstände benennen.
Die Existenz dieser referenzierten Entitäten wird daher noch nicht geprüft.

```gdscript
var world := GameState.world_state
world.define_fact("bandit_stole_key", "bandit_01", "stole", "key_01")
GameState.learn_fact("dannerman", "bandit_stole_key")
var knows := GameState.knows_fact("dannerman", "bandit_stole_key")
GameState.forget_fact("dannerman", "bandit_stole_key")
```

Wissen kann nur registrierten Charakteren über eine vorhandene Fakt-ID zugeordnet
werden. Eine Faktdefinition macht die Aussage nicht allen Figuren bekannt.
Vergessen entfernt lediglich die Zuordnung. Abfragen und Speicher-Snapshots liefern
Kopien; ein ungültiger Wissensimport verändert den bisherigen Stand nicht.

Die GameState-Methoden sind auch für den bestehenden Dialogue Manager erreichbar.
Elaras Banditendialog nutzt jetzt die gemeinsame Rules-API: Die Annahme des
Auftrags vermittelt der sprechenden Figur den Aufenthaltsort des Banditen. Bei
erneuten Gesprächen erscheint eine Erinnerungszeile. Ablehnung vermittelt kein
Wissen; Queststart und einmalige Goldbelohnung laufen ebenfalls über die Rules-API. Wahrheit, Gerüchte, Quellen und verschachtelte
Aussagen wie „A weiß, dass B etwas weiß“ werden noch nicht modelliert.

## Erster Conditions/Effects-Vertrag

`world_rules.gd` arbeitet unabhängig von Szenen mit einem übergebenen WorldState.
`GameState.meets_condition(dictionary)` und `GameState.apply_effects(array)` sind
Adapter für den Dialogue Manager. Die Dialogdatei enthält die Datendefinitionen;
es gibt keine besondere Banditenlogik im Rules-Service.

- Condition `knows_fact`: `character_id`, `fact_id`.
- Effect `define_fact`: `fact_id`, `subject`, `predicate`, `object`.
- Effects `learn_fact` und `forget_fact`: `character_id`, `fact_id`.

Jede Definition enthält zusätzlich `type`. Unbekannte Operationen, zusätzliche oder
fehlende Felder und ungültige Referenzen werden abgelehnt. Conditions verändern
nichts. Eine Effektfolge arbeitet auf einer isolierten Wissenskopie und übernimmt
sie erst, wenn alle Operationen erfolgreich sind. Flags und Gold werden ebenfalls
vorbereitet und erst danach übernommen; die registrierten Charakterresources
behalten ihre Identität. Wiederholtes Lernen und Vergessen
ist idempotent. Fehler werden als `false` zurückgegeben; Aufrufer außerhalb des
Dialogscripts müssen diesen Rückgabewert berücksichtigen.

Der bestehende Dialog verwendet eine geprüfte, konstante Effektdefinition. Der
Wissenseffekt wird unmittelbar vor Ausgabe der Hinweiszeile ausgeführt. Eine
Dialogunterbrechung setzt bereits gehörtes Wissen nicht zurück. Das ist keine
Transaktion über ein vollständiges Gespräch; Queststart wird zusammen mit dem Hinweiswissen übernommen.
Es gibt noch keine allgemeinen logischen Kombinationen, Attributbedingungen,
Kampfeffekte und keine automatische Flagmigration.
Die Regeln benötigen keine zusätzlichen Speicherfelder; der aktuelle Vertrag ist Version 7.

```sh
Godot --headless --path . res://src/debug/tools/test_world_rules.tscn
```

Dieser Test prüft Fehleratomarität und durchläuft den importierten Produktionsdialog
mit dem echten Dialogue Manager, einschließlich beider Antworten, individueller
Wissensprüfung, Speicher-/Laderundlauf und Neustart.

### Geschützter Questabschluss

- Condition `flag_equals`: `key`, boolescher `value`; fehlende Flags gelten als false.
- Effect `set_flag`: `key`, boolescher `value`.
- Effect `change_gold`: `character_id`, ganzzahliger `amount`; Ergebnis 0 bis
  2.147.483.647. Unterdeckung und Überlauf werden ohne Änderungen abgelehnt.
- `apply_effects_if(conditions, effects)` prüft alle Bedingungen und führt die
  Effektfolge synchron aus. Eine falsche oder ungültige Bedingung verhindert sie.

Elaras Abschlussdialog prüft `defeated_bandit == true` und
`quest_bandit_done == false`, vergibt 20 Gold an die sprechende Figur und setzt
zugleich das Abschlussflag. Dies geschieht vor der Belohnungszeile, sodass auch
Abbruch, direkter Cue-Aufruf und erneutes Laden keine zweite Auszahlung erlauben.
Der Queststart muss wie bisher nicht vorher angenommen worden sein.

Die Kampfniederlage ist über `CombatSession.participant_defeated` angebunden:
CombatManager ruft für den betroffenen NPC dessen `NPCInteraction.mark_defeated`
auf. Dessen konfiguriertes `NPCData.defeated_flag` wird über die Rules-API gesetzt.
Es gibt keine hartcodierte Banditen-ID im Kampfsystem. Flucht und das bloße Ende
einer Kampfseite setzen keine Niederlage-Flags. Eine einzelne bestätigte Niederlage
zählt auch dann, wenn weitere Teilnehmer noch kämpfen; Game Over und Loot bleiben offen.
Die Figuren werden dadurch weiterhin nicht dauerhaft aus ihrer Szene entfernt.

```sh
Godot --headless --path . res://src/debug/tools/test_combat_quest.tscn
```

Der Integrationstest startet MainGame, prüft Flucht ohne Sieg-Flag und führt eine
entscheidende Schadensaktion über den echten CombatResolver aus. Die resultierende
Niederlage läuft durch CombatSession und CombatManager bis zur NPC-Interaktion.
Danach werden der echte Dialogeinstieg, einmalige Auszahlung, Speicherung und
Neustartbereinigung geprüft. Die Aktion ist für den Test deterministisch gewählt;
eine manuelle Bedienung aller Kampfzüge ist damit nicht abgedeckt.

## Persistente NPC-Niederlage

`CharacterResource.is_defeated` ist der autoritative Niederlagenzustand. Er ist
unabhängig von Tod und Lebenspunkten; Heilung allein macht einen besiegten NPC
nicht wieder kampffähig. NPCInteraction setzt das Feld bei bestätigter Niederlage
auch bei Figuren ohne eigenes Quest-Flag. Bestehende Sieg-Flags bleiben für Dialoge
kompatibel und werden beim NPC-Szenenaufbau mit dem Zustand abgeglichen.

Besiegte Figuren bleiben sichtbar in ihrer vorhandenen Ruheanimation, bewegen sich
nicht eigenständig und sind weiter ansprechbar. Handel, Angriff und Diebstahl sind
sowohl im Aktionsangebot als auch beim direkten Aufruf gesperrt. Kampfstart,
Teilnehmeraufnahme und Rekrutierung von Umstehenden prüfen die Kampffähigkeit;
bereits vorgemerkte KI-Züge besiegter Teilnehmer werden verworfen.

Levelwechsel und Laden erhalten diesen Zustand. Ein neues Spiel erhält frische
Vorlagen ohne Niederlage. Wiederbelebung/Erholung, Todesdarstellung, Loot und die
Entfernung von Figuren sind ausdrücklich noch keine implementierten Spielregeln.
Die persistente Markierung wird derzeit für NPCs gesetzt; Party-Niederlagen und
Game Over brauchen einen eigenen Ablauf.

## Beziehungsbedingungen und -effekte

- `relationship_at_least`: `character_id` (Beobachter), `target_id`, ganzzahliges
  `minimum` von −10 bis +10. Die Grenze ist einschließlich. Beide Figuren müssen
  registriert sein; unbekannte Figuren erfüllen auch negative Schwellen nicht.
- `change_relationship`: `character_id`, `target_id`, ganzzahliges `amount`
  (−2.147.483.647 bis +2.147.483.647). Die resultierende Wertung wird auf −10 bis
  +10 begrenzt. Selbstbeziehungen dürfen nicht geändert werden.

Die bestehende RelationshipService-Abfrage bleibt maßgeblich: persönlicher Eintrag
vor stärkstem passenden Fraktionseintrag, sonst neutral. Eine Änderung ohne
persönlichen Eintrag startet beim wirksamen Fraktionswert und erzeugt einen
persönlichen Eintrag. Fraktionswerte und die Gegenrichtung bleiben unverändert.
Nulländerungen erzeugen keinen persönlichen Eintrag. Vorhandene Details bleiben
beim Aktualisieren erhalten. Mehrere Änderungen einer Folge werden der Reihe nach
berechnet; jede Änderung begrenzt ihr Ergebnis auf den gültigen Wertebereich.

Die Rules-API arbeitet zunächst auf Kopien der Beziehungseinträge. Erst wenn alle
Effekte gültig sind, übernimmt sie Beziehungen zusammen mit Wissen, Flags und Gold.
`sheet_changed` wird für betroffene Beobachter nach der vollständigen Übernahme
ausgelöst. Charakteridentitäten bleiben erhalten. RelationshipEntry-Referenzen
können ersetzt werden; Verbraucher müssen Beziehungen aus dem Charakterblatt lesen.
Die Array-Reihenfolge und damit bestehende Vorrangregeln bleiben erhalten.

Elaras einmaliger Banditen-Questabschluss erhöht ihre Sympathie für die belohnte
Figur um 1. Ab wirksamer Sympathie 1 verwendet sie eine zusätzliche freundliche
Begrüßung. Die Gegenrichtung wird nicht verändert. Bereits abgeschlossene Quests
alter Spielstände erhalten keinen rückwirkenden Bonus. Da das bestehende
Beziehungssystem auch Kampfseiten beeinflusst, gilt die geänderte Sympathie dort
ebenfalls; es gibt keine getrennte Dialog-Sympathie.

Beziehungen erfordern kein neues Speicherfeld: Sie werden bereits als
CharacterResource-Daten gespeichert. Die Regeltests prüfen Richtung,
Fraktionsfallback, persönliche Vorrangregel, Grenzen, Fehleratomarität und den
Produktionsdialog einschließlich Laden und Schutz vor mehrfacher Belohnung.

## Inventarbedingungen und sichere Übergaben

`has_item` prüft Rucksackbestand: `character_id`, `count` und genau eine Auswahl
über `item_id` oder `world_object_id`. `item_id` zählt nur gewöhnliche Stapel ohne
Welt-ID. Eindeutige Weltinstanzen werden ausschließlich über `world_object_id`
ausgewählt. Ausrüstung wird nicht mitgezählt und muss vorher abgelegt werden.

- `transfer_item`: dieselben Felder plus `target_id`; übergibt vorhandene Einheiten
  aus dem Rucksack des Absenders in den Rucksack des Empfängers.
- `remove_item`: dieselben Felder wie `has_item`; entzieht vorhandene Einheiten.
- Jede Definition enthält `type`. Mengen sind ganzzahlig von 1 bis 10.000;
  Weltinstanzen verlangen genau 1. Selbsttransfers, unbekannte Figuren, Unterbestand,
  mehrdeutige Auswahlen und widersprüchlicher Besitz werden abgelehnt.

Die bestehende PartyTradeUI verwendet `transfer_item`. Der WorldState-Test übergibt
über dieses echte Fenster den aufgenommenen Heiltrank und prüft seinen Besitzer
nach Levelwechsel und Speichern/Laden. Shop und Diebstahl verwenden ebenfalls
den gemeinsamen Transfereffekt (siehe unten).

Effekte berechnen Slotänderungen auf isolierten Kopien. Mehrere Effekte sehen den
zuvor vorbereiteten Bestand. Traglast wird einschließlich Ausrüstung für jeden
Transfer geprüft. Erst nach erfolgreicher Prüfung der gesamten Folge werden alle
Rucksäcke zusammen mit den übrigen Effektbereichen übernommen und Inventarsignale
versendet. Fehler lassen Originalslots und Mengen unverändert. Inventaridentitäten
und vorhandene Signalanbindungen bleiben erhalten; Slotreferenzen werden bei Erfolg
ersetzt. Abgelegte/verbrauchte eindeutige Weltobjekte behalten ihren entfernten
Welteintrag und erscheinen dadurch nicht erneut am Ursprungsort.

Es gibt noch keinen Effekt zum Erzeugen neuer Gegenstände aus Vorlagen oder zum
unbemerkten Entziehen von Ausrüstung. `transfer_item` übergibt ausschließlich
existierenden Besitz. Wiederholbarkeit muss bei Questbelohnungen weiterhin durch
Bedingungen und Abschlussflags abgesichert werden. Der aktuelle Speichervertrag ist Version 7.

## Diebstahl über die Inventar-API

StealUI übergibt bei Erfolg genau eine Einheit mit `transfer_item`, einschließlich
Weltinstanz-ID. Eine Vorprüfung auf Arbeitskopien prüft die Übergabe vor dem
Erfolgswurf. Fehlender Bestand, veraltete Listeneinträge, unregistrierte Figuren,
Übergewicht oder widersprüchlicher Besitz verändern nichts und verursachen keinen
Entdeckungskampf. Erst nach erfolgreicher Übernahme wird Erfolg protokolliert.

Die vorhandene StealResolver-Wahrscheinlichkeit bleibt unverändert. Ein misslungener
Wurf überträgt nichts, schließt das Fenster, löst dessen Eingabesperre und startet
wie bisher einen Kampf mit dem Opfer als Angreifer. Besiegte/nicht kampffähige
Figuren und Selbst-Diebstahl sind ausgeschlossen. Erneutes Öffnen eines bereits
sichtbaren Fensters erzeugt keine zusätzliche Sperre. Ausrüstung ist weiterhin
nicht Teil des Diebstahlangebots.

```sh
Godot --headless --path . res://src/debug/tools/test_steal_rules.tscn
```

Der Test verwendet das echte Fenster und StealManager in MainGame, überschreibt
nur den Würfelaufruf für deterministischen Erfolg/Entdeckung und prüft Mengen,
Weltbesitz, Speicherung, fehlerhafte Übergaben, Sperren und Kampfstart. Die
Zufallsverteilung selbst und eine manuelle UI-Bedienung werden damit nicht getestet.

## Händlertransaktionen und gespeicherte Bestände

WorldState besitzt jetzt `shops` als Dictionary von ShopData-Laufzeitkopien.
ShopManager zeigt dieselben Instanzen und ergänzt nur fehlende Händler aus den
Vorlagen. Levelwechsel und Laden erhalten die gespeicherten Angebote; ein neues
Spiel verwirft sie. ShopData und ShopEntry sind im Resource-Codec ausdrücklich
freigegeben. Ungültige Preise, Bestände, doppelte Item-IDs und Weltinstanzen in
Händlerangeboten werden beim Lesen und Schreiben abgelehnt.

`shop_buy` verwendet `character_id`, `shop_id`, `item_id`, `count: 1`.
`shop_sell` verwendet dieselben Felder oder statt `item_id` eine `world_object_id`.
Wie bisher verarbeitet ein Klick eine Einheit. Preise stammen aus dem Händlerangebot;
für nicht gelistete Gegenstände gilt weiterhin `max(1, int(weight * 10))` als
Verkaufspreis. Negative Preise und Goldüberlauf sind Fehler. Bestand −1 bedeutet
unbegrenzt, 0 ausverkauft. Verkaufsgegenstände verschwinden aus dem Rucksack;
sie werden nicht in das Angebot aufgenommen und füllen keine Bestände auf.

Shop-Effekte nutzen dieselben Inventar- und Gold-Arbeitskopien wie andere Regeln,
zusätzlich vorbereitete Bestände. Bei einem Fehler in irgendeinem Effekt bleibt
der gesamte ursprüngliche Zustand erhalten. Inventarsignale werden erst nach
Übernahme von Gold, Inventar und Händlerbestand ausgelöst. Mehrere Käufe in einer
Folge berücksichtigen bereits reservierte Mengen. Gegenstandsvorlagen werden beim
Kauf kopiert; eindeutige verkaufte Weltgegenstände bleiben als entfernt markiert.

Version 4 speichert die vollständigen ShopData-Angebote einschließlich Preise und
Itemdefinitionen. Bestehende Spielstände übernehmen deshalb spätere Änderungen der
Angebotsvorlagen nicht automatisch; dafür wäre eine gezielte Inhaltsmigration nötig.
Alte Spielstände ohne Händlerdaten starten wie zuvor mit Vorlagenbeständen.

```sh
Godot --headless --path . res://src/debug/tools/test_shop_rules.tscn
```

Die Tests prüfen das echte Shopfenster, begrenzte/unbegrenzte Bestände, Preis- und
Traglastfehler, Rücknahme ganzer Effektfolgen, Verkauf eindeutiger Weltobjekte,
Signalreihenfolge, Speicherfehler, Migration, Laden und Neustart.

## Persistente Weltereignisse (Speicherformat 5)

`WorldState.events.snapshot()` liefert eine tiefe Kopie der Historie. Ein Eintrag
enthält `id` (`event_1`, …), eine fortlaufende `sequence`, `type` und typisierte
`data`. IDs sind innerhalb einer Spielsitzung eindeutig und werden nach Laden
fortgesetzt. Ein neues Spiel startet eine neue Reihenfolge. Es gibt keine Echtzeit-
oder Simulationszeitstempel, da noch keine verbindliche Simulationsuhr existiert.

Erfasste Typen: `npc_defeated`, `quest_completed`, `item_transferred`,
`item_stolen`, `item_removed`, `item_bought`, `item_sold`. Die Nutzdaten enthalten
je nach Typ Charakter, Zielcharakter, Shop oder Quest, Menge und entweder Itemtyp-
oder Weltinstanz-ID. Bei Diebstahl bezeichnet `character_id` den Dieb und
`target_id` das Opfer; beim Transfer Absender und Empfänger. Niederlagen nennen
nur den besiegten NPC, keinen vermuteten Verursacher.

Effektfolgen sammeln Einträge auf Arbeitsdaten und übernehmen sie vor den
Inventar-/Charaktersignalen, erst nach erfolgreicher Prüfung der gesamten Folge.
Fehler erzeugen keine Historie. Wiederholte echte Transfers erzeugen eigene
Ereignisse. NPC-Niederlagen werden am bestätigten Kampfsignal einmalig erfasst;
Szenenaufbau und Flagmigration erzeugen keine nachträglichen Niederlagenereignisse.
Direkte Legacy-Mutationen (z.B. `add_item`) protokollieren nicht automatisch.

`complete_quest` nimmt `quest_id`, `character_id` und das kompatible Abschluss-
`flag`. Es setzt Flag und Ereignis gemeinsam und verhindert wiederholten Abschluss
über Flag oder Historie. Elaras Belohnungsfolge verwendet diesen Effekt.
`event_occurred` nimmt `event_type` und ein `filters`-Dictionary mit exakten
Nutzdatenwerten. Elaras wiederholter Abschlussdialog prüft damit, ob die Belohnung
bereits erfolgt ist. Vorhandene Quest-Flags bleiben für ältere Spielstände gültig.

Historie beschreibt Vergangenes; Inventar, Charakterdaten und Flags bleiben die
Quelle für den aktuellen Zustand. Beim Laden werden nur Daten validiert und
wiederhergestellt, keine Effekte oder Ereignissignale abgespielt. Versionen 1–4
starten ohne erfundene Historie. Unbekannte Typen, beschädigte Nutzdaten, doppelte
IDs oder unterbrochene Reihenfolgen werden abgelehnt. Die Historie wird nicht
beschnitten; die bestehende Dateigrößengrenze von 8 MiB gilt weiterhin. Archivierung
und Indizierung sind spätere Erweiterungen.

```sh
Godot --headless --path . res://src/debug/tools/test_world_events.tscn
```

Zusätzlich prüfen Kampf-, Dialog-, Diebstahl- und Händlertests die angeschlossenen
Produzenten und Verbraucher. Der EventLog für sichtbare Textmeldungen bleibt
getrennt bestehen; er ist kein persistenter Datenspeicher.

## Erster vereinheitlichter Questablauf (Speicherformat 6)

Die Banditenquest besitzt unter `WorldState.quest_states["bandit"]` einen expliziten
Zustand. `get_quest_state("bandit")` liefert `not_started`, `active`, `ready` oder
`completed`. Unbekannte Quest-IDs liefern einen leeren String.

Erlaubte Übergänge:

- `not_started` → `active`: `start_quest` mit `quest_id: "bandit"`.
- `not_started` oder `active` → `ready`: bestätigte Banditenniederlage über die
  vorhandene Sieg-Flag-Anbindung. Sieg vor Auftragsannahme bleibt erlaubt.
- `ready` → `completed`: `complete_quest` innerhalb der Belohnungstransaktion.

Wiederholte Annahme ist vor Abschluss idempotent; späte Annahme setzt `ready` nicht
zurück. Nach Abschluss sind Annahme und erneute Belohnung gesperrt. Bedingungen
verwenden `quest_state` mit `quest_id` und `state`. Dialogeinstieg und Auszahlung
prüfen jetzt diesen Zustand. Ein abgeschlossener Auftrag wird nicht erneut angeboten.
Gold, Beziehung, Abschlussflag und Ereignis werden weiterhin gemeinsam übernommen.

`quest_bandit_started`, `defeated_bandit` und `quest_bandit_done` bleiben als
Kompatibilitätsfelder erhalten. Alte Schreiber über `GameState.set_flag` bzw. den
`set_flag`-Effekt aktualisieren den expliziten Zustand monoton. Zurücksetzen eines
Flags setzt den Questfortschritt nicht zurück; nur Sitzungsneustart tut dies.
Direkte Schreibzugriffe auf `world.flags` umgehen diese Brücke und sind für diese
Flags nicht vorgesehen. Beim Laden von Version 6 werden Widersprüche abgelehnt.

Migration aus Versionen 1–5: Abschluss hat Vorrang vor Sieg, Sieg vor Annahme,
sonst `not_started`. Die Migration vergibt keine Belohnung und erzeugt keine
Ereignisse. `quest_states` und Flags sind nach Migration konsistent.

Dies ist die erste migrierte Quest, kein universeller Questeditor. Fehlschlag,
Abbruch, Wiederholbarkeit und mehrere Ziele sind noch nicht modelliert. Andere
Quest-IDs des bisherigen `complete_quest`-Effekts behalten vorerst dessen alten
Flag-/Ereignisvertrag; sie besitzen noch keine explizite Zustandsmaschine.

```sh
Godot --headless --path . res://src/debug/tools/test_quest_progress.tscn
```

Die Tests prüfen Übergänge, Reihenfolgevarianten, fehlgeschlagene Effektfolgen,
Sperre nach Abschluss, Speicherung, alte Spielstände und Neustart. Die bisherigen
Kampf-/Dialogtests prüfen weiterhin den vollständigen angebundenen Banditenablauf.

## Partyprüfung und Speicherung (Speicherformat 7)

`Party.leader` und alle Begleiter sind `Player` mit umschaltbarer Steuerungsrolle.
`PartyFollower` legt nur die Startrolle fest; Shalka startet weiterhin als Begleiter.
Im Party-Menü verschieben die Pfeile beide Figuren. Platz 1 übernimmt die Steuerung,
der vorherige Anführer folgt ihm. Kamera, HUD, Inventar, Charakterbogen und
Interaktionsmenü verwenden die neue Rolle. Nodes, Weltpositionen und registrierte
Charakterresources werden beim Wechsel nicht ersetzt. Begleiter folgen weiterhin
direkt dem Anführer, keiner Kette.

`WorldState.party_state` speichert `leader_id` und die geordnete Liste `member_ids`,
mit dem Leader an erster Stelle. Vor Aufbau einer Spielwelt darf der Bereich leer
sein. Nach Aufbau der Welt ist eine explizite, gültige Besetzung verpflichtend.
Dannerman und Shalka sind als Anführer oder Begleiter zugelassen. Unbekannte oder
doppelte IDs, ein Anführer außerhalb von Platz 1 und nicht registrierte Mitglieder
werden beim Laden abgelehnt. Die Freigabe liegt in `party_state.gd`.

Während Kampf, Pause oder fremder Interaktionssperre ist das Neuordnen gesperrt.
Das Partyfenster sperrt selbst die Bewegung, nimmt beim Sortieren aber nur seine
eigene Sperre aus. Ein verstorbener Charakter kann nicht zum Anführer werden.
Rekrutierung und Entlassung über die Oberfläche sind weiterhin nicht implementiert.

Party stellt die gespeicherte aktive Besetzung vor dem HUD-/Kameraaufbau wieder
her und bindet vorhandene Follower an den Leader. Nicht aktive Figuren werden aus
dem Party-Szenenbaum entfernt; ihre registrierten Charakterdaten bleiben erhalten.
Die Registry ist somit kein Verzeichnis ausschließlich aktiver Partymitglieder.
Reihenfolgeänderungen aktualisieren den WorldState. Vor dem Speichern erfasst
LevelManager die tatsächlichen Figuren und prüft deren Identität und Zugehörigkeit;
eine ungültige Besetzung wird nicht gespeichert. Charakterwerte werden nicht
neu initialisiert. Session-Reset entfernt auch den Partyzustand.

Versionen 1–6 erhalten bei vorhandener Spielwelt die bisher fest eingebaute
Startparty Dannerman/Shalka; fehlen deren Charakterdaten, wird der Stand abgelehnt.
Snapshots ohne aktive Spielwelt behalten einen leeren Partybereich. Version 7
verlangt das Feld ausdrücklich. Das bestehende Datenformat bleibt erhalten;
Anführerwechsel benötigen keine zusätzlichen Felder. Das aktuelle Format bleibt 8.

```sh
Godot --headless --path . res://src/debug/tools/test_party_state.tscn
```

Geprüft werden echte MainGame-Aufbauten, Bindung von Follower/HUD/Kamera, 0/0-Werte,
Besetzung ohne Begleiter, Levelwechsel, Migration, beschädigte Daten, fehlgeschlagene
Schreibversuche und Neustart. `test_party_leader.tscn` prüft zusätzlich den echten
UI-Pfeil, Wechsel in beide Richtungen, exklusive Steuerung, Begleiterbewegung,
Kamera/HUD, Menübindung, Sperren, Kampfende, Levelwechsel und den vollständigen
Spielladevorgang mit Shalka als Anführer. `-- --visual` erzeugt bei aktivem Renderer
`/tmp/party-leader-preview.png`.

### Dialogkontext im tatsächlichen Gespräch

`DialogueSystem` übergibt den aktuellen Gesprächspartner ausdrücklich als
`{"player": player}` zusätzlich zu den bisherigen Zustandsobjekten. Ein Node
allein macht seine Eigenschaften verfügbar, erzeugt aber keinen Alias `player`.
`test_dialogue_context.tscn` startet über `NPCInteraction.perform_action("talk", …)`
den echten Balloon und prüft Questannahme, Wissensvergabe, Belohnung,
Wiederholungsschutz und Freigabe der Eingabesperre. Dadurch wird auch die
Kontextübergabe geprüft, die reine Dialogresource-Tests mit eigenem Kontext umgehen.

### Zusammenhängender Regressionstest

`res://src/debug/tools/test_gameplay_journey.tscn` führt eine ganze Sitzung aus:
Questannahme über NPC/DialogueSystem/Balloon, Kauf und Verkauf über ShopUI,
Übergabe eines eindeutigen Weltgegenstands über Rules, Diebstahl über StealUI,
Niederlage über CombatResolver/CombatSession, Belohnung über das Gespräch,
Level-Neuaufbau, SaveCatalog, GameState.load_game und Neustart über MainMenu.
Er vergleicht danach alle Charakterinventare, Geld, Besitzer, Händlerbestand,
Wissen, Quest und Ereignisse. Wiederholte Abgabe zahlt nichts zusätzlich aus;
Neustart stellt Ausgangswerte her und erhält die gespeicherte Datei.

Nur Testbudget, Diebstahlswurf und Schadensaktion sind deterministisch gesetzt.
Dies prüft Systemübergänge, nicht Kampfbalancing, räumliche Klickbedienung oder
visuelle Darstellung. Der Test baut seinen Ausgangslevel vollständig neu auf; echte Ortswechsel
zwischen beiden vorhandenen Leveln prüft zusätzlich `test_level_transitions.tscn`.

### Übergänge zwischen Level1Ep1 und MonsterLair-Level1

Beide `Levelwechseln/Ausgang`-Areas verwenden das gemeinsame `zugang.gd`.
Im Inspector werden `target_level` und `target_arrival` eingestellt. Der
Ankunftspfad ist relativ zum Root der Zielszene und zeigt hier auf
`Levelwechseln/Eingang/Eingangsshape`. Nur die Berührung durch den Party-Leader
löst den Wechsel aus; Begleiter und NPCs tun dies nicht. Nach Initialisierung
muss der Leader außerhalb eines Ausgangs gewesen sein, bevor dieser auslöst.
Das verhindert sofortige Wechsel beim Laden innerhalb einer Ausgangszone.

Der LevelManager führt den Wechsel verzögert nach der Kollisionsauswertung aus,
prüft Zielszene und Ankunftsknoten vor dem Abbau und respektiert Kampf, Pause
und Eingabesperren. Bei einem Übergang werden die Partymitglieder am Eingang
zusammengeführt; gespeicherte NPC-/Objektpositionen werden weiterhin restauriert.
Normales Laden ohne Ankunftspfad behält die gespeicherten Partypositionen.

Die Übergangszonen im Ausgangslevel liegen unabhängig vom Banditen unter dem
Levelroot, mit erhaltener Weltposition. Die Höhle implementiert `BaseLevel`.
Ihr Gegner `lair_bandit_01` und der Trank `lair1_potion_1` besitzen eigene IDs;
`defeated_lair_bandit` beeinflusst die bisherige Banditenquest nicht.
Die bisherigen Gegnerwerte und der generische Banditendialog dienen als Vorlage.

`test_level_transitions.tscn` prüft echte Physiküberlappungen, Hin-/Rückweg,
Partyidentität, Ankunft, getrennte Identitäten, Eingabe-/Kampfsperren, Speichern
und Laden im neuen Level und im Ausgang sowie Schutz bei fehlendem Zielpunkt.

Die beiden Ausgangs-Areas sind Instanzen von `src/world/transitions/level_exit.tscn`.
Der LevelManager blendet vor dem Wechsel aus, lässt unter Schwarz die Physik
weiterlaufen und blendet wieder ein. Einrichtung und Zeitparameter stehen in
[Levelübergänge](../../world/transitions/README.md).


## Persistente Kartenerkundung (Speicherformat 8)

`map_exploration` enthält je Level entdeckte Zellen und zuletzt beobachtete
NPC-/Objektmarkierungen. Versionen 1–7 erhalten bei der Migration eine leere Karte.
Version 8 verlangt gültige Kartendaten; Levelwechsel erhalten sie, ein neues Spiel
leert sie. Details und Grenzen: [Levelkarte](../../ui/map/README.md).
