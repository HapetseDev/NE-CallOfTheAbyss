extends RefCounted

## Kampfweites Weltgitter. Zellmitten liegen bei ganzzahligen Weltmetern.
## Flucht und freie Erkundung verwenden weiterhin ihre bisherige Navigation.
const CELL_SIZE := WorldUnits.METER
const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const EPSILON := 0.001
const FLOOR_CLEARANCE := 0.05

static func cell(at: Vector3) -> Vector2i:
	return Vector2i(roundi(at.x / CELL_SIZE), roundi(at.z / CELL_SIZE))

static func center(at: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(at.x * CELL_SIZE, height, at.y * CELL_SIZE)

static func budget(body: Playable) -> float:
	return maxf(1.0, body.get_effective_attribute(CharacterEnums.Attribute.GEWANDHEIT)) * CELL_SIZE

static func is_centered(at: Vector3) -> bool:
	var offset := at - center(cell(at), at.y)
	return offset.length() <= EPSILON

static func _exclusions(body: Playable) -> Array[RID]:
	var result: Array[RID] = [body.get_rid()]
	for actor in body.get_tree().get_nodes_in_group("combat_reactive"):
		if actor is CollisionObject3D and actor != body:
			result.append(actor.get_rid())
	return result

static func floor_point(body: Playable, at: Vector2i, height: float) -> Variant:
	var point := center(at, height)
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point - Vector3.UP * 0.6, body.collision_mask, _exclusions(body))
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < cos(body.floor_max_angle):
		return null
	return Vector3(point.x, hit.position.y + FLOOR_CLEARANCE, point.z)

static func _query(body: Playable, at: Vector3) -> PhysicsShapeQueryParameters3D:
	var collider := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null or collider.shape == null:
		return null
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = body.global_transform * collider.transform
	query.transform.origin += at - body.global_position
	query.collision_mask = body.collision_mask | CombatLineOfSight.LAYER_PLAYER | CombatLineOfSight.LAYER_NPC
	query.exclude = [body.get_rid()]
	return query

static func _free(body: Playable, at: Vector3, session: CombatSession) -> bool:
	for participant in session.participants:
		if is_instance_valid(participant.playable) and participant.playable != body and not participant.has_fled and cell(participant.playable.global_position) == cell(at):
			return false
	var query := _query(body, at)
	return query != null and body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

static func _edge(body: Playable, from: Vector3, to: Vector3) -> bool:
	if absf(to.y - from.y) > minf(0.3, maxf(0.05, body.step_height)):
		return false
	var query := _query(body, from)
	if query == null:
		return false
	query.motion = to - from
	return body.get_world_3d().direct_space_state.cast_motion(query)[0] >= 1.0

## Einmalige Einordnung bei Eintritt/Rückkehr; keine laufende Weltbewegung.
static func place(body: Playable, session: CombatSession) -> bool:
	var origin := cell(body.global_position)
	var candidates: Array[Vector2i] = []
	for x in range(-4, 5):
		for z in range(-4, 5):
			candidates.append(origin + Vector2i(x, z))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return center(a, body.global_position.y).distance_squared_to(body.global_position) < center(b, body.global_position.y).distance_squared_to(body.global_position))
	for candidate in candidates:
		var point = floor_point(body, candidate, body.global_position.y)
		if point == null or not _free(body, point, session):
			continue
		# Kein Einordnen durch Wände oder auf die andere Seite eines Hindernisses.
		if not _edge(body, body.global_position + Vector3.UP * 0.05, point):
			continue
		body.global_position = point
		body.stop_horizontal_velocity()
		return true
	return false

## Dijkstra: tatsächliche Wegkosten, acht Nachbarn, keine diagonalen Abkürzungen.
## Ergebnis enthält für jedes erreichbare Feld Position, Kosten und gesamten Weg.
static func reachable(body: Playable, session: CombatSession, maximum: float = INF) -> Dictionary:
	return _routes(body, session, minf(budget(body), maximum))

## Nur Vorausschau: Diese Wege sind keine Bewegungserlaubnis für einen Zug.
static func planning_routes(body: Playable, session: CombatSession, maximum: float, turn_limit: float = INF) -> Dictionary:
	return _routes(body, session, maximum, minf(budget(body), turn_limit))

static func _routes(body: Playable, session: CombatSession, limit: float, edge_limit: float = INF) -> Dictionary:
	var result: Dictionary = {}
	if session == null or session.state != CombatSession.SessionState.ACTIVE or not is_centered(body.global_position):
		return result
	if not is_finite(limit) or limit < 0 or limit > 35 * CELL_SIZE:
		return result
	var start := cell(body.global_position)
	var points: Dictionary = {}
	var extent := ceili(limit / CELL_SIZE)
	for x in range(-extent, extent + 1):
		for z in range(-extent, extent + 1):
			var key := start + Vector2i(x, z)
			if Vector2(x, z).length() * CELL_SIZE > limit + EPSILON:
				continue
			var point = floor_point(body, key, body.global_position.y)
			if point != null and (key == start or _free(body, point, session)):
				points[key] = point
	if not points.has(start):
		return result
	result[start] = {"position": points[start], "cost": 0.0, "path": PackedVector3Array([points[start]])}
	var pending: Array[Vector2i] = [start]
	while not pending.is_empty():
		pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return result[a].cost < result[b].cost)
		var current: Vector2i = pending.pop_front()
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not points.has(next):
				continue
			if direction.x != 0 and direction.y != 0:
				var horizontal := current + Vector2i(direction.x, 0)
				var vertical := current + Vector2i(0, direction.y)
				if not points.has(horizontal) or not points.has(vertical):
					continue
				if not _edge(body, points[current], points[horizontal]) or not _edge(body, points[current], points[vertical]):
					continue
			var step_cost: float = points[current].distance_to(points[next])
			# Ein einzelner Schritt muss auch in einen späteren Zug passen.
			if step_cost > edge_limit + EPSILON:
				continue
			var cost: float = result[current].cost + step_cost
			if cost > limit + EPSILON or (result.has(next) and cost >= float(result[next].cost) - EPSILON):
				continue
			if not _edge(body, points[current], points[next]):
				continue
			var path: PackedVector3Array = result[current].path.duplicate()
			path.append(points[next])
			result[next] = {"position": points[next], "cost": cost, "path": path}
			if not pending.has(next):
				pending.append(next)
	return result

static func find_path(body: Playable, session: CombatSession, target: Vector3, maximum: float = INF) -> PackedVector3Array:
	var fields := reachable(body, session, maximum)
	return fields[cell(target)].path if fields.has(cell(target)) else PackedVector3Array()
