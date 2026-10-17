class_name HealthPanel
extends RefCounted
## Standalone text builder for a colonist's injury list (no Node, no sim mutation).


static func build(c: Colonist, defs: Defs) -> String:
	var lines: Array[String] = []
	lines.append("%s: %d/%d" % [c.display_name, roundi(c.hp), roundi(c.max_hp)])
	var h := c.health
	if h == null or h.injuries.is_empty():
		lines.append("Здоров")
		return "\n".join(lines)
	if h.downed:
		lines.append("Без сознания")
	lines.append("Кровь %d%%  Боль %d%%" % [roundi(h.blood * 100.0), roundi(h.pain * 100.0)])
	lines.append("Сознание %d%%  Движение %d%%  Манипуляции %d%%" % [
		roundi(h.consciousness * 100.0), roundi(h.moving * 100.0), roundi(h.manipulation * 100.0)])
	for i in h.injuries:
		var part: String = str(defs.health["parts"][i.part]["name"])
		var s := "%s (%s) %.1f" % [i.label, part, i.severity] if not i.is_illness() \
			else "%s %d%%" % [i.label, roundi(i.severity * 100.0)]
		if i.is_bleeding():
			s += " — кровотечение"
		elif i.tended:
			s += " — перевязано"
		lines.append(s)
	return "\n".join(lines)
