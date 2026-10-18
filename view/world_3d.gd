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
uniform vec2 map_size;
varying vec3 wpos;
varying vec3 wnormal;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 xz = wpos.xz - wnormal.xz * 0.02;
	vec3 c = texture(map_tex, xz / map_size).rgb;
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

var _ground := MeshInstance3D.new()
var _blocks := MultiMeshInstance3D.new()
var _ground_mat := ShaderMaterial.new()
var _block_mat := ShaderMaterial.new()
var _blocks_dirty := true
var _wall_key := 0
var _units := {}  # "c<id>" / "e<id>" -> Sprite3D
var _carry := {}  # colonist id -> Sprite3D
var _facing := {}  # key -> [last_pos: Vector2, row: int, moving_until: float]
var _tex := {}
var _time := 0.0
var _tint := Color.WHITE


func _ready() -> void:
	for n in ["colonist_sheet", "colonist_sick_sheet", "colonist_engineer_sheet", "colonist_engineer_sick_sheet",
			"crawler", "brute", "spitter", "burrower", "item_ore", "item_refined", "item_waste", "item_raw_food", "item_meal"]:
		_tex[n] = load(WorldView.SPR + n + ".png")
	var gs := Shader.new()
	gs.code = GROUND_SHADER
	_ground_mat.shader = gs
	var bs := Shader.new()
	bs.code = BLOCK_SHADER
	_block_mat.shader = bs
	_ground.material_override = _ground_mat
	_blocks.material_override = _block_mat
	add_child(_ground)
	add_child(_blocks)
	_g1c_ready()  # region G1c


func bind(p_sim: Simulation, map_tex: Texture2D) -> void:
	sim = p_sim
	var size := Vector2(sim.map.width, sim.map.height)
	var plane := PlaneMesh.new()
	plane.size = size
	_ground.mesh = plane
	_ground.position = Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	_ground_mat.set_shader_parameter("map_tex", map_tex)
	_block_mat.set_shader_parameter("map_tex", map_tex)
	_block_mat.set_shader_parameter("map_size", size)
	_clear_units()
	_blocks_dirty = true
	sim.bus.tile_changed.connect(_on_tile_changed)
	_g1c_bind()  # region G1c
	if overlay and not overlay.draw.is_connected(_draw_overlay):
		overlay.draw.connect(_draw_overlay)


func unbind() -> void:
	if sim and sim.bus.tile_changed.is_connected(_on_tile_changed):
		sim.bus.tile_changed.disconnect(_on_tile_changed)
	_clear_units()
	sim = null


func _on_tile_changed(_c: Vector2i) -> void:
	_blocks_dirty = true


func _clear_units() -> void:
	for s: Node in _units.values():
		s.queue_free()
	_units.clear()
	_carry.clear()
	_facing.clear()


# --- Blocks -------------------------------------------------------------------

func _rebuild_blocks() -> void:
	var cells: Array[Vector3] = []  # x, z, height
	var m := sim.map
	for y in m.height:
		for x in m.width:
			var t := m.get_tile(Vector2i(x, y))
			if t == MapGrid.Tile.ROCK or t == MapGrid.Tile.DEPOSIT:
				cells.append(Vector3(x, y, ROCK_HEIGHT))
	for b: Building in sim.buildings.list:
		if b.def_id == "wall":
			cells.append(Vector3(b.cell.x, b.cell.y, WALL_HEIGHT))
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
	_blocks.multimesh = mm
	_blocks_dirty = false


func _walls_signature() -> int:
	var h := 0
	for b: Building in sim.buildings.list:
		if b.def_id == "wall":
			h = (h * 31 + b.id + 7) % 1000000007
	return h


# --- Frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if sim == null:
		return
	var key := _walls_signature()
	if key != _wall_key:
		_wall_key = key
		_blocks_dirty = true
	if _blocks_dirty:
		_rebuild_blocks()
	_update_tint()
	_g1c_update()  # region G1c
	var seen := {}
	for c: Colonist in sim.colonists.list:
		var k := "c%d" % c.id
		if not c.alive or c.hidden:
			continue
		seen[k] = true
		_update_colonist(k, c)
	for e: Enemy in sim.threats.enemies:
		var k := "e%d" % e.id
		seen[k] = true
		_update_enemy(k, e)
	for k: String in _units.keys():
		if not seen.has(k):
			(_units[k] as Node).queue_free()
			_units.erase(k)
			_facing.erase(k)
	for id: int in _carry.keys():
		if not seen.has("c%d" % id):
			_carry.erase(id)
	if overlay:
		overlay.queue_redraw()


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


func _sprite(k: String) -> Sprite3D:
	if _units.has(k):
		return _units[k]
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
func _face(k: String, p: Vector2) -> Array:
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


func _update_colonist(k: String, c: Colonist) -> void:
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


func _update_enemy(k: String, e: Enemy) -> void:
	var s := _sprite(k)
	s.texture = _tex.get(e.def_id, _tex["crawler"])
	var p := e.visual_pos() + Vector2(0.5, 0.5)
	var f := _face(k, p)
	s.flip_h = int(f[1]) == ROW_LEFT
	var big := 1.5 if e.def_id == "brute" else 1.0
	s.pixel_size = UNIT_PX * big
	var wobble := absf(sin(_time * 10.0 + e.id)) * 0.06
	s.position = Vector3(p.x, wobble, p.y + 0.05)
	var mod := _tint
	if e.leaving:
		mod.a = 0.55
	s.modulate = mod


# --- Screen overlay -------------------------------------------------------------

func _draw_overlay() -> void:
	if sim == null or camera == null:
		return
	for c: Colonist in sim.colonists.list:
		if not c.alive or c.hidden:
			continue
		var p := c.visual_pos() + Vector2(0.5, 0.5)
		if c.combat != null and c.combat.drafted:
			var top := camera.cell_to_screen(Vector3(p.x, 1.55, p.y))
			overlay.draw_colored_polygon(PackedVector2Array([top + Vector2(0, 10), top + Vector2(-7, -2), top + Vector2(7, -2)]), Color(0.95, 0.15, 0.15))
		if c.hp < c.max_hp:
			_bar(camera.cell_to_screen(Vector3(p.x, 0.0, p.y + 0.35)), c.hp / c.max_hp, Color(0.9, 0.25, 0.25))
	for e: Enemy in sim.threats.enemies:
		if e.hp < e.max_hp:
			var p := e.visual_pos() + Vector2(0.5, 0.5)
			_bar(camera.cell_to_screen(Vector3(p.x, 0.0, p.y + 0.35)), e.hp / e.max_hp, Color(0.95, 0.35, 0.3))


func _bar(center: Vector2, frac: float, col: Color) -> void:
	var r := Rect2(center - Vector2(13, 0), Vector2(26, 4))
	overlay.draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	overlay.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)


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
	for k: String in _units:
		var s: Sprite3D = _units[k]
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
