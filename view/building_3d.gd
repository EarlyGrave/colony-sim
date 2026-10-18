class_name Building3D
extends Node3D
## Buildings as raised blocks with their top-down art laid on the top face.
## Reads sim state only. One cell = one 3D unit (same as WorldView3D).

## Block height per building id. Buildings missing here stay flat (ground art).
const HEIGHTS := {
	"hq": 0.9, "refinery": 1.0, "workbench": 0.5, "turret": 0.4,
	"door": 0.65, "stove": 0.45, "bed": 0.25,
	"miner": 0.6, "smelter": 0.85, "assembler": 0.7, "storage_in": 0.35, "storage_out": 0.35,  # region A2c
	"research_bench": 0.6,  # region R2c
	"ash_beacon": 1.0, "penitent_wall": 1.0, "mourning_bell": 1.0,  # region T2
}
## Explicit flat fallbacks (drawn by WorldView on the ground layer).
const FLAT_FALLBACK: Array[String] = ["wall", "training_dummy", "belt", "warden_terminal", "sling"]  # belts: BeltLayer; warden_terminal: region R2b
const TOP_ART := {"hq": "capsule", "refinery": "refinery", "turret": "turret_base", "stove": "stove", "bed": "bed", "door": "door",
	"miner": "machine_miner", "smelter": "machine_smelter", "assembler": "machine_assembler",
	"storage_in": "machine_storage_in", "storage_out": "machine_storage_out"}  # region A2c
const DOOR_OPEN_HEIGHT := 0.08
const DOOR_OPEN_RADIUS := 1.3
const BARREL_LEN := 0.17  ## how far the barrel sprite sits ahead of the turret centre

const SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float damage = 1.0;
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float s = 1.0;
	if (wn.y < 0.5) { s = wn.z > 0.5 ? 0.62 : 0.45; }
	ALBEDO = base_color.rgb * tint.rgb * damage * s;
}
"""

var _nodes := {}  # building id -> {"root", "box", "mat", "top", "barrel"}
var _shader: Shader
var _tex := {}


static func is_3d(def_id: String) -> bool:
	return HEIGHTS.has(def_id)


static func height_of(def_id: String) -> float:
	return float(HEIGHTS.get(def_id, 0.0))


## Centre and size (x, y, z) of the block for a footprint; matches the sim cells.
static func footprint_transform(cell: Vector2i, size: Vector2i, height: float) -> Dictionary:
	return {
		"center": Vector3(cell.x + size.x * 0.5, height * 0.5, cell.y + size.y * 0.5),
		"size": Vector3(size.x, height, size.y),
	}


## Aim angle in map space (radians, +x = 0, +y/down positive) from a building to a target.
static func aim_angle(from: Vector2, target: Vector2) -> float:
	return (target - from).angle()


## Y rotation for a flat sprite whose art points along +x at aim 0.
static func barrel_rotation(aim: float) -> float:
	return -aim


static func damage_tint(b: Building) -> float:
	if b.broken:
		return 0.45
	return lerpf(0.7, 1.0, clampf(b.hp / maxf(b.max_hp, 1.0), 0.0, 1.0))


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = SHADER
	for n in ["capsule", "refinery", "turret_base", "turret_barrel", "stove", "bed", "door",
			"machine_miner", "machine_smelter", "machine_assembler", "machine_storage_in", "machine_storage_out",
			"port_in", "port_out"]:
		_tex[n] = load(WorldView.SPR + n + ".png")


func clear() -> void:
	for d: Dictionary in _nodes.values():
		(d["root"] as Node).queue_free()
	_nodes.clear()


## aim_of: Callable(building_id) -> float. tint: day/contamination tint.
func sync(sim: Simulation, aim_of: Callable, tint: Color) -> void:
	var seen := {}
	for b: Building in sim.buildings.list:
		if not is_3d(b.def_id):
			continue
		seen[b.id] = true
		var d: Dictionary = _nodes.get(b.id, {})
		if d.is_empty():
			d = _create(b)
			_nodes[b.id] = d
		_update(sim, b, d, aim_of, tint)
	for id: int in _nodes.keys():
		if not seen.has(id):
			(_nodes[id]["root"] as Node).queue_free()
			_nodes.erase(id)


func _create(b: Building) -> Dictionary:
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("base_color", Color(b.def["color"]))
	box.material_override = mat
	root.add_child(box)
	var d := {"root": root, "box": box, "mat": mat, "top": null, "barrel": null}
	if _v1_models().has(b.def_id):
		_v1_create(b, d)
	elif TOP_ART.has(b.def_id):
		var top := _flat_sprite(_tex[TOP_ART[b.def_id]], b.size.x)
		root.add_child(top)
		d["top"] = top
	if b.def_id == "turret":
		var barrel := _flat_sprite(_tex["turret_barrel"], b.size.x * 1.1)
		root.add_child(barrel)
		d["barrel"] = barrel
	_a2c_ports(b, root)
	add_child(root)
	return d


func _flat_sprite(t: Texture2D, cells: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = t
	s.axis = Vector3.AXIS_Y
	s.pixel_size = cells / float(t.get_width())
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	return s


func _update(sim: Simulation, b: Building, d: Dictionary, aim_of: Callable, tint: Color) -> void:
	if d.has("model"):
		_v1_update(sim, b, d, tint)
		return
	var h := height_of(b.def_id)
	if b.def_id == "door" and _door_open(sim, b):
		h = DOOR_OPEN_HEIGHT
	var ft := footprint_transform(b.cell, b.size, h)
	var box: MeshInstance3D = d["box"]
	box.position = ft["center"]
	box.scale = ft["size"]
	var dmg := damage_tint(b)
	var mat: ShaderMaterial = d["mat"]
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("damage", dmg)
	var mod := Color(tint.r * dmg, tint.g * dmg, tint.b * dmg)
	var cx := b.cell.x + b.size.x * 0.5
	var cz := b.cell.y + b.size.y * 0.5
	if d["top"] != null:
		var top: Sprite3D = d["top"]
		top.position = Vector3(cx, h + 0.01, cz)
		top.modulate = mod
	if d["barrel"] != null:
		var bar: Sprite3D = d["barrel"]
		var aim: float = aim_of.call(b.id)
		bar.rotation.y = barrel_rotation(aim)
		bar.position = Vector3(cx + cos(aim) * BARREL_LEN, h + 0.02, cz + sin(aim) * BARREL_LEN)
		bar.modulate = mod


func _door_open(sim: Simulation, b: Building) -> bool:
	var c := b.center()
	for col: Colonist in sim.colonists.list:
		if col.alive and not col.hidden and col.visual_pos().distance_to(c) < DOOR_OPEN_RADIUS:
			return true
	for e: Enemy in sim.threats.enemies:
		if e.visual_pos().distance_to(c) < DOOR_OPEN_RADIUS:
			return true
	return false


# region A2c
const PORT_DIRS := {"N": 0, "E": 1, "S": 2, "W": 3}
const PORT_Y := 0.03

## Y rotation of a flat +x-pointing arrow so it faces belt direction `d` (0N 1E 2S 3W).
static func arrow_rotation(d: int) -> float:
	return [PI / 2, 0.0, -PI / 2, PI][d]


## Direction an arrow shows for a port: "out" points away along its side,
## "in" points back into the machine (a feeding belt must point that way).
static func port_arrow_dir(side: int, kind: String) -> int:
	return side if kind == "out" else (side + 2) % 4


func _a2c_ports(b: Building, root: Node3D) -> void:
	for p: Dictionary in b.def.get("ports", []):
		var side: int = PORT_DIRS.get(String(p["dir"]), 1)
		var kind := String(p["kind"])
		var a := _flat_sprite(_tex["port_in" if kind == "in" else "port_out"], 0.9)
		var pc := b.cell + Vector2i(int(p["dx"]), int(p["dy"]))
		# port cells are in world space; the root node sits at the origin.
		a.position = Vector3(pc.x + 0.5, PORT_Y, pc.y + 0.5)
		a.rotation.y = arrow_rotation(port_arrow_dir(side, kind))
		a.modulate = Color(1, 1, 1, 0.9)
		root.add_child(a)
# endregion


# region V1 voxel models (view only; data/models.json)
const MODEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float damage = 1.0;
varying vec3 wn;
varying vec3 lp;
varying vec4 vc;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); lp = VERTEX; vc = COLOR; }
void fragment() {
	float s = 1.0;
	if (wn.y < 0.5) { s = abs(wn.z) > 0.5 ? 0.66 : 0.5; }
	vec3 q = floor(lp * 12.0);
	float n = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float glow = vc.a < 0.5 ? 1.0 : 0.0;
	s = mix(s * (0.94 + 0.12 * n), 1.0, glow);
	vec3 c = vc.rgb * s;
	ALBEDO = c * mix(tint.rgb * damage, vec3(1.0), glow * step(0.9, damage));
}
"""
static var _v1_data := {}
static var _v1_loaded := false
var _v1_shader: Shader
var _v1_meshes := {}  # type -> {"static","on", "groups": {name: ArrayMesh}}


static func _v1_models() -> Dictionary:
	if not _v1_loaded:
		_v1_loaded = true
		var f := FileAccess.open("res://data/models.json", FileAccess.READ)
		if f != null:
			var j: Variant = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				for k: String in j:
					if not k.begins_with("_"):
						_v1_data[k] = j[k]
	return _v1_data


static func _v1_vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Append one box (min corner o, size s) to a SurfaceTool; vertex colour alpha 0.25 marks glow.
static func _v1_add_box(st: SurfaceTool, o: Vector3, s: Vector3, col: Color, glow: bool) -> void:
	col.a = 0.25 if glow else 1.0
	var faces := [
		[Vector3.UP, [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[Vector3.DOWN, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
		[Vector3.BACK, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[Vector3.FORWARD, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[Vector3.RIGHT, [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
		[Vector3.LEFT, [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	]
	for f: Array in faces:
		var vs: Array = f[1]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(f[0])
			st.add_vertex(o + (vs[i] as Vector3) * s)


static func _v1_build(parts: Array, shift: Vector3) -> ArrayMesh:
	if parts.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Dictionary in parts:
		_v1_add_box(st, _v1_vec(p["o"]) - shift, _v1_vec(p["s"]), Color(String(p["c"])), bool(p.get("e", false)))
	return st.commit()


## Build (once per type) the merged static mesh, the working-only mesh and one mesh per animated group.
func _v1_type_meshes(id: String) -> Dictionary:
	if _v1_meshes.has(id):
		return _v1_meshes[id]
	var m: Dictionary = _v1_models()[id]
	var base: Array = []
	var on: Array = []
	var by_group := {}
	for p: Dictionary in m["parts"]:
		if p.has("g"):
			if not by_group.has(p["g"]):
				by_group[p["g"]] = []
			(by_group[p["g"]] as Array).append(p)
		elif bool(p.get("on", false)):
			on.append(p)
		else:
			base.append(p)
	var groups := {}
	var gdefs: Dictionary = m.get("groups", {})
	for g: String in by_group:
		var piv: Vector3 = _v1_vec(gdefs[g]["pivot"])
		groups[g] = _v1_build(by_group[g], piv)
	var res := {"static": _v1_build(base, Vector3.ZERO), "on": _v1_build(on, Vector3.ZERO), "groups": groups}
	_v1_meshes[id] = res
	return res


func _v1_create(b: Building, d: Dictionary) -> void:
	if _v1_shader == null:
		_v1_shader = Shader.new()
		_v1_shader.code = MODEL_SHADER
	(d["box"] as Node3D).visible = false
	var mat := ShaderMaterial.new()
	mat.shader = _v1_shader
	d["mat"] = mat
	var mt := _v1_type_meshes(b.def_id)
	var model := Node3D.new()
	(d["root"] as Node3D).add_child(model)
	var inst := {}
	for key: String in ["static", "on"]:
		if mt[key] != null:
			var mi := MeshInstance3D.new()
			mi.mesh = mt[key]
			mi.material_override = mat
			model.add_child(mi)
			inst[key] = mi
	var gdefs: Dictionary = _v1_models()[b.def_id].get("groups", {})
	var gnodes := {}
	for g: String in mt["groups"]:
		var mi := MeshInstance3D.new()
		mi.mesh = mt["groups"][g]
		mi.material_override = mat
		mi.position = _v1_vec(gdefs[g]["pivot"])
		model.add_child(mi)
		gnodes[g] = mi
	model.position = Vector3(b.cell.x, 0, b.cell.y)
	d["model"] = model
	d["inst"] = inst
	d["gnodes"] = gnodes


## Cosmetic "is this machine busy" read from sim state; broken machines never work.
static func is_working(b: Building) -> bool:
	if b.broken or b.destroyed:
		return false
	match String(b.def.get("machine", "")):
		"processor":
			return b.progress > 0 or b.can_run_recipe()
		"extractor":
			var n := 0
			for v: Variant in b.output.values():
				n += int(v)
			return n < int(b.def.get("output_capacity", 0))
	return false


func _v1_update(_sim: Simulation, b: Building, d: Dictionary, tint: Color) -> void:
	var mat: ShaderMaterial = d["mat"]
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("damage", damage_tint(b))
	var working := is_working(b)
	var inst: Dictionary = d["inst"]
	if inst.has("on"):
		(inst["on"] as Node3D).visible = working
	var t := Time.get_ticks_msec() * 0.001
	var gdefs: Dictionary = _v1_models()[b.def_id].get("groups", {})
	var gnodes: Dictionary = d["gnodes"]
	for g: String in gnodes:
		var n: MeshInstance3D = gnodes[g]
		var cfg: Dictionary = gdefs[g]
		var piv := _v1_vec(cfg["pivot"])
		n.position = piv
		n.rotation = Vector3.ZERO
		n.scale = Vector3.ONE
		n.visible = true
		match String(cfg.get("anim", "")):
			"bob":
				if working:
					n.position.y = piv.y + (0.5 + 0.5 * sin(t * float(cfg["speed"]))) * float(cfg["amp"])
					n.rotation.y = t * float(cfg.get("spin", 0.0))
			"swing":
				if working:
					n.rotation.y = sin(t * float(cfg["speed"])) * float(cfg["amp"])
			"smoke":
				n.visible = working
				if working:
					var f := fposmod(t * 0.5 + float(cfg["phase"]), 1.0)
					n.position = piv + Vector3(f * 0.25, f * 0.9, f * 0.1)
					n.scale = Vector3.ONE * (1.0 - f * 0.7)
# endregion
