extends Node
## N2 screenshots (844x390): win screen with Next Sentence + new-game dialog with dossier row.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/n2_shot.tscn -- --dir=<dir>

const NG := {"sentence": 2, "carry_debt": 450,
	"dossier": {"name": "Vex", "skills": {"mining": 6, "build": 2, "cook": 4}, "perk_id": "iron_back"},
	"techs": ["drill", "belt"], "history": []}


func _shot(path: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var dir := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
	get_window().size = Vector2i(844, 390)
	var w := WinScreen.new({"days": 40, "colonists": 5, "debt_paid": 300, "pollution": 0.3}, "", 120, NG)
	add_child(w)
	await _shot(dir + "/win.png")
	w.queue_free()
	var m := MetaState.new()
	m.set("ng", NG)  # no-op until N1 adds the var
	var dlg := NewGameDialog.new(m)
	add_child(dlg)
	await _shot(dir + "/dialog.png")
	get_tree().quit()
