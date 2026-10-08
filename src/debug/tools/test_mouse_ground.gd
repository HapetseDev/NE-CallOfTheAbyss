extends Node3D
const Picker := preload("res://src/gameplay/character/player/mouse_ground_picker.gd")
const Steps := preload("res://src/gameplay/character/player/step_assist.gd")
class Walker extends CharacterBody3D:
	var speed := 0.0
	func _physics_process(delta: float) -> void:
		velocity.x = speed
		preload("res://src/gameplay/character/player/step_assist.gd").apply(self, delta, 0.35)
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		move_and_slide()
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func box(parent: Node3D, location: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	parent.add_child(shape)
	shape.position = location
	return shape
func frames(count: int) -> void:
	for frame in range(count): await get_tree().physics_frame
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var terrain := StaticBody3D.new()
	add_child(terrain)
	box(terrain, Vector3(0,-0.1,0), Vector3(30,0.2,20))
	# Wand und Boden absichtlich im selben Physics-Body wie bei GridMaps.
	box(terrain, Vector3(0,1.5,2), Vector3(4,3,0.2))
	box(terrain, Vector3(0,4,0), Vector3(4,0.2,4))
	var walker := Walker.new()
	add_child(walker)
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.0
	capsule.shape = capsule_shape
	walker.add_child(capsule)
	capsule.position.y = 0.5
	walker.floor_snap_length = 0.4
	await frames(5)
	var result: Variant = Picker.pick(walker, Vector3(0,5,5), Vector3(0,-1,-1).normalized(), 1.25)
	check(result is Vector3 and absf(result.y) < 0.01, "Verdeckter Boden statt Wand oder höherer Etage")
	result = Picker.pick(walker, Vector3(50,5,5), Vector3(0,-1,-1).normalized(), 1.25)
	check(result == null, "Kein Ziel ohne Boden")
	result = Picker.pick(walker, Vector3(0,1,5), Vector3.FORWARD, 1.25)
	check(result == null, "Horizontaler Kamerastrahl sicher abgelehnt")
	# Drei echte Stufen ohne unsichtbare Hilfsrampe.
	for i in range(3):
		box(terrain, Vector3(2.0+i, (i+1)*0.1, -3), Vector3(1,(i+1)*0.2,2))
	walker.position = Vector3(0,0.02,-3)
	walker.velocity = Vector3.ZERO
	await frames(5)
	walker.speed = 2.0
	await frames(120)
	walker.speed = 0.0
	check(walker.position.x > 3.5 and walker.position.y > 0.5, "Kapsel steigt reale Treppenstufen hinauf")
	walker.speed = -2.0
	await frames(120)
	walker.speed = 0.0
	check(walker.position.x < 0.5 and absf(walker.position.y) < 0.08, "Bodensnap folgt Treppe abwärts")
	box(terrain, Vector3(2,1,-6), Vector3(1,2,2))
	walker.position = Vector3(0,0.02,-6)
	walker.velocity = Vector3.ZERO
	await frames(5)
	walker.speed = 2.0
	await frames(100)
	walker.speed = 0.0
	check(walker.position.x < 1.4 and walker.position.y < 0.1, "Hohe Wand wird nicht überstiegen")
	var ramp := box(terrain, Vector3(8,0.6,-3), Vector3(4,0.2,2))
	ramp.rotation.z = deg_to_rad(15)
	walker.position = Vector3(5.5,0.02,-3)
	walker.velocity = Vector3.ZERO
	await frames(5)
	walker.speed = 2.0
	await frames(85)
	walker.speed = 0.0
	check(walker.position.x > 8 and walker.position.y > 0.7, "Begehbare Schräge wird erklommen")
	result = Picker.pick(walker, Vector3(8,5,-3), Vector3.DOWN, 1.25)
	check(result is Vector3 and result.y > 0.5, "Schrägenziel behält tatsächliche Bodenhöhe")
	# Niedrige Decke lässt die Kapsel passieren, aber keinen Aufstieg zu.
	box(terrain, Vector3(2,0.1,6), Vector3(1,0.2,2))
	box(terrain, Vector3(1.5,1.2,6), Vector3(4,0.2,2))
	walker.position = Vector3(0,0.02,6)
	walker.velocity = Vector3.ZERO
	await frames(5)
	walker.speed = 2.0
	await frames(100)
	walker.speed = 0.0
	check(walker.position.x < 1.4 and walker.position.y < 0.1, "Stufenhilfe respektiert Kopffreiheit")
	walker.position = Vector3(0,4.11,0)
	walker.velocity = Vector3.ZERO
	await frames(10)
	result = Picker.pick(walker, Vector3(0,8,0), Vector3.DOWN, 1.25)
	check(result is Vector3 and absf(result.y - 4.1) < 0.01, "Auf oberer Etage bleibt das Ziel auf oberer Etage")
	walker.velocity = Vector3(2,4,0)
	check(not Steps.apply(walker, 1.0 / 60.0, 0.35), "Keine Stufenhilfe während eines Sprungs")
	print("mouse_ground: %d Checks, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)
