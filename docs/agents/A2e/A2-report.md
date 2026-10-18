# A2e report: machine contamination, balance, e2e test, QA bot, phone UI
Branch a2e-work (base 5c4b22b), not pushed. Full suite 385 pass, 0 fail.
- Machines already contaminate like the refinery (batch_refined: per_batch + waste). Forecast now includes them: ContaminationSystem.machine_rate_per_day() (processors mid-batch) feeds ForecastModel.estimate(..., machine_rate); rate = max(smoothed, machine).
- tests/test_automation_flow.gd (3 tests): miner, 4 belts, smelter, 4 belts, storage_in via Scenario.build_chain (belts by place_belt, node purity forced normal). Result: 19.5 refined/day per chain; contamination 5.5/day with 1 chain vs 14.4/day with 3 (2.6x >= 2.5x).
- Infinite nodes: MineJob no longer clears the designation (stays until the player removes it). test_nodes updated. ESSENCE_BUDGET and the re-designate hook removed from tests/scenario.gd.
- Balance (data/balance.json): contamination per_batch 1.15 to 0.7, per_waste_per_day 0.04 to 0.02; threat per_wave 0.6 to 0.9 (no-turret colony still dies on wave 2-3, turret tests intact). per_contamination 0.1 broke test_waves, reverted.
- Bugs found and fixed: (1) blueprints on node cells (miner) could never be delivered/built (reachable() on a solid cell): BuildingSystem.bp_stand + BuildGiver/DeliverMaterialsGiver/BuildJob/DeliverJob. (2) work.json: construction now precedes mining, else permanent mining designations starve building. (3) storage_in/out were buildable:false though the A2d machine row offers them: now true.
- QA bot: tests/qa_bot.gd (day>=2) and tools/bot_report.gd (tick 600, plus 16 nodes designated) place miner+smelter+storage_in via place_building and belts via place_belt (Scenario.build_chain). Replay tests green.

Bot 25 days x 5 seeds (baseline before: 2 alive, 3 hq_destroyed):
| seed | end day / cause | contam d10 | d20 | refined | miner+smelter built |
|---|---|---|---|---|---|
| 1 | 17 hq_destroyed | 32 | - | 240 | no (not finished) |
| 2 | 17 hq_destroyed | 27 | - | 189 | yes |
| 3 | 22 planet_dead | 42 | 94 | 270 | yes |
| 4 | 25 alive | 33 | 64 | 204 | yes |
| 5 | 25 alive | 34 | 78 | 246 | yes |
Now 2 alive, 2 hq_destroyed, 1 planet_dead: same class spread.

Phone UI (screenshots 2532x1170, scale 2.55 = 844x390 css at DPR 3; tools/screenshot.gd gained --w --h --cat): category popup starts right of the colonist column (view/hud.gd). Automation panel moved from map middle-right to a full-width strip docked above toolbar/popup (view/game.gd _setup_automation). Status line showed untruncated at this size. V1 files untouched.
