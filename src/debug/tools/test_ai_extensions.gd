extends Node

const EXTENSION := "res://addons/limboai/bin/limboai.gdextension"
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _ready() -> void:
	if not GDExtensionManager.is_extension_loaded(EXTENSION):
		GDExtensionManager.load_extension(EXTENSION)
	check(GDExtensionManager.is_extension_loaded(EXTENSION), "LimboAI-GDExtension geladen")
	for type in ["BehaviorTree", "BTPlayer", "BTAlwaysSucceed", "Blackboard", "LimboHSM", "NavigationAgent3D"]:
		check(ClassDB.class_exists(type) and ClassDB.can_instantiate(type), type + " verfügbar")
	if failures == 0:
		var tree = ClassDB.instantiate("BehaviorTree")
		var task = ClassDB.instantiate("BTAlwaysSucceed")
		tree.set_root_task(task)
		check(tree.get_root_task() == task, "Verhaltensbaum nimmt native Aufgabe auf")
		var blackboard = ClassDB.instantiate("Blackboard")
		blackboard.set_var(&"probe", 42)
		check(blackboard.get_var(&"probe") == 42, "Blackboard arbeitet")
		var agent := Node.new()
		add_child(agent)
		agent.owner = self
		var instance = tree.instantiate(agent, blackboard, agent, self)
		check(instance != null, "Verhaltensbaum instanziiert")
		if instance:
			check(instance.update(0.016) == ClassDB.class_get_integer_constant("BTTask", "SUCCESS"), "Native Aufgabe wird erfolgreich ausgeführt")
		agent.free()
	print("ai_extensions: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
