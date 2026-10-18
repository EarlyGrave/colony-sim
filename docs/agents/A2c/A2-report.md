# A2c report - belt + machine 3D view
Branch a2c-belt-art (base c037bec). Screenshot: docs/agents/A2c/belts.png (tools/a2c_shot.gd, run under xvfb-run, places loop/line/machines via Simulation commands).
Files: view/belt_layer.gd (new BeltLayer), tests/test_belt_view.gd (5 tests), tools/a2c_shot.gd.
Regions A2c: view/world_3d.gd (hooks: bind/clear/sync, _a2c_update), view/building_3d.gd (machine heights/tops, port arrows), tools/gen_art.py (belt_art, machine_art).
Belts: one MultiMesh per 32x32 chunk (instance custom data = dir). Shader animates the chevron/roller texture along dir (scroll = belt speed in cells/s), so no per-frame CPU work for belts.
Rebuild: only chunks whose dir slice changed (dir array compared per frame, rebuild counter `rebuilds`).
Items: second MultiMesh per chunk (colored squares from items.json color), only updated for on-screen chunks when belts.item_count > 0; position = BeltLayer.item_position (progress/tpc along dir).
Draw calls: <= 2 per chunk (belts + items); 2000 belts on 250x250 = 2000 instances, <= 1 belt MultiMesh per chunk (tested).
Machines: miner/smelter/assembler/storage_in/out are 3D blocks (heights 0.6/0.85/0.7/0.35) with new top art machine_*.png; FLAT_FALLBACK now only wall, training_dummy, belt.
Port arrows: flat Sprite3D at each port cell (def ports dx,dy relative to cell); out points along port dir, in points back into the machine (opposite of port dir) - i.e. the feeding belt must point that way. Green = in, orange = out.
New art: belt_tile, port_in, port_out, machine_miner/smelter/assembler/storage_in/storage_out (regenerate with python3 tools/gen_art.py).
Perf: not measured in frames (llvmpipe); per-frame CPU is the 62k-byte dir compare plus one 1024-cell scan per visible chunk when items exist.
Caveat: belt items move per sim tick (no sub-tick interpolation); belts draw under items at y=0.02/0.05, above ground, below blocks.
Tests: full suite run result appended below.
Full suite: 6 failures = same baseline as c037bec (test_mining x2, storyteller cave_in, ui_perks, waves x2); test_belt_view 5/5 pass.
