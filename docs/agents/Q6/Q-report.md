# Q6 Auditor Visits - report
Files: data/quests_q6.json (quest `q6_auditor`), tests/test_quest_q6.gd (6 tests, pass). No sim/shared code touched,
so goldens are untouched. Q0's loader must merge quests_q6.json (not yet present in the base commit).
Trigger: `{"tier_done": 2}` (Q0 poll should check MilestoneSystem.is_tier_done(2)). Beats: announce -> inspect (3 options).
Options: hide (-30 plate, wave_mult 1.2 for 5 d; `requires.items.plate=30`, disabled if short), show (debt_pct +10 as
kind "fine" = added interest, flag clue_manifest, letter "Biomass: forecast"), tour (petition_fee_mult 0.95, pollution +0.03).
Assumed names (reconcile with Q0): trigger key `tier_done`; option field `requires.items`; verbs `items` (negative count
= spend), `mod` with `name/value/days` (days 0 = permanent), `debt_pct` POSITIVE value = fine (the <=2% clamp must only
cap reductions), `flag{id}`, `letter{text}`, new verb `pollution{value}` (fraction added), new mod `petition_fee_mult`
(not in Q0's list), beat key `then`, option `label`. Tests use a local stub interpreter (no QuestLog dependency).
Not covered until Q0 lands: real fire-once via QuestLog.state, determinism through sim.
