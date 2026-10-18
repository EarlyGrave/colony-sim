class_name ReviewsPanel
extends GamePanel
## Parole Reviews strip: current review goal and progress. Reads sim state only (opened from the panel bar).

var _sig := ""


func refresh() -> void:
	if sim == null or sim.milestones == null:
		return
	var ms := sim.milestones
	var r := ms.current_review()
	var sig := "%d|%d" % [ms.reviews_done.size(), int(ms.review_progress(r) * 100.0) if not r.is_empty() else -1]
	if sig == _sig:
		return
	_sig = sig
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	if r.is_empty():
		add_line("Parole reviews: %d/%d passed" % [ms.reviews_done.size(), ms.review_defs().size()], Color(0.7, 0.9, 0.7))
		return
	add_line("%s: %d%%" % [r["title"], int(ms.review_progress(r) * 100.0)], Color(1.0, 0.85, 0.4))
