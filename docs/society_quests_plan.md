# Society quests plan (batch SQ) - 1 wave, 3 workers
Decided without owner, review. Source: docs/story/society.md (S1, S2, S3; S4/S5 deferred).
Rules for all: start with `git reset --hard claude/colony-sim-godot-4jftsm`; shared files only in
`# region <agent>`; sim deterministic (no new rng); in-game text English, <=70 chars/line;
debt cuts only via the `debt_pct` verb (clamped by QuestLog.MAX_DEBT_CUT_PCT, never promise >2%);
sim_contract.md stays <=250 lines (drop blank lines, 1 row per file); goldens unchanged (quests data-only,
hash parts only after a quest starts). DO NOT touch tools/factory_bot.gd or data/balance.json (worker SP).
Report <=30 lines in docs/agents/<W>/sq-report.md. Merge order: W1, W2, W3 (W2/W3 stub W1 conds in tests).

## W1 - conds + S1 Cohesion Fee
Owns: NEW sim/society/society_conds.gd, NEW data/quests_s1.json, NEW tests/test_society_s1.gd.
Shared: quest_log.gd `# region W1` in _init (register conds), defs.gd region W1 (quests_s1.json in fallback list), sim_contract.md 1 row.
- Conds via register_cond (value is a dict or int): `block_standing_below {block,v}`, `block_standing_above {block,v}`
  (block "any" = any block; reads sim.blocks, false if blocks missing), `contraband_stash_over n`
  (sim.contraband stash total; false if absent/disabled), `informant_alive` (sim.blocks.informant_id() living).
- Quest s1_cohesion_fee: trigger min_day 15 + block_standing_below {any,30}; beats/choices/Warden+letter text per society.md S1
  (Pay / Refuse / Redirect onto the Lifer). Redirect uses debt_pct +1 on one inmate only.
- Tests: each cond true/false/missing-system; S1 starts in >=7/10 seeds (scenario: force standing via blocks API, jump to day 15);
  each option applies its effects; debt_pct stays within cap; replay hash equal; quick suite green.

## W2 - S3 Whisper Network + informant PA wiring
Owns: NEW data/quests_s3.json, NEW tests/test_society_s3.gd.
Shared: defs.gd region W2 (fallback list), data/flavor.json region W2 (extra pa.informant_report lines), informant_mod.gd region W2 (emit line), sim_contract.md 1 row.
- Quest s3_whisper_network: trigger quest_done q13 + tier_done 2 (or petition phase 1) + informant_alive (use W1 cond;
  in tests register a stub cond until W1 merged). Options per society.md S3: decoy (needs Clerk alive else fails),
  bait the Warden (gamble 0.5), cut him off (remove_colonist, fee back to 1.0). mods: petition_fee_mult, audit_parts_mult only.
- Wire flavor: InformantMod emits a Warden PA line from pa.informant_report (via existing PA/letter path, deterministic pick by day)
  once per 3 days while the Informant lives; respects mod pa_silent.
- Tests: fires >=7/10 seeds (bot/scenario, q13 tolerated, tier 2 forced); each option; fee returns to 1.0 after cut-off;
  PA line emitted, not when pa_silent; determinism hash.

## W3 - S2 Pecking Order + contraband bot pass
Owns: NEW data/quests_s2.json, NEW tests/test_society_s2.gd, NEW tools/contraband_report.gd, data/contraband.json.
Shared: defs.gd region W3 (fallback list), sim_contract.md 1 row (only if contraband default changes).
- Quest s2_pecking_order: trigger block_standing_above {any,70} AND block_standing_below {any,30} (spread>=40);
  options Separate cells / Look away / Lifer mediates (gamble 0.6; lose = mood thought, no death). Stub W1 conds in tests.
- Bot pass: tools/contraband_report.gd, 10 seeds / 60 d, contraband off vs on (reuse factory_eval style, read-only of factory_bot).
  Metrics: alive>=8 count, pillar gap (baseline vs throttle), skim totals, shakedowns possible, wave bump.
  Decision rule: set `enabled` true ONLY if alive>=8 stays >=8/10 AND pillar gap >=2; else leave false.
  If flipped to true: regen goldens with make_gold (list changed ticks in report) and add DECISIONS.md line (orchestrator).
- Tests: S2 fires >=7/10 seeds (force standings); each option; spread shrinks after Separate; no death on mediation loss;
  contraband flag test reads data/contraband.json.

## Orchestrator after merge
quick suite per merge, full sharded + web_smoke before main; update PROGRESS/DECISIONS; log rollback point.
