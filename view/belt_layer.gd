class_name BeltLayer
extends Node3D
## Belts and the items riding them. One MultiMesh per 32x32 chunk for belt
## tiles (animated by a shader, 1 draw call) and one for items (1 draw call).
## Reads sim state only. Cell (x, y) maps to the 3D unit square at (x, y).

const CHUNK := ChunkLayer.CHUNK
const BELT_Y := 0.02
const ITEM_Y := 0.05
const ITEM_SIZE := 0.42

const BELT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tile : filter_nearest, repeat_enable, source_color;
uniform float scroll = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
varying float d;
varying float dmg;  // T3
varying float nk;  // L2: node kind
varying float fm;  // L2: filter bitmask (bit0 left, bit1 front, bit2 right)
void vertex() { d = INSTANCE_CUSTOM.x; dmg = INSTANCE_CUSTOM.y; nk = INSTANCE_CUSTOM.z; fm = INSTANCE_CUSTOM.w; }
void fragment() {
	vec2 dv = vec2(0.0, -1.0);
	if (d > 0.5 && d < 1.5) dv = vec2(1.0, 0.0);
	else if (d > 1.5 && d < 2.5) dv = vec2(0.0, 1.0);
	else if (d > 2.5) dv = vec2(-1.0, 0.0);
	vec2 l = UV - vec2(0.5);
	float a = dot(l, dv);
	float b = dot(l, vec2(-dv.y, dv.x));
	vec3 col = mix(texture(tile, vec2(a + 0.5 - scroll, b + 0.5)).rgb, vec3(0.8, 0.15, 0.1), dmg * 0.6);  // T3
	// region L2: one glyph per node kind, drawn in flow-local coords (a = front, b = right)
	if (nk > 0.5) {
		float k = floor(nk + 0.5);
		float m = 0.0;
		vec3 gc = vec3(1.0);
		if (k < 1.5) { m = step(length(vec2(a, b)), 0.3); gc = vec3(1.0, 0.6, 0.15); }  // basic: disc
		else if (k < 2.5) { m = step(abs(a) + abs(b), 0.34); gc = vec3(0.3, 0.85, 1.0); }  // smart: diamond
		else if (k < 3.5) { m = step(abs(b), 0.34 - (a + 0.3) * 0.55) * step(-0.3, a) * step(a, 0.3); gc = vec3(1.0, 0.9, 0.2); }  // priority: arrow wedge
		else { m = step(max(abs(a), abs(b)), 0.28); gc = vec3(0.45, 0.95, 0.4); }  // merger: square
		col = mix(col, gc, m);
		float bits = floor(fm + 0.5);
		float f0 = mod(bits, 2.0);
		float f1 = mod(floor(bits / 2.0), 2.0);
		float f2 = floor(bits / 4.0);
		float dotm = max(max(f0 * step(length(vec2(a, b + 0.38)), 0.1), f1 * step(length(vec2(a - 0.38, b)), 0.1)), f2 * step(length(vec2(a, b - 0.38)), 0.1));
		col = mix(col, vec3(1.0), dotm);
	}
	// endregion
	ALBEDO = col * tint.rgb;
}
"""

const ITEM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 q = abs(UV - vec2(0.5)) * 2.0;
	float edge = max(q.x, q.y) > 0.82 ? 0.35 : 1.0;
	ALBEDO = COLOR.rgb * edge * tint.rgb;
}
"""

var sim: Simulation
var cols := 0
var rows := 0
var belt_mms: Array[MultiMeshInstance3D] = []
var item_mms: Array[MultiMeshInstance3D] = []
var rebuilds := 0  ## belt MultiMesh rebuilds (perf counter)
var _belt_mat: ShaderMaterial
var _item_mat: ShaderMaterial
var _last_dir := PackedByteArray()
var _l2_kind := PackedByteArray()  # region L2
var _l2_version := -1
var _dirty := {}
var _item_colors := {}  # item id -> Color
var _time := 0.0
var _active: Array[bool] = []


## Chunks (index list) containing at least one belt, from a dir array.
static func belt_cells_in_chunk(dir: PackedByteArray, w: int, h: int, ch: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := ChunkLayer.chunk_cells(ch, w, h)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if dir[y * w + x] != 255:
				out.append(Vector2i(x, y))
	return out


## World position of an item: slides from the entry edge to the exit edge of its cell.
static func item_position(c: Vector2i, d: int, progress: int, tpc: int) -> Vector3:
	var f := clampf(float(progress) / float(tpc), 0.0, 1.0) - 0.5
	var v: Vector2i = BeltGrid.DIRS[d]
	return Vector3(c.x + 0.5 + v.x * f * 0.8, ITEM_Y, c.y + 0.5 + v.y * f * 0.8)


func bind(p_sim: Simulation) -> void:
	clear()
	sim = p_sim
	var tex: Texture2D = load(WorldView.SPR + "belt_tile.png")
	_belt_mat = ShaderMaterial.new()
	_belt_mat.shader = Shader.new()
	_belt_mat.shader.code = BELT_SHADER
	_belt_mat.set_shader_parameter("tile", tex)
	_item_mat = ShaderMaterial.new()
	_item_mat.shader = Shader.new()
	_item_mat.shader.code = ITEM_SHADER
	var w := sim.map.width
	var h := sim.map.height
	cols = ChunkLayer.chunk_count(w)
	rows = ChunkLayer.chunk_count(h)
	for i in cols * rows:
		belt_mms.append(_make_mm(_belt_mat, false))
		item_mms.append(_make_mm(_item_mat, true))
		_active.append(true)
	_last_dir = PackedByteArray()
	_last_dir.resize(w * h)
	_last_dir.fill(255)
	_item_colors.clear()


func _make_mm(mat: Material, colors: bool) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = not colors
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = 0
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func clear() -> void:
	for n in belt_mms:
		n.queue_free()
	for n in item_mms:
		n.queue_free()
	belt_mms.clear()
	item_mms.clear()
	_active.clear()
	_dirty.clear()
	sim = null


## Belt instances currently drawn (all chunks), for tests / perf.
func belt_instance_total() -> int:
	var n := 0
	for m in belt_mms:
		n += m.multimesh.instance_count
	return n


func item_instance_total() -> int:
	var n := 0
	for m in item_mms:
		n += m.multimesh.instance_count
	return n


## Draw calls used by belts: one per chunk MultiMesh that has instances.
func draw_calls() -> int:
	var n := 0
	for m in belt_mms:
		n += 1 if m.multimesh.instance_count > 0 else 0
	for m in item_mms:
		n += 1 if m.multimesh.instance_count > 0 else 0
	return n


## view_chunks: chunk indices (ChunkLayer) currently on screen.
func sync(delta: float, tint: Color, view_chunks: Array[Vector2i]) -> void:
	if sim == null:
		return
	var belts := sim.logistics.belts
	_time += delta
	var cps := float(Simulation.TICKS_PER_SECOND) / float(belts.ticks_per_cell)
	_belt_mat.set_shader_parameter("scroll", fposmod(_time * cps, 1.0))
	_belt_mat.set_shader_parameter("tint", tint)
	_item_mat.set_shader_parameter("tint", tint)
	if belts.dir != _last_dir:
		var w := belts.width
		for ci in cols * rows:
			var ch := Vector2i(ci % cols, ci / cols)
			var r := ChunkLayer.chunk_cells(ch, w, belts.height)
			for y in range(r.position.y, r.end.y):
				var a := y * w + r.position.x
				if belts.dir.slice(a, a + r.size.x) != _last_dir.slice(a, a + r.size.x):
					_dirty[ci] = true
					break
		_last_dir = belts.dir.duplicate()
	_l2_sync_nodes(belts)  # region L2
	# region T3: damaged / repaired tiles re-tint their chunk
	for i: int in belts.hp_dirty:
		var cx := (i % belts.width) / ChunkLayer.CHUNK
		var cy := (i / belts.width) / ChunkLayer.CHUNK
		_dirty[cy * cols + cx] = true
	belts.hp_dirty.clear()
	# endregion
	for ci: int in _dirty.keys():
		_rebuild_belts(ci)
	_dirty.clear()
	var vis := {}
	for ch in view_chunks:
		if ch.x >= 0 and ch.y >= 0 and ch.x < cols and ch.y < rows:
			vis[ch.y * cols + ch.x] = true
	for ci in cols * rows:
		var on: bool = vis.has(ci)
		belt_mms[ci].visible = on
		item_mms[ci].visible = on
		if on and belts.item_count > 0:
			_update_items(ci)
		elif item_mms[ci].multimesh.instance_count > 0 and belts.item_count == 0:
			item_mms[ci].multimesh.instance_count = 0


func _rebuild_belts(ci: int) -> void:
	rebuilds += 1
	var belts := sim.logistics.belts
	var ch := Vector2i(ci % cols, ci / cols)
	var cells := belt_cells_in_chunk(belts.dir, belts.width, belts.height, ch)
	var mm := belt_mms[ci].multimesh
	mm.instance_count = cells.size()
	for i in cells.size():
		var c := cells[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x + 0.5, BELT_Y, c.y + 0.5)))
		mm.set_instance_custom_data(i, Color(float(belts.dir[c.y * belts.width + c.x]), 1.0 - belts.hp[c.y * belts.width + c.x] / belts.max_hp, _l2_kind_at(belts, c), _l2_mask_at(belts, c)))  # T3, L2


func _update_items(ci: int) -> void:
	var belts := sim.logistics.belts
	var w := belts.width
	var ch := Vector2i(ci % cols, ci / cols)
	var r := ChunkLayer.chunk_cells(ch, w, belts.height)
	var list: Array[int] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * w + x
			if belts.item[i] >= 0:
				list.append(i)
	var mm := item_mms[ci].multimesh
	if mm.instance_count != list.size():
		mm.instance_count = list.size()
	for k in list.size():
		var i := list[k]
		var pos := item_position(Vector2i(i % w, i / w), belts.dir[i], belts.progress[i], belts.ticks_per_cell)
		var bas := Basis().scaled(Vector3(ITEM_SIZE, 1.0, ITEM_SIZE))
		mm.set_instance_transform(k, Transform3D(bas, pos))
		mm.set_instance_color(k, _color_of(belts.item[i]))


func _color_of(id: int) -> Color:
	if not _item_colors.has(id):
		var nm := sim.logistics.item_name(id)
		_item_colors[id] = Color(String(sim.defs.items.get(nm, {}).get("color", "#cccccc")))
	return _item_colors[id]


# region L2
## Node kind at a cell (0 = plain belt). Needs BeltGrid.kind from L1; plain belts without it.
func _l2_kind_at(belts: BeltGrid, c: Vector2i) -> float:
	var k: Variant = belts.get("kind")
	return float((k as PackedByteArray)[c.y * belts.width + c.x]) if k != null else 0.0


## Bitmask of smart outputs with a non-"any" filter: 1 left, 2 front, 4 right.
func _l2_mask_at(belts: BeltGrid, c: Vector2i) -> float:
	var f: Variant = belts.get("filters")
	var i := c.y * belts.width + c.x
	if not (f is Dictionary) or not (f as Dictionary).has(i):
		return 0.0
	var m := 0
	var vals: PackedStringArray = (f as Dictionary)[i]
	for slot in mini(3, vals.size()):
		if vals[slot] != "any":
			m |= 1 << slot
	return float(m)


## Marks chunks dirty when node kinds or filters changed (only runs when belts.version moved).
func _l2_sync_nodes(belts: BeltGrid) -> void:
	var k: Variant = belts.get("kind")
	if k == null or belts.version == _l2_version:
		return
	_l2_version = belts.version
	var kinds: PackedByteArray = k
	var w := belts.width
	if _l2_kind.size() != kinds.size():
		_l2_kind.resize(kinds.size())
		_l2_kind.fill(0)
	for ci in cols * rows:
		var ch := Vector2i(ci % cols, ci / cols)
		var r := ChunkLayer.chunk_cells(ch, w, belts.height)
		for y in range(r.position.y, r.end.y):
			var a := y * w + r.position.x
			var hit := false
			for x in r.size.x:
				if kinds[a + x] != 0 or kinds[a + x] != _l2_kind[a + x]:
					hit = true
					break
			if hit:
				_dirty[ci] = true
				break
	_l2_kind = kinds.duplicate()
# endregion
