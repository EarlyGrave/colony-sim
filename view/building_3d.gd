class_name Building3D
extends Node3D
## Buildings as raised blocks with their top-down art laid on the top face.
## Reads sim state only. One cell = one 3D unit (same as WorldView3D).

## Block height per building id. Buildings missing here stay flat (ground art).
const HEIGHTS := {
	"hq": 0.9, "refinery": 1.0, "workbench": 0.5, "turret": 0.4,
	"door": 0.65, "stove": 0.45, "bed": 0.25,
	"miner": 0.6, "smelter": 0.85, "assembler": 0.7, "storage_in": 0.35, "storage_out": 0.35,  # region A2c
}
## Explicit flat fallbacks (drawn by WorldView on the ground layer).
const FLAT_FALLBACK: Array[String] = ["wall", "training_dummy", "belt"]  # belts: BeltLayer
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
	if TOP_ART.has(b.def_id):
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
