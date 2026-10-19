# W3 report: S2 Pecking Order + contraband bot pass
- data/quests_s2.json: s2_pecking_order (min_day 8, block_standing_above/below {any,70}/{any,30}); options Separate (10 plate, strong -15 / weak +15, flag blocks_split), Look away (strong +5, mod weak_despair_mult 1.15 4d, Warden letter), Mediate (gamble 0.6: block_proud / lose = riot_witness thought, no death).
- Shared edits: quest_log.gd `# region W3` new effect verb `block_standing` {target strong|weak, delta}; block_system.gd despair_mult multiplies weak_despair_mult for blocks < thought_low (default 1.0, no state change); defs.gd region W3: loader accepts quests_s*.json + fallback list entry.
- W1 conds block_standing_above/below are stubbed in tests/test_society_s2.gd (only if not registered). W1 must keep the same cond names and {block,v} shape.
- tests/test_society_s2.gd: 7 tests (fires 10/10 forced seeds, need >=7; each option; separate shrinks spread by 30; mediation never kills; replay hash equal; contraband flag reads json).
- tools/contraband_report.gd: --on=0|1 --mode=bot|pillar; CBJSON per seed (alive, skimmed, recovered, stash, blackmarkets, bump steps).
- Bot pass (10 seeds, 60 d, FactoryBot, off vs on): results IDENTICAL on every seed that finished (on-runs of seeds 1 and 4 hit the 290 s timeout under 3 parallel jobs). skimmed=0, stash=0, blackmarkets=0, wave bump=0 everywhere: the bot never reaches despair_min 40, so contraband is inert in the bot economy.
- alive>=8 at day 60: only 5/10 seeds even with contraband OFF, so the rule "alive>=8 stays >=8/10" cannot be met. Pillar-gap run skipped (no behaviour difference to measure).
- DECISION: contraband `enabled` stays false. No golden regen, sim_contract unchanged.
- Follow-up: evaluating contraband needs a scenario forcing despair>=40 (or higher debt pressure); S4 on-ramp stays blocked on that.
