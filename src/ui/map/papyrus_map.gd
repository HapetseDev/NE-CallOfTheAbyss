extends Control

## Custom drawing is needed for geometry, fog and map-space navigation.
var cartography: RefCounted
var zoom := 1.0
var pan := Vector2.ZERO
var _dragging := false
var _view_bounds := Rect2(-16, -16, 32, 32)
var _texture: ImageTexture

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4271
	for y in 256:
		for x in 256:
			var fiber := sin(float(y) * 1.8) * 0.025 + sin(float(x) * 0.7) * 0.012
			image.set_pixel(x, y, NEColors.MAP_PAPER.lerp(NEColors.MAP_AGED, clampf(rng.randf() * 0.18 + fiber, 0.0, 1.0)))
	_texture = ImageTexture.create_from_image(image)

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	if cartography and not cartography.location.is_empty():
		_view_bounds = Rect2(cartography.player_position, Vector2.ZERO)
		for key: String in cartography.state().cells:
			var xy := key.split(",")
			var point: Vector2 = Vector2(float(xy[0]), float(xy[1])) * cartography.CELL_SIZE
			_view_bounds = _view_bounds.expand(point).expand(point + Vector2.ONE * cartography.CELL_SIZE)
		_view_bounds = _view_bounds.grow(cartography.REVEAL_RADIUS * 0.5)
	queue_redraw()

func _scale() -> float:
	if not cartography:
		return 1.0
	var extent: Vector2 = _view_bounds.size.max(Vector2.ONE)
	return minf((size.x - NEDimensions.SPACING_XL * 2) / extent.x, (size.y - NEDimensions.SPACING_XL * 2) / extent.y) * zoom

func _point(world: Vector2) -> Vector2:
	return size * 0.5 + pan + (world - _view_bounds.get_center()) * _scale()

func _draw() -> void:
	if size.x < NEDimensions.SPACING_XL or size.y < NEDimensions.SPACING_XL:
		return
	if _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), NEColors.MAP_PAPER)
	for inset in 8:
		draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2), NEColors.MAP_AGED.lerp(NEColors.MAP_PAPER, float(inset) / 8), false, 1.0)
	if not cartography or cartography.location.is_empty():
		return
	for segment in cartography.segments:
		if cartography.is_explored((segment[0] + segment[1]) * 0.5):
			draw_line(_point(segment[0]), _point(segment[1]), NEColors.MAP_INK, 1.15, true)
	var font := get_theme_default_font()
	var occupied: Array[Rect2] = [Rect2(_point(cartography.player_position) - Vector2(12, 12), Vector2(24, 24))]
	for marker: Dictionary in cartography.state().markers.values():
		var p := _point(cartography.project(marker.position))
		if not Rect2(Vector2.ZERO, size).grow(-NEDimensions.SPACING_M).has_point(p):
			continue
		var color: Color = NEColors.MAP_NPC if marker.kind == "npc" else NEColors.MAP_OBJECT
		draw_circle(p, 3.5, color)
		var text_size := font.get_string_size(marker.label, HORIZONTAL_ALIGNMENT_LEFT, -1, NETypography.SIZE_SMALL)
		for row in 8:
			var label_position := p + Vector2(NEDimensions.SPACING_S, row * (NETypography.SIZE_SMALL + NEDimensions.SPACING_XS))
			label_position.x = clampf(label_position.x, NEDimensions.SPACING_S, maxf(NEDimensions.SPACING_S, size.x - text_size.x - NEDimensions.SPACING_S))
			var box := Rect2(label_position - Vector2(0, text_size.y), text_size).grow(2)
			var overlaps := false
			for used in occupied:
				if used.intersects(box): overlaps = true
			if overlaps: continue
			if box.end.y > size.y - NEDimensions.SPACING_S:
				continue
			occupied.append(box)
			if row > 0:
				draw_line(p, label_position - Vector2(NEDimensions.SPACING_XS, NETypography.SIZE_SMALL * 0.5), color, 0.75, true)
			draw_string_outline(font, label_position, marker.label, HORIZONTAL_ALIGNMENT_LEFT, -1, NETypography.SIZE_SMALL, 3, NEColors.MAP_PAPER)
			draw_string(font, label_position, marker.label, HORIZONTAL_ALIGNMENT_LEFT, -1, NETypography.SIZE_SMALL, color)
			break
	var player := _point(cartography.player_position)
	draw_circle(player, 7, NEColors.MAP_PAPER)
	draw_circle(player, 5, NEColors.MAP_PLAYER)
	draw_arc(player, 9, 0, TAU, 32, NEColors.MAP_PLAYER, 1.5, true)
	draw_string(font, Vector2(NEDimensions.SPACING_M, NEDimensions.SPACING_L), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, NETypography.SIZE_BODY, NEColors.MAP_INK)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var previous := zoom
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.5, 8.0)
			pan = event.position - size * 0.5 - (event.position - size * 0.5 - pan) * zoom / previous
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pan += event.relative
		else:
			_dragging = false
		accept_event()
	queue_redraw()
