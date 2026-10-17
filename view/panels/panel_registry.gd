class_name PanelRegistry
extends RefCounted
## Registry of HUD panels and inspector sections. Other agents add ONE line.
##
## PANELS line format (script must `extends GamePanel`, see game_panel.gd):
##     ["unique_id", "Button label", "res://view/panels/my_panel.gd"],
## INSPECTOR_SECTIONS line format (script must `extends InspectorSection`):
##     ["unique_id", "res://view/panels/sections/my_section.gd"],
##
## To avoid merge conflicts insert your line directly BELOW one free
## "# slot N" comment (do not remove the markers of other slots).

const PANELS: Array = [
	# slot 1
	["work", "Работа", "res://view/panels/work_panel.gd"],
	# slot 2
	# slot 3
	# slot 4
	# slot 5
	# slot 6
]

const INSPECTOR_SECTIONS: Array = [
	["colonist", "res://view/panels/sections/colonist_section.gd"],
	["building", "res://view/panels/sections/building_section.gd"],
	["cell", "res://view/panels/sections/cell_section.gd"],
	# slot 1
	["health", "res://view/panels/sections/health_section.gd"],
	# slot 2
	["bills", "res://view/panels/sections/bills_section.gd"],
	# slot 3
	["zone", "res://view/panels/sections/zone_section.gd"],
	# slot 4
	# slot 5
	# slot 6
]


## Panel entries: Array of [id, label, path].
static func panel_entries() -> Array:
	return PANELS


static func make_panel(id: String) -> GamePanel:
	for e: Array in PANELS:
		if e[0] == id:
			var s := load(e[2]) as GDScript
			if s == null:
				return null
			var p: Variant = s.new()
			if p is GamePanel:
				var gp := p as GamePanel
				gp.set_title(str(e[1]))
				return gp
			return null
	return null


static func make_sections() -> Array[InspectorSection]:
	var out: Array[InspectorSection] = []
	for e: Array in INSPECTOR_SECTIONS:
		var s := load(e[1]) as GDScript
		if s == null:
			continue
		var inst: Variant = s.new()
		if inst is InspectorSection:
			out.append(inst)
	return out
