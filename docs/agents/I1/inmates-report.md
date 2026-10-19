# I1 Cell Block Standing - report

Branch: worktree-agent-adaa1dc62d7ea9b93 (based on claude/colony-sim-godot-4jftsm).

Done:
- `sim/society/block_system.gd` (`sim.blocks`) + `data/blocks.json`: blocks Lifer/Clerk/Zealot/Informant/Fresh Fish,
  Standing 0-100 (start 50, regresses 0.5/day to 50). + on installment rolled on time, - on member death,
  dock (escape) and each missed-installment day. Membership is data only (by colonist id, lazy for the
  starting crew), NO sim.rng use, kept in `blocks.member_of` (not in `bio`, so other state dumps are unchanged).
- Informant: exactly one per run once >= 6 living inmates (prefers a Fresh Fish); `sim.blocks.informant_id()` for I2.
- Despair: `DebtSystem._daily` multiplies despair gain by `blocks.despair_mult(c)` (1.5x at Standing 0, 1.0 at 50,
  0.75x at 100) and reports paid/missed to blocks (regions I1).
- Mood: thoughts `block_proud` (Standing >= 70) / `block_shamed` (<= 30) in mood.json, applied daily.
- Warden "Cohesion fee": a block quiet for 6 days with Standing >= 55 emits `letter_received("Cohesion fee", ...)`.
- Bus: `block_standing_changed(block, standing)`. Hash: `SaveGame.state_hash` appends `blocks.state_parts()` only
  once Standing moved or the Informant exists. Save/load is command-log replay, so Standing round-trips (tested).
- `sim_contract.md`: blocks.json row added (one blank line dropped to stay at 250 lines).
- Goldens regenerated (intended: new hash part): raid_turrets, preset_short_stay/standard_term/hard_time first at
  tick 1800 (13/30 hashes), contamination_crisis first at tick 3000 (1/30). Only the `core` part differs.
- Tests: `tests/test_blocks.gd` (7: block assignment, one Informant, bounds [0,100], despair mult, disabled neutral,
  determinism hash, save/load). `tools/run_tests_quick.sh`: 14 passed, 0 failed.
- `tools/block_report.gd`: 10 seeds/60 d, blocks off vs on (breaks+riots) and per-block despair spread.
  Final tuning (regress 1.0, missed 0.2/day, mult 1.2/0.9): events off=168 on=168 (ratio 1.00), spread>0 in 10/10. First tuning (mult 1.5, loss 1.5/day) gave ratio 2.17, rejected. Bot rarely moves Standing (mostly stays ~50): a stronger effect needs a live essence economy.

Notes: factory_bot / shuttle / quest_log essence_drop_mult / review_sponsored untouched.
