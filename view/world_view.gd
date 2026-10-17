class_name WorldView
extends Node2D
## Draws the simulation. Reads sim state only; never mutates it.

const TILE := 32.0
const COLOR_GROUND := Color("3b342a")
const COLOR_ROCK := Color("6e6b66")
const COLOR_DEPOSIT := Color("5b3f94")

var sim: Simulation
## First corner of a pending rectangle selection (or (-1,-1)).
var pending_corner := Vector2i(-1, -1)
## Cell highlighted by the last tap (inspector).
var selected_cell := Vector2i(-1, -1)
var _map_image: Image
var _map_sprite := Sprite2D.new()


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	_map_image = Image.create(sim.map.width, sim.map.height, false, Image.FORMAT_RGB8)
	for y in sim.map.height:
		for x in sim.map.width:
			_paint_cell(Vector2i(x, y))
	_map_sprite.texture = ImageTexture.create_from_image(_map_image)
	_map_sprite.centered = false
	_map_sprite.scale = Vector2(TILE, TILE)
	_map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_sprite.show_behind_parent = true
	if _map_sprite.get_parent() == null:
		add_child(_map_sprite)
	sim.bus.tile_changed.connect(_on_tile_changed)


func unbind() -> void:
	if sim and sim.bus.tile_changed.is_connected(_on_tile_changed):
		sim.bus.tile_changed.disconnect(_on_tile_changed)
	sim = null


func world_size() -> Vector2:
	return Vector2(sim.map.width, sim.map.height) * TILE


static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _on_tile_changed(c: Vector2i) -> void:
	_paint_cell(c)
	(_map_sprite.texture as ImageTexture).update(_map_image)


func _paint_cell(c: Vector2i) -> void:
	var col := COLOR_GROUND
	match sim.map.get_tile(c):
		MapGrid.Tile.ROCK:
			col = COLOR_ROCK
		MapGrid.Tile.DEPOSIT:
			col = COLOR_DEPOSIT.lightened(clampf(sim.map.get_deposit_amount(c) / 120.0, 0.0, 0.4))
	# Subtle checker so the grid is readable without lines.
	if (c.x + c.y) % 2 == 0:
		col = col.darkened(0.06)
	_map_image.set_pixelv(c, col)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	_draw_zones()
	_draw_designations()
	_draw_items()
	_draw_buildings()
	_draw_colonists()
	_draw_enemies()
	_draw_shots()
	_draw_selection()


func _draw_zones() -> void:
	for zone_id: String in sim.items.zone_cells:
		var col := Color(sim.defs.zones[zone_id]["color"])
		col.a = 0.35
		for c: Vector2i in sim.items.zone_cells[zone_id]:
			draw_rect(Rect2(cell_to_world(c) + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), col)


func _draw_designations() -> void:
	var m := sim.map
	for i in m.mine_designated.size():
		if m.mine_designated[i] != 0:
			var p := cell_to_world(Vector2i(i % m.width, i / m.width))
			draw_line(p + Vector2(6, 6), p + Vector2(TILE - 6, TILE - 6), Color(1, 0.85, 0.3), 3.0)
			draw_line(p + Vector2(TILE - 6, 6), p + Vector2(6, TILE - 6), Color(1, 0.85, 0.3), 3.0)


func _draw_items() -> void:
	for c: Vector2i in sim.items.stacks:
		var st: Dictionary = sim.items.stacks[c]
		var col := Color(sim.defs.items[st["item"]]["color"])
		var frac := clampf(float(st["count"]) / sim.defs.item_stack(st["item"]), 0.15, 1.0)
		var s := lerpf(8.0, TILE - 8.0, frac)
		var p := cell_to_world(c) + Vector2(TILE - s, TILE - s) * 0.5
		draw_rect(Rect2(p, Vector2(s, s)), col)
		draw_rect(Rect2(p, Vector2(s, s)), Color(0, 0, 0, 0.6), false, 1.0)


func _draw_buildings() -> void:
	for b: Building in sim.buildings.list:
		var r := Rect2(cell_to_world(b.cell) + Vector2(2, 2), Vector2(b.size) * TILE - Vector2(4, 4))
		var col := Color(b.def["color"])
		if b.broken:
			col = col.darkened(0.55)
		draw_rect(r, col)
		draw_rect(r, Color(0, 0, 0, 0.8), false, 2.0)
		# HP bar (top) and condition bar (bottom) for machines.
		_bar(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 5)), b.hp / b.max_hp, Color(0.85, 0.2, 0.2))
		if b.is_machine():
			_bar(Rect2(r.position + Vector2(2, r.size.y - 7), Vector2(r.size.x - 4, 5)), b.condition / 100.0, Color(0.9, 0.75, 0.2))
		if not b.recipe.is_empty() and b.progress > 0:
			var f := float(b.progress) / int(b.recipe["work_ticks"])
			draw_arc(r.get_center(), 10, -PI / 2, -PI / 2 + TAU * f, 24, Color.WHITE, 3.0)
		if b.broken:
			draw_line(r.position, r.end, Color(1, 0.3, 0.2), 3.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(1, 0.3, 0.2), 3.0)


func _draw_colonists() -> void:
	for c: Colonist in sim.colonists.list:
		if not c.alive or c.hidden:
			continue
		var p := c.visual_pos() * TILE + Vector2(TILE, TILE) * 0.5
		var body := Color(0.7, 0.9, 0.55) if c.is_sick(sim.tick) else Color(0.95, 0.9, 0.8)
		draw_circle(p, TILE * 0.36, body)
		var ring := Color(0.25, 0.55, 1.0) if c.engineer else Color(0.1, 0.1, 0.1)
		draw_arc(p, TILE * 0.36, 0, TAU, 20, ring, 3.0 if c.engineer else 2.0)
		if c.carry_count > 0:
			draw_rect(Rect2(p + Vector2(4, -14), Vector2(10, 10)), Color(sim.defs.items[c.carry_item]["color"]))
		if c.hp < c.max_hp:
			_bar(Rect2(p + Vector2(-12, 14), Vector2(24, 4)), c.hp / c.max_hp, Color(0.85, 0.2, 0.2))


func _draw_enemies() -> void:
	for e: Enemy in sim.threats.enemies:
		var p := e.visual_pos() * TILE + Vector2(TILE, TILE) * 0.5
		var r := TILE * (0.42 if e.def_id == "brute" else 0.3)
		var col := Color(e.def["color"])
		if e.leaving:
			col.a = 0.5
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, r * 0.8), p + Vector2(-r, r * 0.8)]), col)
		if e.hp < e.max_hp:
			_bar(Rect2(p + Vector2(-12, r + 2), Vector2(24, 4)), e.hp / e.max_hp, Color(0.9, 0.3, 0.3))


func _draw_shots() -> void:
	for s: Array in sim.threats.shots:
		var a: Vector2 = s[0] * TILE + Vector2(TILE, TILE) * 0.5
		var b: Vector2 = s[1] * TILE + Vector2(TILE, TILE) * 0.5
		draw_line(a, b, Color(1, 0.95, 0.5, 0.9), 2.0)


func _draw_selection() -> void:
	if pending_corner.x >= 0:
		draw_rect(Rect2(cell_to_world(pending_corner), Vector2(TILE, TILE)), Color(1, 1, 1, 0.9), false, 3.0)
	if selected_cell.x >= 0:
		draw_rect(Rect2(cell_to_world(selected_cell), Vector2(TILE, TILE)), Color(0.4, 0.9, 1.0, 0.9), false, 2.0)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
