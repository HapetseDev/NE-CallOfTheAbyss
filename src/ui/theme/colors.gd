class_name NEColors
extends RefCounted

## Zentrale Farbpalette des NE-Designsystems.
## Werte sind aus der bereits bestehenden visuellen Identität des Projekts
## abgeleitet (dunkles HUD-Panel-Grau + gedämpftes Gold als Akzent, siehe
## party_hud/combat_order_hud sowie MainMenu vor der Migration).
## Neue UI-Elemente referenzieren ausschließlich diese Konstanten (oder das
## globale Theme, das sie einsetzt) statt eigene Farbwerte zu erfinden.

# Hintergrundflächen (Vollbild-Ebenen, z.B. Menü-Hintergrund)
const BACKGROUND := Color(0.043, 0.043, 0.055, 1.0)
const BACKGROUND_SECONDARY := Color(0.07, 0.075, 0.09, 1.0)

# Panels (Fenster, HUD-Kacheln, Karten)
const PANEL := Color(0.086, 0.094, 0.114, 0.88)
const PANEL_SECONDARY := Color(0.125, 0.125, 0.145, 0.92)

# Ränder
const BORDER := Color(0.35, 0.38, 0.42, 0.9)
const BORDER_HIGHLIGHT := Color(0.78, 0.68, 0.42, 1.0)

# Text
const TEXT_PRIMARY := Color(0.93, 0.93, 0.91, 1.0)
const TEXT_SECONDARY := Color(0.75, 0.78, 0.82, 1.0)
const TEXT_DISABLED := Color(0.48, 0.49, 0.52, 1.0)

# Akzent (gedämpftes Gold - der "leicht fantasy-artige" Akzent des Spiels)
const ACCENT := Color(0.78, 0.68, 0.42, 1.0)
const ACCENT_HOVER := Color(0.88, 0.79, 0.52, 1.0)
const ACCENT_PRESSED := Color(0.62, 0.53, 0.32, 1.0)

# Status-/Semantikfarben
const SUCCESS := Color(0.45, 0.75, 0.5, 1.0)
const WARNING := Color(0.85, 0.65, 0.3, 1.0)
const DANGER := Color(0.8, 0.35, 0.32, 1.0)
const INFO := Color(0.35, 0.55, 0.85, 1.0)

# Abdunklung hinter modalen Fenstern/Dialogen (einheitlich für alle Popups)
const SCRIM := Color(0.0, 0.0, 0.0, 0.6)
