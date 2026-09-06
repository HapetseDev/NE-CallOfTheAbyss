class_name NEDimensions
extends RefCounted

## Zentrales Spacing-/Größensystem des NE-Designsystems.
## Abstände, Radien und Standardgrößen werden konsequent aus diesen
## Konstanten bezogen statt in einzelnen Szenen neu erfunden zu werden.

# Spacing-Skala
const SPACING_XS := 4
const SPACING_S := 8
const SPACING_M := 16
const SPACING_L := 24
const SPACING_XL := 32

# Eck-Radien (bewusst zwei Stufen: knapp für Controls, weicher für Panels)
const RADIUS_SM := 4
const RADIUS_MD := 6
const RADIUS_LG := 10

# Rahmenstärken
const BORDER_WIDTH := 1
const BORDER_WIDTH_STRONG := 2

# Buttons
const BUTTON_HEIGHT := 44
const BUTTON_MIN_WIDTH := 160
const ICON_BUTTON_SIZE := 40

# Icons
const ICON_SIZE_S := 16
const ICON_SIZE_M := 24
const ICON_SIZE_L := 32

# Sonstige Controls
const INPUT_HEIGHT := 36
const TAB_HEIGHT := 36
const LIST_ROW_HEIGHT := 64
const PROGRESS_BAR_HEIGHT := 16
const TOOLTIP_MAX_WIDTH := 280

# Standard-Innenabstand für Panels/Fenster (siehe MarginContainer-Nutzung)
const PANEL_MARGIN := 16
