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


func unbind() -> void:
	if sim and is_instance_valid(sim.bus):
		if sim.bus.item_mined.is_connected(_on_item_mined):
			sim.bus.item_mined.disconnect(_on_item_mined)
		if sim.bus.enemy_killed.is_connected(_on_enemy_killed):
			sim.bus.enemy_killed.disconnect(_on_enemy_killed)
	sim = null
	clear()
	_enemy_pos.clear()


func clear() -> void:
	for f: Array in _fx:
		(f[0] as Node).queue_free()
	_fx.clear()


func active_count() -> int:
	return _fx.size()


func _process(delta: float) -> void:
	tick(delta)


## Advance effects by `delta` seconds and poll the sim for new shots.
func tick(delta: float) -> void:
	if sim != null:
		_poll_shots()
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
