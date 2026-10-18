class_name JuiceFx
extends Node3D
## F4 visual juice: pooled death bursts, splat decals, refinery sludge drips, "AUDITED" text.
## View only. Fixed pools (MultiMesh buffers + Label3D), cosmetic RNG (not sim.rng).
## Driven by `tick(delta)` from Effects3D; `enabled=false` (data/fx.json) turns everything off.

const FX_PATH := "res://data/fx.json"

var cfg: Dictionary = {}
var enabled := true
var sim: Simulation
var shake_px := 0.0  ## camera shake request (px), decays; consumers may read it
var events := 0  ## total spawn events handled (tests)

var _rng := RandomNumberGenerator.new()
var _kinds: Dictionary = {}  # enemy id -> def_id (refreshed by scans)
var _scan_t := 0.0
var _colors: Dictionary = {}  # def_id -> Color

# particles: [x,y,z, vx,vy,vz, age, life, size, r,g,b]
var _pcap := 64
var _p := PackedFloat32Array()
var _plive := 0
var _pmm: MultiMesh
# decals: [x,z,age,size,rot, r,g,b]; age < 0 = free slot
var _dcap := 40
var _d := PackedFloat32Array()
var _dlive := 0
var _dnext := 0
var _dmm: MultiMesh
var _dcount := 0  ## decals alive (not yet faded)
# drips: [x,z,y0,age,size, bid]
var _gcap := 48
var _g := PackedFloat32Array()
var _glive := 0
var _gmm: MultiMesh
var _drip_t: Dictionary = {}  # building id -> seconds until next drip
var _drip_scan := 0.0
var _drip_active: Array = []  # [Building, waste fraction] working on-screen
var _labels: Array[Label3D] = []
var _label_age: Array[float] = []
var _tiers := -1


static func load_cfg() -> Dictionary:
	var f := FileAccess.open(FX_PATH, FileAccess.READ)
	if f == null:
		return {"enabled": false}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {"enabled": false}


func _init() -> void:
	_rng.seed = 90210
	cfg = load_cfg()
	enabled = bool(cfg.get("enabled", false))
	if not enabled:
		return
	_pcap = int(cfg["burst"]["max_particles"])
	_dcap = int(cfg["splat"]["pool"])
	_gcap = int(cfg["drip"]["pool"])
	_pmm = _make_mm(_pcap, false, 3)
	_dmm = _make_mm(_dcap, true, 0)
	_gmm = _make_mm(_gcap, false, 2)
	_p.resize(_pcap * 12)
	_d.resize(_dcap * 8)
	_d.fill(0.0)
	_g.resize(_gcap * 6)
	for i in int(cfg["audited"]["max"]):
		var l := Label3D.new()
		l.text = str(cfg["audited"]["text"])
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = float(cfg["audited"]["pixel_size"])
		l.modulate = Color(str(cfg["audited"]["color"]))
		l.outline_size = 8
		l.no_depth_test = true
		l.font_size = 48
		l.visible = false
		add_child(l)
		_labels.append(l)
		_label_age.append(-1.0)
	var ef := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if ef != null:
		var ed: Variant = JSON.parse_string(ef.get_as_text())
		if ed is Dictionary:
			for k: String in ed:
				_colors[k] = Color(str(ed[k].get("color", "#888888")))


func _make_mm(cap: int, flat: bool, prio: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not flat:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
	mat.render_priority = prio
	q.material = mat
	mm.mesh = q
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2000, -5, -2000), Vector3(4000, 60, 4000))
	add_child(mi)
	return mm


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	reset()
	_tiers = sim.milestones.done_tiers.size() if sim != null and sim.milestones != null else -1


func reset() -> void:
	_plive = 0
	_dlive = 0
	_dnext = 0
	_dcount = 0
	_glive = 0
	_kinds.clear()
	_drip_t.clear()
	_drip_active.clear()
	for i in _labels.size():
		_labels[i].visible = false
		_label_age[i] = -1.0
	if enabled:
		_pmm.visible_instance_count = 0
		_dmm.visible_instance_count = 0
		_gmm.visible_instance_count = 0


func live_particles() -> int:
	return _plive


func live_decals() -> int:
	return _dcount


func live_drips() -> int:
	return _glive


func live_labels() -> int:
	var n := 0
	for a in _label_age:
		if a >= 0.0:
			n += 1
	return n


## Instance counts of the fixed pools: particles, decals, drips, labels.
func pool_sizes() -> Array:
	if not enabled:
		return [0, 0, 0, 0]
	return [_pmm.instance_count, _dmm.instance_count, _gmm.instance_count, _labels.size()]


## Splat colour for a contamination fraction (0..1), via the fx.json ramp.
func splat_color(taint: float) -> Color:
	var ramp: Array = cfg["splat"]["ramp"]
	var t := clampf(taint, 0.0, 1.0)
	var prev: Array = ramp[0]
	for i in range(1, ramp.size()):
		var nx: Array = ramp[i]
		if t <= float(nx[0]):
			var k := (t - float(prev[0])) / maxf(0.0001, float(nx[0]) - float(prev[0]))
			return Color(str(prev[1])).lerp(Color(str(nx[1])), k)
		prev = nx
	return Color(str(prev[1]))


func _taint() -> float:
	return sim.contamination.fraction() if sim != null and sim.contamination != null else 0.0


## An enemy died at `p` (world x,z); kind from the last scan (fallback crawler).
func on_kill(enemy_id: int, p: Vector2) -> void:
	if not enabled:
		return
	events += 1
	var kind: String = _kinds.get(enemy_id, "crawler")
	_kinds.erase(enemy_id)
	var col: Color = _colors.get(kind, Color(0.5, 0.5, 0.5))
	var b: Dictionary = cfg["burst"]
	var n := _rng.randi_range(int(b["count_min"]), int(b["count_max"]))
	if kind == "brute":
		n *= int(b["brute_mult"])
		shake_px = float(b["brute_shake_px"])
	for i in n:
		if _plive >= _pcap:
			break
		var a := _rng.randf() * TAU
		var sp := float(b["speed"]) * _rng.randf_range(0.4, 1.0)
		var o := _plive * 12
		_p[o] = p.x
		_p[o + 1] = 0.35
		_p[o + 2] = p.y
		_p[o + 3] = cos(a) * sp
		_p[o + 4] = _rng.randf_range(0.8, 2.0)
		_p[o + 5] = sin(a) * sp
		_p[o + 6] = 0.0
		_p[o + 7] = float(b["life"])
		_p[o + 8] = float(b["size"]) * _rng.randf_range(0.7, 1.2)
		_p[o + 9] = col.r
		_p[o + 10] = col.g
		_p[o + 11] = col.b
		_plive += 1
	if kind in cfg["splat"]["kinds"]:
		spawn_splat(p)


func spawn_splat(p: Vector2) -> void:
	if not enabled:
		return
	var s: Dictionary = cfg["splat"]
	var c := splat_color(_taint())
	var i := _dnext
	_dnext = (_dnext + 1) % _dcap  # ring: the oldest splat is recycled
	if i >= _dlive:
		_dlive = i + 1
	var o := i * 8
	_d[o] = p.x
	_d[o + 1] = p.y
	_d[o + 2] = 0.0
	_d[o + 3] = float(s["size"]) + _rng.randf_range(-1.0, 1.0) * float(s["size_jitter"])
	_d[o + 4] = _rng.randf() * TAU
	_d[o + 5] = c.r
	_d[o + 6] = c.g
	_d[o + 7] = c.b


func trigger_audited(at: Vector3) -> void:
	if not enabled or _labels.is_empty():
		return
	events += 1
	var k := 0
	for i in _labels.size():
		if _label_age[i] < 0.0:
			k = i
			break
		if _label_age[i] > _label_age[k]:
			k = i
	_label_age[k] = 0.0
	_labels[k].position = at
	_labels[k].modulate.a = 1.0
	_labels[k].visible = true


func tick(delta: float) -> void:
	if not enabled:
		return
	shake_px = maxf(0.0, shake_px - delta * 20.0)
	if sim != null:
		_scan_t -= delta
		if _scan_t <= 0.0:
			_scan_t = 0.25
			for e: Enemy in sim.threats.enemies:
				_kinds[e.id] = e.def_id
			if _kinds.size() > 1500:
				_kinds.clear()
		_poll_audit()
		_tick_drips(delta)
	_tick_particles(delta)
	_tick_decals(delta)
	_tick_labels(delta)


func _poll_audit() -> void:
	if sim.milestones == null:
		return
	var n := sim.milestones.done_tiers.size()
	if _tiers >= 0 and n > _tiers:
		var at := Vector3(float(sim.map_center().x) + 0.5, 1.6, float(sim.map_center().y) + 0.5)
		for b in sim.buildings.list:
			if b.def_id == "warden_terminal" and not b.destroyed:
				at = Vector3(b.cell.x + 0.5, 1.6, b.cell.y + 0.5)
				break
		trigger_audited(at)
	_tiers = n


func _tick_particles(delta: float) -> void:
	if _plive == 0:
		if _pmm.visible_instance_count != 0:
			_pmm.visible_instance_count = 0
		return
	var i := 0
	while i < _plive:
		var o := i * 12
		_p[o + 6] += delta
		if _p[o + 6] >= _p[o + 7]:
			var l := (_plive - 1) * 12  # swap-remove with the last live one
			for j in 12:
				_p[o + j] = _p[l + j]
			_plive -= 1
			continue
		_p[o] += _p[o + 3] * delta
		_p[o + 1] = maxf(0.05, _p[o + 1] + _p[o + 4] * delta)
		_p[o + 2] += _p[o + 5] * delta
		_p[o + 4] -= 6.0 * delta
		i += 1
	var buf := PackedFloat32Array()
	buf.resize(_pcap * 16)
	for k in _plive:
		var o := k * 12
		var life_t: float = _p[o + 6] / _p[o + 7]
		var s: float = _p[o + 8] * (1.0 - 0.5 * life_t)
		_put(buf, k, Vector3(_p[o], _p[o + 1], _p[o + 2]), s, 0.0, Color(_p[o + 9], _p[o + 10], _p[o + 11], 1.0 - life_t), false)
	_pmm.buffer = buf
	_pmm.visible_instance_count = _plive


func _tick_decals(delta: float) -> void:
	if _dlive == 0:
		return
	var life := float(cfg["splat"]["life"])
	var amax := float(cfg["splat"]["alpha"])
	var buf := PackedFloat32Array()
	buf.resize(_dcap * 16)
	var live := 0
	for i in _dlive:
		var o := i * 8
		if _d[o + 2] < 0.0:
			continue
		_d[o + 2] += delta
		if _d[o + 2] >= life:
			_d[o + 2] = -1.0
			continue
		live += 1
		var a := amax * (1.0 - _d[o + 2] / life)
		_put(buf, i, Vector3(_d[o], 0.05, _d[o + 1]), _d[o + 3], _d[o + 4], Color(_d[o + 5], _d[o + 6], _d[o + 7], a), true)
	_dcount = live
	_dmm.buffer = buf
	_dmm.visible_instance_count = _dlive


func _tick_drips(delta: float) -> void:
	var dc: Dictionary = cfg["drip"]
	_drip_scan -= delta
	if _drip_scan <= 0.0:
		_drip_scan = float(dc["scan_interval"])
		_drip_active.clear()
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		for b in sim.buildings.list:
			if b.destroyed or b.broken or b.progress <= 0 or not (b.def_id in dc["buildings"]):
				continue
			var top := Vector3(b.cell.x + b.size.x * 0.5, 0.9, b.cell.y + b.size.y * 0.5)
			if cam != null and not cam.is_position_in_frustum(top):
				continue
			var w := float(int(b.output.get("waste", 0))) / float(dc["waste_for_max"])
			_drip_active.append([b, clampf(w, 0.0, 1.0)])
	for a: Array in _drip_active:
		var b: Building = a[0]
		var t: float = _drip_t.get(b.id, 0.0) - delta
		if t <= 0.0:
			var live := 0
			for i in _glive:
				if int(_g[i * 6 + 5]) == b.id:
					live += 1
			if live < int(dc["max_per_building"]) and _glive < _gcap:
				var o := _glive * 6
				_g[o] = b.cell.x + b.size.x * 0.5 + _rng.randf_range(-0.7, 0.7)
				_g[o + 1] = b.cell.y + b.size.y + 0.08  # front face, not hidden inside the body
				_g[o + 2] = 0.9
				_g[o + 3] = 0.0
				_g[o + 4] = float(dc["size"])
				_g[o + 5] = float(b.id)
				_glive += 1
			t = lerpf(float(dc["interval_max"]), float(dc["interval_min"]), float(a[1]))
		_drip_t[b.id] = t
	var fall := float(dc["fall_time"])
	var i := 0
	while i < _glive:
		var o := i * 6
		_g[o + 3] += delta
		if _g[o + 3] >= fall:
			var l := (_glive - 1) * 6
			for j in 6:
				_g[o + j] = _g[l + j]
			_glive -= 1
			continue
		i += 1
	if _glive == 0 and _gmm.visible_instance_count == 0:
		return
	var col := Color(str(dc["color"]))
	var buf := PackedFloat32Array()
	buf.resize(_gcap * 16)
	for k in _glive:
		var o := k * 6
		var f: float = _g[o + 3] / fall
		_put(buf, k, Vector3(_g[o], lerpf(_g[o + 2], 0.08, f * f), _g[o + 1]), _g[o + 4], 0.0, Color(col.r, col.g, col.b, 1.0), false)
	_gmm.buffer = buf
	_gmm.visible_instance_count = _glive


func _tick_labels(delta: float) -> void:
	var a: Dictionary = cfg["audited"]
	for i in _labels.size():
		if _label_age[i] < 0.0:
			continue
		_label_age[i] += delta
		var t := _label_age[i] / float(a["life"])
		if t >= 1.0:
			_label_age[i] = -1.0
			_labels[i].visible = false
			continue
		_labels[i].position.y += float(a["rise"]) / float(a["life"]) * delta
		_labels[i].modulate.a = 1.0 - t * t


## Writes instance `i` (uniform scale; `flat` = quad lying on the ground, rotated about Y) + colour
## into a 16-float MultiMesh buffer (3x4 row-major transform, then RGBA).
static func _put(buf: PackedFloat32Array, i: int, pos: Vector3, s: float, rot: float, c: Color, flat: bool) -> void:
	var o := i * 16
	if flat:
		var cs := cos(rot) * s
		var sn := sin(rot) * s
		buf[o] = cs
		buf[o + 1] = -sn
		buf[o + 2] = 0.0
		buf[o + 4] = 0.0
		buf[o + 5] = 0.0
		buf[o + 6] = s
		buf[o + 8] = -sn
		buf[o + 9] = -cs
		buf[o + 10] = 0.0
	else:
		buf[o] = s
		buf[o + 5] = s
		buf[o + 10] = s
	buf[o + 3] = pos.x
	buf[o + 7] = pos.y
	buf[o + 11] = pos.z
	buf[o + 12] = c.r
	buf[o + 13] = c.g
	buf[o + 14] = c.b
	buf[o + 15] = c.a
