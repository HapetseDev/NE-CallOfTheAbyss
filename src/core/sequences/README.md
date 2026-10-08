# Sequence-Kern: erster Implementierungsschritt

Der Manager lebt unter `MainGame/Systems/SequenceManager`. Bestehende Systeme,
Addons und das Saveformat werden nicht ersetzt. Engine geprüft: Godot 4.7 Mono.

## Start und Demo

Spiel starten, **Debug** öffnen, **Sequence-Demo starten (2 Sekunden)** anklicken.
Das Debugfenster schließt; der Spieler ist zwei Sekunden gesperrt. Danach setzt
WorldRules `sequence_mvp_done=true` und gibt die eigene Sperre frei. Das Eventlog
meldet Start und Abschluss. Die Demo startet nicht automatisch und ist wiederholbar.

```gdscript
var start_result := MainGame.instance.sequence_manager.start(&"sequence_mvp")
if start_result.accepted:
    var run_id: String = start_result.run_id
    # manager.cancel(run_id), pause(run_id), resume(run_id)
```

Registrierung: `src/resources/sequences/sequence_catalog.tres`. Dieser Catalog
enthält erlaubte Sequencepfade, Startkarten und Bool-Flags. Scripts benutzen IDs,
keine beliebigen Methoden. Jeder Start wird frisch geparst, damit Textänderungen
sofort geprüft werden. Kompilierte Daten werden für den Runner kopiert.

## Implementierte DSL

```text
sequence sequence_mvp version=1 content_version=1 once=false
wait 2.0
set flag="sequence_mvp_done" value=true id=mark_demo
end code="demo_completed"
```

Alternativ `abort reason="..."`. Header optional: `map=chapter1_outskirts` und
`once=true`. Einmalige Completion wird vorläufig als reservierter Bool-Flag
`sequence_completed.<id>` in WorldState gespeichert; fehlgeschlagene/abgebrochene
Runs verbrauchen sie nicht. Der vorhandene Savevertrag speichert diese Flags
nach der Sequence. Die spätere History-/Continuation-Struktur ersetzt diese
schmale Übergangslösung mit einer expliziten Migration.

UTF-8/BOM, CRLF, Kommentare außerhalb von Strings und Escapes werden unterstützt.
Fehler tragen Pfad, Zeile, Spalte und Code. Unbekannte oder noch nicht
implementierte Commands werden vor dem Start abgelehnt. Pflichtparameter,
Typen, Catalog-Flags und eindeutige Effekt-IDs werden geprüft. EOF ohne end/abort
ist ein Fehler. wait liegt zwischen 0 und 3600 Sekunden; wait 0 yieldet einen Frame.

## Lebenszyklus und Grenzen

Ein Run pro Manager; Kampf, Pause, fremde Sperren und nicht bereite Welt ergeben
BUSY/UNAVAILABLE. Bindings sind noch nicht unterstützt. Der Runner läuft nur,
wenn der Szenenbaum nicht pausiert und sein eigener Pausezustand aus ist. Pause
und Cancel sind getrennt. Startsignals dürfen den Run synchron canceln; accepted
bedeutet Startannahme, nicht Completion. Handles speichern ihre einmaligen
Resultate vor dem Signal; sofortige Effekte können daher nicht im await hängen.

GameState-Leases ergänzen Legacy-Inputlocks. Ein Sequence-Abschluss löst nur
seinen eigenen Token. Cancel nach einem bereits ausgeführten Effekt rollt die
Welt nicht zurück. Markierungen pro Effekt sind nur innerhalb des Runs idempotent.
Keine Kampf-/Checkpoint-/Resume-Speicherung in diesem Schritt. Keine Kamera-,
Actor-, Bewegungs-, Dialog-, Parallel- oder Goto-Commands: diese folgen separat.

Das Exportplugin `addons/necota_sequences` nimmt rohe `.sequence`-Dateien unter
`src/resources/sequences/` in Exportpakete auf. Eigene Catalogpfade müssen in
diesem Contentordner liegen, solange nur dieser Exportvertrag implementiert ist.
Das Plugin ist in project.godot aktiviert; keine Änderungen an Drittanbieter-Code.

## Tests

`src/debug/tools/test_sequences.tscn` prüft Parserfehler, Strings/BOM/CRLF,
sofortige Handles, Start/Busy/Cancel/Pause, Fremdsperren, einmalige Completion,
Laufzeitfehler, globale Pause, Wiedereinsetzen nach einem Lade-Rollback,
MainGame-Abbau und WorldState-Flagpersistenz. Bestehende
WorldRules-/WorldLoader-/Level-/Dialogtests bleiben Regressionstests.

Zielspezifikation: `docs/NECOTA_SEQUENCE_SYSTEM.md`. Als nächstes Marker,
LiveActors und einen korrelierten Sequence-Dialogvertrag implementieren.
