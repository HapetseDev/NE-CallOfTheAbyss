# NECOTA – Hinweise für KI-Agenten

Diese Regeln gelten für das gesamte Projekt. Diese Datei bleibt in der
Projektwurzel, damit Agenten sie vor Änderungen finden.

## Einstieg und Dokumentation

- Vor Änderungen den aktuellen Code, die betroffenen Dokumente und `git status`
  prüfen. Vorhandene Änderungen erhalten; nicht zurücksetzen oder überschreiben.
- Zentraler Zielordner für Dokumentation ist `doc/`. Während der laufenden
  Umorganisation liegen zentrale Dokumente noch in `docs/`. Den tatsächlich
  vorhandenen Ort verwenden; keinen zweiten Dokumentationsbestand anlegen.
- Bei verschobenen Dateien nach dem Dateinamen suchen. Fachliche READMEs unter
  `src/` weiterhin beachten, solange sie noch nicht zentral verschoben wurden.
- Zuerst die zur Aufgabe passenden Dokumente lesen, nicht den gesamten Bestand:
  - `DOKUMENTATION.md`: technische Übersicht und Verwendung.
  - `ARCHITEKTUR_OFFENE_PUNKTE.md`: offene Regeln und bekannte Grenzen.
  - `NascentEternity-Design-Document.md`: Spielkonzept und Designabsicht.
  - `NECOTA_SEQUENCE_SYSTEM.md`: Sequence-Zielarchitektur und Umsetzungsphasen.
- Implementierten Stand von Planungen unterscheiden. Tatsächliche APIs und
  Ressourcen vor Verwendung im Code prüfen; Abweichungen dokumentieren.
- Neue zentrale Dokumentation unter `doc/` ablegen, sobald dieser Ordner die
  Umorganisation übernimmt; bis dahin den vorhandenen Ordner `docs/` verwenden.
- Bei Dokumentverschiebungen relative Links und Verweise einschließlich dieser
  Datei aktualisieren. Keine Dokumente ohne Aufgabenbezug umorganisieren.

## Architektur und Änderungen

- Das Spiel verwendet eine 3D-Welt mit 2.5D-Darstellung. Aus dem Projektnamen
  `NECOTA2D` keine 2D-Physik oder 2D-Bewegungsarchitektur ableiten.
- Vorhandene Systeme erweitern und orchestrieren, statt parallele Ersatzsysteme
  einzuführen. Die bestehende Ordnerstruktur unter `src/` beibehalten.
- `MainGame` ist der Spielanker. Spielsysteme leben unter `MainGame/Systems`;
  Level unter `World/LevelRoot`, die Party unter `World/EntityRoot`.
- `GameState.world_state` ist der autoritative Weltzustand. Charakterdaten über
  `CharacterRegistry` und stabile Character-IDs verwenden; Resource-Daten und
  lebende Actor-Nodes unterscheiden. Keine unkontrollierten Laufzeitduplikate.
- Conditions und persistente Effekte über die vorhandenen GameState-/WorldRules-
  Verträge führen. Wissen ist figurenspezifisch; Questübergänge bleiben geprüft.
- Kämpfe laufen über CombatManager/CombatSession in der normalen Spielwelt.
  CameraSystem besitzt die Weltkamera; DialogueSystem integriert Dialogue Manager.
- SequenceManager orchestriert diese Systeme. Nur tatsächlich implementierte
  DSL-Fähigkeiten verwenden; weitere Phasen separat und prüfbar ergänzen.
- Eingabesperren nur für den eigenen Besitzer freigeben. Abbruch, Fehler und
  Szenenabbau müssen eigene Handles, Signals und temporäre Zustände bereinigen.
- Bei Save-Schemaänderungen Writer, Reader, Validierung und Migration gemeinsam
  anpassen. Keine Nodes, laufenden Coroutines oder Signalverbindungen speichern.
- Keine Engine-/Addon-Upgrades oder Änderungen an Drittanbieter-Code als
  beiläufige Voraussetzung einführen. Bestehende Projektversionen prüfen.

## UI-Designsystem – verbindlich

Vor jeder UI-Aufgabe die Designsystem-Dokumentation lesen: derzeit
`src/ui/theme/README.md`; nach Verschiebung deren neue Position in `doc/` bzw.
`docs/` anhand des Inhalts ermitteln. Die Token-Dateien bleiben unter
`src/ui/theme/`, solange der Code nicht ausdrücklich umgebaut wird.

- `NE_Theme.tres` ist das globale Projekt-Theme; Controls erben es automatisch.
- Farben in GDScript über `NEColors.*`, Abstände über `NEDimensions.SPACING_*`
  und Panel-Innenabstände über `MarginContainer` + `NEDimensions.PANEL_MARGIN`.
  Typografie über `NETypography` und die vorhandene Cuprum-Schrift.
- Keine hardcodierten Farbliterale. In `.tscn`/`.tres` den exakt passenden
  Token-Zahlenwert verwenden, da diese Dateien keine GDScript-Konstanten auswerten.
- Keine dekorativen eigenen StyleBox-Overrides für Buttons, Panels oder Balken.
  Overrides sind nur für echte semantische Bedeutung zulässig, z.B. HP/MP.
- Neue modale Fenster/Popups dimmen mit `NEColors.SCRIM`.
- Vor einer neuen Komponentenklasse Standard-Control + globales Theme und
  vorhandene Bausteine unter `src/ui/components/` prüfen. Nur bei tatsächlichem
  zusätzlichem Verhalten oder architektonischem Nutzen eine eigene Klasse bauen.
- Die lokale Theme-Ressource des Drittanbieter-Plugins
  `addons/dialogue_manager/` wird nicht verändert. Projekteigene Dialog-UI
  verwendet das zentrale Designsystem.

## Prüfung und Abschluss

- Änderungen in kleinen, lauffähigen Schritten umsetzen. Relevante vorhandene
  Tests verwenden; neue Tests für beobachtbare Fehler- und Integrationsfälle.
- Testkonvention: Szenen unter `src/debug/tools/`, Prüfzähler und Exitcode.
  Godot-Binary der vorhandenen Installation verwenden, z.B.:
  `godot --headless --path . res://src/debug/tools/test_sequences.tscn`.
- Bei neuen Scripts den Godot-Import/Klassenindex prüfen; bei neuen Rohdateien
  wie `.sequence` auch die Aufnahme in Exportpakete kontrollieren.
- Betroffene Integrationstests für Weltzustand, Laden, Dialog, Party, Kampf oder
  Levelwechsel ausführen. Für UI zusätzlich Darstellung und Bedienung prüfen,
  soweit eine geeignete Laufzeitumgebung verfügbar ist.
- Bestehende Fehler von neuen Regressionen unterscheiden. Keine fremden Fehler
  still mitändern; verbleibende Fehler und ungetestete Grenzen offen benennen.
- Relevante Dokumentation mit dem implementierten Verhalten abgleichen.
  Im Abschluss knapp Änderungen, Tests und verbleibende Grenzen nennen.
