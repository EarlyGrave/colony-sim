class_name PowerLayer
extends Node3D
## L4: pole wires. Thin 3D boxes between linked poles / buildings, one MultiMesh per 32x32 chunk
## (1 draw call per chunk). Rebuilt only when the grid version or the overlay flag changes; with the
## overlay on, wire colours (net palette, brownout red) refresh once a second. Reads sim state only.

const CHUNK := ChunkLayer.CHUNK
const POLE_TOP := 1.4
const THIN := 0.035
const THICK := 0.08
const WIRE_BASE := Color("#23232a")

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() { ALBEDO = COLOR.rgb * tint.rgb; }
"""

var sim: Simulation
var _shader: Shader
var _mms := {}  # chunk Vector2i -> MultiMeshInstance3D
var _badges: Array[Label3D] = []
var _stamp := -2
var _was_overlay := false
var _msec := 0
var wire_count := 0  ## wires drawn (tests / bench)


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	clear()


func clear() -> void:
	for mm: MultiMeshInstance3D in _mms.values():
		mm.queue_free()
	_mms.clear()
	for l in _badges:
		l.visible = false
	_stamp = -2
	wire_count = 0


## Number of MultiMesh draw calls the wires use (one per populated chunk).
func draw_calls() -> int:
	return _mms.size()


func _end_pos(b: Building) -> Vector3:
	var y := POLE_TOP - 0.1 if b.def_id == PowerReader.POLE else clampf(Building3D.height_of(b.def_id), 0.4, 1.2)
	return Vector3(b.cell.x + b.size.x * 0.5, y, b.cell.y + b.size.y * 0.5)


func sync(tint: Color) -> void:
	if sim == null:
		return
	for mmi: MultiMeshInstance3D in _mms.values():
		(mmi.material_override as ShaderMaterial).set_shader_parameter("tint", tint)
	var ver := PowerReader.version(sim)
	var ov := PowerReader.overlay_on
	var now := Time.get_ticks_msec()
	var stale := ov and now - _msec >= PowerReader.REFRESH_MSEC
	if ver == _stamp and ov == _was_overlay and not stale:
		return
	_stamp = ver
	_was_overlay = ov
	_msec = now
	_rebuild(tint)


func _rebuild(tint: Color) -> void:
	var ov := PowerReader.overlay_on
	PowerReader.refresh(sim, true)
	var buckets := {}  # chunk -> Array of [Transform3D, Color]
	var n := 0
	for l: Variant in PowerReader.links(sim):
		var a := sim.buildings.get_by_id(int(l[0]))
		var b := sim.buildings.get_by_id(int(l[1]))
		if a == null or b == null:
			continue
		var pa := _end_pos(a)
		var pb := _end_pos(b)
		var ni := PowerReader.net_index(sim, a.id)
		var col := WIRE_BASE
		if ov:
			col = PowerReader.net_color(ni, PowerReader.factor_of(sim, a.id))
		var t := _wire_xf(pa, pb, THICK if ov else THIN)
		var mid := (pa + pb) * 0.5
		var ck := Vector2i(floori(mid.x / CHUNK), floori(mid.z / CHUNK))
		if not buckets.has(ck):
			buckets[ck] = []
		(buckets[ck] as Array).append([t, col])
		n += 1
	wire_count = n
	for ck: Vector2i in _mms.keys():
		if not buckets.has(ck):
			(_mms[ck] as MultiMeshInstance3D).queue_free()
			_mms.erase(ck)
	for ck: Vector2i in buckets:
		var arr: Array = buckets[ck]
		var mmi: MultiMeshInstance3D = _mms.get(ck)
		if mmi == null:
			mmi = _make_mm()
			_mms[ck] = mmi
		var mm := mmi.multimesh
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i][0])
			mm.set_instance_color(i, arr[i][1])
		(mmi.material_override as ShaderMaterial).set_shader_parameter("tint", tint)
	_update_badges(ov)


static func _wire_xf(pa: Vector3, pb: Vector3, thick: float) -> Transform3D:
	var d := pb - pa
	var ln := maxf(d.length(), 0.01)
	var x := d / ln
	var z := x.cross(Vector3.UP)
	if z.length() < 0.001:
		z = Vector3.BACK
	z = z.normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x * ln, y * thick, z * thick), (pa + pb) * 0.5)


func _make_mm() -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Per-net "supply/demand" badge above the net's first pole (overlay only).
func _update_badges(ov: bool) -> void:
	var nets := PowerReader.nets(sim)
	var used := 0
	if ov:
		for i in nets.size():
			var net: Dictionary = nets[i]
			var poles: Array = net.get("poles", [])
			if poles.is_empty():
				continue
			var pb := sim.buildings.get_by_id(int(poles[0]))
			if pb == null:
				continue
			if used >= _badges.size():
				var l := Label3D.new()
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.no_depth_test = true
				l.shaded = false
				l.font_size = 40
				l.pixel_size = 0.012
				l.outline_size = 14
				l.modulate = Color.WHITE
				add_child(l)
				_badges.append(l)
			var lb := _badges[used]
			used += 1
			var f := float(net["factor"])
			lb.visible = true
			lb.position = _end_pos(pb) + Vector3(0, 0.9, 0)
			lb.text = "%d/%d  x%.2f" % [roundi(float(net["supply"])), roundi(float(net["demand"])), f]
			lb.modulate = PowerReader.net_color(i, f)
	for k in range(used, _badges.size()):
		_badges[k].visible = false
