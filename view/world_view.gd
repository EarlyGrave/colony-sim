class_name WorldView
extends Node2D
## Draws the simulation with pixel-art sprites (assets/sprites, 16 px per tile,
## drawn 2x). Reads sim state only; never mutates it. Purely cosmetic state
## (turret aim, hit flashes, particles) lives here, not in the sim.

const TILE := 32.0
const ART := 16
const SPR := "res://assets/sprites/"

var sim: Simulation
## First corner of a pending rectangle selection (or (-1,-1)).
var pending_corner := Vector2i(-1, -1)
## Cell highlighted by the last tap (inspector).
var selected_cell := Vector2i(-1, -1)

var _tex := {}
var _tile_images := {}
var _map_image: Image
var _map_sprite := Sprite2D.new()
var _time := 0.0
var _turret_aim := {}  # building id -> angle
var _enemy_last := {}  # enemy id -> [pos: Vector2, hp: float, flash_until: float]
var _particles: Array = []  # [pos, vel, life, max_life, color, size]


func _ready() -> void:
	for n in ["colonist", "colonist_engineer", "colonist_sick", "colonist_engineer_sick", "crawler", "brute", "spitter", "burrower",
			"turret_base", "turret_barrel", "refinery", "capsule", "item_ore", "item_refined", "item_waste",
			"designation_mine"]:
		_tex[n] = load(SPR + n + ".png")
	for kind in [["ground", 6], ["rock", 4], ["ore", 3]]:
		var arr: Array[Image] = []
		for v in kind[1]:
			var img: Image = (load(SPR + "%s_%d.png" % [kind[0], v]) as Texture2D).get_image()
			img.convert(Image.FORMAT_RGBA8)
			arr.append(img)
		_tile_images[kind[0]] = arr


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	_turret_aim.clear()
	_enemy_last.clear()
	_particles.clear()
	_map_image = Image.create(sim.map.width * ART, sim.map.height * ART, false, Image.FORMAT_RGBA8)
	for y in sim.map.height:
		for x in sim.map.width:
			_paint_cell(Vector2i(x, y))
	_map_sprite.texture = ImageTexture.create_from_image(_map_image)
	_map_sprite.centered = false
	_map_sprite.scale = Vector2(TILE / ART, TILE / ART)
	_map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_sprite.show_behind_parent = true
	if _map_sprite.get_parent() == null:
		add_child(_map_sprite)
	sim.bus.tile_changed.connect(_on_tile_changed)
	sim.bus.enemy_killed.connect(_on_enemy_killed)


func unbind() -> void:
	if sim:
		if sim.bus.tile_changed.is_connected(_on_tile_changed):
			sim.bus.tile_changed.disconnect(_on_tile_changed)
		if sim.bus.enemy_killed.is_connected(_on_enemy_killed):
			sim.bus.enemy_killed.disconnect(_on_enemy_killed)
	sim = null


func world_size() -> Vector2:
	return Vector2(sim.map.width, sim.map.height) * TILE


static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


# --- Terrain --------------------------------------------------------------------

func _on_tile_changed(c: Vector2i) -> void:
	for d in [Vector2i.ZERO, Vector2i(0, -1), Vector2i(0, 1)]:
		if sim.map.in_bounds(c + d):
			_paint_cell(c + d)
	(_map_sprite.texture as ImageTexture).update(_map_image)


func _variant(c: Vector2i, n: int) -> int:
	return absi(hash(c.x * 7919 + c.y * 104729)) % n


func _paint_cell(c: Vector2i) -> void:
	var m := sim.map
	var kind := "ground"
	match m.get_tile(c):
		MapGrid.Tile.ROCK:
			kind = "rock"
		MapGrid.Tile.DEPOSIT:
			kind = "ore"
	var arr: Array = _tile_images[kind]
	var src: Image = arr[_variant(c, arr.size())]
	var dst := c * ART
	_map_image.blit_rect(src, Rect2i(0, 0, ART, ART), dst)
	var below := c + Vector2i(0, 1)
	var above := c + Vector2i(0, -1)
	if kind != "ground":
		# Cliff face where the rock meets open ground below.
		if m.in_bounds(below) and m.is_passable(below):
			_shade(Rect2i(dst.x, dst.y + ART - 4, ART, 4), Color(0, 0, 0, 0.45))
			_shade(Rect2i(dst.x, dst.y + ART - 1, ART, 1), Color(0, 0, 0, 0.3))
	elif m.in_bounds(above) and not m.is_passable(above):
		# Shadow cast by the rock above.
		_shade(Rect2i(dst.x, dst.y, ART, 3), Color(0, 0, 0, 0.35))


func _shade(r: Rect2i, col: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_map_image.set_pixel(x, y, _map_image.get_pixel(x, y).blend(col))


# --- Frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if sim:
		# The world sickens as contamination grows.
		modulate = Color.WHITE.lerp(Color(0.78, 1.0, 0.7), clampf(sim.contamination.fraction() * 1.5, 0.0, 0.8))
		_update_particles(delta)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	_draw_zones()
	_draw_designations()
	_draw_items()
	_draw_buildings()
	_draw_colonists()
	_draw_enemies()
	_draw_shots()
	_draw_wave_warning()
	_draw_particles()
	_draw_selection()


func _sprite(name: String, center: Vector2, size: Vector2, flip := false, mod := Color.WHITE) -> void:
	var tex: Texture2D = _tex[name]
	if flip:
		draw_set_transform(center, 0.0, Vector2(-1, 1))
		draw_texture_rect(tex, Rect2(-size * 0.5, size), false, mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, Rect2(center - size * 0.5, size), false, mod)


func _draw_zones() -> void:
	for zone_id: String in sim.items.zone_cells:
		var col := Color(sim.defs.zones[zone_id]["color"])
		var fill := col
		fill.a = 0.22
		var edge := col.lightened(0.3)
		edge.a = 0.8
		var cells: Dictionary = sim.items.zone_cells[zone_id]
		for c: Vector2i in cells:
			var p := cell_to_world(c)
			draw_rect(Rect2(p, Vector2(TILE, TILE)), fill)
			# Outline only on the zone's outer border.
			if not cells.has(c + Vector2i(0, -1)):
				draw_line(p, p + Vector2(TILE, 0), edge, 2.0)
			if not cells.has(c + Vector2i(0, 1)):
				draw_line(p + Vector2(0, TILE), p + Vector2(TILE, TILE), edge, 2.0)
			if not cells.has(c + Vector2i(-1, 0)):
				draw_line(p, p + Vector2(0, TILE), edge, 2.0)
			if not cells.has(c + Vector2i(1, 0)):
				draw_line(p + Vector2(TILE, 0), p + Vector2(TILE, TILE), edge, 2.0)


func _draw_designations() -> void:
	var m := sim.map
	var pulse := 0.65 + 0.35 * sin(_time * 4.0)
	for i in m.mine_designated.size():
		if m.mine_designated[i] != 0:
			var p := cell_to_world(Vector2i(i % m.width, i / m.width))
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(1, 0.85, 0.3, 0.8 * pulse), false, 2.0)
			_sprite("designation_mine", p + Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE) * 0.8, false, Color(1, 1, 1, 0.9))


const ITEM_SPRITES := {"essence_ore": "item_ore", "refined_essence": "item_refined", "waste": "item_waste"}
const PILE_OFFSETS: Array[Vector2] = [Vector2(0, 3), Vector2(-6, -3), Vector2(6, -4)]


func _draw_items() -> void:
	for c: Vector2i in sim.items.stacks:
		var st: Dictionary = sim.items.stacks[c]
		var n := int(st["count"])
		var piles := 1 + int(n >= 15) + int(n >= 35)
		var center := cell_to_world(c) + Vector2(TILE, TILE) * 0.5
		for i in piles:
			_sprite(ITEM_SPRITES.get(st["item"], "item_ore"), center + PILE_OFFSETS[piles - 1 - i], Vector2(TILE, TILE))


func _draw_buildings() -> void:
	for b: Building in sim.buildings.list:
		var r := Rect2(cell_to_world(b.cell), Vector2(b.size) * TILE)
		var mod := Color(0.55, 0.5, 0.5) if b.broken else Color.WHITE
		var center := r.get_center()
		match b.def_id:
			"hq":
				_sprite("capsule", center, r.size, false, mod)
			"refinery":
				_sprite("refinery", center, r.size, false, mod)
				if b.progress > 0 and not b.broken:
					_smoke(r.position + Vector2(r.size.x * 0.7, 4), Color(0.5, 0.75, 0.3, 0.5))
			"turret":
				_sprite("turret_base", center, r.size, false, mod)
				var aim: float = _turret_aim.get(b.id, -PI / 2)
				draw_set_transform(center, aim, Vector2.ONE)
				_sprite("turret_barrel", Vector2(TILE * 0.2, 0), r.size * 1.1, false, mod)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				draw_rect(r.grow(-2), Color(b.def["color"]) * mod)
		if b.broken:
			_smoke(center, Color(0.3, 0.3, 0.3, 0.6))
			if int(_time * 6.0) % 3 == 0:
				draw_circle(center + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 2.0, Color(1, 0.85, 0.3))
		# Bars only when there is something to show.
		if b.hp < b.max_hp:
			_bar(Rect2(r.position + Vector2(3, -6), Vector2(r.size.x - 6, 4)), b.hp / b.max_hp, Color(0.9, 0.25, 0.25))
		if b.is_machine() and b.condition < 100.0:
			_bar(Rect2(r.position + Vector2(3, r.size.y + 2), Vector2(r.size.x - 6, 3)), b.condition / 100.0, Color(0.95, 0.75, 0.2))
		if not b.recipe.is_empty() and b.progress > 0:
			var f := float(b.progress) / int(b.recipe["work_ticks"])
			draw_arc(center, TILE * 0.3, -PI / 2, -PI / 2 + TAU * f, 24, Color(0.85, 0.6, 1.0), 3.0)


## Cheap animated smoke column (cosmetic, time-based).
func _smoke(origin: Vector2, col: Color) -> void:
	for i in 3:
		var t := fmod(_time * 0.8 + i / 3.0, 1.0)
		var c := col
		c.a *= 1.0 - t
		draw_circle(origin + Vector2(sin(_time * 2.0 + i) * 3.0, -t * 18.0), 3.0 + t * 5.0, c)


func _draw_colonists() -> void:
	for c: Colonist in sim.colonists.list:
		if not c.alive or c.hidden:
			continue
		var moving := not c.path.is_empty()
		var p := c.visual_pos() * TILE + Vector2(TILE, TILE) * 0.5
		var bob := -absf(sin(_time * 12.0)) * 2.0 if moving else 0.0
		var flip := moving and c.path[0].x < c.cell.x
		draw_set_transform(Vector2.ZERO)
		_ellipse_shadow(p + Vector2(0, TILE * 0.4))
		var name := "colonist"
		if c.engineer:
			name += "_engineer"
		if c.is_sick(sim.tick):
			name += "_sick"
		_sprite(name, p + Vector2(0, bob), Vector2(TILE, TILE), flip)
		if c.carry_count > 0:
			_sprite(ITEM_SPRITES.get(c.carry_item, "item_ore"), p + Vector2(0, -TILE * 0.55 + bob), Vector2(TILE, TILE) * 0.7)
		if c.hp < c.max_hp:
			_bar(Rect2(p + Vector2(-12, TILE * 0.5), Vector2(24, 4)), c.hp / c.max_hp, Color(0.9, 0.25, 0.25))


func _draw_enemies() -> void:
	var seen := {}
	for e: Enemy in sim.threats.enemies:
		seen[e.id] = true
		var p := e.visual_pos() * TILE + Vector2(TILE, TILE) * 0.5
		var last: Array = _enemy_last.get(e.id, [p, e.hp, 0.0])
		if e.hp < float(last[1]):
			last[2] = _time + 0.12
		var flip := p.x < Vector2(last[0]).x - 0.01
		_enemy_last[e.id] = [p, e.hp, last[2]]
		var scale := 1.5 if e.def_id == "brute" else 1.0
		var wobble := sin(_time * 10.0 + e.id) * 1.5
		_ellipse_shadow(p + Vector2(0, TILE * 0.4 * scale))
		var mod := Color(1, 1, 1, 0.55) if e.leaving else Color.WHITE
		_sprite(e.def_id, p + Vector2(0, wobble), Vector2(TILE, TILE) * scale, flip, mod)
		if _time < float(last[2]):
			draw_circle(p, TILE * 0.35 * scale, Color(1, 1, 1, 0.55))
		if e.hp < e.max_hp:
			_bar(Rect2(p + Vector2(-12, TILE * 0.5 * scale), Vector2(24, 4)), e.hp / e.max_hp, Color(0.95, 0.35, 0.3))
	for id in _enemy_last.keys():
		if not seen.has(id):
			_enemy_last.erase(id)


func _on_enemy_killed(id: int) -> void:
	if not _enemy_last.has(id):
		return
	var p: Vector2 = _enemy_last[id][0]
	for i in 12:
		var a := randf() * TAU
		_particles.append([p, Vector2(cos(a), sin(a)) * randf_range(30, 90), 0.0, randf_range(0.3, 0.6),
			Color(0.75, 0.15, 0.12) if i % 2 == 0 else Color(0.35, 0.08, 0.1), randf_range(2.0, 4.0)])


func _draw_wave_warning() -> void:
	var t: ThreatSystem = sim.threats
	if not t.awakened or t.next_spawn_origin.x < 0:
		return
	if not t.wave_active and t.next_wave_tick - sim.tick >= int(t.cfg["warning_ticks"]):
		return
	var o := t.next_spawn_origin
	var c := Vector2(o) * TILE + Vector2(TILE, TILE) * 0.5
	# Arrow points inward, from the nearest map edge toward the center.
	var inward := Vector2(sim.map_center() - o).normalized()
	if o.x == 0 or o.x == sim.map.width - 1:
		inward = Vector2(1.0 if o.x == 0 else -1.0, 0.0)
	else:
		inward = Vector2(0.0, 1.0 if o.y == 0 else -1.0)
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var col := Color(1.0, 0.15, 0.1, 0.45 + 0.5 * pulse)
	var side := Vector2(-inward.y, inward.x)
	var tip := c + inward * TILE * (1.2 + 0.4 * pulse)
	var base := c - inward * TILE * 0.2
	draw_colored_polygon(PackedVector2Array([tip, base + side * TILE * 0.6, base - side * TILE * 0.6]), col)
	draw_circle(c, TILE * (0.5 + 0.3 * pulse), Color(col, 0.3))


func _draw_shots() -> void:
	for s: Array in sim.threats.shots:
		var a: Vector2 = s[0] * TILE + Vector2(TILE, TILE) * 0.5
		var b: Vector2 = s[1] * TILE + Vector2(TILE, TILE) * 0.5
		var dir := (b - a).normalized()
		var muzzle := a + dir * TILE * 0.55
		draw_line(muzzle, b, Color(1, 0.95, 0.55, 0.9), 2.0)
		draw_circle(muzzle, 4.0, Color(1, 0.9, 0.4, 0.9))
		draw_circle(b, 3.0, Color(1, 1, 0.8, 0.9))
		# Remember where each turret points (cosmetic).
		var bld := sim.buildings.at(Vector2i(roundi(float(s[0].x)), roundi(float(s[0].y))))
		if bld != null:
			_turret_aim[bld.id] = dir.angle()


func _update_particles(delta: float) -> void:
	for p in _particles:
		p[2] += delta
		p[0] += p[1] * delta
		p[1] *= 0.9
	_particles = _particles.filter(func(p: Array) -> bool: return p[2] < p[3])


func _draw_particles() -> void:
	for p in _particles:
		var col: Color = p[4]
		col.a = 1.0 - p[2] / p[3]
		draw_rect(Rect2(p[0] - Vector2(p[5], p[5]) * 0.5, Vector2(p[5], p[5])), col)


func _ellipse_shadow(at: Vector2) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, TILE * 0.32, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_selection() -> void:
	if pending_corner.x >= 0:
		draw_rect(Rect2(cell_to_world(pending_corner), Vector2(TILE, TILE)), Color(1, 1, 1, 0.9), false, 3.0)
	if selected_cell.x >= 0:
		draw_rect(Rect2(cell_to_world(selected_cell), Vector2(TILE, TILE)), Color(0.4, 0.9, 1.0, 0.9), false, 2.0)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
