class_name Bill
extends RefCounted
## One production order on a building with `"bills": true`.

var id: int
var recipe_id: String
## "count" (do X times), "until" (keep N in stock), "forever".
var mode: String
var target: int
var done := 0
var paused := false


func _init(p_id: int, p_recipe: String, p_mode: String, p_target: int) -> void:
	id = p_id
	recipe_id = p_recipe
	mode = p_mode
	target = p_target
