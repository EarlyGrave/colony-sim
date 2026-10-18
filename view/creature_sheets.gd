class_name CreatureSheets
extends RefCounted
## 4-direction walk sheets for creatures: 3 columns (idle, step A, step B) x
## 4 rows (down, left, right, up), 16 px frames. Same layout as colonist sheets.

const COLS := 3
const ROWS := 4
const FRAME := 16
const ROW_DOWN := 0
const ROW_LEFT := 1
const ROW_RIGHT := 2
const ROW_UP := 3

static var _cache := {}


static func sheet_path(def_id: String) -> String:
	return "res://assets/sprites/%s_sheet.png" % def_id


static func has_sheet(def_id: String) -> bool:
	return ResourceLoader.exists(sheet_path(def_id))


## Sheet texture, or null when missing (caller falls back to the single sprite).
static func get_sheet(def_id: String) -> Texture2D:
	if not _cache.has(def_id):
		_cache[def_id] = load(sheet_path(def_id)) if has_sheet(def_id) else null
	return _cache[def_id]


static func frame_index(row: int, col: int) -> int:
	return row * COLS + col


## Pixel rect of a frame inside the sheet.
static func frame_rect(row: int, col: int) -> Rect2i:
	return Rect2i(col * FRAME, row * FRAME, FRAME, FRAME)


## Facing row for a screen-space movement delta (camera looks north).
static func row_for_delta(d: Vector2, current: int = ROW_DOWN) -> int:
	if d.length() <= 0.0005:
		return current
	if absf(d.x) > absf(d.y):
		return ROW_RIGHT if d.x > 0.0 else ROW_LEFT
	return ROW_DOWN if d.y > 0.0 else ROW_UP
