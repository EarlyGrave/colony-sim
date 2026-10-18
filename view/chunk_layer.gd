class_name ChunkLayer
extends Node
## Splits the flat ground layers into CHUNK x CHUNK cell chunks. Each chunk is
## its own SubViewport (16 px per cell, so 512 px) that renders the shared
## 2D canvas of the map viewport through an offset canvas transform; chunks
## outside the camera are switched off. Also holds the pure chunk maths
## (cell -> chunk, dirty sets, culling) so it can be tested without a scene.

const CHUNK := 32  ## cells per chunk side
const PX := 16  ## texture pixels per cell

var cols := 0
var rows := 0
var map_w := 0
var map_h := 0
var viewports: Array[SubViewport] = []  # index = cy * cols + cx
var enabled: Array[bool] = []
var sizes: Array[Vector2i] = []  # region W2e: full pixel size of each chunk viewport
var update_calls := 0  ## chunk texture refreshes requested (perf counter)


static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))


static func chunk_count(cells: int) -> int:
	return ceili(float(cells) / CHUNK)


## Cell rect covered by a chunk, clipped to the map.
static func chunk_cells(ch: Vector2i, w: int, h: int) -> Rect2i:
	var pos := ch * CHUNK
	return Rect2i(pos, Vector2i(mini(CHUNK, w - pos.x), mini(CHUNK, h - pos.y)))


## Chunks whose pixels change when `cell` changes. The ground painter also
## re-shades the rows directly above and below (cliff / shadow), so an edit
## on a chunk border dirties both neighbours.
static func chunks_for_change(cell: Vector2i, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in [0, -1, 1]:
		var c: Vector2i = cell + Vector2i(0, dy)
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			continue
		var ch := chunk_of(c)
		if not out.has(ch):
			out.append(ch)
	return out


## Culling predicate: is `cell` inside `rect` (cell units) grown by `margin`?
static func cell_visible(cell: Vector2, rect: Rect2, margin: float) -> bool:
	return rect.grow(margin).has_point(cell)


## Chunks intersecting a cell rect (already grown by the caller), clipped to the map.
static func chunks_in_rect(rect: Rect2, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a := chunk_of(Vector2i(floori(rect.position.x), floori(rect.position.y)))
	var b := chunk_of(Vector2i(floori(rect.end.x), floori(rect.end.y)))
	for cy in range(maxi(a.y, 0), mini(b.y, chunk_count(h) - 1) + 1):
		for cx in range(maxi(a.x, 0), mini(b.x, chunk_count(w) - 1) + 1):
			out.append(Vector2i(cx, cy))
	return out


func index_of(ch: Vector2i) -> int:
	return ch.y * cols + ch.x


## Creates one viewport per chunk sharing `world_2d`.
func build(w: int, h: int, world_2d: World2D) -> void:
	clear()
	map_w = w
	map_h = h
	cols = chunk_count(w)
	rows = chunk_count(h)
	for cy in rows:
		for cx in cols:
			var ch := Vector2i(cx, cy)
			var r := chunk_cells(ch, w, h)
			var vp := SubViewport.new()
			vp.disable_3d = true
			vp.size = Vector2i.ONE  # region W2e: render target is only allocated while active
			sizes.append(r.size * PX)
			vp.world_2d = world_2d
			vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			add_child(vp)
			vp.canvas_transform = Transform2D(0.0, Vector2(-r.position * PX))
			viewports.append(vp)
			enabled.append(false)


func clear() -> void:
	for vp in viewports:
		vp.queue_free()
	viewports.clear()
	enabled.clear()
	sizes.clear()
	cols = 0
	rows = 0


func texture_of(ch: Vector2i) -> Texture2D:
	return viewports[index_of(ch)].get_texture()


## Switches chunk rendering on for exactly the given chunks.
func set_active(chunks: Array[Vector2i]) -> void:
	var want := {}
	for ch in chunks:
		want[index_of(ch)] = true
	for i in viewports.size():
		var on: bool = want.has(i)
		if on != enabled[i]:
			enabled[i] = on
			# region W2e: inactive chunks release their render target (1x1), active ones get the full size back
			viewports[i].size = sizes[i] if on else Vector2i.ONE
			viewports[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
			# endregion
