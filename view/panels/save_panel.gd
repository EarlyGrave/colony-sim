class_name SavePanel
extends GamePanel
## Menu panel: manual save / load. Load goes through GameController.load_game().

var _status: Label


func build() -> void:
	var b := Button.new()
	b.text = "Сохранить"
	b.custom_minimum_size = Vector2(0, 72)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		_status.text = "Сохранено." if SaveStore.write(sim) else "Не удалось сохранить.")
	content.add_child(b)
	var l := Button.new()
	l.text = "Загрузить"
	l.custom_minimum_size = Vector2(0, 72)
	l.focus_mode = Control.FOCUS_NONE
	l.pressed.connect(func() -> void:
		var gc := get_tree().current_scene as GameController
		if gc != null:
			gc.load_game())
	content.add_child(l)
	_status = add_line("Автосохранение: раз в игровые сутки.", Color(0.7, 0.7, 0.7))
