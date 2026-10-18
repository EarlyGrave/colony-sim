class_name ExpeditionPanel
extends GamePanel
## Expedition dialog (biome -> crew -> supplies -> confirm) and the sling cargo
## dialog (target map -> items -> confirm). Reads sim state; intent goes through
## Campaign.send_expedition / Campaign.sling_send exactly once per confirm.

signal sent(kind: String, ok: bool)

enum Step { BIOME, CREW, SUPPLIES, CONFIRM }

const BTN := Vector2(64, 64)

var campaign: Object
var mode := "expedition"  ## "expedition" or "cargo"
var step := Step.BIOME
var biome := ""
var crew: Array[int] = []
var supplies: Dictionary = {}
var target := -1  ## cargo destination map id
var cargo: Dictionary = {}
var result := ""
var cfg: Dictionary = {}


func setup(c: Object, p_mode := "expedition") -> void:
	campaign = c
	mode = p_mode
	cfg = CampaignView.config()
	title = "Expedition" if mode == "expedition" else "Sling cargo"
	reset()


func reset() -> void:
	step = Step.BIOME
	biome = ""
	crew.clear()
	supplies.clear()
	cargo.clear()
	target = -1
	result = ""


func build() -> void:
	_render()


func refresh() -> void:
	pass


# --- state / queries ---------------------------------------------------------

func biome_ids() -> Array[String]:
	var out: Array[String] = []
	if sim != null:
		for b: String in sim.defs.biomes:
			if b != "start":
				out.append(b)
	out.sort()
	return out


## "" when expeditions are available, otherwise the reason they are locked.
func lock_reason() -> String:
	if sim != null and sim.research != null and not sim.research.rule_unlocked("expeditions"):
		return "Locked: research Expeditions first."
	return ""


func alive_colonists() -> Array:
	var out: Array = []
	if sim != null:
		for col in sim.colonists.list:
			if col.alive and not col.hidden:
				out.append(col)
	return out


func supply_options() -> Array[String]:
	var out: Array[String] = []
	if sim != null:
		for id: String in sim.defs.items:
			if sim.items.count_stored(id) > 0:
				out.append(id)
	out.sort()
	return out


func pick_biome(id: String) -> bool:
	if lock_reason() != "" or not biome_ids().has(id):
		return false
	biome = id
	step = Step.CREW
	_render()
	return true


func toggle_colonist(id: int) -> void:
	if crew.has(id):
		crew.erase(id)
	elif crew.size() < alive_colonists().size() - 1:  # someone must stay home
		crew.append(id)
	_render()


func adjust(item: String, delta: int, bucket := "") -> void:
	var d: Dictionary = supplies if (bucket == "" and mode == "expedition") or bucket == "supplies" else cargo
	var cap := sim.items.count_stored(item) if sim != null else 0
	if mode == "cargo":
		cap = mini(cap, int(cfg.get("sling", {}).get("capacity", cap)) - _sum(cargo) + int(cargo.get(item, 0)))
	var n := clampi(int(d.get(item, 0)) + delta, 0, maxi(cap, 0))
	if n == 0:
		d.erase(item)
	else:
		d[item] = n
	_render()


func _sum(d: Dictionary) -> int:
	var s := 0
	for k: Variant in d:
		s += int(d[k])
	return s


func next() -> void:
	if step == Step.CREW and crew.is_empty():
		return
	if step < Step.CONFIRM:
		step = (step + 1) as Step
	_render()


func back() -> void:
	if step > Step.BIOME:
		step = (step - 1) as Step
	_render()


func travel_ticks() -> int:
	return int(cfg.get("travel_ticks", 0))


func collateral_total() -> int:
	return int(cfg.get("debt_share", cfg.get("collateral", 0))) * crew.size()


func confirm() -> bool:
	if campaign == null or not campaign.has_method("send_expedition") or step != Step.CONFIRM or crew.is_empty():
		return false
	var ok: bool = campaign.call("send_expedition", biome, crew.duplicate(), supplies.duplicate())
	result = "Party dispatched." if ok else "The expedition could not leave."
	sent.emit("expedition", ok)
	if ok:
		reset()
	_render()
	return ok


func pick_target(id: int) -> void:
	target = id
	_render()


func cargo_targets() -> Array[int]:
	var out: Array[int] = []
	for m: Dictionary in CampaignView.maps(campaign):
		var id := int(m.get("id", 0))
		if id != CampaignView.active_id(campaign):
			out.append(id)
	return out


func confirm_cargo() -> bool:
	if campaign == null or not campaign.has_method("sling_send") or target < 0 or cargo.is_empty():
		return false
	var ok: bool = campaign.call("sling_send", target, cargo.duplicate())
	result = "Crate launched." if ok else "The sling cannot fire (no sling, cooldown or over capacity)."
	sent.emit("cargo", ok)
	if ok:
		cargo.clear()
	_render()
	return ok


# --- rendering ---------------------------------------------------------------

func _render() -> void:
	if content == null:
		return
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if sim == null:
		return
	if result != "":
		add_line(result, Color(0.6, 1.0, 0.7))
	if mode == "cargo":
		_render_cargo()
		return
	var lock := lock_reason()
	if lock != "":
		add_line(lock, Color(1.0, 0.6, 0.4))
	match step:
		Step.BIOME:
			add_line("1/4  Choose a destination")
			for id in biome_ids():
				var b := _button(content, str(id).capitalize(), func() -> void: pick_biome(id))
				b.disabled = lock != ""
				b.name = "biome_" + id
				var def: Dictionary = sim.defs.biomes[id]
				add_line("Hazard %d, yield x%.1f" % [int(def.get("hazard", 0)), float(def.get("yield_mult", 1.0))], Color(0.7, 0.7, 0.7))
		Step.CREW:
			add_line("2/4  Choose the crew (someone stays home)")
			for col in alive_colonists():
				var cid: int = col.id
				var b := _button(content, ("[x] " if crew.has(cid) else "[ ] ") + col.display_name, func() -> void: toggle_colonist(cid))
				b.name = "crew_%d" % cid
			_nav(crew.is_empty())
		Step.SUPPLIES:
			add_line("3/4  Pack supplies")
			_steppers(supplies, "supplies")
			_nav(false)
		Step.CONFIRM:
			add_line("4/4  Confirm")
			add_line("%s, %d colonists" % [biome.capitalize(), crew.size()])
			add_line("Supplies: %s" % (_fmt(supplies) if not supplies.is_empty() else "none"))
			add_line("Travel time: %s" % CampaignView.ticks_text(travel_ticks(), sim.ticks_per_day))
			add_line("Debt collateral if the crew is lost: %d" % collateral_total(), Color(1.0, 0.6, 0.4))
			var c := _button(content, "Send expedition", confirm)
			c.name = "confirm_btn"
			_nav(false, true)


func _render_cargo() -> void:
	add_line("Choose a destination map")
	var targets := cargo_targets()
	if targets.is_empty():
		add_line("No other map to send to.", Color(0.7, 0.7, 0.7))
	for id in targets:
		var b := _button(content, ("> " if id == target else "") + CampaignView.label(campaign, id), func() -> void: pick_target(id))
		b.name = "target_%d" % id
	var cap := int(cfg.get("sling", {}).get("capacity", 0))
	add_line("Crate: %d / %s items" % [_sum(cargo), str(cap) if cap > 0 else "?"])
	_steppers(cargo, "cargo")
	var c := _button(content, "Launch crate", confirm_cargo)
	c.name = "launch_btn"
	c.disabled = target < 0 or cargo.is_empty()


func _steppers(d: Dictionary, bucket: String) -> void:
	var any := false
	for id in supply_options():
		any = true
		var row := HBoxContainer.new()
		content.add_child(row)
		var l := Label.new()
		l.text = "%s  (%d)" % [str(sim.defs.items[id]["name"]), sim.items.count_stored(id)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var m := _button(row, "-", func() -> void: adjust(id, -1, bucket))
		m.name = "minus_" + id
		var q := Label.new()
		q.text = str(int(d.get(id, 0)))
		q.custom_minimum_size.x = 40
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(q)
		var p := _button(row, "+", func() -> void: adjust(id, 1, bucket))
		p.name = "plus_" + id
	if not any:
		add_line("Nothing in storage.", Color(0.7, 0.7, 0.7))


func _nav(next_disabled: bool, last := false) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	_button(row, "Back", back).name = "back_btn"
	if not last:
		var n := _button(row, "Next", next)
		n.name = "next_btn"
		n.disabled = next_disabled


func _fmt(d: Dictionary) -> String:
	var parts: Array[String] = []
	for k: String in d:
		parts.append("%s x%d" % [str(sim.defs.items[k]["name"]).to_lower(), int(d[k])])
	return ", ".join(parts)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
