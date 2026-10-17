class_name WorldView
extends Node2D
## Draws the simulation. Reads sim state only; never mutates it.

const TILE := 32.0
const COLOR_GROUND := Color("3b342a")
const COLOR_ROCK := Color("6e6b66")
const COLOR_DEPOSIT := Color("5b3f94")

var sim: Simulation
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
