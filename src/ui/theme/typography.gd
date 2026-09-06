class_name NETypography
extends RefCounted

## Zentrale Schriftgrößen-Skala des NE-Designsystems.
##
## Bewusste Design-Entscheidung: Es gibt aktuell keine projekteigene
## Font-Datei (assets/fonts/ ist ein leerer Platzhalter), daher nutzt das
## gesamte UI weiterhin Godots Standardschrift als gemeinsame Basis.
## Konsistenz entsteht ausschließlich über diese Größen-Tokens. Sobald eine
## Wunsch-Schriftart vorliegt, wird sie an genau einer Stelle eingesetzt:
## hier (SIZE_* bleiben gültig) und als Font-Ressource in NE_Theme.tres.

const SIZE_DISPLAY := 56 # Titelbildschirm-Logo/Spieltitel
const SIZE_H1 := 28      # Fenstertitel
const SIZE_H2 := 22      # Abschnittsüberschriften (groß)
const SIZE_H3 := 18      # Abschnittsüberschriften (klein) / NESectionHeader
const SIZE_BODY := 15    # Fließtext, Standard-Controls
const SIZE_SMALL := 12   # Hinweistexte, Fußzeilen
const SIZE_BUTTON := 16  # Button-Beschriftung
const SIZE_TOOLTIP := 12 # Tooltip-Text
const SIZE_STAT := 14    # Zahlen-/Statuswerte (SP, KP, Readiness, ...)
