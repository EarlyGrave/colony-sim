class_name WorldView3D
extends Node3D
## Pseudo-3D presentation of the world. The flat layers (terrain, zones,
## items, overlays) are drawn by WorldView into an off-screen SubViewport and
## shown as a textured ground plane; rock and walls are raised blocks whose
## tops sample the same texture; colonists and creatures are standing pixel
## sprites (colonists have 4-direction walk sheets). One cell = one 3D unit.
## Reads sim state only; never mutates it.

const ROCK_HEIGHT := 0.75
const WALL_HEIGHT := 0.65
const UNIT_PX := 1.25 / 16.0  ## Sprite3D pixel_size: a 16 px colonist is 1.25 cells tall
## Sheet rows: down, left, right, up. Columns: idle, step A, step B.
const ROW_DOWN := 0
const ROW_LEFT := 1
const ROW_RIGHT := 2
const ROW_UP := 3
const WALK_CYCLE: Array[int] = [1, 0, 2, 0]

const GROUND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D map_tex : filter_nearest, source_color;
void fragment() {
	ALBEDO = texture(map_tex, UV).rgb;
}
"""

## Blocks sample the map texture at their world xz, so tops show the rock/ore
## or wall pixel art; sides are darker, south faces lit a bit more.
const BLOCK_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform sampler2D map_tex : filter_nearest, source_color;
uniform vec2 map_size;  // chunk size in cells
uniform vec2 map_origin;  // chunk origin in cells
varying vec3 wpos;
varying vec3 wnormal;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 xz = wpos.xz - wnormal.xz * 0.02;
	vec3 c = texture(map_tex, clamp((xz - map_origin) / map_size, vec2(0.0), vec2(1.0))).rgb;
	float shade = 1.0;
	if (wnormal.y < 0.5) {
		shade = wnormal.z > 0.5 ? 0.62 : 0.45;
		shade *= mix(0.7, 1.0, clamp(wpos.y / 0.75, 0.0, 1.0));
	}
	ALBEDO = c * shade;
}
"""

var sim: Simulation
var camera: CameraController
var overlay: Node2D  ## screen-space bars and markers, drawn over the 3D scene

var chunks := ChunkLayer.new()  ## ground chunk viewports
var _ground_shader: Shader
var _block_shader: Shader
var _chunk_nodes: Array[Node3D] = []  # per chunk: ground + blocks holder
var _blocks: Array[MultiMeshInstance3D] = []  # per chunk
var _blocks_dirty := {}  # chunk index -> true
var _wall_keys := {}  # chunk index -> wall signature
var block_rebuilds := 0  ## chunk block MultiMeshes rebuilt (perf counter)
var view_rect := Rect2(-1e6, -1e6, 2e6, 2e6)  ## visible cells, refreshed per frame
const CULL_MARGIN := 3.0  ## cells around the view where sprites stay alive
var _seen := {}  # region W2c: reused per-frame scratch
var _units := {}  # int key (colonist id * 2, enemy id * 2 + 1) -> Sprite3D
var _carry := {}  # colonist id -> Sprite3D
var _facing := {}  # int key -> [last_pos: Vector2, row: int, moving_until: float]
var _tex := {}
var _time := 0.0
var _tint := Color.WHITE
var world_view: WorldView  # region G1b: source of turret aim
var _buildings3d := Building3D.new()  # region G1b
var _belt_layer := BeltLayer.new()  # region A2c


func _ready() -> void:
	for n in ["colonist_sheet", "colonist_sick_sheet", "colonist_engineer_sheet", "colonist_engineer_sick_sheet",
			"crawler", "brute", "spitter", "burrower", "item_ore", "item_refined", "item_waste", "item_raw_food", "item_meal"]:
		_tex[n] = load(WorldView.SPR + n + ".png")
	_ground_shader = Shader.new()
	_ground_shader.code = GROUND_SHADER
	_block_shader = Shader.new()
	_block_shader.code = BLOCK_SHADER
	add_child(chunks)
	_g1c_ready()  # region G1c
	add_child(_buildings3d)  # region G1b
	add_child(_belt_layer)  # region A2c


func bind(p_sim: Simulation, world_2d: World2D) -> void:
	sim = p_sim
	_build_chunks(world_2d)
	_clear_units()
	_buildings3d.clear()  # region G1b
	_g1d_bind()  # region G1d hook
	sim.bus.tile_changed.connect(_on_tile_changed)
	_g1c_bind()  # region G1c
	_belt_layer.bind(sim)  # region A2c
	if overlay and not overlay.draw.is_connected(_draw_overlay):
		overlay.draw.connect(_draw_overlay)


func unbind() -> void:
	if _g1d_fx != null:
		_g1d_fx.unbind()  # region G1d hook
	if sim and sim.bus.tile_changed.is_connected(_on_tile_changed):
		sim.bus.tile_changed.disconnect(_on_tile_changed)
	_clear_units()
	_buildings3d.clear()  # region G1b
	_belt_layer.clear()  # region A2c
	sim = null


func _on_tile_changed(c: Vector2i) -> void:
	if sim.map.in_bounds(c):
		_blocks_dirty[chunks.index_of(ChunkLayer.chunk_of(c))] = true


func _build_chunks(world_2d: World2D) -> void:
	for n in _chunk_nodes:
		n.queue_free()
	_chunk_nodes.clear()
	_blocks.clear()
	_blocks_dirty.clear()
	_wall_keys.clear()
	var w := sim.map.width
	var h := sim.map.height
	chunks.build(w, h, world_2d)
	for cy in chunks.rows:
		for cx in chunks.cols:
			var ch := Vector2i(cx, cy)
			var r := ChunkLayer.chunk_cells(ch, w, h)
			var tex := chunks.texture_of(ch)
			var gm := ShaderMaterial.new()
			gm.shader = _ground_shader
			gm.set_shader_parameter("map_tex", tex)
			var bm := ShaderMaterial.new()
			bm.shader = _block_shader
			bm.set_shader_parameter("map_tex", tex)
			bm.set_shader_parameter("map_size", Vector2(r.size))
			bm.set_shader_parameter("map_origin", Vector2(r.position))
			var holder := Node3D.new()
			var ground := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(r.size)
			ground.mesh = plane
			ground.position = Vector3(r.position.x + r.size.x * 0.5, 0.0, r.position.y + r.size.y * 0.5)
			ground.material_override = gm
			holder.add_child(ground)
			var blocks := MultiMeshInstance3D.new()
			blocks.material_override = bm
			holder.add_child(blocks)
			add_child(holder)
			_chunk_nodes.append(holder)
			_blocks.append(blocks)
			_blocks_dirty[_blocks.size() - 1] = true


func _clear_units() -> void:
	for s: Node in _units.values():
		s.queue_free()
	_units.clear()
	_carry.clear()
	_facing.clear()


# --- Blocks -------------------------------------------------------------------

func _rebuild_chunk_blocks(idx: int) -> void:
	var ch := Vector2i(idx % chunks.cols, idx / chunks.cols)
	var cells: Array[Vector3] = []  # x, z, height
	var m := sim.map
	var r := ChunkLayer.chunk_cells(ch, m.width, m.height)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := m.get_tile(Vector2i(x, y))
			if t == MapGrid.Tile.ROCK or t == MapGrid.Tile.DEPOSIT:
				cells.append(Vector3(x, y, ROCK_HEIGHT))
	for b: Building in sim.buildings.list:
		if b.def_id == "wall" and ChunkLayer.chunk_of(b.cell) == ch:
			cells.append(Vector3(b.cell.x, b.cell.y, WALL_HEIGHT))
	block_cells_last = cells.size()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = cells.size()
	for i in cells.size():
		var c := cells[i]
		var basis := Basis.from_scale(Vector3(1.0, c.z, 1.0))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(c.x + 0.5, c.z * 0.5, c.y + 0.5)))
	_blocks[idx].multimesh = mm
	_blocks_dirty.erase(idx)
	block_rebuilds += 1


var block_cells_last := 0


## Per-chunk wall signatures; chunks whose walls changed get rebuilt.
func _walls_signatures() -> Dictionary:
	var sigs := {}
	for b: Building in sim.buildings.list:
		if b.def_id == "wall":
			var i := chunks.index_of(ChunkLayer.chunk_of(b.cell))
			sigs[i] = (int(sigs.get(i, 0)) * 31 + b.id + 7) % 1000000007
	return sigs


## All solid-block cells (rock, deposits, walls) of every chunk, for tests.
func block_instance_total() -> int:
	var n := 0
	for mmi in _blocks:
		if mmi.multimesh != null:
			n += mmi.multimesh.instance_count
	return n


# --- Frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if sim == null:
		return
	var sigs := _walls_signatures()
	for i in chunks.viewports.size():
		if int(sigs.get(i, 0)) != int(_wall_keys.get(i, 0)):
			_blocks_dirty[i] = true
	_wall_keys = sigs
	for i: int in _blocks_dirty.keys():
		_rebuild_chunk_blocks(i)
	_update_view_rect()
	_update_tint()
	_g1c_update()  # region G1c
	_buildings3d.sync(sim, _aim_of, _tint)  # region G1b
	_a2c_update(delta)  # region A2c
	# region W2c
	var seen := _seen
	seen.clear()
	for c: Colonist in sim.colonists.list:
		var k := c.id * 2
		if not c.alive or c.hidden:
			continue
		seen[k] = true
		if not _in_view(c.visual_pos() + Vector2(0.5, 0.5)):
			_cull(k)
			continue
		_update_colonist(k, c)
	for e: Enemy in sim.threats.enemies:
		var k := e.id * 2 + 1
		seen[k] = true
		if not _in_view(e.visual_pos() + Vector2(0.5, 0.5)):
			_cull(k)
			continue
		_update_enemy(k, e)
	for k: int in _units.keys():
		if not seen.has(k):
			(_units[k] as Node).queue_free()
			_units.erase(k)
			_facing.erase(k)
	for id: int in _carry.keys():
		if not seen.has(id * 2):
			_carry.erase(id)
	# endregion
	if overlay:
		overlay.queue_redraw()


func _update_view_rect() -> void:
	if camera != null and camera.is_inside_tree():
		view_rect = camera.visible_cell_rect()
	var margin := ChunkLayer.CHUNK * 0.25
	chunks.set_active(ChunkLayer.chunks_in_rect(view_rect.grow(margin), sim.map.width, sim.map.height))


func _in_view(p: Vector2) -> bool:
	return ChunkLayer.cell_visible(p, view_rect, CULL_MARGIN)


## Night and contamination tint for the standing sprites (the ground gets it
## from WorldView's own drawing).
func _update_tint() -> void:
	var t := Color.WHITE.lerp(Color(0.78, 1.0, 0.7), clampf(sim.contamination.fraction() * 1.5, 0.0, 0.8))
	var cfg: Dictionary = sim.defs.time
	var dark := 1.0 - sim.clock.daylight()
	if dark > 0.01:
		var night := Color(str(cfg["night_tint"]))
		t = t.lerp(Color(t.r * night.r, t.g * night.g, t.b * night.b), float(cfg["night_tint_alpha"]) * dark)
	_tint = t


func _cull(k: int) -> void:
	if _units.has(k):
		(_units[k] as Sprite3D).visible = false


func _sprite(k: int) -> Sprite3D:
	if _units.has(k):
		var u: Sprite3D = _units[k]
		u.visible = true
		return u
	var s := Sprite3D.new()
	s.pixel_size = UNIT_PX
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.offset = Vector2(0, 8)  # feet on the ground
	add_child(s)
	_units[k] = s
	return s


## Facing row from movement on screen (camera always looks north).
func _face(k: int, p: Vector2) -> Array:
	var f: Array = _facing.get(k, [p, ROW_DOWN, 0.0])
	var d: Vector2 = p - Vector2(f[0])
	if d.length() > 0.0005:
		if absf(d.x) > absf(d.y):
			f[1] = ROW_RIGHT if d.x > 0 else ROW_LEFT
		else:
			f[1] = ROW_DOWN if d.y > 0 else ROW_UP
		f[2] = _time + 0.15
	f[0] = p
	_facing[k] = f
	return f


func _update_colonist(k: int, c: Colonist) -> void:
	var s := _sprite(k)
	var name := "colonist"
	if c.engineer:
		name += "_engineer"
	if c.is_sick(sim.tick):
		name += "_sick"
	s.texture = _tex[name + "_sheet"]
	s.hframes = 3
	s.vframes = 4
	var p := c.visual_pos() + Vector2(0.5, 0.5)
	var f := _face(k, p)
	var moving := _time < float(f[2]) or not c.path.is_empty()
	var col := WALK_CYCLE[int(_time * 8.0 + c.id) % WALK_CYCLE.size()] if moving else 0
	s.frame = int(f[1]) * 3 + col
	s.position = Vector3(p.x, 0.0, p.y + 0.05)
	s.modulate = _tint
	if c.carry_count > 0:
		var cs: Sprite3D = _carry.get(c.id)
		if cs == null:
			cs = Sprite3D.new()
			cs.pixel_size = UNIT_PX * 0.6
			cs.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			cs.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			cs.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			cs.shaded = false
			cs.position = Vector3(0, 1.35, 0.02)
			s.add_child(cs)
			_carry[c.id] = cs
		cs.texture = _tex.get(WorldView.ITEM_SPRITES.get(c.carry_item, "item_ore"), _tex["item_ore"])
		cs.modulate = _tint
		cs.visible = true
	elif _carry.has(c.id):
		(_carry[c.id] as Sprite3D).visible = false


func _update_enemy(k: int, e: Enemy) -> void:
	var s := _sprite(k)
	var p := e.visual_pos() + Vector2(0.5, 0.5)
	var f := _face(k, p)
	if not _update_enemy_sheet(s, e, f):  # region G1a
		s.texture = _tex.get(e.def_id, _tex["crawler"])
		s.hframes = 1
		s.vframes = 1
		s.frame = 0
		s.flip_h = int(f[1]) == ROW_LEFT
	var big := 1.5 if e.def_id == "brute" else 1.0
	s.pixel_size = UNIT_PX * big
	var wobble := absf(sin(_time * 10.0 + e.id)) * 0.06
	s.position = Vector3(p.x, wobble, p.y + 0.05)
	var mod := _tint
	if e.leaving:
		mod.a = 0.55
	s.modulate = mod


# region G1a
func _update_enemy_sheet(s: Sprite3D, e: Enemy, f: Array) -> bool:
	var tex := CreatureSheets.get_sheet(e.def_id)
	if tex == null:
		return false
	s.texture = tex
	s.hframes = CreatureSheets.COLS
	s.vframes = CreatureSheets.ROWS
	s.flip_h = false
	var moving := _time < float(f[2])
	var col := WALK_CYCLE[int(_time * 8.0 + e.id) % WALK_CYCLE.size()] if moving else 0
	s.frame = CreatureSheets.frame_index(int(f[1]), col)
	return true
# endregion


# --- Screen overlay -------------------------------------------------------------

func _draw_overlay() -> void:
	if sim == null or camera == null:
		return
	for c: Colonist in sim.colonists.list:
		if not c.alive or c.hidden:
			continue
		var p := c.visual_pos() + Vector2(0.5, 0.5)
		if not _in_view(p):
			continue
		if c.combat != null and c.combat.drafted:
			var top := camera.cell_to_screen(Vector3(p.x, 1.55, p.y))
			overlay.draw_colored_polygon(PackedVector2Array([top + Vector2(0, 10), top + Vector2(-7, -2), top + Vector2(7, -2)]), Color(0.95, 0.15, 0.15))
		if c.hp < c.max_hp:
			_bar(camera.cell_to_screen(Vector3(p.x, 0.0, p.y + 0.35)), c.hp / c.max_hp, Color(0.9, 0.25, 0.25))
	for e: Enemy in sim.threats.enemies:
		if e.hp < e.max_hp:
			var p := e.visual_pos() + Vector2(0.5, 0.5)
			if not _in_view(p):
				continue
			_bar(camera.cell_to_screen(Vector3(p.x, 0.0, p.y + 0.35)), e.hp / e.max_hp, Color(0.95, 0.35, 0.3))


func _bar(center: Vector2, frac: float, col: Color) -> void:
	var r := Rect2(center - Vector2(13, 0), Vector2(26, 4))
	overlay.draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	overlay.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)


# region G1d
var _g1d_fx: Effects3D


func _g1d_bind() -> void:
	if _g1d_fx == null:
		_g1d_fx = Effects3D.new()
		add_child(_g1d_fx)
	_g1d_fx.bind(sim)
# endregion


# region G1c atmosphere, shadows, selection ring, standing item piles
const SHADOW_BLOB := "res://assets/sprites/shadow_blob.png"
const MAX_PILES := 300  ## cap on standing item sprites
const PILE_SIZE := 0.62  ## cells; a 16 px item sprite
const PILE_TEX := {"essence_ore": "item_ore", "refined_essence": "item_refined", "waste": "item_waste",
		"raw_food": "item_raw_food", "meal": "item_meal"}

## Colonist id shown with the selection ring (set by GameController); -1 = none.
var selected_colonist := -1:
	set(v):
		selected_colonist = v
		if marker:
			marker.select(v)

var atmosphere: Atmosphere
var marker: SelectionMarker
var _shadows := MultiMeshInstance3D.new()
var _piles_root := Node3D.new()
var _piles: Array[Sprite3D] = []
var _pile_frame := 0


func _g1c_ready() -> void:
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	marker = SelectionMarker.new()
	add_child(marker)
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	_shadows.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load(SHADOW_BLOB)
	m.disable_fog = true
	_shadows.material_override = m
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadows)
	add_child(_piles_root)


func _g1c_bind() -> void:
	atmosphere.configure(Vector2(sim.map.width, sim.map.height))
	selected_colonist = -1
	marker.clear()
	_pile_frame = 0


func _g1c_update() -> void:
	atmosphere.set_tint(_tint)
	marker.refresh(sim)
	# One blob per unit, in one MultiMesh.
	var spots: Array[Vector3] = []  # x, z, size
	for k: int in _units:
		var s: Sprite3D = _units[k]
		if not s.visible:
			continue
		spots.append(Vector3(s.position.x, s.position.z, 1.5 if s.pixel_size > UNIT_PX * 1.2 else 0.95))
	var mm := _shadows.multimesh
	if mm.instance_count != spots.size():
		mm.instance_count = spots.size()
	for i in spots.size():
		var sp := spots[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(sp.z, 1.0, sp.z * 0.7)), Vector3(sp.x, 0.03, sp.y - 0.02)))
	_pile_frame += 1
	if _pile_frame % 10 == 1:
		_update_piles()


## Upright item sprites for ground stacks, capped at MAX_PILES.
func _update_piles() -> void:
	var n := 0
	for c: Vector2i in sim.items.stacks:
		if n >= MAX_PILES:
			break
		if not _in_view(Vector2(c) + Vector2(0.5, 0.5)):
			continue
		var st: Dictionary = sim.items.stacks[c]
		var cnt := int(st["count"])
		var s: Sprite3D
		if n < _piles.size():
			s = _piles[n]
		else:
			s = Sprite3D.new()
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			s.shaded = false
			s.offset = Vector2(0, 5)
			_piles_root.add_child(s)
			_piles.append(s)
		s.texture = _tex.get(PILE_TEX.get(st["item"], "item_ore"), _tex["item_ore"])
		s.pixel_size = PILE_SIZE / 16.0 * (1.0 + 0.25 * float(int(cnt >= 15) + int(cnt >= 35)))
		s.position = Vector3(c.x + 0.5, 0.0, c.y + 0.62)
		s.modulate = _tint
		s.visible = true
		n += 1
	for i in range(n, _piles.size()):
		_piles[i].visible = false
# endregion


# region G1b
func _aim_of(id: int) -> float:
	return world_view.turret_aim(id) if world_view else -PI / 2
# endregion


# region A2c
func _a2c_update(delta: float) -> void:
	var vis := ChunkLayer.chunks_in_rect(view_rect.grow(ChunkLayer.CHUNK * 0.25), sim.map.width, sim.map.height)
	_belt_layer.sync(delta, _tint, vis)
# endregion
