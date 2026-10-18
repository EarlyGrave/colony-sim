# B4 report (repair + expedition purpose) - all behind balance key `b4_enabled` (default false)
- data/recipes.json: `hand_plate` (6 essence_ore -> 1 plate, workbench, no tech; flag `"b4": true`). bill_system.add_bill refuses b4 recipes unless the key is on.
- data/contracts.json: `b4_templates` -> "Frontier Quota" demands 3 cinder_ore (`demand` field); contract_system offers it only with key on; can_deliver/deliver consume the demand.
- data/crises.json: top-level `b4_options.siege.tribute` (3 prism_ore, -6 taint, wave delay); merged into CrisisSystem.crises only with key on (kept out of the crisis dicts so golden dumps stay identical).
- UI: map_switcher shows a "Recall <outpost>" chip per non-active outpost; hud calls campaign.recall. (No expedition_dialog.gd exists; the panel is view/panels/expedition_panel.gd, untouched.)
- tools/bot_report.gd: `--b4` flag enables the key and adds a standing hand_plate bill (until 4).
- tests/test_b4_repair_exped.gd: 5 tests (recipe gated, plate produced, contract demand, crisis option gated, recall returns party).
- Goldens untouched/byte-identical; sharded suite: 687 passed, 0 failed.

## qa_r3 baseline profile, 25 d, seeds 1..5, belt repairs
- key off: 0,0,0,0,0 ; `--b4`: 2,11,9,4,14 (>0 on every seed). End days unchanged (seed 3 planet_dead d21 as before).

## Not done
- Bot-driven send_expedition completing the frontier contract on >=3/5 seeds is NOT measured (bot has no expedition play); the delivery path is covered only by a unit test with injected cinder_ore.
- contracts.json is shared with B2 (`clean_bonus`); I only appended a separate `b4_templates` key at the end of the file.
