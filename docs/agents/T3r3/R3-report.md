# T3 report (line damage, repair, turret mode)
- Belts: `BeltGrid.hp` (dense), stall below 30% (`line_damage` in balance.json), hp 0 = broken marker, repair restores. Hash includes hp only if hp != max. Goldens raid_turrets + contamination_crisis REGENERATED (behaviour change from biting, first diff tick 2200); full suite otherwise 425 green.
- Creatures: `ThreatSystem._attack_structure` (region T3, one call at top of `_tick_enemy`): bite adjacent belt, own `bite_cd`, `structure_dmg` per species (chewers 8, others 4). Machines: existing damage path, `broken` below 25% hp.
- Repair: `RepairJob.for_belt`, RepairGiver offers belts/machines only when plates are in storage; cost from data (1 plate/tile, 2/machine, `repair_cost` on def overrides). Wear-only repairs stay free. `repair_priority` mode rule.
- Rules: `set_rule` now accepts a mode string for rules with `modes` (`turret_target_mode`, `repair_priority`; hidden from HUD). "threatening" uses highest `threat_priority` building as anchor (T1's `pick_target` can replace `_threat_anchor`).
- View: belt shader tints damaged tiles (region T3 in belt_layer.gd); machines already show hp bar/smoke.
- Perf: perf_threat 300/250 p95 5.9 ms vs 5.5 baseline (noise; early out when no belts).
- Tests: tests/test_line_damage.gd (5). Not done: 2000-tick throughput test, 10-seed sweep; spec "scrap" cost uses plate (no scrap item).
- Docs: sim_contract.md updated.
