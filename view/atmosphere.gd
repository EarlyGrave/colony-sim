class_name Atmosphere
extends Node3D
## Sky gradient, distance fog and a soft fade at the map border so the world
## never ends in a hard line. Pure presentation; reads nothing from the sim.

const FOG_ENABLED := true
const FOG_BEGIN := 40.0  ## cells from the camera where fog starts
const FOG_END := 170.0
const EDGE_FADE := 9.0  ## cells inside the map border that darken softly
const EDGE_MARGIN := 220.0  ## cells of "void" apron around the map
const EDGE_DARKEN := 0.7  ## alpha at the very border (inside edge)
const SKY_TOP := Color(0.16, 0.2, 0.32)
const SKY_HORIZON := Color(0.2, 0.2, 0.28)
const VOID_COLOR := Color(0.2, 0.2, 0.28)

const EDGE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec2 map_size;
uniform float fade = 9.0;
uniform float darken = 0.7;
uniform vec4 void_color : source_color;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = abs(wpos.xz - map_size * 0.5) - map_size * 0.5;
	float sd = max(q.x, q.y);
	float a = sd > 0.0 ? 1.0 : darken * (1.0 - clamp(-sd / fade, 0.0, 1.0));
	a = a * a * (3.0 - 2.0 * a);
	ALBEDO = void_color.rgb;
	ALPHA = a;
}
"""

var env := Environment.new()
var _world_env := WorldEnvironment.new()
var _edge := MeshInstance3D.new()
var _edge_mat := ShaderMaterial.new()
var _sky_mat := ProceduralSkyMaterial.new()


func _init() -> void:
	var sky := Sky.new()
	_sky_mat.sky_top_color = SKY_TOP
	_sky_mat.sky_horizon_color = SKY_HORIZON
	_sky_mat.ground_horizon_color = SKY_HORIZON
	_sky_mat.ground_bottom_color = SKY_TOP.darkened(0.3)
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = FOG_ENABLED
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = SKY_HORIZON
	env.fog_depth_begin = FOG_BEGIN
	env.fog_depth_end = FOG_END
	env.fog_depth_curve = 1.4
	_world_env.environment = env
	add_child(_world_env)
	var sh := Shader.new()
	sh.code = EDGE_SHADER
	_edge_mat.shader = sh
	_edge_mat.set_shader_parameter("fade", EDGE_FADE)
	_edge_mat.set_shader_parameter("darken", EDGE_DARKEN)
	_edge_mat.set_shader_parameter("void_color", VOID_COLOR)
	_edge.material_override = _edge_mat
	_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_edge)


## Size the edge apron for a map of `size` cells.
func configure(size: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = size + Vector2.ONE * EDGE_MARGIN * 2.0
	_edge.mesh = plane
	_edge.position = Vector3(size.x * 0.5, 0.04, size.y * 0.5)
	_edge_mat.set_shader_parameter("map_size", size)


## Day / contamination tint nudges the sky so night is darker around the map.
func set_tint(t: Color) -> void:
	var c := SKY_HORIZON * Color(t.r, t.g, t.b)
	_sky_mat.sky_horizon_color = c
	_sky_mat.ground_horizon_color = c
	_sky_mat.sky_top_color = SKY_TOP * Color(t.r, t.g, t.b)
	env.fog_light_color = c
	_edge_mat.set_shader_parameter("void_color", VOID_COLOR * Color(t.r, t.g, t.b))
