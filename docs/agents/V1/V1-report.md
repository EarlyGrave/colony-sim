# V1 report - port arrows + voxel machine models
Base bb5ac0a. View-only; sim/ untouched.
- Port arrows (tools/gen_art.py region A2c): IN = cyan chevron-tail arrow, OUT = magenta solid arrow (shapes differ for color-blind). Machine edge marks recoloured to match.
- data/models.json (new, view-only): per type a list of boxes {o, s, c, e (unshaded glow), g (animated group), on (only while working)} + groups {anim bob|swing|smoke, pivot, speed, amp}. Coordinates are cells relative to the footprint corner, so footprints stay exact.
- view/building_3d.gd region V1: models built once per type (SurfaceTool, merged static mesh + working-only glow mesh + one mesh per animated group), reused by all buildings. Unshaded shader with vertex colours, per-face shading and a small pixel-noise dither (nearest-look). Old Building3D API, HEIGHTS, TOP_ART, ports unchanged.
- Models: miner (frame, orange out chute, drill bit bobs + spins), smelter (furnace, chimney, glowing mouth + chimney glow + 3 smoke puffs while working), assembler (body, console, swinging arm with red gripper), storage_in (crate + funnel hopper + cyan inlet), storage_out (crate + magenta lamp + spout).
- Working state: Building3D.is_working(b) reads sim (processor: progress>0 or can_run_recipe; extractor: output below capacity); broken => never works and tinted dark (0.45). Time-based animation from Time.get_ticks_msec, no sim mutation.
- Not done (optional): hq, refinery, turret, workbench, stove keep flat-top blocks.
- Screenshots: scratchpad v1_default.png, v1_zoom_a.png (miner/smelter, zoom 2.2), v1_zoom_b.png (assembler, 2.2). tools/a2c_shot.gd takes optional args: zoom dx dy.
- Smelter glow/smoke not seen in shots (no recipe input in the scene); logic untested visually.
- Tests: see commit message / full suite result below.
- Full suite: 376 passed, 0 failed.
