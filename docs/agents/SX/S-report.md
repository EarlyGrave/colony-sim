# SX reconcile report (shuttle batch)
Done: panels/views use real APIs (`max_hp`, ticks `t_left`, `next_decay` absolute tick, `debt_rate_cut` in %), has_method guards dropped. ShuttlePanel: Deliver parts / Repair gantry / Launch buttons (64 px), part cost line. BeaconPanel: alive/max, next decay, % per day, launched, total cut.
WinScreen wired (`game.gd` region SX) to bus `shuttle_won`: days, debt paid, pollution, colonists + flavor `shuttle_ending`; Continue closes, New Run opens the new-game dialog.
`release_gantry` / `beacon_launcher` removed from FLAT_FALLBACK (new `Building3D.PROCEDURAL` + `has_model()`; WorldView draws no flat art); ShuttleView3D models scaled up ~2x, dark base + hazard stripes, bright towers, bigger shuttle/beacon/HP bar.
`s1_enabled` / `s2_enabled` now true (no s3/s4 flags exist). Goldens regenerated once: 0 hashes changed (features need P4). sim_contract.md untouched (250 lines, no new commands).
Tuning (data/shuttle.json): parts_need 40->24, siege_interval 1500->1200, min 600->500. Bot SUPPLY: fuel_cell 3/day d20, refined_essence 7/day d20 (scripted, no real factory); bot builds gantry + pole + 3 solar + 6 turrets (free placement), beacon launcher + solar, delivers parts, launches, repairs gantry <70% HP. Flags: `--turrets=0`, `--first=N`.
Bot table (standard, 60 d, tools/shuttle_bot.gd; turrets / no turrets):
| seed | P4 day | launch day | outcome | min gantry HP | beacons / debt cut | no-turret outcome (min HP) |
|---|---|---|---|---|---|---|
| 1 | 32 | 36.5 | won | 100% | 27 / 65 | won (18%), HQ lost d57 |
| 2 | 33 | 36.5 | won | 100% | 26 / 94 | won (100%) |
| 3 | 19(P3) 25 | 29.5 | won | 100% | 32 / 95 | won (100%) |
| 4 | 31 | 35.5 | won | 100% | 28 / 178 | won (19%) |
| 5 | 35 | none by d60 (refined short) | - | - | 1 / 15 | won d47.5 (77%) |
Launch 4/5 (turrets), survival 4/4; debt 81-100% by d60. Siege is easy with 6 turrets; no-turret runs drop to 18-19% HP, so defenses matter. Targets met (>=1/5, >=50%).
Screenshots (844x390, real game scene, tools/sx_shot.gd): docs/agents/SX/gantry_mid_build.png, countdown_siege.png, win_screen.png.
Tests: sharded suite 757 passed, 0 failed (x2); web_smoke PASS. Stray files /b1.txt, /b3.txt left at filesystem root by an early run (rm blocked).
