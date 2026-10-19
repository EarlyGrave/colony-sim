# TW4 report (relayed by orchestrator; worker could not write the file)
Branch worktree-agent-a038f190de22e10d0, commit cefdadb. Quick tests 14/14, goldens unchanged.
1. storyteller.gd region ST: `requires` accepts wave_pending / dormant / scent_high; colony_is_whole() false inside warning_ticks (no harmful events in the warning window).
2. data/events.json: scout_sighting (needs wave_pending; names origin side + threats.raid_objective_next if present), molt (needs dormant; +1 day to dormant_until if present). Fallbacks until W1/W2 land.
3. Summary columns flee_deaths, hidden_starve, objmet: tools/factory_bot.gd (region ST), factory_bot_report.gd, factory_eval_summary.py (PASS/FAIL for first two), balance_report.gd per seed.
4. Ledger keys expected: died:flee (W3), starve:hidden, raid_objective_met (W1) — confirm names at merge.
5. tests/test_storyteller.gd +3 tests. molt keeps no state (goldens dump all Storyteller vars).
