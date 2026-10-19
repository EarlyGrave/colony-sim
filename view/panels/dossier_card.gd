class_name DossierCard
extends PanelContainer
## N2: Next Sentence dossier: veteran name, top skills, perk, carried debt, carried techs.
## Reads the N1 `ng` dict: {sentence, carry_debt, dossier{name, skills{}, perk_id}, techs[], history[]}.

const MAX_SKILLS := 3


static func has_carry(ng: Dictionary) -> bool:
	return int(ng.get("sentence", 1)) > 1 or int(ng.get("carry_debt", 0)) > 0 \
		or not (ng.get("dossier", {}) as Dictionary).is_empty()


static func top_skills(skills: Dictionary, n := MAX_SKILLS) -> Array[String]:
	var ids: Array = skills.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var x := float(skills[a])
		var y := float(skills[b])
		return x > y if x != y else str(a) < str(b))
	var out: Array[String] = []
	for id in ids.slice(0, n):
		out.append("%s %d" % [str(id).capitalize(), int(skills[id])])
	return out


static func card_text(ng: Dictionary) -> String:
	var d: Dictionary = ng.get("dossier", {})
	var lines: Array[String] = []
	lines.append("Sentence %d" % int(ng.get("sentence", 1)))
	lines.append("Veteran: %s" % str(d.get("name", "none")))
	var sk := top_skills(d.get("skills", {}))
	lines.append("Skills: %s" % (", ".join(sk) if not sk.is_empty() else "-"))
	var perk := str(d.get("perk_id", ""))
	lines.append("Perk: %s" % (perk.capitalize().replace("_", " ") if perk != "" else "-"))
	lines.append("Carried debt: %d" % int(ng.get("carry_debt", 0)))
	var techs: Array = ng.get("techs", [])
	lines.append("Techs: %s" % (", ".join(PackedStringArray(techs)) if not techs.is_empty() else "-"))
	return "\n".join(lines)


func _init(ng: Dictionary = {}) -> void:
	ModalStyle.apply(self)
	var l := Label.new()
	l.name = "Text"
	l.text = card_text(ng)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ModalStyle.style_label(l)
	add_child(l)
