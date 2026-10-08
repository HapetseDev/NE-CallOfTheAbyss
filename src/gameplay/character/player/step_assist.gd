extends RefCounted

## Hebt nur an einem tatsächlich erreichbaren, niedrigen Absatz an.
static func apply(body: CharacterBody3D, delta: float, height: float) -> bool:
	if height <= 0 or not body.is_on_floor() or body.velocity.y > 0.01:
		return false
	var motion := Vector3(body.velocity.x, 0, body.velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return false
	var hit := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, motion, hit):
		return false
	if hit.get_normal().dot(Vector3.UP) >= cos(body.floor_max_angle):
		return false # Schrägen erledigt move_and_slide.
	# Der Kontakt liegt am Rand der Kapsel. Direkt dahinter muss eine
	# begehbare Oberseite liegen; die schräge Kapselnormale reicht nicht.
	var probe := hit.get_position() + motion.normalized() * 0.05
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(probe.x, body.global_position.y + height, probe.z),
		Vector3(probe.x, body.global_position.y, probe.z),
		body.collision_mask, [body.get_rid()])
	query.collide_with_areas = false
	var surface := body.get_world_3d().direct_space_state.intersect_ray(query)
	if surface.is_empty() or surface.normal.dot(Vector3.UP) < cos(body.floor_max_angle):
		return false
	var rise: float = surface.position.y - body.global_position.y + body.safe_margin
	if rise <= 0.001 or rise > height:
		return false
	var lift := Vector3.UP * rise
	if body.test_move(body.global_transform, lift):
		return false
	var raised := body.global_transform
	raised.origin += lift
	if body.test_move(raised, motion):
		return false
	body.global_position.y += rise
	return true
