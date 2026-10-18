class_name BarkLayer
extends Control
## F3: short speech bubbles above colonists. Per-colonist cooldown in game time,
## at most `bark_max` bubbles visible. Text from FlavorPicker (F1) when present,
## else data/names.json "barks".

var sim: Simulation
var camera: Camera3D
var last_bark: Dictionary = {}  ## colonist id -> tick
var bubbles: Array[Label] = []
var shown := 0  ## total barks shown (diagnostics / tests)
var _timer := Timer.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer.wait_time = 1.0
	_timer.timeout.connect(poll)
	add_child(_timer)


func bind(p_sim: Simulation, bus: Object, p_camera: Camera3D) -> void:
	sim = p_sim
	camera = p_camera
	last_bark.clear()
	if not bus.wave_repelled.is_connected(_on_won):
		bus.wave_repelled.connect(_on_won)
	if _timer.is_stopped():
		_timer.start()


func _on_won(_i: int) -> void:
	if sim == null:
		return
	for c in sim.colonists.list:
		if c.alive and not c.hidden and try_bark(c, "wave_won"):
			break


## Checks colonist states (about once a second, not per frame).
func poll() -> void:
	if sim == null:
		return
	for c in sim.colonists.list:
		if not c.alive or c.hidden:
			continue
		var st := state_of(c)
		if st != "":
			try_bark(c, st)


func state_of(c: Colonist) -> String:
	if c.job != null and (c.job.type == "flee" or c.job.type == "retreat"):
		return "fleeing"
	if c.needs != null and c.needs.food < 0.25:
		return "hungry"
	if c.job != null:
		if c.job.type == "operate":
			return "refining"
		if c.job.type == "mine":
			return "working"
	return ""


## Shows a bubble unless the cooldown is running or the visible cap is hit.
func try_bark(c: Colonist, state: String) -> bool:
	var cfg: Dictionary = sim.defs.balance["flavor"]
	var cd := int(cfg["bark_cooldown_s"]) * Simulation.TICKS_PER_SECOND
	if last_bark.has(c.id) and sim.tick - int(last_bark[c.id]) < cd:
		return false
	if bubbles.size() >= int(cfg["bark_max"]):
		return false
	var text := _line(state, c)
	if text == "":
		return false
	last_bark[c.id] = sim.tick
	shown += 1
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 0.9, 0.92)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	l.add_theme_stylebox_override("normal", sb)
	l.set_meta("cid", c.id)
	add_child(l)
	bubbles.append(l)
	_place(l)
	if is_inside_tree():
		get_tree().create_timer(float(cfg["bark_visible_s"])).timeout.connect(func() -> void:
			bubbles.erase(l)
			if is_instance_valid(l):
				l.queue_free())
	return true


func _process(_d: float) -> void:
	for l in bubbles:
		if is_instance_valid(l):
			_place(l)


func _place(l: Label) -> void:
	if camera == null or sim == null:
		return
	var c := sim.colonists.get_by_id(int(l.get_meta("cid")))
	if c == null:
		return
	var v := c.visual_pos()
	var p := camera.unproject_position(Vector3(v.x + 0.5, 1.6, v.y + 0.5))
	l.position = p - Vector2(l.size.x * 0.5, l.size.y)


func _line(state: String, c: Colonist) -> String:
	var script: Script = null
	if ResourceLoader.exists("res://view/flavor_picker.gd"):  # F1, optional
		script = load("res://view/flavor_picker.gd")
	if script != null and script.has_method("pick") and script.has_method("has_key") and script.call("has_key", "barks." + state):
		var s := str(script.call("pick", "barks." + state, {"who": c.display_name}))
		if s != "":
			return s
	var arr: Array = sim.defs.names.get("barks", {}).get(state, [])
	return "" if arr.is_empty() else str(arr[ColonistRecord.mix(c.id, sim.tick / 900) % arr.size()])
