# NE-Designsystem

Zentrales UI-Designsystem für *NE — Call of the Abyss*. Ziel: **eine
visuelle Sprache, ein Theme, ein Satz wiederverwendbarer Komponenten** für
Hauptmenü, HUD, Inventar, Charakterbogen, Handel, Tauschen, Stehlen und
jede künftige UI-Fläche.

## Designprinzipien

- **Ein System, keine Einzelstücke.** Jede Farbe, jeder Abstand, jeder
  Radius kommt aus `colors.gd` / `dimensions.gd` / `typography.gd` oder aus
  `NE_Theme.tres`. Keine Szene definiert eigene, abweichende Werte.
- **Reduziert statt überladen.** Dunkles, ruhiges Panel-Grau, ein
  gedämpfter Goldakzent, klare Kanten (1px Border, kleine Radien). Kein
  Glow, keine Ornamentik, keine Runen.
- **Zustände über Farbe/Rand, nicht über Form.** Hover/Pressed/Focus
  ändern Hintergrund- und Randfarbe, nie Radius, Breite oder Layout.
- **Container statt harter Positionierung.** Anchors, `MarginContainer`,
  `*BoxContainer`, `size_flags` — keine magischen Pixelkoordinaten für
  Inhalte, die mitwachsen müssen.

## Warum kein eigenes Font-Asset?

Im Projekt lag keine Font-Datei vor (`assets/fonts/` war leer). Statt eine
Schriftart zu erfinden, nutzt das gesamte UI bewusst **Godots
Standardschrift** als gemeinsame Basis — Konsistenz entsteht rein über die
Größen-Tokens in `typography.gd`. Sobald eine Wunsch-Schriftart feststeht,
wird sie an **einer** Stelle eingesetzt: als `default_font` in
`NE_Theme.tres` (und optional projektspezifische Preload-Referenzen in
`typography.gd`).

## Farbpalette (`colors.gd`)

Abgeleitet aus der bereits im Projekt vorhandenen visuellen Identität
(dunkles HUD-Panel-Grau + gedämpftes Gold aus dem ursprünglichen
Hauptmenü).

| Token | Wert | Verwendung |
|---|---|---|
| `BACKGROUND` | `#0b0b0e` | Vollbild-Hintergrundebenen (Menü-Backdrops) |
| `BACKGROUND_SECONDARY` | `#121319` | zweite Hintergrundebene |
| `PANEL` | `#161821` @ 88% | Fenster, HUD-Kacheln |
| `PANEL_SECONDARY` | `#202024` @ 92% | verschachtelte Panels, Eingabefelder, Leisten |
| `BORDER` | `#595f6b` @ 90% | Standardrahmen |
| `BORDER_HIGHLIGHT` | `#c7ad6b` | Tooltip-Rahmen, Akzent-Rahmen |
| `TEXT_PRIMARY` | `#edeced` | Fließtext, Standardbeschriftung |
| `TEXT_SECONDARY` | `#bfc7d1` | Hinweise, Metainformationen |
| `TEXT_DISABLED` | `#7b7d85` | deaktivierte Zustände, dezente Zusatzinfos |
| `ACCENT` / `ACCENT_HOVER` / `ACCENT_PRESSED` | Gold-Skala | Fokus, aktiver Tab, primäre Betonung |
| `SUCCESS` | Grün | eigene Partei, positive Ereignisse |
| `WARNING` | Amber | Debug-/Achtungs-Hinweise |
| `DANGER` | Rot | Gegner, HP-Balken, Fehlermeldungen |
| `INFO` | Blau | MP-Balken, neutrale Hinweise |
| `SCRIM` | Schwarz @ 60% | Abdunklung hinter jedem modalen Fenster/Dialog |

## Typografie (`typography.gd`)

`SIZE_DISPLAY`(56) → Titelbildschirm · `SIZE_H1`(28) → Fenstertitel ·
`SIZE_H2`(22) → Dialogtitel · `SIZE_H3`(18) → Abschnittstitel
(`NESectionHeader`) · `SIZE_BODY`(15) → Standardtext · `SIZE_SMALL`(12) →
Hinweise/Fußzeilen · `SIZE_BUTTON`(16) → Button-Text · `SIZE_TOOLTIP`(12) ·
`SIZE_STAT`(14) → Zahlen-/Statuswerte.

Kompakte, dauerhaft sichtbare HUD-Titel (z.B. "Reihenfolge" im
Kampf-HUD) bleiben bewusst kleiner als Fenster-Sektionstitel — andere
Größenklasse, kein Widerspruch zum System.

## Spacing- & Größensystem (`dimensions.gd`)

`SPACING_XS/S/M/L/XL` = 4/8/16/24/32. `RADIUS_SM`(4) für Controls
(Buttons, Inputs, Tabs, Balken), `RADIUS_MD`(6) für Panels/Fenster/Popups,
`RADIUS_LG`(10) für künftige große Flächen. `BORDER_WIDTH`(1) Standard,
`BORDER_WIDTH_STRONG`(2) für Fokus-Ringe. Weitere Standardgrößen:
`BUTTON_HEIGHT`(44), `BUTTON_MIN_WIDTH`(160), `INPUT_HEIGHT`(36),
`LIST_ROW_HEIGHT`(64, siehe Inventar-Slots), `PANEL_MARGIN`(16).

## Das globale Theme (`NE_Theme.tres`)

`NE_Theme.tres` ist als Projekt-Default eingetragen
(`project.godot` → `[gui] theme/custom`). Dadurch erbt **jedes** Control im
Projekt — auch jedes künftig neu erstellte — automatisch Button-, Panel-,
Label-, LineEdit-, CheckBox-, ProgressBar-, Tab-, Scrollbar-, Popup-,
Window-, Separator-, ItemList- und Tooltip-Stile, ohne dass eine Szene
selbst etwas einstellen muss.

Abgedeckte Zustände pro interaktivem Control: **Normal, Hover, Pressed,
Focus, Disabled** (Buttons/Inputs/CheckBoxen), zusätzlich **Selected**
(ItemList, Tabs) und **Active** (aktiver Tab/aktives Kampf-HUD-Element via
Szenenlogik, z.B. `combat_order_entry.gd`). Hover/Pressed/Focus ändern nur
Rand-/Hintergrundfarbe — Radius und Form bleiben identisch zum
Normal-Zustand.

**Wichtig:** `.tres`-Dateien können keine GDScript-Konstanten referenzieren.
Die Farbwerte in `NE_Theme.tres` sind deshalb 1:1 als Literale eingetragen
und müssen bei einer Palettenänderung manuell synchron zu `colors.gd`
gehalten werden.

## Wiederverwendbare Komponenten (`src/ui/components/`)

Bewusst schlank gehalten — eine Komponente bekommt nur dann eine eigene
Klasse, wenn sie einen echten Vorteil bietet:

- **`indicators/*.tres`** — geteilte `StyleBoxFlat`-Ressourcen für
  Balkenhintergrund sowie HP-/MP-/Initiative-Füllung
  (`bar_background.tres`, `hp_fill.tres`, `mp_fill.tres`,
  `readiness_fill.tres`). Werden per `ExtResource` in `party_hud_entry.tscn`
  und `combat_order_entry.tscn` referenziert statt pro Szene dupliziert.
- **`panels/NESectionHeader`** (`ne_section_header.gd/.tscn`) — Label mit
  fest verdrahteter H3-Größe/-Farbe für Abschnittstitel *innerhalb* eines
  Fensters (z.B. "Ausrüstung", "Gegenstände", Attribut-Abschnitte im
  Charakterbogen).
- **Kein `NEButton`/`NEPanel`/`NEWindow` als eigene Klasse:** Ein normaler
  `Button`/`Panel`/`PanelContainer`/`Window`-Node ist bereits vollständig
  über `NE_Theme.tres` gestylt. Eine Wrapper-Klasse ohne zusätzliches
  Verhalten wäre reine Bürokratie — stattdessen einfach den Godot-Bordtyp
  verwenden.
- **Tooltips** laufen über Godots eingebauten Mechanismus
  (`Control.tooltip_text`, siehe `InventoryUI`) und sind über die
  Theme-Typen `TooltipPanel`/`TooltipLabel` gestylt — kein eigenes
  `NETooltip`-Control nötig.

## Bekannte Ausnahme: Dialogue-Manager-Addon

`addons/dialogue_manager/example_balloon/` bringt eine eigene, lokale
Theme-Ressource mit (Drittanbieter-Plugin-Code). Diese Datei wurde
**nicht** verändert. `src/ui/dialogue/` ist aktuell nur ein Platzhalter —
sobald ein projekteigenes Dialogfenster gebaut wird, gehört es dort hin
und erbt automatisch `NE_Theme.tres`, da es ein normales
projekteigenes `Control` sein wird (keine lokale Theme-Ressource setzen!).

## Regeln für neue UI-Elemente

1. Keine Farb-Literale in neuem Code/Szenen — immer `NEColors.*`
   (GDScript) referenzieren; in `.tscn`-Dateien den exakt gleichen
   Zahlenwert wie das passende Token eintragen (siehe Tabelle oben).
2. Keine eigenen `StyleBoxFlat`-Overrides für Button/Panel/ProgressBar
   etc. anlegen — das globale Theme deckt das ab. Ein Override ist nur
   gerechtfertigt bei einer *semantischen* Abweichung (z.B. HP=rot vs.
   MP=blau), nicht bei rein dekorativen Vorlieben.
3. Abstände immer über `NEDimensions.SPACING_*`, nie als Rohzahl.
4. Ein neues modales Fenster/Popup dimmt den Hintergrund immer mit
   `NEColors.SCRIM`.
5. Innenabstand eines Panels/Fensters über `MarginContainer` mit
   `NEDimensions.PANEL_MARGIN`, nicht über harte `custom_minimum_size`-Tricks.
6. Vor dem Bau einer neuen Komponente prüfen, ob ein Standard-Control +
   globales Theme bereits reicht (siehe oben) — nur bei echtem
   architektonischem Mehrwert eine eigene Klasse/Szene anlegen.

### Beispiel: neues UI-Element hinzufügen

Ein neues Bestätigungsdialog-Popup, ohne das Designsystem zu umgehen:

```gdscript
extends Control

func _build_ui() -> void:
    set_anchors_preset(PRESET_FULL_RECT)

    var dim := ColorRect.new()
    dim.set_anchors_preset(PRESET_FULL_RECT)
    dim.color = NEColors.SCRIM  # (1) einheitliche Abdunklung
    add_child(dim)

    var panel := PanelContainer.new()  # (2) erbt Panel-Stil aus NE_Theme
    panel.set_anchors_preset(PRESET_CENTER)
    add_child(panel)

    var margin := MarginContainer.new()  # (3) Innenabstand über Token
    margin.add_theme_constant_override(&"margin_left", NEDimensions.PANEL_MARGIN)
    margin.add_theme_constant_override(&"margin_top", NEDimensions.PANEL_MARGIN)
    margin.add_theme_constant_override(&"margin_right", NEDimensions.PANEL_MARGIN)
    margin.add_theme_constant_override(&"margin_bottom", NEDimensions.PANEL_MARGIN)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override(&"separation", NEDimensions.SPACING_S)
    margin.add_child(box)

    var title := preload("res://src/ui/components/panels/ne_section_header.tscn").instantiate()
    title.text = "Wirklich beenden?"  # (4) NESectionHeader statt Label + font_size-Override
    box.add_child(title)

    var confirm := Button.new()  # (5) ganz normaler Button - schon vollständig gestylt
    confirm.text = "Ja"
    confirm.custom_minimum_size = Vector2(NEDimensions.BUTTON_MIN_WIDTH, NEDimensions.BUTTON_HEIGHT)
    box.add_child(confirm)
```

Kein einziger Farb-, Radius- oder Fontgrößen-Wert wird hier neu erfunden —
alles kommt aus dem System.
