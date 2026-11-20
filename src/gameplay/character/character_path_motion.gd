extends RefCounted

## Gemeinsamer physischer Wegfolger für Flucht und KI-Kampfbewegung.
## Besitzer-ID schützt fremde Bewegungen vor Abbruch durch alte Commands.
var owner_id: int = 0
var path := PackedVector3Array()
var _finished := Callable()
var _speed := 1.0
var _radius := 0.12
var _avoid_characters := false
var _stalled := 0.0
var _previous := Vector3.ZERO

func start(body: Playable, owner: int, points: PackedVector3Array, speed: float, finished: Callable, arrival_radius: float, avoid_characters: bool) -> bool:
	if owner_id != 0 or points.is_empty() or owner == 0 or not is_finite(speed) or speed <= 0:
		return false
	for point in points:
		if not point.is_finite():
			return false
	owner_id = owner
	path = points.duplicate()
	_speed = speed
	_finished = finished
	_radius = arrival_radius
	_avoid_characters = avoid_characters
	_previous = body.global_position
	_stalled = 0.0
	return true

func cancel(body: Playable, owner: int) -> void:
	if owner_id != owner:
		return
	path.clear()
	owner_id = 0
	_finished = Callable()
	body.stop_horizontal_velocity()
	body.update_animation("idle")

func finish(body: Playable, arrived: bool) -> void:
	var callback := _finished
	cancel(body, owner_id)
	if callback.is_valid():
		callback.call(arrived)

func tick(body: Playable, delta: float) -> void:
	if path.is_empty() or delta <= 0:
		return
	var offset := path[0] - body.global_position
	offset.y = 0
	if offset.length() < _radius:
		path.remove_at(0)
		body.stop_horizontal_velocity()
		if path.is_empty():
			finish(body, true)
		return
	_stalled = _stalled + delta if body.global_position.distance_to(_previous) < 0.005 else 0.0
	_previous = body.global_position
	if _stalled > 2.0:
		finish(body, false)
		return
	var step := offset.normalized() * minf(_speed * delta, offset.length())
	if _avoid_characters and not _clear_step(body, step):
		body.stop_horizontal_velocity()
		return
	body.direction = offset.normalized()
	body.set_direction()
	body.set_horizontal_velocity(step / delta)
	body.update_animation("walk" if _avoid_characters else "run")

func _clear_step(body: Playable, step: Vector3) -> bool:
	var collider := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null or collider.shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.transform.origin.y += 0.04
	query.motion = step
	query.collision_mask = body.collision_mask | CombatLineOfSight.LAYER_PLAYER | CombatLineOfSight.LAYER_NPC
	query.exclude = [body.get_rid()]
	var fractions := body.get_world_3d().direct_space_state.cast_motion(query)
	return fractions[0] >= 1.0
