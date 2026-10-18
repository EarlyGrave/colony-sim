class_name ShuttleView3D
extends Node3D
## S3: voxel Release Gantry (3 build stages by parts), shuttle + launch pose, beacon + glow, siege HP bar.
## Reads sim only; every sim name is guarded with has_method.
## Assumed sim API: get_shuttle_state() {phase, parts, need, t_left, hp, hp_max}, get_beacon_state() {alive},
## building def ids "release_gantry" / "beacon_launcher" in sim.buildings.list.

const GANTRY_ID := "release_gantry"
const LAUNCHER_ID := "beacon_launcher"
const STAGE_COLORS := [Color(0.45, 0.47, 0.5), Color(0.62, 0.64, 0.68), Color(0.8, 0.82, 0.86)]

var sim: Simulation
var _gantry: Node3D
var _shuttle: Node3D
var _beacons := Node3D.new()
var _bar: MeshInstance3D
var _stage := -1
var _launch := 0.0


static func stage_for(parts: int, need: int) -> int:
	if parts <= 0 or need <= 0:
		return 0
	var f := float(parts) / float(need)
	return 0 if f < 0.34 else (1 if f < 1.0 else 2)


static func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if glow:
		m.emission_enabled = true
		m.emission = c
	return m


static func _box(parent: Node3D, o: Vector3, s: Vector3, c: Color, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = _mat(c, glow)
	mi.position = o + s * 0.5
	parent.add_child(mi)
	return mi


## Gantry (4x4 footprint, origin = top-left) for stage 0..2.
static func build_gantry(stage: int) -> Node3D:
	var n := Node3D.new()
	var c: Color = STAGE_COLORS[clampi(stage, 0, 2)]
	_box(n, Vector3(0, 0, 0), Vector3(4, 0.15, 4), Color(0.3, 0.3, 0.33))
	_box(n, Vector3(0.2, 0.15, 0.2), Vector3(0.4, 1.2, 0.4), c)
	_box(n, Vector3(0.2, 0.15, 3.4), Vector3(0.4, 1.2, 0.4), c)
	if stage >= 1:
		_box(n, Vector3(0.2, 1.35, 0.2), Vector3(0.4, 1.0, 0.4), c)
		_box(n, Vector3(0.2, 1.35, 3.4), Vector3(0.4, 1.0, 0.4), c)
		_box(n, Vector3(0.2, 1.9, 0.2), Vector3(0.4, 0.2, 3.6), c.darkened(0.2))
	if stage >= 2:
		_box(n, Vector3(0.6, 2.2, 0.6), Vector3(0.4, 0.2, 0.4), Color(1, 0.3, 0.2), true)
		_box(n, Vector3(3.2, 0.15, 1.5), Vector3(0.6, 0.5, 1.0), Color(0.9, 0.7, 0.2))
	return n


static func build_shuttle() -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(-0.4, 0, -0.4), Vector3(0.8, 1.4, 0.8), Color(0.88, 0.9, 0.94))
	_box(n, Vector3(-0.25, 1.4, -0.25), Vector3(0.5, 0.5, 0.5), Color(0.9, 0.35, 0.25))
	_box(n, Vector3(-0.8, 0, -0.1), Vector3(0.4, 0.6, 0.2), Color(0.6, 0.62, 0.68))
	_box(n, Vector3(0.4, 0, -0.1), Vector3(0.4, 0.6, 0.2), Color(0.6, 0.62, 0.68))
	return n


static func build_beacon() -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(-0.15, 0, -0.15), Vector3(0.3, 0.7, 0.3), Color(0.5, 0.45, 0.4))
	_box(n, Vector3(-0.22, 0.7, -0.22), Vector3(0.44, 0.3, 0.44), Color(0.4, 0.9, 1.0), true)
	return n


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	if _beacons.get_parent() == null:
		add_child(_beacons)


func clear() -> void:
	sim = null
	_stage = -1
	_launch = 0.0
	for ch in get_children():
		if ch != _beacons:
			ch.queue_free()
	for ch in _beacons.get_children():
		ch.queue_free()
	_gantry = null
	_shuttle = null
	_bar = null


func _find(def_id: String) -> Array:
	var out: Array = []
	if sim == null or sim.get("buildings") == null:
		return out
	for b in sim.buildings.list:
		if b.def_id == def_id:
			out.append(b)
	return out


func sync(delta: float = 0.0) -> void:
	if sim == null:
		return
	var st: Dictionary = sim.get_shuttle_state() if sim.has_method("get_shuttle_state") else {}
	_update_beacons()
	var g := _find(GANTRY_ID)
	if g.is_empty():
		if _gantry != null:
			_gantry.queue_free()
			_gantry = null
			_stage = -1
		return
	var b = g[0]
	var phase := String(st.get("phase", "building"))
	var armed := phase in ["ready", "countdown", "won"]
	var stage := 2 if armed else stage_for(int(st.get("parts", 0)), int(st.get("need", 1)))
	if _gantry == null or stage != _stage:
		if _gantry != null:
			_gantry.queue_free()
		_gantry = build_gantry(stage)
		_gantry.position = Vector3(b.cell.x, 0, b.cell.y)
		add_child(_gantry)
		_stage = stage
	var base := _gantry.position + Vector3(2, 0.15, 2)
	if armed and _shuttle == null:
		_shuttle = build_shuttle()
		add_child(_shuttle)
	elif not armed and _shuttle != null:
		_shuttle.queue_free()
		_shuttle = null
	if _shuttle != null:
		_launch = minf(_launch + delta * 3.0, 40.0) if phase == "won" else 0.0
		_shuttle.position = base + Vector3(0, _launch, 0)
	_update_bar(st, phase)


func _update_bar(st: Dictionary, phase: String) -> void:
	if phase != "countdown" or float(st.get("hp_max", 0.0)) <= 0.0:
		if _bar != null:
			_bar.queue_free()
			_bar = null
		return
	if _bar == null:
		_bar = _box(self, Vector3.ZERO, Vector3(1, 0.12, 0.12), Color(0.9, 0.2, 0.2), true)
	var f := clampf(float(st.get("hp", 0.0)) / float(st["hp_max"]), 0.0, 1.0)
	(_bar.mesh as BoxMesh).size = Vector3(maxf(0.01, 3.6 * f), 0.12, 0.12)
	_bar.position = _gantry.position + Vector3(2, 3.0, 0.3)


func _update_beacons() -> void:
	var l := _find(LAUNCHER_ID)
	var alive := 0
	if sim.has_method("get_beacon_state"):
		alive = int(sim.get_beacon_state().get("alive", 0))
	var want := mini(alive, 6) if not l.is_empty() else 0
	while _beacons.get_child_count() > want:
		var last := _beacons.get_child(_beacons.get_child_count() - 1)
		_beacons.remove_child(last)
		last.queue_free()
	while _beacons.get_child_count() < want:
		var i := _beacons.get_child_count()
		var bn := build_beacon()
		bn.position = Vector3(l[0].cell.x + 0.5 + i * 0.7, 0, l[0].cell.y - 0.6)
		_beacons.add_child(bn)
