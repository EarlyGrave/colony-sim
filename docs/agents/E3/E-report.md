# E3 Chain Gang Review - report
Gate: `balance.json e3_enabled` (false). Goldens untouched (gate off => no hash/behavior change).
Files: `sim/research/milestone_system.gd` (region E3), `data/milestones.json` (`e3_reviews`), `data/balance.json` (`e3_enabled`, `e3.clean_ref`), `tests/test_e3_reviews.gd`, `tools/review_bot.gd` (flags `--e3 --rich`), one-line region E3 in `sim/threats/threat_system.gd` (audit reschedule + bonus days).
- R4 "Ledger": remaining debt < 5% (kind `debt_left_below_pct`; "all cleared and gone" counts). Reward 30 essence, audits +1 d, rank "Trusted Inmate".
- R5 "Range": range score = sum over nets of max(0, supply-demand) x (1 - pollution_fraction/clean_ref 0.5), threshold 150 (JSON). Reward 50 essence, audits +1 d, rank "Chain Gang Foreman".
- E3 reviews are inserted before K2's outpost step so that step never blocks them.
## Bot table (review_bot, 40 d, seeds 1-5)
| mode | R1-3 | R4 | R5 |
|---|---|---|---|
| plain bot (--e3) | 5/5 | 0/5 (debt left 47-80%; colony dies d26-36) | 0/5 (no power built) |
| --rich (600 essence at d14, pays debts) | 5/5 | 5/5 | 0/5 (bot builds no power) |
Honest gap: the plain bot cannot reach R4 (target >=3/5 missed) or R5 (target >=1/5): it does not refine enough or build generators. R5 threshold 150 comes from building data (generators 100-240, machines 20-50), not bot-verified; needs a power-profile bot run to tune.
Tests: test_e3_reviews 3/3; full sharded suite: 721 passed, 0 failed.
