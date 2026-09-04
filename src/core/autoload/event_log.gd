extends Node

## Projektweites Ereignis-Log (Fallout-1/2-Stil): Kampfaktionen, Gegenstände
## aufheben, Dialogzeilen, … alles, was als kurze Textzeile sichtbar werden
## soll. Reiner Signal-Bus, kennt keine UI – EventLogHud (src/ui/hud/) zeigt
## die Zeilen an. Autoload, weil Ereignisse aus allen Systemen (Kampf,
## Inventar, Dialog, künftig z.B. Wahrnehmung) kommen können.

signal event_logged(text: String)


func log(text: String) -> void:
	if text.is_empty():
		return
	event_logged.emit(text)


func log_lines(lines: Array[String]) -> void:
	for line in lines:
		log(line)
