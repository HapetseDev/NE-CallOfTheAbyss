# Spielefenster

Umsetzung vom 4. Oktober 2026 nach `NascentEternity-Design-Document.md`,
Abschnitt „Darstellung von Spielefenster“.

## Architektur und Verhalten

`MainGame` erzeugt `GameWindows` unter dem bestehenden `UI/MenuRoot`.
Die untere Spiel-Leiste behält den historischen Typnamen `TopBarHud` und
öffnet Party, Charakter, Inventar, Karte, Log, Menü und Debug in dieser Reihenfolge.
Die sieben Fenster sind zyklisch; jeweils drei angeschrägte Seitenkarten zeigen
die Nachbarfenster. Eine gemeinsame Mitte enthält die aktive Ansicht.
Seitenkarten zeigen die Fenstertitel, keine separaten Live-Renderings.

Die vorhandenen CharacterSheetUI-, InventoryUI- und MapUI-Szenen erhalten einen
expliziten eingebetteten Modus. Ihre Inhaltscontainer werden in die gemeinsame
Ansicht eingehängt, ihre ursprünglichen nativen Fenster und Overlays bleiben
verborgen. Bestehende Darstellungs- und Inventarfunktionen bleiben zuständig;
beim Seitenwechsel werden Views und Signalverbindungen bereinigt.

Partywahl verwendet `Party.move_member`: Platz 1 bestimmt den Anführer,
Kamera, Steuerungsrollen, HUD und gespeicherte Reihenfolge folgen dem vorhandenen
Vertrag. Kampf, fremde Eingabesperren und tote Anführer verhindern einen Wechsel.
Charakterblätter und Inventare sind ohne feste Mitgliedergrenze in der aktuellen
Partyreihenfolge vertikal angeordnet. Charakterblätter teilen einen Scrollbereich.
Inventarraster wachsen mit dem tatsächlichen Gepäck.

Gegenstände öffnen mit Bestätigung oder Rechtsklick ein Aktionsmenü für
Verwenden, Ausrüsten, Ablegen und Übergabe. Jede Übergabe verschiebt **ein Stück**
über `GameState.apply_effects(transfer_item)` und prüft Traglast und Besitzer.
Drag-Payloads enthalten die Quellansicht und den Gegenstand; andere Rucksäcke
nehmen Gegenstände auf, Ausrüstungsslots akzeptieren nur passende Gegenstände
aus demselben Inventar. Ausrüstung kann in den eigenen Rucksack gezogen werden.
Das Aktionsmenü prüft den Gegenstand erneut, falls sich das Inventar inzwischen
ändert. Der bestehende Paperdoll-Bereich mit Ausrüstungsslots wird weiterverwendet.

Die Übersicht zeigt Portrait, SP und KP in halbtransparenten Panels über den
Weltfiguren. Benachbarte Statuspanels weichen horizontal aus. Das halbtransparente
Log liegt oberhalb der Spiel-Leiste. `EventLog` hält bis zu 100 Zeilen für neu
geöffnete Logansichten vor; vorhandene Signalempfänger bleiben kompatibel.

## Bedienung

- Maus: Spiel-Leiste, Seitenkarten und Pfeile; Mausrad zum Scrollen;
  Drag-and-Drop zwischen Inventaren oder auf passende Ausrüstungsslots.
- Tastatur: Tab/Pfeiltasten für Fokus, Enter/Leertaste bestätigen, Escape schließen.
  Q/E wechseln das Fenster; I/C öffnen Inventar/Charakter. Ein fokussierter
  Scrollbereich lässt sich mit Auf/Ab bewegen.
- Controller: Steuerkreuz/linker Stick für den Standard-UI-Fokus,
  Bestätigen/Abbrechen über Godots UI-Aktionen; Schultertasten wechseln zyklisch,
  Start öffnet das Menü. Im fokussierten Scrollbereich bewegen Auf/Ab die Ansicht.
- Das Menü verlinkt die vorhandene Speicher-/Ladeoberfläche und Debug den
  vorhandenen Charaktereditor. Optionen bieten Lautstärke je Audiobus für die
  laufende Sitzung; eine persistente allgemeine Optionsverwaltung existiert noch nicht.

Die gemeinsame Oberfläche hält eine eigene `GameState`-Input-Lease und gibt nur
diese frei. Der Wechsel in Speichern/Laden oder Debug schließt zuerst die
Fensteroberfläche, bevor das bestehende Zielsystem seine Sperre übernimmt.
Die Fenster pausieren die Simulation nicht; sie sperren die Weltsteuerung wie
zuvor die jeweiligen Menüsysteme.

Das globale Theme setzt Button-Hover auf RGB +20% und Pressed auf RGB −20%
gegenüber dem normalen Button, bei unveränderter Geometrie und Alpha.
`UIAudio` liefert weiterhin Auswahl-, Bestätigungs- und Zurück-Sounds.

## Prüfungen

Godot 4.7 stable mono, vorhandene Installation. Tests unter `src/debug/tools/`:
`test_game_windows` (Navigation, Reihenfolge, Scrollsteuerung, Übergaben,
Traglastfehler, Drag-Absender, Controller-Seitenwechsel, Sperren),
`test_party_order_ui`, `test_party_leader`, `test_map_ui`, `test_save_menu`,
`test_character_registry`, `test_conversation_ui`, `test_ui_audio`,
`test_world_rules`, `test_world_loader` und `test_gameplay_journey` bestehen.
Bestehende UI-Tests wurden auf den gemeinsamen Fenstervertrag umgestellt.

`test_party_state` meldet auch im unveränderten Ausgangsprojekt einen Fehler:
„Laden erzeugt keinen ungewollten Begleiter“. Der Test zählt sämtliche Party-Kinder,
einschließlich des schon vorhandenen `OcclusionVisual`; kein neuer UI-Fehler.
Diese unabhängige Testannahme wurde nicht verändert.

Grafische Prüfung über `preview_game_windows.tscn` mit OpenGL Compatibility:
Übersicht, Party, Charakter, Inventar und Karte gerendert und geprüft.
Controller-Ereignisse wurden simuliert; kein physischer Controller wurde getestet.
Godot meldet in der Sandbox einen Zertifikatsspeicher-Hinweis und beim grafischen
Start die Konvertierung einer bestehenden BPTC-Textur. Kein Addon wurde geändert.
