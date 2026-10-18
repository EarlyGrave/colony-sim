class_name InspectorPanel
extends GamePanel
## Inspector for a tapped colonist / building / cell. Content comes from the
## sections registered in PanelRegistry.INSPECTOR_SECTIONS.

signal panel_requested(panel_id: String, colonist_id: int)

var target: Dictionary = {}
var _sections: Array[InspectorSection] = []


func _init() -> void:
	super()
	title = "Inspect"


func set_target(t: Dictionary) -> void:
	target = t
	if sim:
		refresh()


func build() -> void:
	_sections = PanelRegistry.make_sections()


func refresh() -> void:
	if sim == null:
		return
	target["request_panel"] = func(pid: String, cid: int) -> void: panel_requested.emit(pid, cid)
	var fresh := VBoxContainer.new()
	fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in _sections:
		if s.applies(sim, target):
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 2)
			fresh.add_child(box)
			s.build(sim, target, box)
	var parent := content.get_parent()
	parent.remove_child(content)
	content.queue_free()
	content = fresh
	parent.add_child(content)
