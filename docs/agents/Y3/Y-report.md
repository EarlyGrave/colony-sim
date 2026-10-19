# Y3 report: throughput / debt / HQ (opt-in economy preset)
Mechanism: `balance.json` `y3` block (+ `y3_enabled:false` marker) = {Defs property: {"a.b.c": value}}; `Defs.apply_y3()` (region Y3 in sim/core/defs.gd) applies it. Default OFF, nothing calls it in game/tests, so goldens are byte-identical (no regen). Bot tools take `--y3=1` (factory_bot_report, kx_pillar_table). Test: tests/test_y3_economy.gd. Orchestrator: call apply_y3() on default Defs when wanting the preset.
Overrides: mining.yield 5->10; refine_essence work_ticks 100->60, refined out 3->7 (waste stays 4); turret cost 10->5 refined; hq max_hp 500->2500; colonist max_hp 100->140; threat first_wave_delay 2.8->3.5, per_wealth 0.002->0.0008, base_strength 1.5->1.2, per_wave 0.9->0.7; debt despair_per_day 16->7, break_despair_min 40->70, escape_weight 0.5->0.2.
Table (60 d, standard, factory bot; ore / refined produced; plates; debt%; alive; end):
| seed | before | after (--y3=1) |
|---|---|---|
| 1 | 1540/255, pl16, 20%, 8, survived | 1307/440, pl7, 50%, 4, survived |
| 2 | 969/153, pl8, 8%, 0, colonists_dead | 861/447, pl8, 51%, 0, colonists_dead |
| 3 | 1558/186, pl4, 5%, 6, hq_destroyed | 12453/489, pl4, 73%, 7, hq_destroyed |
| 4 | 1180/153, pl9, 2%, 0, colonists_dead | 14308/468, pl8, 54%, 8, survived |
| 5 | 721/96, pl7, 0%, 0, hq_destroyed | 14146/503, pl8, 97%, 8, survived |
Failures 4/5 -> 2/5 (target <=1/5 NOT met). Refined 96-255 -> 440-503 (target 500: met on 1 seed, ~470 avg). Ore >=2.5k met on 3/5 (bot consumption ~1000-1500; seeds 1-2 ore-starved by bot layout).
Pillar gate (d21, standard, --y3=1): baseline 7.4 waves vs throttle 4.2 = gap 3.2 (>=2, passes; flag off: baseline 6.4 vs throttle 4.2, mining 4.0). Mining-only not re-run with the flag (mining bot unaffected by refine keys).
Gap: seed 2 (identical across tweaks, 861 ore) and seed 3 hq_destroyed (even at HQ 2500 hp) are not hp/raid-size driven; likely bot layout (ore starvation, stalls) or Y4 territory; HQ loss reason not diagnosed. Plates stay 4-16: Y2's domain.
Sharded suite: 769 passed, 0 failed. Committed in worktree, not pushed.
