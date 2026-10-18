# T5 report (ecology + QA)
- New: data/ecology.json, sim/ecology/ecology_system.gd (Simulation.ecology, tick after mutation), tests/test_ecology.gd (8 tests), tools/qa_r3.gd.
- Nests: 2-4 per seed on reachable edge cells (own RNG seed^0xEC01, no sim.rng use). Bank += (local field + planet level) * absorb_rate * chip_pressure.
- Raids: `starved_max` (4) units free, extra units paid from banks (unit_cost); unaffordable units dropped. Waves leave from the fullest nest (edge pick still runs so wave_rng stream is kept).
- Rally: letter "Creatures are massing" `rally_ticks` (1800) before wave + HUD strip with compass side and 96x64 "Look" button (`# region T5` in view/hud.gd).
- Variants: `variants.mutant` block inside each enemies.json entry (a separate top-level key would break test_creature_sheets); tier by nest pollution with hysteresis (revert_ratio 0.8).
- Goldens regenerated: raid_turrets, contamination_crisis (wave clipping). Full suite 419 pass before golden regen; golden/contract_doc/ecology/ui/qa re-run green.
## QA 25d x seeds 1-5 (end day, cause; contam% d10/d20; kills; lost bld)
baseline: 21 dead, 22 dead, 22 dead, 25 alive, 25 alive (115 d); d10 30/29/38/36/34, d20 96/90/92/82/77; kills 24/24/29/26/27
automation: 23 dead, 25, 25, 24 dead, 23 dead (120 d = 1.04x); d10 33/26/40/36/34, d20 89/79/80/81/89; kills 25/27/37/27/26
chip: STUB = identical to automation (T4 not merged; slot_chip hook guarded) -> 1.04x. All <= 1.3x. Peak pollution 97-99.7%.
belt hp lost / repairs: n/a (T3 not merged). Planet death by day 21-24 is contamination, pre-existing.
## Gaps / notes
- Waves aim via old `_choose_target`; T1 `pick_target` absent in base. Rally is letter+HUD only (no pre-spawned gathering creatures).
- Nests are not drawn in the world view; chip pressure reads `sim.chips.active_count()` if T4 provides it.
- Run: `godot --headless --path . -s tools/qa_r3.gd` (~6 min).
