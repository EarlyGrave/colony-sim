# F1a plan — balance restore (orchestrator, 2026-10-20; source: docs/design/next_batches.md §2 F1a)
Goal G (10 seeds / 60 d `tools/factory_eval.sh`): alive>=8 >= 8/10, audit >= 7, P1 >= 4, P3 >= 3, launch >= 1;
`kx_pillar_table --days=21 --seeds=5` standard_term gap >= 2.0, baseline >= 6. Dev now: 7/10, 5, 3, 2, 0, gap 2.2.
Host has 4 cores: each worker runs factory_eval with `--jobs=1` (3 workers in parallel). Use `--ov=JSON` to try a lever
without editing data; commit only the winning values. Every worker reports a table: lever | alive>=8 | audit | P1 | P3 | launch | gap.

One wave, 3 workers, disjoint files:
- **SK (skills + traits)** owns data/skills.json, data/traits.json, tools/skill_model.gd (new: days to L3/L6/L10 full-time, 3 seeds).
  Levers: init level_min 1→2, efficiency L0 0.30→0.45 (L1 0.60→0.65), trait hunger ±. Must keep test_waves / test_k5_power green.
- **TH (threat pressure)** owns data/threat.json, data/balance.json `scent` block and `pollution` block. Levers: lockdown_radius
  36→28/32, scent per_refine 0.15→0.10, scent decay. Must keep pillar gap >= 2.0 (refining must stay clearly dangerous).
- **LA (launch)** owns tools/factory_bot.gd (region LA), data/balance.json `repair_rock_fix`/`haul_blocked_fix`, sim fixes only inside
  `# region LA`. Goal: launch >= 1/10 at 60 d without lowering alive (copper/parts chain stuck on seeds 3/4/7/10).
Merge order LA → TH → SK, then one combined factory_eval + pillar table by the orchestrator; goldens regen once after the last merge.
Tests: each worker `tools/run_tests_quick.sh claude/colony-sim-godot-4jftsm`; no full suite. Report ≤ 30 lines in the reply.
