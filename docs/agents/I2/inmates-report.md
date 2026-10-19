# I2 report - The Informant quest + petition_fee_mult
- New: `data/quests_q13.json` (quest `q13_informant`; cfg min_day 12, fee 1.1 +0.05/day, max 1.3, tolerate +0.05).
- New: `sim/society/informant_mod.gd` (`InformantMod`, QuestLog code module: daily poll, resolve(option), state_parts).
- Regions: `quest_log.gd` `# region I2` in `_init` registers the module (no essence_drop_mult/review_sponsored edits);
  `defs.gd` fallback list (+quests_q13.json); `data/flavor.json` pa.informant_report (3 Warden lines);
  `docs/sim_contract.md` (1 row, merged two prose lines; stays 250 lines, no region marker because of the cap).
- Informant source: `sim.blocks.informant_id()` if present (I1), else bio tag/block "Informant"; tests inject `informant_fn`.
- Options: tolerate (fee up, his ration thought `ate_raw` daily), false_info (needs tag Clerk, idles him 1 day, option disabled without one),
  transfer (`debt._remove(c,"transferred")`). His death also ends it; fee returns to the pre-quest value.
- No debt effects added: the 2% cut cap is untouched. Hash part only after the quest starts (goldens unaffected).
- Tests `tests/test_informant.gd` (9): not before d12, fires 10/10 seeds, fee in (1.0,1.3] while alive and == 1.0 after each exit,
  each option, death, mid-quest replay hash.
- Untended colonies die ~day 9, so tests jump the clock to day 10.
- Not wired: the flavor line has no view trigger yet; nothing emits it.
