extends GamePanel
## Wraps WorkTab (priority matrix) as a HUD panel.

var _tab: WorkTab


func build() -> void:
	_tab = WorkTab.new()
	content.add_child(_tab)
	_tab.bind(sim)


func refresh() -> void:
	if _tab:
		_tab.refresh()
