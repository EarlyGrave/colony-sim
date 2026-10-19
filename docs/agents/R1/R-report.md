# R1 report: Q10 Maintenance Window + Q3 Parole Board

Added
- data/quests_q10.json (`q10_maintenance`): trigger min_day 40 + flag installment_missed. Beat "silence" sets mod `pa_silent` for 0.25 d (6 h), then "Apology form 9-A" with raid / respect / sabotage as in the plan. Sabotage = pa_silent 3 d + petition_fee_mult 0.8 + wave_mult 1.1.
- data/quests_q3.json (`q3_parole_board`): trigger reviews_done 1; sponsor (-20 refined, flag review_sponsored, petition_fee_mult 1.1 permanent) / decline / bribe (-10 refined, flag audit_dates_known, audit_parts_mult 0.8 6 d). Hints show cost vs the 4/inmate installment.
- tests/test_r1_quests.gd (13 tests): per-option effects, sabotage blocks audits + quest letters then lifts, flag set by DebtSystem, trigger checks, answered-quest replay hash equal over 2 runs.

Sim edits (all in `# region R1`, no rng)
- DebtSystem._daily: sets quest flag `installment_missed` on the first unpaid installment after grace (only if quests enabled).
- QuestLog: MOD_DEFAULTS `pa_silent` 0.0; `letter` effect skipped while pa_silent.
- MilestoneSystem: `pa_silent()`; `deliver()` and `tick_reviews()` do nothing while silent.

Notes
- "Sponsor: rank +1 sooner" is only a flag (review_sponsored) plus fee mult; no review code reads it yet.
- Q3 costs (20 / 10 refined) are my choice, hence the plan left them open.
- Full suite result: see orchestrator line below.
