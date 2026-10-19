class_name BeaconPanel
extends GamePanel
## Penance Beacons sheet (S2 sim): read-only. Reads Simulation.get_beacon_state().
## Keys: enabled, alive, next_decay (absolute tick, -1 none), debt_rate_cut (percent of total debt per day), launched, total_cut, max_alive.

var _sig := ""
var api: Object  ## test seam


static func state_of(s: Object) -> Dictionary:
	if s != null:
		return s.get_beacon_state()
	return {}


func refresh() -> void:
	var s := _a()
	var st := state_of(s)
	var sig := str(st)
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if st.is_empty():
		add_line("No beacons yet. Build a Beacon Launcher.", Color(0.7, 0.7, 0.7))
		return
	var per_day: int = int(s.get("ticks_per_day")) if s != null and s.get("ticks_per_day") != null else 1200
	add_line("Live beacons: %d/%d" % [int(st.get("alive", 0)), int(st.get("max_alive", 0))])
	var nd := int(st.get("next_decay", -1))
	if nd >= 0:
		add_line("Next decay: %s" % ShuttlePanel.time_text(maxi(0, nd - int(s.get("tick"))), per_day))
	add_line("Debt cut: %.1f%% per day" % float(st.get("debt_rate_cut", 0.0)), Color(0.6, 0.9, 0.6))
	add_line("Launched: %d, total cut: %d" % [int(st.get("launched", 0)), int(st.get("total_cut", 0))], Color(0.7, 0.7, 0.8))


func _a() -> Object:
	return api if api != null else sim
