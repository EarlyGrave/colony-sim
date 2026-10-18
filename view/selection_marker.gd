class_name SelectionMarker
extends Node3D
## Ring on the ground under the selected colonist. Follows the colonist's
## visual position; hidden when nothing is selected.

const RING_SIZE := 1.15
const HEIGHT := 0.05

var colonist_id := -1
var _mesh := MeshInstance3D.new()


func _init() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * RING_SIZE
	_mesh.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load("res://assets/sprites/select_ring.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.disable_fog = true
	_mesh.material_override = m
	add_child(_mesh)
	visible = false


func select(id: int) -> void:
	colonist_id = id


func clear() -> void:
	colonist_id = -1
	visible = false


## Move to the selected colonist; call once per frame (or after changes).
func refresh(sim: Simulation) -> void:
	if sim == null or colonist_id < 0:
		visible = false
		return
	var c := sim.colonists.get_by_id(colonist_id)
	if c == null or not c.alive or c.hidden:
		visible = false
		return
	var p := c.visual_pos() + Vector2(0.5, 0.5)
	position = Vector3(p.x, HEIGHT, p.y + 0.05)
	visible = true
