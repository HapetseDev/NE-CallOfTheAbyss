class_name StateFollowerIdle extends State

## Ruhezustand für Party-Follower (kein Player). Bewegung läuft unabhängig
## über PartyFollower._update_follow(), nicht über diese State Machine –
## deshalb hier keine Walk-Transition und explizit KEIN handle_input()-
## Override (die Basisklasse gibt bereits null zurück, reagiert also nicht
## auf Interact/Jump). Die State Machine läuft für Follower ohnehin nur
## während einer aktiven Kampfteilnahme (siehe Playable.enter_combat_mode/
## PartyFollower._ready) – außerhalb ist ihr process_mode deaktiviert.
## Heißt bewusst "Idle" im Szenenbaum, damit Playable.exit_combat_mode()
## (sucht per Name) sie findet.


func enter() -> void:
	player.update_animation("idle")
