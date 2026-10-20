extends Node
const Simulation := preload("res://src/debug/simulation/combat_text_simulation.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func sheet(name_text: String, power: int, speed: int, defense: int) -> CharacterResource:
	var result := CharacterResource.new()
	result.character_name = name_text
	result.koerperkraft = power
	result.gewandheit = speed
	result.robustheit = defense
	return result

func _run() -> void:
	var first := sheet("A", 5, 4, 2)
	var second := sheet("B", 4, 3, 1)
	var simulation := Simulation.new()
	simulation.setup([first, second], [{}, {}], 42)
	check(simulation.actors[0].character != first, "Simulation verwendet Charakterkopien")
	simulation.step()
	check(simulation.turns == 1 and simulation.lines.size() > 3, "Einzelschritt protokolliert eine Aktion")
	var result := simulation.run()
	check(result.winner == 0 and result.damage[0] > 0, "Stärkerer schnellerer Testkämpfer gewinnt")
	check(first.staerkepunkte == 0 and second.staerkepunkte == 0, "Originalpunkte unverändert")
	var repeat := Simulation.new()
	repeat.setup([first, second], [{}, {}], 42)
	check(repeat.run() == result, "Gleicher Zufallsstart erzeugt gleichen vollständigen Verlauf")
	repeat.cleanup()
	simulation.cleanup()
	seed(123)
	var expected := randf()
	seed(123)
	simulation.setup([first, second], [{}, {}], 50)
	simulation.run()
	check(randf() == expected, "Simulation verändert Spiel-Zufallsfolge nicht")
	simulation.cleanup()
	var armor := sheet("Panzer", 1, 1, 100)
	simulation.setup([armor, armor], [{}, {}], 1)
	for actor in simulation.actors:
		var protection := ItemData.new()
		protection.is_armor = true
		actor.character.inventory.equip("rumpf", protection)
	result = simulation.run()
	check(result.winner == -1 and result.turns <= Simulation.MAX_TURNS, "Schadensloser Kampf wird begrenzt")
	check(result.damage == [0, 0] and result.log.contains("Robustheit"), "Nullschaden wird als Rüstungsschutz benannt")
	simulation.cleanup()
	var frozen := sheet("Langsam", 1, 0, 1)
	simulation.setup([frozen, frozen], [{}, {}], 1)
	result = simulation.run()
	check(result.winner == -1 and result.turns == 0, "Gewandheit 0 blockiert Oberfläche nicht")
	simulation.cleanup()
	var fragile := {"item_path": "custom", "combat_value": 10, "break_chance": 1.0}
	simulation.setup([first, second], [fragile, {}], 5)
	simulation.step()
	check(simulation.lines[-1].contains("zerbrochen"), "Bruch ist im Textprotokoll sichtbar")
	check(simulation.actors[0].equipment.primaer_hand == null, "Bruch entfernt Simulationsgegenstand")
	var log_count := simulation.lines.size()
	simulation.step()
	check(simulation.lines.size() > log_count, "Nach Bruch kann der Kampf weiterlaufen")
	simulation.cleanup()
	var throwing := {"item_path": "res://src/resources/items/messer.tres", "mode_index": 1}
	simulation.setup([first, second], [throwing, {}], 1)
	simulation.step()
	check(simulation.actors[0].equipment.primaer_hand == null, "Messerwurf verbraucht das Exemplar")
	simulation.cleanup()
	simulation.setup([first, second], [{"ability_id": "magie_feuerstoss"}, {}], 1)
	simulation.step()
	check(simulation.lines[-1].contains("Schlag"), "Nicht gelernte Fähigkeit fällt auf Schlag zurück")
	simulation.cleanup()
	var main := load("res://src/ui/menus/MainMenu.tscn").instantiate() as MainMenu
	add_child(main)
	check(main.simulation_button.text == "Kampfsimulation", "Simulation im Hauptmenü erreichbar")
	main.simulation_button.pressed.emit()
	await get_tree().process_frame
	var menu := main.get_node("CombatSimulationMenu")
	check(menu.fighters.size() == 2, "Zwei editierbare Figuren vorhanden")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/necota-simulation-editor.png")
	var source := CharacterSheetFactory.load_sheet("dannerman")
	menu.fighters[0].attributes.koerperkraft.value = 20
	check(source.koerperkraft == 3, "Editor verändert Vorlagen nicht")
	var tabs: TabContainer = menu._log.get_parent()
	menu._step(tabs)
	check(menu._simulation.turns == 1 and menu._log.text.contains("Schaden"), "Menü führt Einzelschritt aus")
	if "--visual-smoke" in OS.get_cmdline_user_args():
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/necota-simulation-log.png")
	menu.fighters[0].attributes.koerperkraft.value = 21
	check(menu._simulation == null, "Werteänderung verwirft laufenden Schrittverlauf")
	menu._count.value = 10
	menu._run_series(tabs)
	for frame in 60:
		await get_tree().process_frame
		if not menu._running:
			break
	check(menu._status.text.contains("10 Kämpfe") and not menu._running, "Serienvergleich mit Siegquoten abgeschlossen")
	print("SIMULATION_SAMPLE: ", menu._status.text)
	menu._count.value = 500
	menu._run_series(tabs)
	menu._reset()
	await get_tree().process_frame
	check(not menu._running and menu._status.text.contains("Zurückgesetzt"), "Serie lässt sich abbrechen")
	menu._close()
	await get_tree().process_frame
	check(main.get_node_or_null("CombatSimulationMenu") == null, "Zurück schließt und bereinigt Simulation")
	check(get_viewport().gui_get_focus_owner() == main.simulation_button, "Fokus kehrt zum Hauptmenü zurück")
	main.queue_free()
	await get_tree().process_frame
	print("combat_simulation: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
