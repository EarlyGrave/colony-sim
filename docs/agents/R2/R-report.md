# R2 report: Q8 What the Creatures Wear + mimic
- data/quests_q8.json: trigger pollution_over 70 + quest_done pilgrims_of_the_slag (Q2's real id); 4 beats (drops, walk_in, hum, nest) then Feed / Cleanse / Study.
  Feed: wave_mult 0.5 2d, pollution +10%. Cleanse: 40 plate, pollution -15%. Study: flag clue_survey_tag, mod essence_drop_mult 2.0 2d, spawns 1 mimic.
- data/enemies.json: `mimic` (crawler stats, hp 42, dmg 8, move 5, threat_cost 2.0, `sprite: crawler`, `quest_only`). In no raid table, so waves never spawn it.
- Shared edits: QuestLog verb `spawn_enemy` (# region R2); Defs quest-file fallback list; WorldView uses def `sprite` alias; docs/sim_contract.md table row.
- Note: `essence_drop_mult` mod is set but no sim code reads it yet (follow-up consumer).
- Tests: tests/test_r2_q8.gd (6 tests) green. Goldens untouched (q_enabled false by default).
- Pillar table (21d, 5 seeds, standard_term): baseline mean_waves=6.2 [7,6,9,5,4]; throttle 4.0 [4,4,4,4,4]; gap 2.2 (>=2 kept; quest inert in bot runs).
- Full tools/run_tests_sharded.sh: see handback summary.
