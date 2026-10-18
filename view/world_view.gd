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
var show_field := true:  ## contamination overlay toggle
	set(v):
		show_field = v
		if flat and not _nm.is_empty():
			_mark_all(7)
var patrol_draft: Array[Vector2i] = []
# region A2d
var belt_draft: Array[Vector2i] = []  ## preview path being dragged
var belt_bad: Dictionary = {}  ## cell -> true for invalid preview cells
var belt_last_dir := 1
# endregion
## Cell highlighted by the last tap (inspector).
var selected_cell := Vector2i(-1, -1)
## Pseudo-3D mode: units and rock relief are drawn by WorldView3D; this node
## only paints the flat ground layers (plus unit shadows) into a SubViewport.
var flat := false

var _tex := {}
var _tile_images := {}
var _chunk_images: Array[Image] = []  # per ground chunk (ChunkLayer.CHUNK cells)
var _chunk_sprites: Array[Sprite2D] = []
var _chunk_cols := 0
var chunk_updates := 0  ## chunk textures re-uploaded (perf counter, see tests)
var _time := 0.0
var _turret_aim := {}  # building id -> angle
var _enemy_last := {}  # enemy id -> [pos: Vector2, hp: float, flash_until: float]
var _particles: Array = []  # [pos, vel, life, max_life, color, size]


func _ready() -> void:
	for n in ["colonist", "colonist_engineer", "colonist_sick", "colonist_engineer_sick", "crawler", "brute", "spitter", "burrower",
			"turret_base", "turret_barrel", "refinery", "capsule", "item_ore", "item_refined", "item_waste",
			"designation_mine", "wall", "door", "bed", "stove", "plant_young", "plant_ripe", "item_raw_food", "item_meal"]:
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
	_build_chunks()
	for y in sim.map.height:
		for x in sim.map.width:
			_paint_cell(Vector2i(x, y))
	for i in _chunk_images.size():
		(_chunk_sprites[i].texture as ImageTexture).update(_chunk_images[i])
	sim.bus.tile_changed.connect(_on_tile_changed)
	sim.bus.enemy_killed.connect(_on_enemy_killed)
	_w2a_bind()  # region W2a


func _build_chunks() -> void:
	for sp in _chunk_sprites:
		sp.queue_free()
	_chunk_sprites.clear()
	_chunk_images.clear()
	var w := sim.map.width
	var h := sim.map.height
	_chunk_cols = ChunkLayer.chunk_count(w)
	for cy in ChunkLayer.chunk_count(h):
		for cx in _chunk_cols:
			var r := ChunkLayer.chunk_cells(Vector2i(cx, cy), w, h)
			var img := Image.create(r.size.x * ART, r.size.y * ART, false, Image.FORMAT_RGBA8)
			var sp := Sprite2D.new()
			sp.texture = ImageTexture.create_from_image(img)
			sp.centered = false
			sp.position = Vector2(r.position) * TILE
			sp.scale = Vector2(TILE / ART, TILE / ART)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.show_behind_parent = true
			add_child(sp)
			_chunk_images.append(img)
			_chunk_sprites.append(sp)


func unbind() -> void:
	_w2a_unbind()  # region W2a
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
	if flat:
		_mark_cell_nb(c)  # region W2a
	for ch in ChunkLayer.chunks_for_change(c, sim.map.width, sim.map.height):
		var i := ch.y * _chunk_cols + ch.x
		(_chunk_sprites[i].texture as ImageTexture).update(_chunk_images[i])
		chunk_updates += 1


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
	var ch := ChunkLayer.chunk_of(c)
	var img: Image = _chunk_images[ch.y * _chunk_cols + ch.x]
	var dst := (c - ch * ChunkLayer.CHUNK) * ART
	img.blit_rect(src, Rect2i(0, 0, ART, ART), dst)
	var below := c + Vector2i(0, 1)
	var above := c + Vector2i(0, -1)
	if flat:
		return
	if kind != "ground":
		# Cliff face where the rock meets open ground below.
		if m.in_bounds(below) and m.is_passable(below):
			_shade(img, Rect2i(dst.x, dst.y + ART - 4, ART, 4), Color(0, 0, 0, 0.45))
			_shade(img, Rect2i(dst.x, dst.y + ART - 1, ART, 1), Color(0, 0, 0, 0.3))
	elif m.in_bounds(above) and not m.is_passable(above):
		# Shadow cast by the rock above.
		_shade(img, Rect2i(dst.x, dst.y, ART, 3), Color(0, 0, 0, 0.35))


func _shade(img: Image, r: Rect2i, col: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


# --- Frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if flat:
		_w2a_process(delta)  # region W2a: dirty-driven chunk canvases
		return
	_time += delta
	if sim:
		# The world sickens as contamination grows.
		modulate = Color.WHITE.lerp(Color(0.78, 1.0, 0.7), clampf(sim.contamination.fraction() * 1.5, 0.0, 0.8))
		_update_particles(delta)
	queue_redraw()


func _draw() -> void:
	if sim == null or flat:  # flat mode paints through the chunk canvases (region W2a)
		return
	_draw_zones()
	_draw_contamination_field()  # region mutation
	_draw_designations()
	_draw_plants()  # region needs
	_draw_items()
	_draw_buildings()
	_draw_colonists()
	_draw_enemies()
	_draw_shots()
	_draw_wave_warning()
	_draw_particles()
	_draw_selection()
	_draw_night()  # region needs


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


const ITEM_SPRITES := {"essence_ore": "item_ore", "refined_essence": "item_refined", "waste": "item_waste",
		"raw_food": "item_raw_food", "meal": "item_meal"}
const PILE_OFFSETS: Array[Vector2] = [Vector2(0, 3), Vector2(-6, -3), Vector2(6, -4)]


func _draw_items() -> void:
	if flat:
		return  # standing piles come from WorldView3D
	for c: Vector2i in sim.items.stacks:
		var st: Dictionary = sim.items.stacks[c]
		var n := int(st["count"])
		var piles := 1 + int(n >= 15) + int(n >= 35)
		var center := cell_to_world(c) + Vector2(TILE, TILE) * 0.5
		for i in piles:
			_sprite(ITEM_SPRITES.get(st["item"], "item_ore"), center + PILE_OFFSETS[piles - 1 - i], Vector2(TILE, TILE))


func _draw_buildings() -> void:
	_draw_blueprints()  # region construction
	for b: Building in sim.buildings.list:
		var r := Rect2(cell_to_world(b.cell), Vector2(b.size) * TILE)
		var mod := Color(0.55, 0.5, 0.5) if b.broken else Color.WHITE
		var center := r.get_center()
		var kind := "-" if flat and Building3D.is_3d(b.def_id) else b.def_id  # region G1b
		match kind:
			"-":
				pass
			"hq":
				_sprite("capsule", center, r.size, false, mod)
			"refinery":
				_sprite("refinery", center, r.size, false, mod)
				if b.progress > 0 and not b.broken:
					_smoke(r.position + Vector2(r.size.x * 0.7, 4), Color(0.5, 0.75, 0.3, 0.5))
			"bed", "stove":  # region needs
				_sprite(b.def_id, center, r.size, false, mod)
			"turret":
				_sprite("turret_base", center, r.size, false, mod)
				var aim: float = _turret_aim.get(b.id, -PI / 2)
				draw_set_transform(center, aim, Vector2.ONE)
				_sprite("turret_barrel", Vector2(TILE * 0.2, 0), r.size * 1.1, false, mod)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"wall", "door":
				_sprite(b.def_id, center, r.size, false, mod)
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
		if flat:
			continue  # blob shadows come from WorldView3D
		_ellipse_shadow(p + Vector2(0, TILE * 0.4))
		var name := "colonist"
		if c.engineer:
			name += "_engineer"
		if c.is_sick(sim.tick):
			name += "_sick"
		_sprite(name, p + Vector2(0, bob), Vector2(TILE, TILE), flip)
		if c.carry_count > 0:
			_sprite(ITEM_SPRITES.get(c.carry_item, "item_ore"), p + Vector2(0, -TILE * 0.55 + bob), Vector2(TILE, TILE) * 0.7)
		# region combat
		if c.combat != null and c.combat.drafted:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -TILE * 0.95), p + Vector2(-7, -TILE * 0.7), p + Vector2(7, -TILE * 0.7)]), Color(0.95, 0.15, 0.15))
		# endregion
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
		if flat:
			continue  # blob shadows come from WorldView3D
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
	_draw_patrol()
	_draw_belt_draft()
	if pending_corner.x >= 0:
		draw_rect(Rect2(cell_to_world(pending_corner), Vector2(TILE, TILE)), Color(1, 1, 1, 0.9), false, 3.0)
	if selected_cell.x >= 0:
		draw_rect(Rect2(cell_to_world(selected_cell), Vector2(TILE, TILE)), Color(0.4, 0.9, 1.0, 0.9), false, 2.0)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)


# region construction
## Planned buildings: translucent sprite, delivered-materials bar, work bar.
func _draw_blueprints() -> void:
	for bp: Blueprint in sim.buildings.blueprints:
		var r := Rect2(cell_to_world(bp.cell), Vector2(bp.size) * TILE)
		var ghost := Color(0.6, 0.8, 1.0, 0.45)
		if _tex.has(bp.def_id) or bp.def_id in ["refinery"]:
			_sprite(bp.def_id, r.get_center(), r.size, false, ghost)
		elif bp.def_id == "turret":
			_sprite("turret_base", r.get_center(), r.size, false, ghost)
		else:
			draw_rect(r.grow(-2), Color(Color(bp.def["color"]), 0.45))
		draw_rect(r.grow(-1), Color(0.6, 0.85, 1.0, 0.8), false, 2.0)
		var need := 0
		for item: String in bp.def["cost"]:
			need += int(bp.def["cost"][item])
		_bar(Rect2(r.position + Vector2(3, r.size.y - 7), Vector2(r.size.x - 6, 4)), float(bp.delivered_total()) / maxf(need, 1.0), Color(0.75, 0.55, 1.0))
		if bp.work_done > 0.0:
			_bar(Rect2(r.position + Vector2(3, r.size.y + 1), Vector2(r.size.x - 6, 4)), bp.progress_fraction(), Color(0.4, 0.9, 0.5))
# region needs
func _draw_plants() -> void:
	for c: Vector2i in sim.farming.plants:
		var p: Plant = sim.farming.plants[c]
		var ripe := sim.farming.is_mature(p)
		var f := sim.farming.growth_fraction(p)
		var sz := Vector2(TILE, TILE) * (1.0 if ripe else 0.5 + 0.5 * f)
		_sprite("plant_ripe" if ripe else "plant_young", cell_to_world(c) + Vector2(TILE, TILE) * 0.5, sz)


## Night tint over the whole map (screen-space overlay is not needed: the world is the view).
func _draw_night() -> void:
	var cfg: Dictionary = sim.defs.time
	var dark := 1.0 - sim.clock.daylight()
	if dark <= 0.01:
		return
	var col := Color(str(cfg["night_tint"]))
	col.a = float(cfg["night_tint_alpha"]) * dark
	draw_rect(Rect2(Vector2.ZERO, world_size()), col)
# endregion

# region mutation
## Green wash by cell contamination; mutated cells go purple-green.
## One map-sized ImageTexture, only rows the sim marked dirty are re-coloured.
var _field_img: Image
var _field_tex: ImageTexture
var _field_bytes := PackedByteArray()  ## RGBA8, w*h*4
var _field_cursor := 0
var _field_rects: Array[Rect2i] = []  ## region W2a: cell spans rewritten by the last update
var _field_fresh := false
var field_pixel_writes := 0  ## cells whose colour changed (perf counter)


func _field_color(v: float, tainted: float, mutated: float) -> Color:
	if v < tainted * 0.4:
		return Color(0, 0, 0, 0)
	if v >= mutated:
		return Color(0.6, 0.25, 0.8, 0.32)
	return Color(0.35, 0.8, 0.25, clampf(v / maxf(mutated, 0.01), 0.0, 1.0) * 0.28)


## Brings the overlay image up to date with the field. Returns the texture.
## Only rows the sim marked dirty are visited and only cells whose 8-bit colour
## changed are rewritten; the image is then uploaded once.
func update_field_texture() -> ImageTexture:
	var mut := sim.mutation
	var w := sim.map.width
	var h := sim.map.height
	var fresh := _field_img == null or _field_img.get_width() != w or _field_img.get_height() != h
	if fresh:
		_field_bytes.resize(w * h * 4)
		_field_bytes.fill(0)
	if fresh:
		mut.dirty_rows.fill(1)
		_field_cursor = 0
	var budget := h if fresh else int(sim.defs.balance["field_perf"]["overlay_rows_per_frame"])
	var lo: float = mut.tainted_threshold() * 0.4
	var mutated: float = mut.mutated_threshold()
	var inv := 0.28 * 255.0 / maxf(mutated, 0.01)
	var writes := 0
	_field_rects.clear()  # region W2a
	_field_fresh = fresh
	var start := _field_cursor
	for k in h:
		if budget <= 0:
			break
		var y := (start + k) % h
		if mut.dirty_rows[y] == 0:
			continue
		mut.dirty_rows[y] = 0
		budget -= 1
		_field_cursor = (y + 1) % h
		var row := y * w
		var minx := w
		var maxx := -1
		for x in w:
			var v: float = mut.field[row + x]
			var o := (row + x) * 4
			var r := 0
			var g := 0
			var b := 0
			var a := 0
			if v >= mutated:
				r = 153
				g = 64
				b = 204
				a = 82
			elif v >= lo:
				r = 89
				g = 204
				b = 64
				a = int(minf(v * inv, 71.4))
			if _field_bytes[o + 3] == a and _field_bytes[o] == r:
				continue
			_field_bytes[o] = r
			_field_bytes[o + 1] = g
			_field_bytes[o + 2] = b
			_field_bytes[o + 3] = a
			writes += 1
			minx = mini(minx, x)
			maxx = x
		if maxx >= 0:
			_field_rects.append(Rect2i(minx, y, maxx - minx + 1, 1))
	field_pixel_writes += writes
	if fresh:
		_field_img = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, _field_bytes)
		_field_tex = ImageTexture.create_from_image(_field_img)
	elif writes > 0:
		_field_img.set_data(w, h, false, Image.FORMAT_RGBA8, _field_bytes)
		_field_tex.update(_field_img)
	return _field_tex


func _draw_contamination_field() -> void:
	if not show_field:
		return
	var tex := update_field_texture()
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(sim.map.width, sim.map.height) * TILE), false)
# endregion


# region batch3 ui
## Patrol route: the saved one faintly, the draft being edited brightly.
func _draw_patrol() -> void:
	var half := Vector2(TILE, TILE) * 0.5
	var saved: Array[Vector2i] = sim.idle_work.patrol_route if sim.idle_work != null else []
	for set_i in 2:
		var pts: Array[Vector2i] = saved if set_i == 0 else patrol_draft
		if set_i == 0 and not patrol_draft.is_empty():
			continue
		var col := Color(0.4, 0.8, 1.0, 0.45) if set_i == 0 else Color(1.0, 0.85, 0.2, 0.95)
		for i in pts.size():
			var p := cell_to_world(pts[i]) + half
			if i > 0:
				draw_line(cell_to_world(pts[i - 1]) + half, p, col, 2.0)
			draw_circle(p, TILE * 0.3, col)
# endregion


# region G1b
func turret_aim(id: int) -> float:
	return _turret_aim.get(id, -PI / 2)
# endregion


# region A2d
func _draw_belt_draft() -> void:
	for i in belt_draft.size():
		var c := belt_draft[i]
		var bad := belt_bad.has(c)
		var r := Rect2(cell_to_world(c), Vector2(TILE, TILE))
		draw_rect(r, Color(0.9, 0.15, 0.1, 0.55) if bad else Color(0.2, 0.85, 0.9, 0.45))
		var d := belt_last_dir
		if i + 1 < belt_draft.size():
			d = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)].find(belt_draft[i + 1] - c)
		if d >= 0:
			var v := Vector2([Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][d])
			var mid := r.get_center()
			draw_line(mid - v * TILE * 0.3, mid + v * TILE * 0.3, Color.WHITE, 3.0)
			draw_circle(mid + v * TILE * 0.3, 4.0, Color.WHITE)
# endregion


# region W2a
## Flat mode: the ground overlays are painted by three canvas items per chunk
## (under = zones/field/designations/plants, over = buildings/shots/selection,
## night = tint). A chunk canvas redraws, and its SubViewport re-renders once,
## only when something inside it changed (bus signals, per-tick polling of
## buildings/blueprints/plants, selection edits) or while it holds animated
## content (pulsing designations, smoke, shots, particles, wave arrow).
class ChunkCanvas:
	extends Node2D
	var view: WorldView
	var idx := 0
	var layer := 0

	func _draw() -> void:
		view._draw_chunk(self, idx, layer)


const _UNDER := 1
const _OVER := 2
const _NIGHT := 4
var _canvases: Array[ChunkCanvas] = []  # 3 per chunk: idx * 3 + layer
var _nm := PackedByteArray()  ## per chunk: layer bits needing a redraw
var _vd := PackedByteArray()  ## per chunk: viewport needs a refresh
var _anim_u := PackedByteArray()  ## chunk's under layer holds animated content
var _anim_o := PackedByteArray()
var _dyn_prev := {}  ## chunk idx -> true, chunks touched by shots/particles/wave arrow last frame
var _dyn_now := {}
var _last_tick := -1
var _bsig := {}  # building id -> [hp, condition, progress, broken, aim, cell, size]
var _psig := {}  # blueprint key -> [work_done, delivered, cell, size]
var _plant_sig := {}  # cell -> quantised growth state
var _sel_sig := 0
var _sel_rect := Rect2i()
var _sel_has := false
var _night_q := -1
var _night_col := Color.BLACK
var _night_col_s := ""
var _mod_last := Color.WHITE
var chunk_redraws := 0  ## canvas redraws executed (perf counter)


func _w2a_bind() -> void:
	if not flat:
		return
	var n := _chunk_sprites.size()
	for cv in _canvases:
		cv.queue_free()
	_canvases.clear()
	for i in n:
		for layer in 3:
			var cv := ChunkCanvas.new()
			cv.view = self
			cv.idx = i
			cv.layer = layer
			cv.z_index = layer
			add_child(cv)
			_canvases.append(cv)
	_nm.resize(n)
	_vd.resize(n)
	_anim_u.resize(n)
	_anim_o.resize(n)
	_nm.fill(7)
	_vd.fill(1)
	_anim_u.fill(0)
	_anim_o.fill(0)
	_dyn_prev.clear()
	_dyn_now.clear()
	_bsig.clear()
	_psig.clear()
	_plant_sig.clear()
	_last_tick = -1
	_sel_sig = 0
	_sel_has = false
	_night_q = -1
	_field_img = null
	_mod_last = Color(-1, 0, 0)
	var b := sim.bus
	b.zone_changed.connect(_w2a_cell_signal)
	b.zone_settings_changed.connect(_w2a_cell_signal)
	b.designation_changed.connect(_w2a_cell_signal)
	b.plant_sown.connect(_w2a_plant_signal)
	b.plant_harvested.connect(_w2a_plant_signal)
	b.map_switched.connect(_w2a_map_switched)


func _w2a_unbind() -> void:
	if sim != null:
		var b := sim.bus
		for pair in [[b.zone_changed, _w2a_cell_signal], [b.zone_settings_changed, _w2a_cell_signal],
				[b.designation_changed, _w2a_cell_signal], [b.plant_sown, _w2a_plant_signal],
				[b.plant_harvested, _w2a_plant_signal], [b.map_switched, _w2a_map_switched]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
	for cv in _canvases:
		cv.queue_free()
	_canvases.clear()
	_nm.clear()
	_vd.clear()


func _w2a_cell_signal(c: Vector2i) -> void:
	_mark_cell_nb(c)


func _w2a_plant_signal(c: Vector2i, _x: Variant, _y: Variant = 0) -> void:
	_mark_cell_nb(c)


func _w2a_map_switched(_id: int) -> void:
	if not _nm.is_empty():
		_mark_all(7)


## Marks layer bits `bits` dirty on every chunk (plus their viewports).
func _mark_all(bits: int) -> void:
	for i in _nm.size():
		_nm[i] |= bits
		_vd[i] = 1


## Marks the chunks overlapping a cell rect: layer bits for canvas redraw, and the viewport refresh.
func _mark_rect(r: Rect2i, bits: int) -> void:
	if _nm.is_empty() or sim == null:
		return
	var a := Vector2i(maxi(r.position.x, 0), maxi(r.position.y, 0))
	var e := Vector2i(mini(r.end.x - 1, sim.map.width - 1), mini(r.end.y - 1, sim.map.height - 1))
	if e.x < a.x or e.y < a.y:
		return
	var ca := ChunkLayer.chunk_of(a)
	var cb := ChunkLayer.chunk_of(e)
	for cy in range(ca.y, cb.y + 1):
		for cx in range(ca.x, cb.x + 1):
			var i := cy * _chunk_cols + cx
			_nm[i] |= bits
			_vd[i] = 1


func _mark_cell_nb(c: Vector2i) -> void:
	_mark_rect(Rect2i(c - Vector2i.ONE, Vector2i(3, 3)), _UNDER | _OVER)


func _dyn_add(px: Rect2) -> void:
	var a := Vector2i((px.position / TILE).floor())
	var e := Vector2i((px.end / TILE).floor())
	a = Vector2i(maxi(a.x, 0), maxi(a.y, 0))
	e = Vector2i(mini(e.x, sim.map.width - 1), mini(e.y, sim.map.height - 1))
	if e.x < a.x or e.y < a.y:
		return
	var ca := ChunkLayer.chunk_of(a)
	var cb := ChunkLayer.chunk_of(e)
	for cy in range(ca.y, cb.y + 1):
		for cx in range(ca.x, cb.x + 1):
			_dyn_now[cy * _chunk_cols + cx] = true


func _w2a_process(delta: float) -> void:
	_time += delta
	if sim == null or _nm.is_empty():
		return
	# The world sickens as contamination grows (a render-time modulate; only re-render on a visible change).
	var mod := Color.WHITE.lerp(Color(0.78, 1.0, 0.7), clampf(sim.contamination.fraction() * 1.5, 0.0, 0.8))
	if absf(mod.r - _mod_last.r) >= 0.004 or absf(mod.g - _mod_last.g) >= 0.004 or absf(mod.b - _mod_last.b) >= 0.004:
		_mod_last = mod
		modulate = mod
		_vd.fill(1)
	_update_particles(delta)
	if sim.tick != _last_tick:
		_last_tick = sim.tick
		_poll_buildings()
		if sim.tick % 5 == 0:
			_poll_plants()
		_track_enemies()
	_poll_selection()
	_poll_night()
	_poll_field()
	_poll_dynamic()
	for i in _nm.size():
		if _anim_u[i] != 0:
			_nm[i] |= _UNDER
		if _anim_o[i] != 0:
			_nm[i] |= _OVER
	_flush_dirty()


func _flush_dirty() -> void:
	var cl := ChunkLayer.find(get_world_2d())
	for i in _nm.size():
		if cl != null and i < cl.enabled.size() and not cl.enabled[i]:
			continue  # off screen: stays pending until the chunk comes back
		var m := _nm[i]
		if m != 0:
			for k in 3:
				if m & (1 << k) != 0:
					_canvases[i * 3 + k].queue_redraw()
					chunk_redraws += 1
			_nm[i] = 0
			_vd[i] = 1
		if _vd[i] != 0:
			_vd[i] = 0
			if cl != null:
				cl.mark(i)


func _mark_bld(cell: Vector2i, size: Vector2i) -> void:
	_mark_rect(Rect2i(cell - Vector2i.ONE, size + Vector2i(2, 2)), _OVER)


func _poll_buildings() -> void:
	var seen := {}
	for b: Building in sim.buildings.list:
		seen[b.id] = true
		var aim: float = _turret_aim.get(b.id, 0.0) if b.def_id == "turret" else 0.0
		var s: Array = _bsig.get(b.id, [])
		if s.is_empty():
			_bsig[b.id] = [b.hp, b.condition, b.progress, b.broken, aim, b.cell, b.size]
			_mark_bld(b.cell, b.size)
		elif s[0] != b.hp or s[1] != b.condition or s[2] != b.progress or s[3] != b.broken or s[4] != aim:
			s[0] = b.hp
			s[1] = b.condition
			s[2] = b.progress
			s[3] = b.broken
			s[4] = aim
			_mark_bld(b.cell, b.size)
	for bp: Blueprint in sim.buildings.blueprints:
		var key := -1 - bp.id
		seen[key] = true
		var dl := bp.delivered_total()
		var s: Array = _psig.get(key, [])
		if s.is_empty():
			_psig[key] = [bp.work_done, dl, bp.cell, bp.size]
			_mark_bld(bp.cell, bp.size)
		elif s[0] != bp.work_done or s[1] != dl:
			s[0] = bp.work_done
			s[1] = dl
			_mark_bld(bp.cell, bp.size)
	for id: int in _bsig.keys():
		if not seen.has(id):
			var s: Array = _bsig[id]
			_mark_bld(s[5], s[6])
			_bsig.erase(id)
	for id: int in _psig.keys():
		if not seen.has(id):
			var s: Array = _psig[id]
			_mark_bld(s[2], s[3])
			_psig.erase(id)


func _poll_plants() -> void:
	var seen := {}
	for c: Vector2i in sim.farming.plants:
		var p: Plant = sim.farming.plants[c]
		var q := 1000 if sim.farming.is_mature(p) else int(sim.farming.growth_fraction(p) * 32.0)
		seen[c] = true
		if _plant_sig.get(c, -1) != q:
			_plant_sig[c] = q
			_mark_cell_nb(c)
	for c: Vector2i in _plant_sig.keys():
		if not seen.has(c):
			_plant_sig.erase(c)
			_mark_cell_nb(c)


## Last known enemy positions (kill particles); flat mode never draws the units themselves.
func _track_enemies() -> void:
	var seen := {}
	for e: Enemy in sim.threats.enemies:
		seen[e.id] = true
		_enemy_last[e.id] = [e.visual_pos() * TILE + Vector2(TILE, TILE) * 0.5, e.hp, 0.0]
	if _enemy_last.size() != seen.size():
		for id in _enemy_last.keys():
			if not seen.has(id):
				_enemy_last.erase(id)


func _selection_bounds() -> Rect2i:
	var pts: Array[Vector2i] = []
	if pending_corner.x >= 0:
		pts.append(pending_corner)
	if selected_cell.x >= 0:
		pts.append(selected_cell)
	pts.append_array(patrol_draft)
	if sim.idle_work != null:
		pts.append_array(sim.idle_work.patrol_route)
	pts.append_array(belt_draft)
	if pts.is_empty():
		return Rect2i()
	var r := Rect2i(pts[0], Vector2i.ONE)
	for c in pts:
		r = r.expand(c).expand(c + Vector2i.ONE)
	return r


func _poll_selection() -> void:
	var saved: Array = sim.idle_work.patrol_route if sim.idle_work != null else []
	var sig := hash([pending_corner, selected_cell, patrol_draft, saved, belt_draft, belt_bad, belt_last_dir])
	if sig == _sel_sig:
		return
	_sel_sig = sig
	var nr := _selection_bounds()
	if _sel_has:
		_mark_rect(_sel_rect.grow(1), _OVER)
	if nr.size != Vector2i.ZERO:
		_mark_rect(nr.grow(1), _OVER)
	_sel_rect = nr
	_sel_has = nr.size != Vector2i.ZERO


func _night_color() -> Color:
	var cfg: Dictionary = sim.defs.time
	if str(cfg["night_tint"]) != _night_col_s:
		_night_col_s = str(cfg["night_tint"])
		_night_col = Color(_night_col_s)
	var col := _night_col
	col.a = float(cfg["night_tint_alpha"]) * (1.0 - sim.clock.daylight())
	return col


func _poll_night() -> void:
	var col := _night_color()
	var dark := 1.0 - sim.clock.daylight()
	var q := int(roundf(col.a * 255.0)) if dark > 0.01 else 0
	if q != _night_q:
		_night_q = q
		_mark_all(_NIGHT)


func _poll_field() -> void:
	if not show_field:
		return
	update_field_texture()
	if _field_fresh:
		_mark_all(_UNDER)
		return
	for r in _field_rects:
		_mark_rect(r, _UNDER)


func _wave_visible() -> bool:
	var t: ThreatSystem = sim.threats
	if not t.awakened or t.next_spawn_origin.x < 0:
		return false
	return t.wave_active or t.next_wave_tick - sim.tick < int(t.cfg["warning_ticks"])


## Chunks touched by moving cosmetics this frame and the previous one are redrawn.
func _poll_dynamic() -> void:
	_dyn_now.clear()
	var half := Vector2(TILE, TILE) * 0.5
	for s: Array in sim.threats.shots:
		var a: Vector2 = s[0] * TILE + half
		var b: Vector2 = s[1] * TILE + half
		_dyn_add(Rect2(a, Vector2.ZERO).expand(b).grow(TILE * 0.6))
		var bld := sim.buildings.at(Vector2i(roundi(float(s[0].x)), roundi(float(s[0].y))))
		if bld != null:
			_turret_aim[bld.id] = (b - a).normalized().angle()
	for p in _particles:
		var pos: Vector2 = p[0]
		_dyn_add(Rect2(pos - Vector2(4, 4), Vector2(8, 8)))
	if _wave_visible():
		var c := Vector2(sim.threats.next_spawn_origin) * TILE + half
		_dyn_add(Rect2(c - Vector2(TILE, TILE) * 2.4, Vector2(TILE, TILE) * 4.8))
	for i: int in _dyn_now:
		_nm[i] |= _OVER
		_vd[i] = 1
	for i: int in _dyn_prev:
		if not _dyn_now.has(i):
			_nm[i] |= _OVER
			_vd[i] = 1
	var t := _dyn_prev
	_dyn_prev = _dyn_now
	_dyn_now = t


func _draw_chunk(cv: ChunkCanvas, idx: int, layer: int) -> void:
	if sim == null or idx >= _chunk_sprites.size():
		return
	var ch := Vector2i(idx % _chunk_cols, idx / _chunk_cols)
	var r := ChunkLayer.chunk_cells(ch, sim.map.width, sim.map.height)
	match layer:
		0:
			_c_under(cv, idx, r)
		1:
			_c_over(cv, idx, ch)
		_:
			if _night_q > 0:
				cv.draw_rect(Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE), _night_color())


func _c_sprite(cv: CanvasItem, name: String, center: Vector2, size: Vector2, mod := Color.WHITE) -> void:
	cv.draw_texture_rect(_tex[name], Rect2(center - size * 0.5, size), false, mod)


func _c_bar(cv: CanvasItem, r: Rect2, frac: float, col: Color) -> void:
	cv.draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
	cv.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)


func _c_smoke(cv: CanvasItem, origin: Vector2, col: Color) -> void:
	for i in 3:
		var t := fmod(_time * 0.8 + i / 3.0, 1.0)
		var c := col
		c.a *= 1.0 - t
		cv.draw_circle(origin + Vector2(sin(_time * 2.0 + i) * 3.0, -t * 18.0), 3.0 + t * 5.0, c)


## Cells of `cells` (a Dictionary keyed by Vector2i) inside chunk rect `r`.
static func _cells_in(cells: Dictionary, r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if cells.size() < r.size.x * r.size.y:
		for c: Vector2i in cells:
			if r.has_point(c):
				out.append(c)
	else:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if cells.has(Vector2i(x, y)):
					out.append(Vector2i(x, y))
	return out


func _c_under(cv: ChunkCanvas, idx: int, r: Rect2i) -> void:
	var m := sim.map
	# Zones (outline only on the zone's outer border).
	for zone_id: String in sim.items.zone_cells:
		var cells: Dictionary = sim.items.zone_cells[zone_id]
		if cells.is_empty():
			continue
		var col := Color(sim.defs.zones[zone_id]["color"])
		var fill := col
		fill.a = 0.22
		var edge := col.lightened(0.3)
		edge.a = 0.8
		for c in _cells_in(cells, r):
			var p := cell_to_world(c)
			cv.draw_rect(Rect2(p, Vector2(TILE, TILE)), fill)
			if not cells.has(c + Vector2i(0, -1)):
				cv.draw_line(p, p + Vector2(TILE, 0), edge, 2.0)
			if not cells.has(c + Vector2i(0, 1)):
				cv.draw_line(p + Vector2(0, TILE), p + Vector2(TILE, TILE), edge, 2.0)
			if not cells.has(c + Vector2i(-1, 0)):
				cv.draw_line(p, p + Vector2(0, TILE), edge, 2.0)
			if not cells.has(c + Vector2i(1, 0)):
				cv.draw_line(p + Vector2(TILE, 0), p + Vector2(TILE, TILE), edge, 2.0)
	# Contamination overlay: this chunk's slice of the map-sized texture.
	if show_field and _field_tex != null:
		cv.draw_texture_rect_region(_field_tex, Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE), Rect2(r), Color.WHITE)
	# Mine designations (pulsing, so the chunk stays animated while any exists).
	var pulse := 0.65 + 0.35 * sin(_time * 4.0)
	var anim := 0
	for y in range(r.position.y, r.end.y):
		var row := y * m.width
		for x in range(r.position.x, r.end.x):
			if m.mine_designated[row + x] != 0:
				anim = 1
				var p := cell_to_world(Vector2i(x, y))
				cv.draw_rect(Rect2(p + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(1, 0.85, 0.3, 0.8 * pulse), false, 2.0)
				_c_sprite(cv, "designation_mine", p + Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE) * 0.8, Color(1, 1, 1, 0.9))
	_anim_u[idx] = anim
	# Plants.
	var plants: Dictionary = sim.farming.plants
	if not plants.is_empty():
		for c in _cells_in(plants, r):
			var p: Plant = plants[c]
			var ripe := sim.farming.is_mature(p)
			var f := sim.farming.growth_fraction(p)
			var sz := Vector2(TILE, TILE) * (1.0 if ripe else 0.5 + 0.5 * f)
			_c_sprite(cv, "plant_ripe" if ripe else "plant_young", cell_to_world(c) + Vector2(TILE, TILE) * 0.5, sz)


func _c_over(cv: ChunkCanvas, idx: int, ch: Vector2i) -> void:
	var anim := 0
	for bp: Blueprint in sim.buildings.blueprints:
		if ChunkLayer.chunk_of(bp.cell) != ch:
			continue
		var br := Rect2(cell_to_world(bp.cell), Vector2(bp.size) * TILE)
		var ghost := Color(0.6, 0.8, 1.0, 0.45)
		if _tex.has(bp.def_id) or bp.def_id in ["refinery"]:
			_c_sprite(cv, bp.def_id, br.get_center(), br.size, ghost)
		elif bp.def_id == "turret":
			_c_sprite(cv, "turret_base", br.get_center(), br.size, ghost)
		else:
			cv.draw_rect(br.grow(-2), Color(Color(bp.def["color"]), 0.45))
		cv.draw_rect(br.grow(-1), Color(0.6, 0.85, 1.0, 0.8), false, 2.0)
		var need := 0
		for item: String in bp.def["cost"]:
			need += int(bp.def["cost"][item])
		_c_bar(cv, Rect2(br.position + Vector2(3, br.size.y - 7), Vector2(br.size.x - 6, 4)), float(bp.delivered_total()) / maxf(need, 1.0), Color(0.75, 0.55, 1.0))
		if bp.work_done > 0.0:
			_c_bar(cv, Rect2(br.position + Vector2(3, br.size.y + 1), Vector2(br.size.x - 6, 4)), bp.progress_fraction(), Color(0.4, 0.9, 0.5))
	for b: Building in sim.buildings.list:
		if ChunkLayer.chunk_of(b.cell) != ch:
			continue
		var br := Rect2(cell_to_world(b.cell), Vector2(b.size) * TILE)
		var mod := Color(0.55, 0.5, 0.5) if b.broken else Color.WHITE
		var center := br.get_center()
		var kind := "-" if Building3D.is_3d(b.def_id) else b.def_id
		match kind:
			"-":
				pass
			"hq":
				_c_sprite(cv, "capsule", center, br.size, mod)
			"refinery":
				_c_sprite(cv, "refinery", center, br.size, mod)
				if b.progress > 0 and not b.broken:
					anim = 1
					_c_smoke(cv, br.position + Vector2(br.size.x * 0.7, 4), Color(0.5, 0.75, 0.3, 0.5))
			"bed", "stove":
				_c_sprite(cv, b.def_id, center, br.size, mod)
			"turret":
				_c_sprite(cv, "turret_base", center, br.size, mod)
				var aim: float = _turret_aim.get(b.id, -PI / 2)
				cv.draw_set_transform(center, aim, Vector2.ONE)
				_c_sprite(cv, "turret_barrel", Vector2(TILE * 0.2, 0), br.size * 1.1, mod)
				cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"wall", "door":
				_c_sprite(cv, b.def_id, center, br.size, mod)
			_:
				cv.draw_rect(br.grow(-2), Color(b.def["color"]) * mod)
		if b.broken:
			anim = 1
			_c_smoke(cv, center, Color(0.3, 0.3, 0.3, 0.6))
			if int(_time * 6.0) % 3 == 0:
				cv.draw_circle(center + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 2.0, Color(1, 0.85, 0.3))
		if b.hp < b.max_hp:
			_c_bar(cv, Rect2(br.position + Vector2(3, -6), Vector2(br.size.x - 6, 4)), b.hp / b.max_hp, Color(0.9, 0.25, 0.25))
		if b.is_machine() and b.condition < 100.0:
			_c_bar(cv, Rect2(br.position + Vector2(3, br.size.y + 2), Vector2(br.size.x - 6, 3)), b.condition / 100.0, Color(0.95, 0.75, 0.2))
		if not b.recipe.is_empty() and b.progress > 0:
			var f := float(b.progress) / int(b.recipe["work_ticks"])
			cv.draw_arc(center, TILE * 0.3, -PI / 2, -PI / 2 + TAU * f, 24, Color(0.85, 0.6, 1.0), 3.0)
	var half := Vector2(TILE, TILE) * 0.5
	# Shots belong to the chunk of their muzzle.
	for s: Array in sim.threats.shots:
		var a: Vector2 = s[0] * TILE + half
		var b: Vector2 = s[1] * TILE + half
		var dir := (b - a).normalized()
		var muzzle := a + dir * TILE * 0.55
		if ChunkLayer.chunk_of(world_to_cell(muzzle)) != ch:
			continue
		cv.draw_line(muzzle, b, Color(1, 0.95, 0.55, 0.9), 2.0)
		cv.draw_circle(muzzle, 4.0, Color(1, 0.9, 0.4, 0.9))
		cv.draw_circle(b, 3.0, Color(1, 1, 0.8, 0.9))
	if _wave_visible() and ChunkLayer.chunk_of(sim.threats.next_spawn_origin) == ch:
		_c_wave_warning(cv)
		anim = 1
	for p in _particles:
		if ChunkLayer.chunk_of(world_to_cell(p[0])) != ch:
			continue
		var col: Color = p[4]
		col.a = 1.0 - p[2] / p[3]
		cv.draw_rect(Rect2(p[0] - Vector2(p[5], p[5]) * 0.5, Vector2(p[5], p[5])), col)
	_anim_o[idx] = anim
	_c_selection(cv, ch)


func _c_wave_warning(cv: CanvasItem) -> void:
	var o := sim.threats.next_spawn_origin
	var c := Vector2(o) * TILE + Vector2(TILE, TILE) * 0.5
	var inward: Vector2
	if o.x == 0 or o.x == sim.map.width - 1:
		inward = Vector2(1.0 if o.x == 0 else -1.0, 0.0)
	else:
		inward = Vector2(0.0, 1.0 if o.y == 0 else -1.0)
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var col := Color(1.0, 0.15, 0.1, 0.45 + 0.5 * pulse)
	var side := Vector2(-inward.y, inward.x)
	var tip := c + inward * TILE * (1.2 + 0.4 * pulse)
	var base := c - inward * TILE * 0.2
	cv.draw_colored_polygon(PackedVector2Array([tip, base + side * TILE * 0.6, base - side * TILE * 0.6]), col)
	cv.draw_circle(c, TILE * (0.5 + 0.3 * pulse), Color(col, 0.3))


func _c_selection(cv: CanvasItem, ch: Vector2i) -> void:
	var half := Vector2(TILE, TILE) * 0.5
	var saved: Array[Vector2i] = sim.idle_work.patrol_route if sim.idle_work != null else []
	for set_i in 2:
		var pts: Array[Vector2i] = saved if set_i == 0 else patrol_draft
		if set_i == 0 and not patrol_draft.is_empty():
			continue
		var col := Color(0.4, 0.8, 1.0, 0.45) if set_i == 0 else Color(1.0, 0.85, 0.2, 0.95)
		for i in pts.size():
			if ChunkLayer.chunk_of(pts[i]) != ch:
				continue
			var p := cell_to_world(pts[i]) + half
			if i > 0:
				cv.draw_line(cell_to_world(pts[i - 1]) + half, p, col, 2.0)
			cv.draw_circle(p, TILE * 0.3, col)
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in belt_draft.size():
		var c := belt_draft[i]
		if ChunkLayer.chunk_of(c) != ch:
			continue
		var bad := belt_bad.has(c)
		var r := Rect2(cell_to_world(c), Vector2(TILE, TILE))
		cv.draw_rect(r, Color(0.9, 0.15, 0.1, 0.55) if bad else Color(0.2, 0.85, 0.9, 0.45))
		var d := belt_last_dir
		if i + 1 < belt_draft.size():
			d = dirs.find(belt_draft[i + 1] - c)
		if d >= 0:
			var v := Vector2(dirs[d])
			var mid := r.get_center()
			cv.draw_line(mid - v * TILE * 0.3, mid + v * TILE * 0.3, Color.WHITE, 3.0)
			cv.draw_circle(mid + v * TILE * 0.3, 4.0, Color.WHITE)
	if pending_corner.x >= 0 and ChunkLayer.chunk_of(pending_corner) == ch:
		cv.draw_rect(Rect2(cell_to_world(pending_corner), Vector2(TILE, TILE)), Color(1, 1, 1, 0.9), false, 3.0)
	if selected_cell.x >= 0 and ChunkLayer.chunk_of(selected_cell) == ch:
		cv.draw_rect(Rect2(cell_to_world(selected_cell), Vector2(TILE, TILE)), Color(0.4, 0.9, 1.0, 0.9), false, 2.0)
# endregion
