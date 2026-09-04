extends Node

## Projektweites Ereignis-Log (Fallout-1/2-Stil): Kampfaktionen, Gegenstände
## aufheben, Dialogzeilen, … alles, was als kurze Textzeile sichtbar werden
## soll. Reiner Signal-Bus, kennt keine UI – EventLogHud (src/ui/hud/) zeigt
## die Zeilen an. Autoload, weil Ereignisse aus allen Systemen (Kampf,
## Inventar, Dialog, künftig z.B. Wahrnehmung) kommen können.

signal event_logged(text: String)


## Heißt bewusst nicht "log": GDScript reserviert diesen Namen für die
## eingebaute globale Math-Funktion log(x: float) (natürlicher Logarithmus) –
## eine gleichnamige Methode hier wird beim Aufruf trotzdem an das Builtin
## gebunden ("argument 1 should be float but is String").
func add(text: String) -> void:
	if text.is_empty():
		return
	event_logged.emit(text)


func add_lines(lines: Array[String]) -> void:
	for line in lines:
		add(line)
