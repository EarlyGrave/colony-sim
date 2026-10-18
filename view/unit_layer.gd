class_name UnitLayer
extends Node3D
## Colonists and creatures as billboard quads, one MultiMesh per sheet texture
## (W2b). Per instance: world position (origin of the transform) and custom
## data (facing row, moving flag, phase). The vertex shader billboards the quad
## and the fragment shader picks the frame, running the walk cycle from TIME,
## so a frame costs one packed-buffer upload per sheet instead of ~8 Sprite3D
## property sets per unit. Also fills the blob-shadow buffer for G1c.

const STRIDE := 16  ## floats per instance: 12 transform + 4 custom
const SHADOW_STRIDE := 12
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
uniform sampler2D sheet : filter_nearest, source_color;
uniform vec2 grid = vec2(3.0, 4.0);  // columns, rows of the sheet
uniform float size = 1.25;  // quad edge in cells
uniform float wobble = 0.0;  // creature hop height
uniform vec4 tint : source_color = vec4(1.0);
varying vec2 uv_frame;
void vertex() {
	vec4 cd = INSTANCE_CUSTOM;  // x row, y moving, z phase
	float t = floor(TIME * 8.0 + cd.z);
	float step_i = mod(t, 4.0);
	float col = 0.0;
	if (cd.y > 0.5) {
		col = step_i < 0.5 ? 1.0 : (step_i > 1.5 && step_i < 2.5 ? 2.0 : 0.0);
	}
	vec2 uv = UV;
	if (grid.x < 1.5) {
		if (cd.x > 0.5 && cd.x < 1.5) uv.x = 1.0 - uv.x;  // single sprite: flip for "left"
		col = 0.0;
	}
	float row = grid.x < 1.5 ? 0.0 : cd.x;
	uv_frame = (vec2(col, row) + uv) / grid;
	vec3 o = MODEL_MATRIX[3].xyz;
	o.y += wobble * abs(sin(TIME * 10.0 + cd.z));
	vec3 c = (VIEW_MATRIX * vec4(o, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.x * size, (VERTEX.y + 0.5) * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec4 s = texture(sheet, uv_frame);
	if (s.a < 0.5) discard;
	ALBEDO = s.rgb * tint.rgb;
}
"""

static var _shader: Shader
static var _shadow_mat: StandardMaterial3D

var _groups := {}  # key -> Group
var _quad: QuadMesh
var _blob: PlaneMesh


class Group:
	extends RefCounted
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var mat: ShaderMaterial
	var buf := PackedFloat32Array()
	var smm: MultiMesh  ## blob shadows, same instance order
	var smmi: MultiMeshInstance3D
	var sbuf := PackedFloat32Array()
	var n := 0
	var cap := 0
	var shadow := 0.95  ## blob shadow size in cells

	func grow() -> void:
		var old := cap
		cap = maxi(16, cap * 2)
		buf.resize(cap * UnitLayer.STRIDE)
		sbuf.resize(cap * UnitLayer.SHADOW_STRIDE)
		mm.instance_count = cap
		smm.instance_count = cap
		for i in range(old, cap):  # constant part of the blob transform
			var o := i * UnitLayer.SHADOW_STRIDE
			sbuf[o] = shadow
			sbuf[o + 5] = 1.0
			sbuf[o + 7] = 0.03
			sbuf[o + 10] = shadow * 0.7

	## Add one unit standing at (x, 0, z); the y slot stays 0.
	func push(x: float, z: float, row: int, moving: bool, phase: int) -> void:
		if n >= cap:
			grow()
		var o := n * UnitLayer.STRIDE
		buf[o + 3] = x
		buf[o + 11] = z
		buf[o + 12] = row
		buf[o + 13] = 1.0 if moving else 0.0
		buf[o + 14] = phase
		var so := n * UnitLayer.SHADOW_STRIDE
		sbuf[so + 3] = x
		sbuf[so + 11] = z - 0.02
		n += 1


func _init() -> void:
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_blob = PlaneMesh.new()
	_blob.size = Vector2.ONE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.albedo_texture = load("res://assets/sprites/shadow_blob.png")
		_shadow_mat.disable_fog = true


## Group for a sheet/sprite key, created on first use.
func group(key: String, tex: Texture2D, cols: int, rows: int, size: float, wobble: float = 0.0, shadow: float = 0.95) -> Group:
	var g: Group = _groups.get(key)
	if g != null:
		return g
	g = Group.new()
	g.shadow = shadow
	g.mat = ShaderMaterial.new()
	g.mat.shader = _shader
	g.mat.set_shader_parameter("sheet", tex)
	g.mat.set_shader_parameter("grid", Vector2(cols, rows))
	g.mat.set_shader_parameter("size", size)
	g.mat.set_shader_parameter("wobble", wobble)
	g.mm = MultiMesh.new()
	g.mm.transform_format = MultiMesh.TRANSFORM_3D
	g.mm.use_custom_data = true
	g.mm.mesh = _quad
	g.smm = MultiMesh.new()
	g.smm.transform_format = MultiMesh.TRANSFORM_3D
	g.smm.mesh = _blob
	var big := AABB(Vector3(-1e4, -10.0, -1e4), Vector3(2e4, 20.0, 2e4))
	g.mmi = MultiMeshInstance3D.new()
	g.mmi.multimesh = g.mm
	g.mmi.material_override = g.mat
	g.mmi.custom_aabb = big
	g.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.smmi = MultiMeshInstance3D.new()
	g.smmi.multimesh = g.smm
	g.smmi.material_override = _shadow_mat
	g.smmi.custom_aabb = big
	g.smmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g.smmi)
	add_child(g.mmi)
	g.grow()
	_groups[key] = g
	return g


func begin() -> void:
	for g: Group in _groups.values():
		g.n = 0


## Upload the buffers; `tint` is the night/contamination colour.
func finish(tint: Color) -> void:
	for g: Group in _groups.values():
		g.mm.visible_instance_count = g.n
		g.smm.visible_instance_count = g.n
		if g.n > 0:
			g.mm.buffer = g.buf
			g.smm.buffer = g.sbuf
			g.mat.set_shader_parameter("tint", tint)


func total() -> int:
	var t := 0
	for g: Group in _groups.values():
		t += g.n
	return t


func clear() -> void:
	for g: Group in _groups.values():
		g.mmi.queue_free()
		g.smmi.queue_free()
	_groups.clear()
