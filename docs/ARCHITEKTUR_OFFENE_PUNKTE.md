# Architektur: offene Entscheidungen und nächste Schritte

Stand: 21. September 2026. Arbeitsnotiz für die weitere Zusammenarbeit.
Offene Entscheidungen sind keine bereits beschlossenen Spielregeln.

## Wiedereinstieg: Questabläufe erweitern

**Status:** Der erste Ablauf ist umgesetzt. Die Banditenquest kennt
`not_started`, `active`, `ready` und `completed`. Ein Sieg vor Auftragsannahme
ist erlaubt. Abschluss und Belohnung sind einmalig; alte Flags bleiben kompatibel.
Der aktuelle Speichervertrag ist Version 7. Weitere Questtypen warten auf Spielregeln und
eine konkrete Beispielquest, nicht auf eine technische Voraussetzung.

### Noch zu entscheiden

- [ ] **Abbruch:** Welche Quests darf man abbrechen? Kann man sie erneut annehmen?
  Bleiben Teilfortschritt und bereits erhaltene Gegenstände bestehen? Werden
  Questgegenstände entfernt oder zurückgegeben?
- [ ] **Fehlschlag:** Welche konkreten Ereignisse lösen ihn aus? Ist er endgültig,
  wiederholbar oder durch einen alternativen Lösungsweg vermeidbar?
- [ ] **Mehrere Ziele:** Welche Ziele müssen alle erfüllt sein, welche sind
  Alternativen? Gibt es eine Reihenfolge? Zählt bereits vor Annahme Erledigtes?
- [ ] **Wiederholbarkeit:** Welche Quests sind wiederholbar, unter welchen
  Voraussetzungen und mit welcher erneuten Belohnung? Was wird zurückgesetzt?
- [ ] **Weitere Beispielquest:** Eine konkrete Quest auswählen, an der die
  tatsächlich benötigten Erweiterungen implementiert und getestet werden.

### Ausfüllvorlage für die nächste Quest

- Name / kurze Beschreibung:
- Auftraggeber und Ort:
- Voraussetzungen für die Annahme:
- Ziele und erkennbare Erfüllungsereignisse:
- Reihenfolge / Alternativen / Fortschritt vor Annahme:
- Abgabeort und Abschlussbedingung:
- Belohnung und Empfänger (einzelne Figur oder Party):
- Questgegenstände und Umgang mit ihnen:
- Abbruchregel:
- Fehlschlagregel:
- Wiederholbarkeit:
- Benötigte Dialoge, NPCs und Gegenstände; bereits vorhanden oder neu anzulegen:

### Umsetzung nach Klärung

Nur die für diese Quest benötigten Zustände und Übergänge ergänzen. Vorhandene
WorldState-, Conditions/Effects-, Inventar-, Beziehungs- und Ereignis-APIs nutzen.
Alte Spielstände migrieren; keine nachträglichen Belohnungen oder erfundene
Ereignisse erzeugen. Erlaubte/verbotene Übergänge, Fehler ohne Teiländerungen,
Mehrfachaufrufe, Speichern/Laden und Neustart testen.

Zum Wiederaufgreifen genügt beispielsweise:
„Lass uns die offenen Questregeln in ARCHITEKTUR_OFFENE_PUNKTE.md klären.“

## Danach: Speichern und Laden vervollständigen

**Stand und empfohlene Reihenfolge; offene Folgeschritte noch nicht freigegeben:**

1. **Partyzustand geprüft und gespeichert (erledigt):** Speicherformat 7 erfasst
   aktive Mitglieder, Reihenfolge und den unterstützten Anführer. Dannerman bleibt
   der einzige steuerbare Leader; Shalka ist die vorhandene Begleiterin. Laden,
   HUD/Kamera, Migration und Neustart sind getestet. Rekrutierung, weitere Figuren
   und ein Führungswechsel brauchen eigene Regeln und passende Charakterrollen.
2. **Gemeinsamer sicherer Ladeablauf (erledigt):** `GameState.load_game(path)`
   prüft den Spielstand vor dem Szenentausch, baut die gespeicherte Welt auf und
   prüft die Bindungen. Datei-/Versionsfehler erhalten die laufende Sitzung;
   erkennbare Aufbaufehler stellen ihre bisherigen Nodes und Daten wieder her.
   Kampf, Pause, Interaktionen und paralleles Laden sind gesperrt. Der Einstieg
   aus Spiel und Hauptmenü sowie Rückkehr nach Fehlern sind getestet.
3. **Speicher-/Ladeoberfläche (erledigt):** Hauptmenü und Spielmenü verwenden
   dieselbe Oberfläche. Es gibt beliebig viele manuelle Speicherplätze unter
   `user://saves/`, begrenzt durch den Datenträger. Jeder Speichervorgang erzeugt
   eine neue Datei, auch bei gleichem Namen. Suche, Seitenansicht, Ladebestätigung
   und Fehlermeldungen sind eingebaut und getestet. Automatisches Speichern und
   nachträgliche Verwaltung (Löschen/Umbenennen/Überschreiben) bleiben separate
   Erweiterungen.
4. **Durchgehender Spielablauf automatisch geprüft (erledigt):**
   `test_gameplay_journey.tscn` kombiniert echte Questgespräche, Handel,
   Übergabe, erfolgreichen Diebstahl, Kampfniederlage, Questabschluss,
   Level-Neuaufbau, manuelles Speichern, sicheres Laden und neues Spiel.
   Geprüft werden Inventare, Gold, Besitz, Shopbestand, Wissen, Questzustand,
   Ereignishistorie und Wiederholungsschutz. Zufallserfolg und Kampfschaden
   werden für den Test kontrolliert. Der ursprüngliche Test baut seinen Ausgangslevel neu auf; zusätzlich
   prüft `test_level_transitions.tscn` echte Übergänge zwischen Level1Ep1 und
   MonsterLair-Level1, Ankunftspositionen, getrennte Gegner/Objekte sowie Laden
   im neuen Ort und innerhalb eines Ausgangs. Ein manueller Sicht-/Bedienungstest
   der Levelgeometrie bleibt offen.

Diese Arbeiten können unabhängig von zusätzlichen Questinhalten erfolgen.
Das vorhandene Format ist weiterhin kein vollständiger Simulationsspielstand:
laufende Kämpfe/Dialoge, UI-Zustände, Physikgeschwindigkeiten und eine
Simulationsuhr sind nicht enthalten.

## Weitere offene Spielregeln

- Erholung oder Wiederbelebung besiegter NPCs: Bedingungen und Zeitpunkt.
- Party-Niederlage: Konsequenzen, Fortsetzung oder Game Over.
- Rückkauf verkaufter Gegenstände: derzeit nicht vorgesehen; Verkäufe füllen
  Händlerangebote nicht auf.

## Technische Anlaufstellen

- [WorldState, Speichervertrag und Integrationen](src/core/world/README.md)
- [Erster Questablauf](src/core/world/quest_progress.gd)
- [Gemeinsame Regeln](src/core/world/world_rules.gd)
- [Banditenquest-Dialog](src/resources/dialogue/quest_giver.dialogue)
- [Questtests](src/debug/tools/test_quest_progress.gd)
- [Ursprünglicher Architekturentwurf](NECOTA%20Core%20Architecture%201.0)
