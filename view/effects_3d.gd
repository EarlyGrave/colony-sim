class_name Effects3D
extends Node3D
## Short-lived 3D effects (tracers, hit sparks, mining dust, death puffs).
## Cosmetic only: reads sim state and EventBus signals, never mutates the sim.
## Cosmetic randomness uses a local RNG, not sim.rng. Lifetimes are advanced
## by `tick(delta)` so tests can drive time without a scene tree process.

const MAX_EFFECTS := 120
const TRACER_LIFE := 0.12
const SPARK_LIFE := 0.25
const DUST_LIFE := 0.6
const PUFF_LIFE := 0.7

var sim: Simulation
var spawned := 0  ## total effects spawned (for tests)
var _fx: Array = []  # [node: MeshInstance3D, age: float, life: float, vel: Vector3, grow: float]
var _rng := RandomNumberGenerator.new()
var _last_shot_tick := -1
var _enemy_pos := {}  # enemy id -> Vector2 last known cell position
var _quad := QuadMesh.new()


func _init() -> void:
	_rng.seed = 7331
	_quad.size = Vector2(1, 1)


func bind(p_sim: Simulation) -> void:
	unbind()
	sim = p_sim
	_last_shot_tick = -1
	sim.bus.item_mined.connect(_on_item_mined)
	sim.bus.enemy_killed.connect(_on_enemy_killed)
	_build_nests()  # region R3X


func unbind() -> void:
	if sim and is_instance_valid(sim.bus):
		if sim.bus.item_mined.is_connected(_on_item_mined):
			sim.bus.item_mined.disconnect(_on_item_mined)
		if sim.bus.enemy_killed.is_connected(_on_enemy_killed):
			sim.bus.enemy_killed.disconnect(_on_enemy_killed)
	sim = null
	clear()
	_enemy_pos.clear()
	_clear_nests()  # region R3X


func clear() -> void:
	_c3_hide(0)  # region C3
	for f: Array in _fx:
		(f[0] as Node).queue_free()
	_fx.clear()


func active_count() -> int:
	return _fx.size()


func _process(delta: float) -> void:
	tick(delta)


## Advance effects by `delta` seconds and poll the sim for new shots.
func tick(delta: float) -> void:
	_tick_nests(delta)  # region R3X
	if sim != null:
		_poll_shots()
		_c3_sync()  # region C3
		for e: Enemy in sim.threats.enemies:
			_enemy_pos[e.id] = e.visual_pos()
	var keep: Array = []
	for f: Array in _fx:
		f[1] += delta
		var n := f[0] as MeshInstance3D
		if f[1] >= f[2]:
			n.queue_free()
			continue
		var t: float = f[1] / f[2]
		n.position += (f[3] as Vector3) * delta
		if float(f[4]) > 0.0:
			n.scale = Vector3.ONE * (float(f[4]) * (0.5 + t))
		(n.material_override as StandardMaterial3D).albedo_color.a = 1.0 - t
		keep.append(f)
	_fx = keep


func _poll_shots() -> void:
	for s: Array in sim.threats.shots:
		var t := int(s[2])
		if t <= _last_shot_tick:
			continue
		_last_shot_tick = maxi(_last_shot_tick, t)
		var a: Vector2 = s[0] + Vector2(0.5, 0.5)
		var b: Vector2 = s[1] + Vector2(0.5, 0.5)
		spawn_tracer(a, b)
		spawn_spark(b)


func _on_item_mined(cell: Vector2i, _item: String, _amount: int) -> void:
	for i in 3:
		_spawn(Vector3(cell.x + 0.5 + _rng.randf_range(-0.3, 0.3), 0.3, cell.y + 0.5 + _rng.randf_range(-0.3, 0.3)),
			Color(0.75, 0.68, 0.55), DUST_LIFE, Vector3(0, 0.5, 0), 0.3)


func _on_enemy_killed(enemy_id: int) -> void:
	var p: Vector2 = _enemy_pos.get(enemy_id, Vector2.ZERO) + Vector2(0.5, 0.5)
	_enemy_pos.erase(enemy_id)
	for i in 4:
		_spawn(Vector3(p.x + _rng.randf_range(-0.2, 0.2), 0.4, p.y + _rng.randf_range(-0.2, 0.2)),
			Color(0.45, 0.5, 0.4), PUFF_LIFE, Vector3(_rng.randf_range(-0.4, 0.4), 0.6, _rng.randf_range(-0.4, 0.4)), 0.6)


func spawn_tracer(from: Vector2, to: Vector2) -> void:
	var mid := (from + to) * 0.5
	var n := _spawn(Vector3(mid.x, 0.6, mid.y), Color(1, 0.95, 0.55), TRACER_LIFE, Vector3.ZERO, 0.0)
	if n == null:
		return
	n.rotation = Vector3(-PI / 2, 0, 0)
	n.rotate_y(-(to - from).angle() + PI / 2)
	n.mesh = _stretched(maxf(from.distance_to(to), 0.1))
	(n.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	(n.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


func spawn_spark(at: Vector2) -> void:
	_spawn(Vector3(at.x, 0.5, at.y), Color(1, 1, 0.7), SPARK_LIFE, Vector3.ZERO, 0.35)


func _stretched(len: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.06, len)
	return q


func _spawn(pos: Vector3, col: Color, life: float, vel: Vector3, size: float) -> MeshInstance3D:
	if _fx.size() >= MAX_EFFECTS:
		return null
	var n := MeshInstance3D.new()
	n.mesh = _quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.no_depth_test = false
	n.material_override = m
	n.position = pos
	add_child(n)
	_fx.append([n, 0.0, life, vel, size])
	spawned += 1
	return n


# region R3X
## Creature nests: a small voxel mound per ecology nest; pulses (scale + glow) while its
## hunger bank holds at least one raid unit's worth. Cosmetic only.
const NEST_PULSE_HZ := 1.6
var _nests: Array = []  # [root: Node3D, nest index, mat: StandardMaterial3D]
var _nest_t := 0.0


func nest_count() -> int:
	return _nests.size()


## True when the nest at index `i` is drawn pulsing.
func nest_pulsing(i: int) -> bool:
	return sim != null and sim.ecology != null and i < sim.ecology.nests.size() \
		and float(sim.ecology.nests[i]["bank"]) >= float(sim.ecology.cfg["default_unit_cost"])


func _clear_nests() -> void:
	for n: Array in _nests:
		(n[0] as Node).queue_free()
	_nests.clear()


func _build_nests() -> void:
	_clear_nests()
	if sim == null or sim.ecology == null:
		return
	for i in sim.ecology.nests.size():
		var c: Vector2i = sim.ecology.nests[i]["cell"]
		var root := Node3D.new()
		root.position = Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.2, 0.28)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.15, 0.2)
		mat.emission_energy_multiplier = 0.0
		# voxel mound: 3x3 base, 2x2 middle, 1x1 top
		for layer in [[1.6, 0.35, 0.18], [1.0, 0.3, 0.5], [0.5, 0.3, 0.8]]:
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(layer[0], layer[1], layer[0])
			box.mesh = bm
			box.material_override = mat
			box.position = Vector3(0, layer[2], 0)
			root.add_child(box)
		add_child(root)
		_nests.append([root, i, mat])


func _tick_nests(delta: float) -> void:
	if _nests.is_empty():
		return
	_nest_t += delta
	for n: Array in _nests:
		var root: Node3D = n[0]
		var mat: StandardMaterial3D = n[2]
		if nest_pulsing(int(n[1])):
			var k := 0.5 + 0.5 * sin(_nest_t * TAU * NEST_PULSE_HZ)
			root.scale = Vector3.ONE * (1.0 + 0.12 * k)
			mat.emission_energy_multiplier = 0.4 + 1.2 * k
		else:
			root.scale = Vector3.ONE
			mat.emission_energy_multiplier = 0.0
# endregion


# region C3 telegraph markers: red cells + a ring that shrinks to the centre as the wind-up ends
var _c3_cells: Array[MeshInstance3D] = []
var _c3_rings: Array[MeshInstance3D] = []
var _c3_shown := 0


func c3_visible_cells() -> int:
	return _c3_shown


func _c3_node(pool: Array[MeshInstance3D], i: int, mesh: Mesh) -> MeshInstance3D:
	if i < pool.size():
		return pool[i]
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	pool.append(m)
	return m


func _c3_hide(from: int) -> void:
	for i in range(from, _c3_cells.size()):
		_c3_cells[i].visible = false
	for i in range(0, _c3_rings.size()):
		if i >= from:
			_c3_rings[i].visible = false


func _c3_sync() -> void:
	var cell_i := 0
	var ring_i := 0
	for t: Dictionary in sim.threats.telegraphs():
		var cells: Array = t["cells"]
		var frac: float = t["frac"]
		var sum := Vector2.ZERO
		for c: Vector2i in cells:
			sum += Vector2(c) + Vector2(0.5, 0.5)
			var n := _c3_node(_c3_cells, cell_i, _quad)
			cell_i += 1
			n.visible = true
			n.rotation = Vector3(-PI / 2.0, 0, 0)
			n.scale = Vector3.ONE * 0.92
			n.position = Vector3(c.x + 0.5, 0.07, c.y + 0.5)
			(n.material_override as StandardMaterial3D).albedo_color = Color(0.95, 0.12, 0.1, 0.35 + 0.35 * (1.0 - frac))
		var ctr := sum / maxf(1.0, float(cells.size()))
		var tor := TorusMesh.new()
		var r := _c3_node(_c3_rings, ring_i, tor)
		if r.mesh == tor:
			tor.inner_radius = 0.42
			tor.outer_radius = 0.5
		ring_i += 1
		r.visible = true
		r.scale = Vector3.ONE * (0.4 + 2.2 * frac)
		r.position = Vector3(ctr.x, 0.09, ctr.y)
		(r.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	for i in range(cell_i, _c3_cells.size()):
		_c3_cells[i].visible = false
	for i in range(ring_i, _c3_rings.size()):
		_c3_rings[i].visible = false
	_c3_shown = cell_i
# endregion
