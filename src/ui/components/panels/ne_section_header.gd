class_name NESectionHeader extends Label

## Einheitlicher Abschnittstitel innerhalb eines Fensters/Panels (z.B.
## "Ausrüstung", "Gegenstände"). Zentralisiert Größe/Farbe an einer Stelle,
## damit neue Fenster nicht erneut font_size/font_color pro Label setzen.
## Für kompakte, dauerhaft sichtbare HUD-Titel (z.B. combat_order_hud) nicht
## gedacht - andere Größenklasse, siehe README.


func _ready() -> void:
	add_theme_font_size_override(&"font_size", NETypography.SIZE_H3)
	add_theme_color_override(&"font_color", NEColors.TEXT_PRIMARY)
