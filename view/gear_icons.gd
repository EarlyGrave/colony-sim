class_name GearIcons
extends RefCounted
## F8: gear icon loader. 16x16 pixel art in assets/sprites/gear_<base>.png,
## rarity overlays gear_frame_<rarity>.png, gear_socket.png. Draw with NEAREST.

const DIR := "res://assets/sprites/"
const SLOT_COLORS := {
	"head": Color("#7c8794"), "hands": Color("#c8a060"), "legs": Color("#4f5866"),
	"torso_inner": Color("#d8c8a8"), "torso_outer": Color("#4a5a70"), "weapon": Color("#c83a2c"),
}

static var _fallbacks: Dictionary = {}


static func _load(name: String) -> Texture2D:
	var path := DIR + name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Icon for a gear base id; never null (generic coloured tile when the file is missing).
static func texture(base: String, slot: String = "") -> Texture2D:
	var t := _load("gear_" + base)
	if t != null:
		return t
	var key := base + "|" + slot
	if not _fallbacks.has(key):
		_fallbacks[key] = _make_fallback(base, slot)
	return _fallbacks[key]


## Rarity border overlay (transparent centre); null when missing.
static func frame(rarity: String) -> Texture2D:
	return _load("gear_frame_" + rarity)


static func socket() -> Texture2D:
	var t := _load("gear_socket")
	return t if t != null else _make_fallback("socket", "")


static func _make_fallback(base: String, slot: String) -> Texture2D:
	var col: Color = SLOT_COLORS.get(slot, Color("#8a8f99"))
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(2, 14):
		for x in range(2, 14):
			var edge := x == 2 or x == 13 or y == 2 or y == 13
			img.set_pixel(x, y, Color("#1a1420") if edge else col)
	# crude per-base mark so different bases look different
	var n: int = base.unicode_at(0) if base.length() > 0 else 63
	for i in range(5):
		if (n >> i) & 1:
			img.set_pixel(5 + i, 5 + (i % 3) * 3, Color("#f4f0e8"))
	return ImageTexture.create_from_image(img)
