# R3 report
- QuestLog._trigger_ok: new conds sentence_min (sim.opts.sentence) and carry_debt (sim.opts.carry_debt >= n), in `# region R3`; new effect verb `gamble` {chance, win[], lose[]} = single sim.rng draw.
- data/quests_q11.json (open/bury/report), data/quests_q12.json (pay/contest/accept; flags clue_loop, clue_double, clue_quota). Defs fallback list + docs/sim_contract.md updated.
- tests/test_r3_ng_quests.gd: sentence 1 none, 2 only Q11, 3+carry+q11 done -> Q12, contest deterministic per seed.
- Sentence-1 sims unchanged (conds only evaluated for quests with those triggers); goldens untouched.
