# W1 society report
- Branch: worktree of claude/colony-sim-godot-4jftsm (see git log, commit "W1: society conds + S1").
- New: sim/society/society_conds.gd (4 conds + lowest_block helper), data/quests_s1.json, tests/test_society_s1.gd (9 tests).
- Shared: quest_log.gd region W1 (register conds in _init; verbs ref_block/standing/mood_block), defs.gd region W1 (fallback list), data/mood.json thought left_to_ledger, sim_contract.md row.
- Conds are false when blocks/contraband missing or disabled; "any" counts only blocks with living members.
- S1: invoice beat (letter) -> next day ask with Pay/Refuse/Redirect; debt change only +1% on one Lifer.
- Tests: S1 starts 10/10 seeds with forced standing; each option; hash equal on replay.
