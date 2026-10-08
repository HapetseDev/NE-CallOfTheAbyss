# Charakterregistrierung

`GameState.world_state.characters` besitzt die registrierten Charakterdaten einer
Spielsitzung. `GameState.character_registry` bleibt der kompatible Zugriff darauf. `CharacterRegistry` kann für Tests auch unabhängig instanziiert werden.
Alle sechs vorhandenen Charaktere sind migriert: `dannerman`, `shalka`,
`bandit_01`, `merchant_01`, `quest_giver_01` und `test_npc`. Ihre Vorlagen
enthalten feste IDs; das Laden einer Vorlage verändert diese nicht.

## Vertrag

- Eine stabile, nicht leere ID identifiziert einen Charakter, nicht seinen Namen.
  IDs sind nach der Registrierung unveränderlich; umgebende Leerzeichen werden
  abgelehnt, nicht stillschweigend entfernt.
- `register_character(id, template)` erstellt beim ersten Aufruf eine tiefe Kopie
  einschließlich verschachtelter und externer Resources und initialisiert diese.
  Die Vorlage bleibt unverändert, auch bei `resource_local_to_scene = true`.
- Eine leere Vorlagen-ID erlaubt verschiedene Instanz-IDs derselben Vorlage.
  Eine gesetzte Vorlagen-ID muss mit der angefragten ID übereinstimmen.
- Wiederholte Registrierung derselben ID mit derselben Vorlageninstanz liefert
  dieselben Laufzeitdaten, ohne erneut Punkte oder Inventar zu initialisieren.
- Eine andere Vorlage für eine belegte ID wird abgelehnt. Auch inhaltlich gleiche,
  separat erzeugte Vorlagen gelten als unterschiedlich: Änderungen werden nicht
  automatisch in laufende Charaktere übernommen.
- Bei Fehlern wird `null` zurückgegeben und `registration_rejected(id, reason)`
  gesendet. Aufrufer müssen den Rückgabewert prüfen. Ursachen: `invalid_id`,
  `missing_template`, `template_id_mismatch`, `conflicting_template`, `copy_failed`.
- `get_character(id)` liefert vorhandene Daten oder `null`, ohne Nebenwirkungen.
- `clear()` entfernt Daten und Vorlagenbindungen aus der Registrierung. Bereits
  herausgegebene Referenzen bleiben gültig: erst Weltfiguren/UI abbauen, dann an
  einer Sitzungsgrenze zurücksetzen. Niemals beim normalen Levelwechsel aufrufen.

## Verwendung

```gdscript
var template := load("res://src/resources/characters/sheets/bandit_01.tres") as CharacterResource
var character := GameState.character_registry.register_character("bandit_01", template)
if character == null:
    return
# Playable.bind_character(character) übernimmt registrierte Daten ohne Kopie.
```

Bei NPCs aktiviert `use_character_registry` die Registrierung über `NPCData.npc_id`
und eine explizite Charaktervorlage (`NPC.character` oder `NPCData.character`).
Fehlerhafte Registrierung entfernt die Weltfigur mit einer Fehlermeldung, statt
unbemerkt unabhängige Ersatzdaten anzulegen. `Playable` erkennt registrierte
Datensätze anhand ihrer Identität und kopiert/initialisiert sie nicht erneut.

`GameState.reset_session()` leert den gesamten WorldState und die Eingabesperren.
`MainGame` ruft dies beim Verlassen nach dem Abbau seiner Kinder auf; das
Hauptmenü setzt die Sitzung zusätzlich vor einem neuen Spiel zurück. Normale
Levelwechsel behalten die Daten. Der erste versionierte Speichervertrag ist unter `world/README.md` beschrieben.

Dannermans Startmesser liegt in seiner Vorlage und wird nicht bei leerem Inventar
erneut vergeben. ShopManager kopiert Shopdaten für jede Sitzung, damit der
Neustart auch Händlerbestände wiederherstellt. Beim Schließen eines Dialogfensters
wird dessen temporärer Kontext freigegeben; das Drittanbieter-Addon bleibt unverändert.
Die Registry verhindert Datenkonflikte, aber noch
nicht mehrere Weltfiguren, die auf denselben Datensatz zeigen.

## Tests

Vom Projektverzeichnis mit Godot 4.7 ausführen (auf macOS gegebenenfalls den
vollständigen Pfad zum Godot-Programm verwenden):

```sh
Godot --headless --path . res://src/debug/tools/test_character_registry.tscn
```

Die Tests starten als Szene, damit Projekt-Autoloads vor dem Testskript verfügbar
sind. Sie prüfen Identität, einmalige Initialisierung, Vorlagen- und
Instanzisolation, Inventarsignale, Konflikte, Reset und externe Item-Ressourcen.
Zusätzlich werden alle echten Charakterszenen entfernt und erneut erzeugt.
Punkte (einschließlich 0/0), Gold, Inventar, Skills und Beziehungen sowie die
Signalbindung werden geprüft. Integrationstests durchlaufen zwei Levelwechsel
und zwei echte Hauptmenü-Neustarts, einschließlich offener Handelsfenster und
eines Dialogs während eines Kampfes. Die Tests prüfen auch frische Startdaten,
Händlerbestände und die Bereinigung der Eingabesperren und Kampfflags.
Fehlgeschlagene Prüfungen führen zu Exit-Code 1.
