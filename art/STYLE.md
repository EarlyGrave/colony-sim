# Pixel-art style guide

Derived from the existing pipeline (`tools/gen_art.py` -> `assets/sprites/`,
drawn by `view/world_view.gd`). Where this file and the code disagree, the
code wins until this file is updated.

## 1. Grid, scale, filtering

- Source tile: **16x16 px** (`ART = 16` in `world_view.gd`, "authored at 16 px per tile").
- Drawn tile: **32 px** (`TILE = 32.0`), i.e. a clean **2x** integer upscale.
- Filtering: **nearest** (`TEXTURE_FILTER_NEAREST`); never bilinear, never rotate
  or non-integer-scale pixel art (the brute is drawn at 1.5x as an exception for size
  readability; keep new enemies at 1.0x or 2.0x where possible).
- Pixel grid rule: every sprite is a whole multiple of 16 px (16x16 small, 32x32 for
  2x2-tile buildings such as refinery/capsule). One source pixel = one 2x2 block on screen.
  No half pixels, no anti-aliasing, no semi-transparent edge pixels (the only alpha
  used is the capsule scorch shadow, alpha 160, as a ground decal).
- Small sprites are authored as ASCII grids with a palette (`grid(rows, pal)`);
  symmetric ones as left halves via `mirror()`. Large buildings use PIL primitives
  (`rectangle`, `ellipse`, `point`) with a 1-px outline.

## 2. Palette (actual values in gen_art.py)

| Purpose | Colors |
|---|---|
| Outline (universal) | `#1a1420` |
| Terrain: ground | base `#4a3c2c`; speckle `#544531 #403325 #57483a`; pebbles `#7a6a58 #5e5040`; grass tuft `#5c5532` |
| Terrain: rock wall | base `#6e6a64`; speckle `#7a7670 #625e58 #827e78`; crack `#4e4a46`; top edge highlight `#8c8882` |
| Terrain: essence ore vein | base `#3c3448`; speckle `#463d54 #342c3e`; crystal `#9b6cff`, rim `#5b3fa0`, highlight `#d3a8ff` |
| Essence (resource) | ore `#9b6cff / #d3a8ff`; refined `#d36bff / #f2c2ff`; tank glow `#b46cff / #e2c2ff`, tank window bg `#2a1838` |
| Waste / contamination | `#6f9a2a / #4c6c1c`, hazard mark `#e6d84a`; chimney glow `#7fbf3f` |
| Colonists | jumpsuit `#e07b28 / #a8541a`; skin `#f0c8a0 / #c89670`; hair `#4a3020`; engineer helmet `#3a78d0 / #24508c`; sick skin `#9fd06a / #6a9a3c`; white `#f4f0e8` |
| Enemies | crawler `#c83a2c / #8a2018`; brute `#7a2a4a / #4e1830`, eye `#ffd23a` |
| Machines / metal | `#7c8794 #4f5866 #b8c2cc`, teal accent `#4fb3a9`; refinery platform `#3b3f47 #2a2d33`, tank `#6c7480 #9aa4b0`, chimney `#555b66 #7c8490`, pipes `#8a6a40`, panel `#2c3a3a`, hazard dots `#e0b030`, LEDs `#ff4040 #40ff80` |
| Capsule | hull `#c9a227 / #e8c650 / #7a5c14`, fins `#8a6a1a`, window `#2c4a66 / #8ac8f0`, scorch `#2a221a` |
| UI icons (current) | pickaxe: steel `#b8c2cc`, head `#4f5866 / #7c8794`, wood handle `#a0703c` |

Reserved hues (do not reuse for unrelated things): **purple = essence**, **toxic
green/yellow = waste**, **red/magenta = enemies**, **orange = colonists**,
**blue = engineer/safe tech**.

### Rule for new resources

1. **Distinct hue family per resource** - at least ~40 degrees of hue apart from every
   existing resource, and never purple/toxic-green/red.
2. **Distinct silhouette per resource** (phone-readable even in greyscale): ore chunk =
   lumpy rock with colored flecks; coal = angular black lumps; wood = horizontal log with
   ring end; stone = grey flat slab; sand = low flat pile; clay = smooth rounded blob;
   fiber = thin bundle of strands; berries = cluster of 3 round dots + leaf.
3. Iron vs copper ore must differ by **both** hue (grey-blue vs orange-teal) **and**
   fleck pattern (iron: few large square flecks; copper: many small dots + green patina edge).
4. Each color gets 3 tones (dark / base / light) like the existing ramps; outline `#1a1420`.

### Proposed colors for new raw resources (dark / base / light)

| Resource | Dark | Base | Light | Silhouette |
|---|---|---|---|---|
| wood | `#5a3a1e` | `#8a5a2b` | `#b98348` | log, horizontal, ring end |
| stone | `#6b6f78` | `#9aa0a8` | `#c4c9cf` | flat angular slab (cooler/lighter than rock wall `#6e6a64`) |
| iron_ore | `#3d4a5c` | `#6a7c94` | `#a3b6cf` | lumpy, few big square flecks (blue-grey) |
| copper_ore | `#8a4a1e` | `#d97a3a` | `#f0b080` | lumpy, many dots, patina `#3fae8c` |
| coal | `#14121a` | `#2e2c36` | `#5a5864` | angular black lumps, white glint pixel |
| sand | `#b59a5a` | `#e0c882` | `#f3e5b0` | low flat mound |
| clay | `#8a4e3a` | `#b9694c` | `#d99a7c` | smooth rounded blob |
| fiber | `#7a8a2a` | `#b4c44a` | `#dbe58a` | thin strand bundle, tied middle |
| berries | `#8a1c3a` | `#d6335a` | `#ff8aa4` | 3-dot cluster + green leaf `#4f9a3a` |

Check: coal is near-black but kept off the outline color `#1a1420` by the lighter base;
berries red is less saturated/pinker than crawler red `#c83a2c`; copper `#d97a3a` is
shifted away from colonist orange `#e07b28` by the patina + ore silhouette (an item on
the ground is never body-shaped). Review both on a phone screenshot before locking.

## 3. Outline, shading, lighting (as used)

- **1-px dark outline** `#1a1420` around every character, creature, item and machine;
  tiles (terrain) have **no outline**.
- Light from **top-left**: highlight pixels top/left (`l`, `V`, `#e8c650` strip on the left of
  the capsule hull, top-edge line on rock), shade bottom/right (`O`, `R`, `P` ramps).
- Flat ramps of **2-3 tones** per material; no dithering, no gradients. Terrain texture
  comes from sparse random speckle (40-50 px of 256) in +-1 tone of the base.
- Characters are drawn facing right and mirrored in code (`flip`); sprites are
  left-right symmetric where possible (`mirror()`), so facing needs no extra art.
- Ground contact: a soft ellipse shadow is drawn in code (`_ellipse_shadow`), not in the PNG.
- Emissive things (essence window, waste glow, eyes, LEDs) use the lightest tone of their
  ramp and sit on a very dark background (`#2a1838`) for contrast.

## 4. Animation

Existing (all cosmetic, done in code, `_time` based - sim stays deterministic):
- Colonist walk: vertical bob `-abs(sin(t*12))*2` px while moving (single frame sprite).
- Enemy: wobble `sin(t*10 + id)*1.5` px.
- Chimney/waste smoke: procedural puffs (`_smoke`), no sprite frames.
- Turret: two layers - `turret_base` static + `turret_barrel` rotated in code.

Rule for new content (frames are optional polish, never required for gameplay):
- Machine working: **2-4 frames**, ~4-6 fps, looped; only moving parts change (gear, piston,
  glow, LED); the silhouette and footprint never change between frames.
- Colonist walk: **2 frames** (contact + passing) or keep bob-only for tools/carry layers;
  4 frames max.
- Enemy attack: **2-3 frames** (windup, strike, [recover]); idle can stay a code wobble.
- All frames same size as frame 0, same outline, same palette; frame 0 doubles as the
  idle/static sprite.

## 5. Phone readability (390x844, UI scale ~0.85 x DPR)

- A tile is 32 px on screen (~27 css px at 0.85); the camera may zoom out, so a feature
  smaller than **2x2 source px** disappears. Minimum detail: 2x2 px; minimum gap between
  features: 1 px; minimum eye/LED: 1 px but only on a dark field.
- Identify objects by **silhouette first, color second**; verify by viewing the sprite
  in greyscale at 1x zoom.
- Items drawn on ground/carried (0.7 scale) must fit in about 10x10 source px, centered,
  with transparent margin >= 2 px.
- HUD icons: 16x16 source, 2x pixel-perfect, 1-px outline, max 3 tones, **one idea per icon**,
  no text inside the icon; touch target >= 64 px (button), icon centered inside it. Use the
  same hue as the in-world resource so icon and item are recognized as the same thing.

## 6. Pipeline: adding a sprite

1. Add a function (or extend `items()` / `terrain()` / ...) in `tools/gen_art.py`, using
   `grid()` + ASCII rows for 16x16, or PIL primitives for >= 32x32. Fixed seeds only
   (deterministic output). Add new palette letters locally via `{**PAL, ...}`.
2. Call it from `main()`.
3. `python3 tools/gen_art.py`  (requires Pillow).
4. `godot --headless --path . --import` to create the `.png.import` file.
5. Commit the PNG **and** its `.png.import`, plus the gen_art.py change; reference the
   sprite by id in `data/*.json` or the `view/` sprite tables, never by hard-coded path in `sim/`.
6. Do not hand-edit PNGs - always regenerate.

Naming: `<kind>_<id>[_<frame>].png`, lowercase snake_case. Kinds: `item`, `building`,
`enemy`, `weapon`, `tile`, `icon`, `colonist`, `fx`. Examples: `item_iron_ore.png`,
`building_smelter_0.png`, `building_smelter_1.png`, `enemy_spitter_attack_1.png`,
`icon_wood.png`. Terrain variants keep `ground_N`/`rock_N`/`ore_N` (legacy names; new
terrain uses `tile_<id>_<variant>`). Existing legacy names (`brute`, `crawler`, `refinery`,
`capsule`, `turret_*`, `designation_mine`) stay until a deliberate rename.

## 7. Sprite checklist for E10-E17

(Final lists depend on `data/*.json`; ids below are proposals. Tick when generated.)

### Items (16x16, `item_*`)
- [ ] wood  [ ] stone  [ ] iron_ore  [ ] copper_ore  [ ] coal  [ ] sand  [ ] clay  [ ] fiber  [ ] berries
- [ ] iron_plate  [ ] copper_plate  [ ] steel  [ ] glass  [ ] brick  [ ] rope/cloth
- [ ] plank  [ ] ammo  [ ] food_meal  [ ] medkit  [ ] tool (pick/axe)
- Existing: item_ore, item_refined, item_waste

### Terrain / resource nodes (16x16, 3-4 variants each)
- [ ] tree (+stump)  [ ] bush_berries  [ ] stone_outcrop  [ ] iron_vein  [ ] copper_vein
- [ ] coal_vein  [ ] sand patch  [ ] clay patch  [ ] fiber plant  [ ] floor/wall tiles (wood, stone)
- [ ] contamination overlay tiles (light / heavy)

### Buildings (16x16 or 32x32; 2-4 frame work animation where noted)
- [ ] sawmill (anim)  [ ] stone cutter  [ ] furnace/smelter (anim)  [ ] kiln (anim)
- [ ] workbench  [ ] kitchen/stove (anim)  [ ] storage crate/shelf  [ ] bed  [ ] power generator (anim)
- [ ] wall  [ ] door  [ ] conveyor (4 directions x 2 frames)
- [ ] clinic/medbay  [ ] scrubber/filter (waste cleaning, anim)
- Existing: refinery, capsule, turret_base/turret_barrel

### Weapons (16x16, `weapon_*`; held/icon)
- [ ] pistol  [ ] rifle  [ ] club/pipe  [ ] shotgun  [ ] flamethrower
- [ ] turret variants (gun, heavy, flame) base + barrel

### Enemies (16x16 or 32x32; walk 2 frames + attack 2-3 frames)
- [ ] spitter (ranged, toxic green-adjacent but red/magenta family - keep off waste green)
- [ ] swarmer (small, fast)  [ ] tank/behemoth (32x32)  [ ] flyer
- Existing: crawler, brute

### Colonists / UI
- [ ] colonist walk frames (2)  [ ] colonist carrying overlay  [ ] role variants (builder, medic)
- [ ] HUD icons for every item above (`icon_<id>`), alarm, build, zone, speed controls
