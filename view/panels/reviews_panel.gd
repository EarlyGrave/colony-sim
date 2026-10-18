class_name ReviewsPanel
extends GamePanel
## Parole Reviews strip: current review goal and progress. Reads sim state only (opened from the panel bar).

var _sig := ""


func refresh() -> void:
	if sim == null or sim.milestones == null:
		return
	var ms := sim.milestones
	var r := ms.current_review()
	var sig := "%d|%d|%s" % [ms.reviews_done.size(), int(ms.review_progress(r) * 100.0) if not r.is_empty() else -1, str(k3_lines())]  # region K3
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if r.is_empty():
		add_line("Parole reviews: %d/%d passed" % [ms.reviews_done.size(), ms.review_defs().size()], Color(0.7, 0.9, 0.7))
		for l in k3_lines():  # region K3
			add_line(str(l), Color(0.8, 0.8, 0.9))
		for l in e4_lines():  # region E4
			add_line(str(l), Color(0.8, 0.8, 0.9))
		return
	add_line("%s: %d%%" % [r["title"], int(ms.review_progress(r) * 100.0)], Color(1.0, 0.85, 0.4))
	for l in e4_lines():  # region E4
		add_line(str(l), Color(0.8, 0.8, 0.9))


# region K3
## Extra read-only lines: audit countdown and (when K2 provides it) the outpost step.
func k3_lines() -> Array:
	var out: Array = []
	if sim == null:
		return out
	if sim.threats.days_to_audit() >= 0.0:
		out.append("Next audit in %d d" % int(ceil(float(sim.threats.days_to_audit()))))
	if sim.milestones.k2_demand_text() != "":
		out.append(sim.milestones.k2_demand_text())
	if sim.milestones.outpost_step_text() != "":
		out.append(sim.milestones.outpost_step_text())
	return out
# endregion
	for l in k3_lines():  # region K3
		add_line(str(l), Color(0.8, 0.8, 0.9))


# region E4
## Reviews 4-5 (E3): rank title and range score, only when the sim provides them.
func e4_lines() -> Array:
	var out: Array = []
	if sim == null or sim.milestones == null:
		return out
	var ms: MilestoneSystem = sim.milestones
	if ms.e3_rank_title() != "":
		out.append("Rank: %s" % ms.e3_rank_title())
	if ms.e3_on():
		out.append("Range score: %d" % int(ms.e3_range_score()))
	return out
# endregion
