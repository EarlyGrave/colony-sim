# R4 report: shuttle launch by the real bot (NOT MET, partial)
| metric (10 seeds, 60 d) | before | after R4 bot change | target |
|---|---|---|---|
| launch | 0/10 | 0/10 | >=1 |
| audit tier 2 | 7/10 | 7/10 | >=6 PASS |
| alive>=8 | 8/10 (seeds 2,3 hq_destroyed) | 8/10 | >=7 PASS |
| P1 / P3 | 4 / 4 | 4 / 4 | - |
| reach P4 | seeds 1,5,6,7 | same, all stuck "P4: refined_essence -48..-57 (stock 0)" | - |

Change: tools/factory_bot.gd `# region R4` `_hoarding()`: from petition III on (or shuttle unlocked) no extra debt payments or contracts, so refined is kept for P4 and parts (installments and turrets still first). Knob pg_bot.hoard (default 1). Result identical to baseline: stock stays 0, so refined (~450-680 per 60 d) goes elsewhere (turrets, research, installments), and P3 lands d37-43, leaving ~20 d for P4 (60 refined) plus 24 shuttle parts (24 refined, 48 plates, 24 fuel cells).

Not done: haul_blocked_fix NOT enabled (DB measured it worse for survival; no run shows alive>=8 would hold). Goldens NOT regenerated (no sim/balance change; byte-identical). Pillar table and web_smoke not re-run (nothing sim-side changed). Full suite not run (orchestrator instruction).

Why not met: 60 d is too short for the current economy. Needs a 2nd refinery plus earlier ore (PG next bottleneck: unhaulable deposit-anchored miners, i.e. haul_blocked_fix needs its own balance pass) or a longer horizon (--days=90). Suggested next: bot builds a 2nd refinery after P2, stops research spending after P3, tune with the fix on.

Eval cost: ~1 h per 10-seed run at host load 10-20 (use --jobs=3 --timeout=1500).
