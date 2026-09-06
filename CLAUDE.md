# NE - Call of the Abyss

## UI-Designsystem (verbindlich für jede UI-Arbeit)

Das Projekt hat ein zentrales UI-Designsystem unter `src/ui/theme/`:

- `NE_Theme.tres` — globales Theme, als Projekt-Default eingetragen
  (`project.godot` → `[gui] theme/custom`). Jedes Control erbt es
  automatisch.
- `colors.gd`, `dimensions.gd`, `typography.gd` — Design-Tokens
  (`NEColors`, `NEDimensions`, `NETypography`), global via `class_name`
  verfügbar, kein Autoload/Import nötig.
- `README.md` — Designprinzipien, Palette, Regeln, Beispiel-Code für neue
  UI-Elemente.
- `src/ui/components/` — wiederverwendbare Bausteine (z.B.
  `panels/NESectionHeader`, geteilte Balken-Styleboxen unter
  `indicators/`).

**Regeln, die für jede neue oder geänderte UI-Szene/jedes Script gelten:**

1. Vor jeder UI-Aufgabe `src/ui/theme/README.md` lesen.
2. Keine Farb-Literale hardcoden — immer `NEColors.*` referenzieren
   (GDScript) bzw. den exakt gleichen Zahlenwert des passenden Tokens in
   `.tscn`-Dateien eintragen (`.tres`/`.tscn` können keine GDScript-
   Konstanten referenzieren).
3. Keine eigenen `StyleBoxFlat`-Overrides für Button/Panel/ProgressBar/etc.
   anlegen — das globale Theme deckt Normal/Hover/Pressed/Focus/Disabled
   bereits ab. Ein Override ist nur bei echter semantischer Bedeutung
   gerechtfertigt (z.B. HP=rot vs. MP=blau), nie aus rein dekorativer
   Vorliebe.
4. Abstände über `NEDimensions.SPACING_*`, Innenabstand von Panels/
   Fenstern über `MarginContainer` + `NEDimensions.PANEL_MARGIN`.
5. Jedes neue modale Fenster/Popup dimmt den Hintergrund mit
   `NEColors.SCRIM`.
6. Vor dem Bau einer neuen Komponentenklasse prüfen, ob ein
   Standard-Control + globales Theme bereits reicht — nur bei echtem
   architektonischem Mehrwert eine eigene Klasse/Szene anlegen (siehe
   README, Abschnitt "Wiederverwendbare Komponenten").
7. Ausnahme: `addons/dialogue_manager/` (Drittanbieter-Plugin) bringt eine
   eigene lokale Theme-Ressource mit und wird nicht angefasst.
