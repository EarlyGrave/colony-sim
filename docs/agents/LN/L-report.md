# LN report: launch attempt 2 + quest-mod consumers
Task 2 DONE. Task 1 NOT MET (0/10 launch at 60 d and at 90 d); no data tweak kept.

| change | where |
|---|---|
| essence_drop_mult: a kill drops round(balance creature_essence_base(1) * (mult-1)) essence_ore at the kill cell (ledger "creature"); 0 at default 1.0 | threat_system.damage_enemy |
| review_sponsored: next review counts +b3.sponsor_boost (0.25) further along (if already >0), flag cleared when that review completes | milestone_system._sponsored_progress |
| mod default essence_drop_mult 1.0 | quest_log MOD_DEFAULTS |
| bot knobs (region LN): refinery2 (tier 2), stop_research (after P3), prebuild fuel_cell bill (after P3), hoard from tier 2 | tools/factory_bot.gd |
| tests/test_ln_consumers.gd (3) | green |

| 10 seeds | before | all bot knobs | +P4 30/parts_need 12 | 90 d |
|---|---|---|---|---|
| launch | 0 | 0 | 0 | 0 |
| audit tier2 | 7 | 7 | 7 | 10 |
| alive>=8 (end) | 8 | 9 | 9 | 5 |
| P3 | 3-4 | 3 | 3 | 3 |
| P4 reach | 3 | 3 (seeds 1,5,7) | 3 | 3 |
extra_miners=3: worse (2 hq_destroyed, P3 2/10), dropped.

Why it fails: seed 7 ledger over 60 d: refinery recipe output only 114 refined (research 276 spent but 240 refunded, debt 84, construction 21, petition 17). Stock is always 0, so extra refineries (not ore-limited? ore 1035 mined) and hoarding change nothing (runs byte-identical to baseline); lowering P4 to 30 and parts to 12 still left P4 short by 19-27. A launch needs ~3x the refined throughput (ore-to-refinery logistics / refine yield), not a bot or amount tweak. Data tweaks reverted.
Next: investigate why 1035 ore mined gives only 114 refined (ore sitting in construction/stock vs refinery feed), or raise refine yield with a pillar re-check.
Pillar (kx_pillar_table): baseline 6.2 vs throttle 4.0 (gap 2.2 OK). Goldens untouched. Full sharded suite: 862 passed, 0 failed.
